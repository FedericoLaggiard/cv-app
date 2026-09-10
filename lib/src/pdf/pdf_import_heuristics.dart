/// Pure text→schema mapping heuristics for PDF auto-import (ticket 13, used
/// by [PdfImporter] in `pdf_importer.dart`, ticket 28).
///
/// Deliberately has no dependency on Flutter or `pdfrx` — the caller maps
/// whatever PDF-extraction library it uses into [PdfPageText]/[PdfCharRect],
/// so this module is `dart test`-able on its own and portable if the PDF
/// backend ever changes.
///
/// Philosophy (ticket 13, amended by ticket 53/Slice P): ticket 13's
/// original precision-over-recall stance — never auto-filling
/// nome/cognome/headline, ruolo/azienda, titolo/istituto — was correct only
/// under pure auto-import, where a wrong field silently lands in a saved CV.
/// Slice O's review step (`ImportProposalReport`) changed that: a wrong
/// suggestion now costs a visible correction, not a silent error. This
/// module now **proposes aggressively** wherever a plausible candidate
/// exists, and marks every proposal derived from a statistical/majority rule
/// (rather than an explicit textual match) as `certain: false` so the review
/// step can flag it. Anything still not confidently mapped lands in a
/// custom section titled "Da rivedere".
library;

import 'package:uuid/uuid.dart';

import '../domain/cv_document.dart';
import '../domain/cv_section.dart';
import '../domain/enums.dart';
import '../domain/year_month.dart';
import 'import_proposal_report.dart';

const _uuid = Uuid();

/// One character's glyph + bounding box, in PDF page coordinates.
class PdfCharRect {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;

  const PdfCharRect({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// A page's extracted characters, in reading order.
class PdfPageText {
  final int pageIndex;
  final List<PdfCharRect> chars;

  const PdfPageText({required this.pageIndex, required this.chars});

  /// Concatenates [chars] into plain text. Callers building fixtures for
  /// this module normally set one [PdfCharRect] per *line* (not per glyph)
  /// with `text` holding the whole line — [height] then doubles as "this
  /// line's font size" for the heading-detection proxy.
  String get plainText => chars.map((c) => c.text).join('\n');
}

// -------------------- Section title dictionary --------------------

/// IT+EN synonyms per recognized section. A `const` literal rather than an
/// asset YAML (per ticket 28 implementation notes): the list is small,
/// static, and this keeps the module dependency-free and trivially testable.
const Map<SectionKind, List<String>> _sectionTitleSynonyms = {
  SectionKind.sommario: [
    'sommario',
    'profilo',
    'profile',
    'about me',
    'about myself',
    'summary',
    'chi sono',
  ],
  SectionKind.esperienze: [
    'esperienza',
    'esperienze',
    'esperienze professionali',
    'esperienza lavorativa',
    'esperienze lavorative',
    'experience',
    'work experience',
    'professional experience',
    'employment history',
  ],
  SectionKind.formazione: [
    'formazione',
    'istruzione',
    'formazione e istruzione',
    'percorso di studi',
    'education',
    'education and training',
    'academic background',
  ],
  SectionKind.skill: [
    'skill',
    'skills',
    'competenze',
    'competenze tecniche',
    'technical skills',
    'hard skills',
  ],
  SectionKind.lingue: [
    'lingue',
    'lingue straniere',
    'competenze linguistiche',
    'languages',
    'language skills',
  ],
  SectionKind.certificazioni: [
    'certificazioni',
    'certificati',
    'certifications',
    'certificates',
    'licenses and certifications',
  ],
};

/// Normalizes a heading candidate for dictionary lookup: trims, lowercases,
/// and folds `&` into `and` (`EDUCATION & TRAINING` -> `education and
/// training`) so the dictionary only needs one spelling per synonym.
String _normalizeHeadingText(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// -------------------- Slice P (ticket 53): aggressive-mapping vocab -------

/// Legal-form markers that signal "this text names a company", used by the
/// per-document ruolo/azienda ordering vote.
final RegExp _companyMarkerRe = RegExp(
  r'\b(Srl|S\.p\.A\.?|S\.r\.l\.?|Spa|Inc\.?|Ltd\.?|GmbH|SA|LLC|Corp\.?)\b',
);

/// Job-title vocabulary that signals "this text names a role", used by the
/// per-document ruolo/azienda ordering vote.
final RegExp _roleVocabRe = RegExp(
  r'\b(Architect|Engineer|Developer|Manager|Lead(?:er)?|Analyst|'
  r'Sviluppat(?:ore|rice|ori)|Consulente|Responsabile)\b',
  caseSensitive: false,
);

/// Degree vocabulary that signals "this text names a qualification", used
/// by the per-document titolo/istituto ordering vote.
final RegExp _degreeVocabRe = RegExp(
  r'\b(Laurea|Diploma|Bachelor|Master|PhD|Dottorato|Degree)\b',
  caseSensitive: false,
);

/// Institution vocabulary that signals "this text names a school", used by
/// both the titolo/istituto vote and the comma-split explicit pattern.
/// Deliberately excludes the bare word "School" — too common inside degree
/// titles themselves (e.g. "Secondary School Diploma") to be a safe marker
/// on its own; callers that scan a whole line for this pattern should take
/// the *last* match so a genuine institution name later in the line still
/// wins over an incidental "School"/"Scuola" earlier in a degree title.
final RegExp _institutionVocabRe = RegExp(
  r'\b(Universit[aà]|University|Istituto|Politecnico|College|Academy|'
  r'Institute|Scuola)\b',
  caseSensitive: false,
);

/// `{ruolo} presso {azienda}` / `{ruolo} at {azienda}` — the keyword itself
/// disambiguates the order, so a match is an explicit (certain) signal, not
/// a per-document vote. Anchored to the whole line and side lengths capped
/// so it doesn't fire on an ordinary sentence that happens to contain " at ".
final RegExp _connectorLineRe = RegExp(
  r'^(\S(?:.{0,60}\S)?)\s+(?:presso|at)\s+(\S(?:.{0,60}\S)?)$',
  caseSensitive: false,
);

/// `{left} | {right}` — the pipe is an explicit separator, but which side is
/// role vs. company still needs vocabulary or a document-wide vote.
final RegExp _pipeSplitLineRe = RegExp(r'^(.+?)\s*\|\s*(.+)$');

/// `{titolo}, {istituto}` — comma-separated formazione line.
final RegExp _commaSplitLineRe = RegExp(r'^(.+?),\s*(.+)$');

/// A block-boundary anchor embedded mid-line rather than alone on its own
/// line: `{titolo} (2012 – 2020): {descrizione}` (a common "rolled-up
/// earlier experience" summary pattern). Only years, no months.
final RegExp _embeddedYearRangeLineRe = RegExp(
  r'^(.*?)\s*\((\d{4})\s*[\-–—]\s*'
  r'(\d{4}|present|current|now|oggi|in corso|presente)\)\s*:?\s*(.*)$',
  caseSensitive: false,
);

/// CEFR levels plus the "native speaker" marker, used for Lingue parsing.
final RegExp _cefrLevelRe = RegExp(
  r'\b(A1|A2|B1|B2|C1|C2)\b|\b(madrelingua|mother tongue)\b',
  caseSensitive: false,
);

const Map<String, LivelloCefr> _cefrWireToLevel = {
  'a1': LivelloCefr.a1,
  'a2': LivelloCefr.a2,
  'b1': LivelloCefr.b1,
  'b2': LivelloCefr.b2,
  'c1': LivelloCefr.c1,
  'c2': LivelloCefr.c2,
};

/// A line with 2+ occurrences of the same repeated separator (`|`, `•`,
/// `,`) is a skill-tags line (ticket 53 user story 5).
final RegExp _repeatedPipeRe = RegExp(r'\|.*\|');
final RegExp _repeatedBulletRe = RegExp(r'•.*•');
final RegExp _repeatedCommaRe = RegExp(r',.*,');

// -------------------- Contact regexes (signal-first) --------------------

final RegExp _emailRe = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
);
final RegExp _phoneRe = RegExp(
  r'(?<!\w)(\+\d{1,3}[ \-.]?)?(\(?\d{2,4}\)?[ \-.]?)?\d{3,4}[ \-.]?\d{3,4}(?!\w)',
);
final RegExp _linkedinRe = RegExp(
  r'(?:https?://)?(?:www\.)?linkedin\.com/in/[A-Za-z0-9_-]+/?',
  caseSensitive: false,
);
final RegExp _githubRe = RegExp(
  r'(?:https?://)?(?:www\.)?github\.com/[A-Za-z0-9_-]+/?',
  caseSensitive: false,
);

/// Generic URLs: an explicit `http(s)://` scheme always counts (any TLD),
/// otherwise the last label must be in a TLD allowlist. A blocklist of
/// non-TLD extensions (`.js`, `.ts`, ...) would only ever cover today's
/// false positives — the allowlist fails predictably instead: at worst it
/// misses an exotic TLD, it never invents a link from a library name like
/// `React.js` or an abbreviated name like `A.B.` (ticket 51).
final RegExp _urlRe = RegExp(
  r'(?:https?://[^\s]+)'
  r'|(?:(?:www\.)?[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*'
  r'\.(?:com|org|net|io|dev|it|eu|co|me|ai|app|xyz|info|biz|edu|gov|tv|cc'
  r'|us|uk|de|fr|es|nl)(?:/[^\s]*)?)',
  caseSensitive: false,
);

// -------------------- Date parsing --------------------

const Map<String, int> _monthNames = {
  'gennaio': 1,
  'gen': 1,
  'january': 1,
  'jan': 1,
  'febbraio': 2,
  'feb': 2,
  'february': 2,
  'marzo': 3,
  'mar': 3,
  'march': 3,
  'aprile': 4,
  'apr': 4,
  'april': 4,
  'maggio': 5,
  'mag': 5,
  'may': 5,
  'giugno': 6,
  'giu': 6,
  'june': 6,
  'jun': 6,
  'luglio': 7,
  'lug': 7,
  'july': 7,
  'jul': 7,
  'agosto': 8,
  'ago': 8,
  'august': 8,
  'aug': 8,
  'settembre': 9,
  'set': 9,
  'sep': 9,
  'september': 9,
  'sept': 9,
  'ottobre': 10,
  'ott': 10,
  'october': 10,
  'oct': 10,
  'novembre': 11,
  'nov': 11,
  'november': 11,
  'dicembre': 12,
  'dic': 12,
  'december': 12,
  'dec': 12,
};

const List<String> _currentMarkers = [
  'in corso',
  'presente',
  'present',
  'current',
  'ongoing',
  'today',
  'oggi',
  'now',
];

/// True if [token] (already lowercased+trimmed) marks an open-ended range.
bool isCurrentMarker(String token) => _currentMarkers.contains(token);

/// Parses a single free-text month+year token (not a range) such as
/// "gennaio 2020", "Jan 2020", "01/2020", "1-2020" into a [YearMonth].
/// Returns `null` on anything that doesn't confidently look like one.
YearMonth? tryParseFreeTextYearMonth(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  // Numeric day/month/year (`01/06/2024`, Europass-style). Checked before
  // the month/year form below: distinct group count, anchored, so the two
  // never collide.
  final numericDmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$')
      .firstMatch(text);
  if (numericDmy != null) {
    final day = int.parse(numericDmy.group(1)!);
    final month = int.parse(numericDmy.group(2)!);
    final year = int.parse(numericDmy.group(3)!);
    if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
      return YearMonth(year, month);
    }
    return null;
  }

  final numeric = RegExp(r'^(\d{1,2})[/\-.](\d{4})$').firstMatch(text);
  if (numeric != null) {
    final month = int.parse(numeric.group(1)!);
    final year = int.parse(numeric.group(2)!);
    if (month >= 1 && month <= 12) {
      return YearMonth(year, month);
    }
    return null;
  }

  final yearOnlyMonthName = RegExp(
    r'^([A-Za-zàèéìòù]+)[.\s]+(\d{4})$',
    caseSensitive: false,
  ).firstMatch(text);
  if (yearOnlyMonthName != null) {
    final monthWord = yearOnlyMonthName.group(1)!.toLowerCase();
    final month = _monthNames[monthWord];
    if (month != null) {
      return YearMonth(int.parse(yearOnlyMonthName.group(2)!), month);
    }
    return null;
  }

  // Day + month-name + year (`1 Jun 2024`, `30 SEP 2007`, Europass-style).
  // The day is parsed only to validate the token and then discarded — the
  // schema (ticket 01) is month+year.
  final dayMonthNameYear = RegExp(
    r'^(\d{1,2})[.\s]+([A-Za-zàèéìòù]+)\.?[.\s]+(\d{4})$',
    caseSensitive: false,
  ).firstMatch(text);
  if (dayMonthNameYear != null) {
    final day = int.parse(dayMonthNameYear.group(1)!);
    final monthWord = dayMonthNameYear.group(2)!.toLowerCase();
    final year = int.parse(dayMonthNameYear.group(3)!);
    final month = _monthNames[monthWord];
    if (day >= 1 && day <= 31 && month != null) {
      return YearMonth(year, month);
    }
    return null;
  }

  return null;
}

/// A parsed date range: `start`, optional `end`, and whether it's
/// open-ended ("in corso"/"present"/...).
class ParsedDateRange {
  final YearMonth start;
  final YearMonth? end;
  final bool current;
  const ParsedDateRange({required this.start, this.end, this.current = false});
}

final RegExp _rangeSplitRe = RegExp(r'\s*[\-–—]\s*');

/// Parses a full date-range line such as "Gennaio 2020 - Marzo 2022",
/// "01/2020 – in corso", "Jan 2020 — Present". Returns `null` if it can't
/// confidently find at least a start date.
ParsedDateRange? tryParseDateRangeLine(String line) {
  final text = line.trim();
  if (text.isEmpty) return null;

  final parts = text.split(_rangeSplitRe);
  if (parts.isEmpty) return null;

  final start = tryParseFreeTextYearMonth(parts[0]);
  if (start == null) return null;

  if (parts.length == 1) {
    return ParsedDateRange(start: start);
  }

  final endToken = parts.sublist(1).join('-').trim().toLowerCase();
  if (isCurrentMarker(endToken)) {
    return ParsedDateRange(start: start, current: true);
  }

  final end = tryParseFreeTextYearMonth(parts.sublist(1).join('-'));
  if (end == null) {
    // Unrecognized tail: still return the start-only range rather than
    // discarding a confidently-parsed start date.
    return ParsedDateRange(start: start);
  }
  return ParsedDateRange(start: start, end: end);
}

/// Any line in a block that parses as a date range is treated as that
/// item's date-range line for grouping purposes.
bool looksLikeDateRangeLine(String line) => tryParseDateRangeLine(line) != null;

/// True if [text] matches one of the known section-title synonyms
/// case-insensitively, regardless of its geometry. Exposed (ticket 50) so
/// the conversion-rate corpus test can tell a heading line — structurally
/// consumed by [buildFromPages], never "lost" — apart from a line that
/// truly went unaccounted for.
bool isRecognizedSectionHeading(String text) {
  final normalized = _normalizeHeadingText(text);
  return _sectionTitleSynonyms.values.any((s) => s.contains(normalized));
}

// -------------------- Contact extraction --------------------

ContattiData _extractContacts(
  String fullText,
  ImportProposalReportBuilder report,
) {
  final email = _emailRe.firstMatch(fullText)?.group(0);
  if (email != null) {
    report.add('contatti.email', certain: true, sourceLines: [email]);
  }
  final links = <Link>[];

  final linkedin = _linkedinRe.firstMatch(fullText)?.group(0);
  if (linkedin != null) {
    links.add(Link(label: 'LinkedIn', url: _withScheme(linkedin)));
  }
  final github = _githubRe.firstMatch(fullText)?.group(0);
  if (github != null) {
    links.add(Link(label: 'GitHub', url: _withScheme(github)));
  }

  // Generic URLs, excluding ones already captured as LinkedIn/GitHub/email.
  for (final match in _urlRe.allMatches(fullText)) {
    final url = match.group(0)!;
    if (url == linkedin || url == github) continue;
    if (email != null && email.contains(url)) continue;
    if (linkedin != null && linkedin.contains(url)) continue;
    if (github != null && github.contains(url)) continue;
    links.add(Link(label: 'Link', url: _withScheme(url)));
  }

  final phoneMatch = _findPhone(fullText, email);
  if (phoneMatch != null) {
    report.add('contatti.telefono', certain: true, sourceLines: [phoneMatch]);
  }

  return ContattiData(email: email, telefono: phoneMatch, link: links);
}

String _withScheme(String url) =>
    url.startsWith(RegExp(r'https?://')) ? url : 'https://$url';

String? _findPhone(String fullText, String? email) {
  // Strip the email first so its digits (if any) never get mistaken for a
  // phone number.
  final withoutEmail = email == null
      ? fullText
      : fullText.replaceAll(email, '');
  for (final match in _phoneRe.allMatches(withoutEmail)) {
    final candidate = match.group(0)!.trim();
    final digitCount = candidate.replaceAll(RegExp(r'\D'), '').length;
    if (digitCount >= 7 && digitCount <= 15) {
      return candidate;
    }
  }
  return null;
}

// -------------------- Section splitting --------------------

class _DetectedSection {
  final SectionKind kind;
  final int startLine;
  const _DetectedSection(this.kind, this.startLine);
}

/// Every non-empty line across all pages, in reading order. [isHeadingSized]
/// is the geometric heading proxy: this line's raw height compared against
/// its *own page's* median line-height, not a global one — pages in a
/// multi-page CV can use different type scales, so a single document-wide
/// median would misjudge headings on whichever page departs from it.
class _FlatLine {
  final String text;
  final bool isHeadingSized;
  const _FlatLine(this.text, this.isHeadingSized);
}

/// Matches standalone pagination markers: `Page 1/2`, `Pagina 1 di 2`,
/// `Page 1 of 2`, `Page 1-2`, or a bare `1/2`. Only the slash form is
/// recognized without a `page`/`pagina` prefix — an unprefixed `N-M` or
/// `N of M` is plausible CV content (a year range, a count) and must not
/// be eaten (ticket 51).
final RegExp _paginationLineRe = RegExp(
  r'^(?:(?:page|pagina)\s*\d{1,4}\s*(?:/|-|di|of)\s*\d{1,4}'
  r'|\d{1,4}\s*/\s*\d{1,4})$',
  caseSensitive: false,
);

String _normalizeForRecurrence(String text) => text.trim().toLowerCase();

List<_FlatLine> _flatten(List<PdfPageText> pages) {
  final nonEmptyPages = [
    for (final page in pages)
      if (page.chars.isNotEmpty) page,
  ];

  // Header/footer detection by positional recurrence: a line that appears
  // verbatim as the first (or last) non-empty line on 2+ pages is treated
  // as running header/footer chrome, not content (ticket 51).
  final firstLineTexts = <String>[];
  final lastLineTexts = <String>[];
  for (final page in nonEmptyPages) {
    final nonEmptyChars = page.chars.where((c) => c.text.trim().isNotEmpty);
    if (nonEmptyChars.isEmpty) continue;
    firstLineTexts.add(_normalizeForRecurrence(nonEmptyChars.first.text));
    lastLineTexts.add(_normalizeForRecurrence(nonEmptyChars.last.text));
  }
  bool recurs(String normalized, List<String> positionTexts) =>
      positionTexts.where((t) => t == normalized).length >= 2;

  final lines = <_FlatLine>[];
  for (final page in nonEmptyPages) {
    final heights = page.chars.map((c) => c.height).toList()..sort();
    final pageMedian = heights[heights.length ~/ 2];
    final nonEmptyChars = page.chars
        .where((c) => c.text.trim().isNotEmpty)
        .toList();
    for (var i = 0; i < page.chars.length; i++) {
      final c = page.chars[i];
      final text = c.text.trim();
      if (text.isEmpty) continue;
      if (_paginationLineRe.hasMatch(text)) continue;

      final normalized = _normalizeForRecurrence(text);
      final isFirstOnPage = identical(c, nonEmptyChars.first);
      final isLastOnPage = identical(c, nonEmptyChars.last);
      if (isFirstOnPage && recurs(normalized, firstLineTexts)) continue;
      if (isLastOnPage && recurs(normalized, lastLineTexts)) continue;

      lines.add(_FlatLine(text, c.height >= pageMedian));
    }
  }
  return lines;
}

List<_DetectedSection> _detectSectionHeadings(List<_FlatLine> lines) {
  final found = <_DetectedSection>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.isHeadingSized) continue;
    final normalized = _normalizeHeadingText(line.text);
    for (final entry in _sectionTitleSynonyms.entries) {
      if (entry.value.contains(normalized)) {
        found.add(_DetectedSection(entry.key, i));
        break;
      }
    }
  }
  return found;
}

/// A heading-sized, short, ALL-CAPS line that isn't one of the known
/// section-title synonyms (ticket 53, item 5): "PROGETTI", "PUBBLICAZIONI".
/// Requiring ALL-CAPS deliberately keeps this conservative — without it,
/// synthetic fixtures where every line shares one geometric size (no real
/// heading/body distinction) would misfire on ordinary short content lines
/// like a person's name. Contact-ish or date-range lines are excluded too:
/// they're short by nature but never section titles.
bool _looksLikeUnrecognizedHeading(_FlatLine line) {
  if (!line.isHeadingSized) return false;
  final text = line.text.trim();
  if (text.isEmpty) return false;
  if (text != text.toUpperCase() || text == text.toLowerCase()) return false;
  if (text.split(RegExp(r'\s+')).length > 6) return false;
  if (isRecognizedSectionHeading(text)) return false;
  if (looksLikeDateRangeLine(text)) return false;
  if (_emailRe.hasMatch(text) ||
      _urlRe.hasMatch(text) ||
      _phoneRe.hasMatch(text)) {
    return false;
  }
  return true;
}

/// Every heading boundary in the document, recognized and unrecognized
/// alike, in document order — the unified list [buildFromPages] walks to
/// split the body into sections.
class _HeadingBoundary {
  final SectionKind? kind;
  final String originalText;
  final int startLine;
  const _HeadingBoundary({
    this.kind,
    required this.originalText,
    required this.startLine,
  });
}

List<_HeadingBoundary> _detectAllHeadingBoundaries(List<_FlatLine> lines) {
  final recognizedLines = <int>{};
  final found = <_HeadingBoundary>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.isHeadingSized) continue;
    final normalized = _normalizeHeadingText(line.text);
    for (final entry in _sectionTitleSynonyms.entries) {
      if (entry.value.contains(normalized)) {
        found.add(
          _HeadingBoundary(
            kind: entry.key,
            originalText: line.text,
            startLine: i,
          ),
        );
        recognizedLines.add(i);
        break;
      }
    }
  }
  for (var i = 0; i < lines.length; i++) {
    if (recognizedLines.contains(i)) continue;
    if (_looksLikeUnrecognizedHeading(lines[i])) {
      found.add(_HeadingBoundary(originalText: lines[i].text, startLine: i));
    }
  }
  found.sort((a, b) => a.startLine.compareTo(b.startLine));
  return found;
}

/// First non-empty line of the document, before any recognized heading:
/// nome/cognome (ticket 53, item 2). 2–4 capitalized tokens, no digits or
/// `@`, not itself a section-title synonym. Split convention: first token is
/// `nome`, the rest is `cognome`. `certain` is `false` once there are more
/// than 2 tokens — compound names (`Maria Grazia Del Bianco`) will split
/// wrong and the review step should flag it.
({String nome, String cognome, bool certain, String sourceLine})?
_tryExtractName(
  List<_FlatLine> lines,
  List<_DetectedSection> recognizedHeadings,
) {
  if (lines.isEmpty) return null;
  // "Before any recognized heading" only ever matters for line 0 — the
  // candidate is always the document's first line — so this is just: is
  // line 0 itself a recognized heading? An unrecognized-but-title-shaped
  // heading (item 5) doesn't disqualify it; only a *recognized* one does.
  if (recognizedHeadings.any((h) => h.startLine == 0)) return null;

  final candidate = lines.first.text.trim();
  if (candidate.contains('@') || RegExp(r'\d').hasMatch(candidate)) return null;
  if (isRecognizedSectionHeading(candidate)) return null;

  final tokens = candidate.split(RegExp(r'\s+'));
  if (tokens.length < 2 || tokens.length > 4) return null;
  final capitalizedRe = RegExp(r'^[A-ZÀ-Ý][\wà-ÿ.\-]*$');
  if (!tokens.every((t) => capitalizedRe.hasMatch(t))) return null;

  return (
    nome: tokens.first,
    cognome: tokens.sublist(1).join(' '),
    certain: tokens.length == 2,
    sourceLine: candidate,
  );
}

// -------------------- Item grouping --------------------

/// Tries to parse a mid-line "rolled-up earlier experience" anchor:
/// `{titolo} (2012 – 2020): {descrizione}` — years only, no months, and the
/// title/description live on the same physical line as the range.
({ParsedDateRange range, String title, String trailing})?
_tryParseEmbeddedYearRange(String line) {
  final m = _embeddedYearRangeLineRe.firstMatch(line.trim());
  if (m == null) return null;
  final title = m.group(1)!.trim();
  if (title.isEmpty) return null;
  final startYear = int.tryParse(m.group(2)!);
  if (startYear == null) return null;
  final endToken = m.group(3)!.toLowerCase();
  final trailing = (m.group(4) ?? '').trim();
  if (isCurrentMarker(endToken)) {
    return (
      range: ParsedDateRange(start: YearMonth(startYear, 1), current: true),
      title: title,
      trailing: trailing,
    );
  }
  final endYear = int.tryParse(endToken);
  if (endYear == null) return null;
  return (
    range: ParsedDateRange(
      start: YearMonth(startYear, 1),
      end: YearMonth(endYear, 12),
    ),
    title: title,
    trailing: trailing,
  );
}

/// Whether a block boundary comes from a whole-line date range
/// ([standard], `tryParseDateRangeLine`) or from an embedded-year-range
/// title line ([embedded], `_tryParseEmbeddedYearRange`).
enum _AnchorType { standard, embedded }

/// One block-boundary line found in a section's body, plus the date range
/// it carries. [embeddedTitle]/[embeddedTrailing] are only set for
/// [_AnchorType.embedded] anchors — the title and post-`:` description text
/// that live on the anchor line itself, e.g. "Lead Dev (2012 – 2020):
/// Delivered...".
class _Anchor {
  final int lineIndex;
  final _AnchorType type;
  final ParsedDateRange range;
  final String? embeddedTitle;
  final String? embeddedTrailing;
  const _Anchor({
    required this.lineIndex,
    required this.type,
    required this.range,
    this.embeddedTitle,
    this.embeddedTrailing,
  });
}

/// Every line in [lines] that anchors a block boundary, in document order —
/// a whole-line date range or an embedded-year-range title line.
List<_Anchor> _findAnchors(List<String> lines) {
  final anchors = <_Anchor>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final standard = tryParseDateRangeLine(line);
    if (standard != null) {
      anchors.add(
        _Anchor(lineIndex: i, type: _AnchorType.standard, range: standard),
      );
      continue;
    }
    final embedded = _tryParseEmbeddedYearRange(line);
    if (embedded != null) {
      anchors.add(
        _Anchor(
          lineIndex: i,
          type: _AnchorType.embedded,
          range: embedded.range,
          embeddedTitle: embedded.title,
          embeddedTrailing: embedded.trailing,
        ),
      );
    }
  }
  return anchors;
}

/// One experience/formazione item: the date-anchored block plus the (up to
/// two) lines immediately preceding its anchor — the candidate ruolo/azienda
/// (or titolo/istituto) source lines (ticket 53). [ownHeadSubject]/
/// [ownHeadOrg] cover the opposite layout, where the CV places
/// "{ruolo} presso {azienda}" right *after* its own date line rather than
/// before the next one — claimed from the block's own first content line
/// before it's ever offered to the next block as a preceding-line candidate.
class _ItemBlock {
  List<String> precedingLines;
  final ParsedDateRange range;
  final String dateSourceLine;
  final String? embeddedTitle;
  String? ownHeadSubject;
  String? ownHeadOrg;
  String? ownHeadSourceLine;
  List<String> descriptionLines;
  _ItemBlock({
    required this.precedingLines,
    required this.range,
    required this.dateSourceLine,
    this.embeddedTitle,
    required this.descriptionLines,
  });
}

/// The last [max] elements of [pool], or all of it if shorter.
List<String> _takeTrailing(List<String> pool, int max) =>
    pool.length <= max ? pool : pool.sublist(pool.length - max);

/// Splits a section's body lines into [_ItemBlock]s anchored on date-range
/// (or embedded-year-range) lines. Lines immediately preceding an anchor are
/// peeled off the *previous* block's description and offered to the next
/// block as `precedingLines` — this is what lets ruolo/azienda/titolo/
/// istituto be read off the lines a CV conventionally places just above the
/// date, instead of always landing in `descrizione`. Any overflow leading
/// lines (more than 2 before the very first anchor) are returned separately
/// for the caller to route to "Da rivedere", same as before this ticket.
///
/// [patterns] is tried against each block's own first content line *before*
/// that line becomes a preceding-line candidate for the next block —
/// otherwise a "date, then {ruolo} presso {azienda}" block
/// (europass_it_01-style) or a "date, then {titolo}, {istituto}" block would
/// have its own role/company (or titolo/istituto) line stolen by whatever
/// block follows it (see ticket 53 implementation notes).
({List<_ItemBlock> blocks, List<String> unclaimedLeading}) _groupIntoItemBlocks(
  List<String> lines,
  _SubjectOrgPatterns patterns,
) {
  if (lines.isEmpty) return (blocks: [], unclaimedLeading: []);

  final anchors = _findAnchors(lines);
  // No date anchor at all: nothing to structure — the whole body routes to
  // "Da rivedere" via unclaimedLeading, same as ticket 13's fallback.
  if (anchors.isEmpty) return (blocks: [], unclaimedLeading: lines);

  final rawContents = <List<String>>[];
  for (var k = 0; k < anchors.length; k++) {
    final start = anchors[k].lineIndex + 1;
    final end = k + 1 < anchors.length
        ? anchors[k + 1].lineIndex
        : lines.length;
    rawContents.add(<String>[for (var i = start; i < end; i++) lines[i]]);
  }
  final leading = [for (var i = 0; i < anchors.first.lineIndex; i++) lines[i]];

  final blocks = <_ItemBlock>[];
  for (var k = 0; k < anchors.length; k++) {
    final anchor = anchors[k];

    final ownContent = <String>[
      if ((anchor.embeddedTrailing ?? '').isNotEmpty) anchor.embeddedTrailing!,
      ...rawContents[k],
    ];
    final block = _ItemBlock(
      precedingLines: const [],
      range: anchor.range,
      dateSourceLine: lines[anchor.lineIndex],
      embeddedTitle: anchor.embeddedTitle,
      descriptionLines: ownContent,
    );

    // Own-head claim: only for standard anchors (an embedded anchor already
    // carries its own title on the anchor line itself).
    if (anchor.embeddedTitle == null && ownContent.isNotEmpty) {
      final resolved = _tryExplicitSubjectOrg(ownContent.first, patterns);
      if (resolved != null) {
        block.ownHeadSubject = resolved.subject;
        block.ownHeadOrg = resolved.org;
        block.ownHeadSourceLine = ownContent.first;
        // Deliberately NOT removed from descriptionLines: this line reads
        // naturally as both the ruolo/azienda (titolo/istituto) source *and*
        // part of the free-text description (confirmed against the
        // europass_it_01 golden — unlike a peeled precedingLines window,
        // which the CV never meant as prose to begin with).
      }
    }

    blocks.add(block);
  }

  // Second pass: PEEK (don't remove) up to 2 trailing lines of block
  // (k-1)'s content after its own-head claim above, as precedingLines
  // candidates for block k. Nothing is peeled off block (k-1)'s own
  // description here — a candidate line only leaves `descriptionLines` once
  // [_resolveSubjectOrgPairs] confirms something actually used it (see
  // `_applyConsumedPreceding`, called by the section builders after
  // resolution): most blocks' trailing content is just prose that happens
  // to be short, not an azienda/istituto line waiting to be claimed.
  for (var k = 0; k < blocks.length; k++) {
    final precedingPool = k == 0 ? leading : blocks[k - 1].descriptionLines;
    blocks[k].precedingLines = _takeTrailing(precedingPool, 2);
  }

  final unclaimedLeading = leading.length > 2
      ? leading.sublist(0, leading.length - 2)
      : <String>[];
  return (blocks: blocks, unclaimedLeading: unclaimedLeading);
}

/// The regexes that decide subject (ruolo/titolo) vs. org
/// (azienda/istituto) for one section kind — bundled together because
/// [_groupIntoItemBlocks], [_tryExplicitSubjectOrg], and
/// [_resolveSubjectOrgPairs] all need the same set per call. Esperienze and
/// Formazione each define one instance (`_esperienzePatterns`/
/// `_formazionePatterns`) and pass it to all three.
class _SubjectOrgPatterns {
  final RegExp? connectorRe;
  final RegExp? splitRe;
  final RegExp? markerRe;
  final RegExp subjectVocabRe;
  final RegExp orgVocabRe;
  const _SubjectOrgPatterns({
    this.connectorRe,
    this.splitRe,
    this.markerRe,
    required this.subjectVocabRe,
    required this.orgVocabRe,
  });
}

/// `{ruolo} presso/at {azienda}` explicit connector, vocab-guided `|` split
/// (fixture: "Flutter Architect | Nortek Bank").
final _esperienzePatterns = _SubjectOrgPatterns(
  connectorRe: _connectorLineRe,
  splitRe: _pipeSplitLineRe,
  subjectVocabRe: _roleVocabRe,
  orgVocabRe: _companyMarkerRe,
);

/// `{titolo}, {istituto}` comma split, institution-marker embedded mid-line
/// (fixture: "Secondary School Diploma ... Istituto Tecnico Superiore G.
/// Fermi").
final _formazionePatterns = _SubjectOrgPatterns(
  splitRe: _commaSplitLineRe,
  markerRe: _institutionVocabRe,
  subjectVocabRe: _degreeVocabRe,
  orgVocabRe: _institutionVocabRe,
);

// -------------------- Per-document ruolo/azienda (titolo/istituto) vote --

/// Whether [text] carries a "subject" (role/degree) or "org"
/// (company/institution) signal, per the vocab regexes — or neither.
enum _Signal { subject, org, none }

/// Tries every explicit (non-vote) pattern against a single [line]:
/// connector, then vocab-guided split, then a marker embedded mid-line.
/// Shared between the own-head claim (block's own first content line) and
/// the preceding-lines scan, so both layouts recognize the same patterns.
({String subject, String org})? _tryExplicitSubjectOrg(
  String line,
  _SubjectOrgPatterns patterns,
) {
  final connectorRe = patterns.connectorRe;
  if (connectorRe != null) {
    final m = connectorRe.firstMatch(line);
    if (m != null) {
      return (subject: m.group(1)!.trim(), org: m.group(2)!.trim());
    }
  }

  final splitRe = patterns.splitRe;
  if (splitRe != null) {
    final m = splitRe.firstMatch(line);
    if (m != null) {
      final left = m.group(1)!.trim();
      final right = m.group(2)!.trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        final leftSignal = _classify(
          left,
          subjectRe: patterns.subjectVocabRe,
          orgRe: patterns.orgVocabRe,
        );
        final rightSignal = _classify(
          right,
          subjectRe: patterns.subjectVocabRe,
          orgRe: patterns.orgVocabRe,
        );
        if (leftSignal == _Signal.subject || rightSignal == _Signal.org) {
          return (subject: left, org: right);
        }
        if (leftSignal == _Signal.org || rightSignal == _Signal.subject) {
          return (subject: right, org: left);
        }
      }
    }
  }

  final markerRe = patterns.markerRe;
  if (markerRe != null) {
    final matches = markerRe.allMatches(line).toList();
    if (matches.isNotEmpty) {
      final split = matches.last.start;
      final left = line
          .substring(0, split)
          .trim()
          .replaceAll(RegExp(r'[,\s]+$'), '');
      final right = line.substring(split).trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        return (subject: left, org: right);
      }
    }
  }

  return null;
}

/// Classifies [text] as carrying a subject signal, an org signal, or
/// neither — [_Signal.none] when both or neither vocab matches, since a
/// line matching both isn't a usable disambiguator.
_Signal _classify(
  String text, {
  required RegExp subjectRe,
  required RegExp orgRe,
}) {
  final hasSubject = subjectRe.hasMatch(text);
  final hasOrg = orgRe.hasMatch(text);
  if (hasSubject && !hasOrg) return _Signal.subject;
  if (hasOrg && !hasSubject) return _Signal.org;
  return _Signal.none;
}

/// Tallies, across a document's blocks, whether the line/part *nearer* to
/// the date anchor tends to be the org (company/institution) or the subject
/// (role/degree) — ticket 53's "voto per-documento sull'ordine". `null`
/// means no clear majority: caller falls back to leaving both fields blank.
class _OrderVote {
  int _nearIsOrg = 0;
  int _farIsOrg = 0;
  void record({required bool nearIsOrg}) {
    if (nearIsOrg) {
      _nearIsOrg++;
    } else {
      _farIsOrg++;
    }
  }

  bool? get nearIsOrgMajority {
    if (_nearIsOrg == 0 && _farIsOrg == 0) return null;
    if (_nearIsOrg == _farIsOrg) return null;
    return _nearIsOrg > _farIsOrg;
  }
}

/// One resolved (or attempted) subject/org pair for a block, pending a
/// possible per-document vote to fill in `null` fields.
class _PendingPair {
  final _ItemBlock block;
  final int index;
  final String far;
  final String near;
  _PendingPair({
    required this.block,
    required this.index,
    required this.far,
    required this.near,
  });
}

/// Resolves subject (ruolo/titolo) + org (azienda/istituto) for every block
/// of a section, applying explicit per-block signals first and a
/// per-document majority vote for whatever's left ambiguous.
///
/// `patterns.connectorRe` is an optional explicit "{subject} keyword {org}"
/// pattern (Esperienze's `presso`/`at`) whose keyword alone disambiguates
/// order — always certain, never needs the vote. `patterns.splitRe` is a
/// single-line separator pattern (Esperienze's `|`, Formazione's `,`) whose
/// *sides*' order needs vocab or the vote to resolve.
/// [consumedPrecedingCount] is how many of the block's `precedingLines` were
/// actually used to resolve `org`/`subject` — 0 unless something matched.
/// Callers use it to trim exactly that many trailing lines off the
/// *previous* block's `descriptionLines` (see `_applyConsumedPreceding`):
/// `precedingLines` is only ever a peek until a match confirms those lines
/// weren't ordinary prose.
typedef _SubjectOrgResult = ({
  String subject,
  String org,
  bool subjectCertain,
  bool orgCertain,
  List<String> sourceLines,
  int consumedPrecedingCount,
});

List<_SubjectOrgResult> _resolveSubjectOrgPairs(
  List<_ItemBlock> blocks,
  _SubjectOrgPatterns patterns,
) {
  final results = List<_SubjectOrgResult>.filled(blocks.length, (
    subject: '',
    org: '',
    subjectCertain: false,
    orgCertain: false,
    sourceLines: <String>[],
    consumedPrecedingCount: 0,
  ), growable: false);

  final vote = _OrderVote();
  final pending = <_PendingPair>[];

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    String? subject = block.embeddedTitle ?? block.ownHeadSubject;
    String? org = block.ownHeadOrg;
    var subjectCertain = subject != null;
    var orgCertain = org != null;
    var consumedPreceding = 0;
    final sourceLines = <String>[
      if (block.ownHeadSourceLine != null) block.ownHeadSourceLine!,
      ...block.precedingLines,
    ];

    final candidateLines = block.precedingLines;

    // 1–3. Explicit connector / vocab-guided split / embedded marker,
    // tried against every candidate line still available.
    if (org == null) {
      for (final line in candidateLines) {
        final resolved = _tryExplicitSubjectOrg(line, patterns);
        if (resolved != null) {
          subject ??= resolved.subject;
          org = resolved.org;
          subjectCertain = true;
          orgCertain = true;
          consumedPreceding = candidateLines.length;
          break;
        }
      }
    }

    // 4. Two bare candidate lines, no explicit separator matched: classify
    //    each independently; direct signal wins, otherwise queue for the
    //    per-document vote.
    if (org == null && candidateLines.length == 2) {
      final far = candidateLines[0];
      final near = candidateLines[1];
      final farSignal = _classify(
        far,
        subjectRe: patterns.subjectVocabRe,
        orgRe: patterns.orgVocabRe,
      );
      final nearSignal = _classify(
        near,
        subjectRe: patterns.subjectVocabRe,
        orgRe: patterns.orgVocabRe,
      );
      if (farSignal == _Signal.org && nearSignal != _Signal.org) {
        org = far;
        subject ??= near;
        subjectCertain = true;
        orgCertain = true;
        consumedPreceding = 2;
        vote.record(nearIsOrg: false);
      } else if (nearSignal == _Signal.org && farSignal != _Signal.org) {
        org = near;
        subject ??= far;
        subjectCertain = true;
        orgCertain = true;
        consumedPreceding = 2;
        vote.record(nearIsOrg: true);
      } else if (farSignal == _Signal.subject &&
          nearSignal != _Signal.subject) {
        subject ??= far;
        org = near;
        subjectCertain = true;
        orgCertain = true;
        consumedPreceding = 2;
        vote.record(nearIsOrg: true);
      } else if (nearSignal == _Signal.subject &&
          farSignal != _Signal.subject) {
        subject ??= near;
        org = far;
        subjectCertain = true;
        orgCertain = true;
        consumedPreceding = 2;
        vote.record(nearIsOrg: false);
      } else {
        pending.add(_PendingPair(block: block, index: i, far: far, near: near));
      }
    }

    results[i] = (
      subject: subject ?? '',
      org: org ?? '',
      subjectCertain: subjectCertain,
      orgCertain: orgCertain,
      sourceLines: sourceLines,
      consumedPrecedingCount: consumedPreceding,
    );
  }

  final majority = vote.nearIsOrgMajority;
  if (majority != null) {
    for (final p in pending) {
      final org = majority ? p.near : p.far;
      final subject = majority ? p.far : p.near;
      final prior = results[p.index];
      results[p.index] = (
        subject: prior.subject.isEmpty ? subject : prior.subject,
        org: org,
        subjectCertain: prior.subject.isEmpty ? false : prior.subjectCertain,
        orgCertain: false,
        sourceLines: prior.sourceLines,
        consumedPrecedingCount: 2,
      );
    }
  }

  return results;
}

/// Trims off each block's `precedingLines` from the tail of the *previous*
/// block's `descriptionLines`, but only for blocks whose
/// [_SubjectOrgResult.consumedPrecedingCount] confirms something actually
/// used them — see [_resolveSubjectOrgPairs] doc.
void _applyConsumedPreceding(
  List<_ItemBlock> blocks,
  List<_SubjectOrgResult> pairs,
) {
  for (var k = 1; k < blocks.length; k++) {
    final count = pairs[k].consumedPrecedingCount;
    if (count == 0) continue;
    final prevDesc = blocks[k - 1].descriptionLines;
    final keep = prevDesc.length - count;
    blocks[k - 1].descriptionLines = keep <= 0
        ? const []
        : prevDesc.sublist(0, keep);
  }
}

// -------------------- Public entry point --------------------

/// Builds a best-effort [CvDocument] from extracted PDF pages, following
/// ticket 13's conservative signal-first / section-first strategy, together
/// with the [ImportProposalReport] (ticket 52) describing the confidence and
/// provenance of every field it proposed.
(CvDocument, ImportProposalReport) buildFromPages(List<PdfPageText> pages) {
  final now = DateTime.now();
  final fullText = pages.map((p) => p.plainText).join('\n');
  final flat = _flatten(pages);
  final report = ImportProposalReportBuilder();

  final sections = <CvSection>[];

  final contacts = _extractContacts(fullText, report);
  if (contacts.email != null ||
      contacts.telefono != null ||
      contacts.link.isNotEmpty) {
    sections.add(ContattiSection(displayTitle: 'Contatti', data: contacts));
  }

  if (flat.isEmpty) {
    return (
      CvDocument(
        id: _uuid.v4(),
        createdAt: now,
        updatedAt: now,
        variantName: '',
        sections: sections,
      ),
      report.build(),
    );
  }

  // Anti-disastro fallback stays keyed on *recognized* headings only — an
  // unrecognized-but-title-shaped heading (item 5 below) is a bonus, not
  // something that should lower the safety bar that disables section-first
  // splitting entirely.
  final recognizedHeadings = _detectSectionHeadings(flat);

  final reviewBuffer = StringBuffer();

  if (recognizedHeadings.length < 2) {
    // Fallback anti-disastro: section-first disabled entirely.
    for (final l in flat) {
      reviewBuffer.writeln(l.text);
    }
  } else {
    final boundaries = _detectAllHeadingBoundaries(flat);

    final name = _tryExtractName(flat, recognizedHeadings);
    if (name != null) {
      report.add(
        'anagrafica.nome',
        certain: name.certain,
        sourceLines: [name.sourceLine],
      );
      report.add(
        'anagrafica.cognome',
        certain: name.certain,
        sourceLines: [name.sourceLine],
      );
      sections.add(
        AnagraficaSection(
          displayTitle: 'Anagrafica',
          data: AnagraficaData(nome: name.nome, cognome: name.cognome),
        ),
      );
    }

    // Everything before the first heading also goes to "Da rivedere".
    for (var i = 0; i < boundaries.first.startLine; i++) {
      reviewBuffer.writeln(flat[i].text);
    }

    for (var h = 0; h < boundaries.length; h++) {
      final section = boundaries[h];
      final bodyStart = section.startLine + 1;
      final bodyEnd = h + 1 < boundaries.length
          ? boundaries[h + 1].startLine
          : flat.length;
      final bodyLines = [
        for (var i = bodyStart; i < bodyEnd; i++) flat[i].text,
      ];

      switch (section.kind) {
        case SectionKind.esperienze:
          sections.add(_buildEsperienze(bodyLines, reviewBuffer, report));
        case SectionKind.formazione:
          sections.add(_buildFormazione(bodyLines, reviewBuffer, report));
        case SectionKind.certificazioni:
          sections.add(_buildCertificazioni(bodyLines, report));
        case SectionKind.lingue:
          final lingue = _buildLingue(
            section.originalText,
            bodyLines,
            report,
            0,
          );
          if (lingue != null) sections.add(lingue);
        case SectionKind.skill:
          final skill = _buildSkill(section.originalText, bodyLines, report);
          if (skill != null) sections.add(skill);
        case SectionKind.sommario:
          // Free text — ticket 13/51: becomes its own custom section under
          // the heading's original text, not an anonymous dump into "Da
          // rivedere".
          final unstructured = _buildUnstructuredCustomSection(
            section.originalText,
            bodyLines,
          );
          if (unstructured != null) sections.add(unstructured);
        case null:
          // Unrecognized but title-shaped heading (ticket 53, item 5): its
          // own custom section under the original title, not merged into
          // whatever section precedes it.
          final unstructured = _buildUnstructuredCustomSection(
            section.originalText,
            bodyLines,
          );
          if (unstructured != null) sections.add(unstructured);
        default:
          for (final l in bodyLines) {
            reviewBuffer.writeln(l);
          }
      }
    }
  }

  final review = reviewBuffer.toString().trim();
  if (review.isNotEmpty) {
    sections.add(
      CustomSection(
        id: _uuid.v4(),
        displayTitle: 'Da rivedere',
        markdown: review,
      ),
    );
  }

  return (
    CvDocument(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: '',
      sections: sections,
    ),
    report.build(),
  );
}

EsperienzeSection _buildEsperienze(
  List<String> bodyLines,
  StringBuffer reviewBuffer,
  ImportProposalReportBuilder report,
) {
  final grouped = _groupIntoItemBlocks(bodyLines, _esperienzePatterns);
  for (final l in grouped.unclaimedLeading) {
    reviewBuffer.writeln(l);
  }

  final pairs = _resolveSubjectOrgPairs(grouped.blocks, _esperienzePatterns);
  _applyConsumedPreceding(grouped.blocks, pairs);

  final items = <EsperienzaItem>[];
  for (var i = 0; i < grouped.blocks.length; i++) {
    final block = grouped.blocks[i];
    final pair = pairs[i];
    final index = items.length;

    report.add(
      'esperienze[$index].dateRange',
      certain: true,
      sourceLines: [block.dateSourceLine],
    );
    if (block.descriptionLines.isNotEmpty) {
      report.add(
        'esperienze[$index].descrizione',
        certain: true,
        sourceLines: block.descriptionLines,
      );
    }
    if (pair.subject.isNotEmpty) {
      report.add(
        'esperienze[$index].ruolo',
        certain: pair.subjectCertain,
        sourceLines: pair.sourceLines,
      );
    }
    if (pair.org.isNotEmpty) {
      report.add(
        'esperienze[$index].azienda',
        certain: pair.orgCertain,
        sourceLines: pair.sourceLines,
      );
    }

    items.add(
      EsperienzaItem(
        id: _uuid.v4(),
        ruolo: pair.subject,
        azienda: pair.org,
        startDate: block.range.start,
        endDate: block.range.end,
        current: block.range.current,
        descrizione: block.descriptionLines.isEmpty
            ? null
            : block.descriptionLines.join('\n'),
      ),
    );
  }
  return EsperienzeSection(displayTitle: 'Esperienze', items: items);
}

FormazioneSection _buildFormazione(
  List<String> bodyLines,
  StringBuffer reviewBuffer,
  ImportProposalReportBuilder report,
) {
  final grouped = _groupIntoItemBlocks(bodyLines, _formazionePatterns);
  for (final l in grouped.unclaimedLeading) {
    reviewBuffer.writeln(l);
  }

  final pairs = _resolveSubjectOrgPairs(grouped.blocks, _formazionePatterns);
  _applyConsumedPreceding(grouped.blocks, pairs);

  final items = <FormazioneItem>[];
  for (var i = 0; i < grouped.blocks.length; i++) {
    final block = grouped.blocks[i];
    final pair = pairs[i];
    final index = items.length;

    report.add(
      'formazione[$index].dateRange',
      certain: true,
      sourceLines: [block.dateSourceLine],
    );
    if (block.descriptionLines.isNotEmpty) {
      report.add(
        'formazione[$index].descrizione',
        certain: true,
        sourceLines: block.descriptionLines,
      );
    }
    if (pair.subject.isNotEmpty) {
      report.add(
        'formazione[$index].titolo',
        certain: pair.subjectCertain,
        sourceLines: pair.sourceLines,
      );
    }
    if (pair.org.isNotEmpty) {
      report.add(
        'formazione[$index].istituto',
        certain: pair.orgCertain,
        sourceLines: pair.sourceLines,
      );
    }

    items.add(
      FormazioneItem(
        id: _uuid.v4(),
        titolo: pair.subject,
        istituto: pair.org.isEmpty ? null : pair.org,
        startDate: block.range.start,
        endDate: block.range.end,
        current: block.range.current,
        descrizione: block.descriptionLines.isEmpty
            ? null
            : block.descriptionLines.join('\n'),
      ),
    );
  }
  return FormazioneSection(displayTitle: 'Formazione', items: items);
}

/// Builds a custom section titled with [originalHeadingText] (the heading
/// exactly as it appeared in the source, not the dictionary synonym) from
/// [bodyLines]. Returns `null` if the body is empty — a bare heading with
/// no content has nothing to show.
CustomSection? _buildUnstructuredCustomSection(
  String originalHeadingText,
  List<String> bodyLines,
) {
  final markdown = bodyLines.join('\n').trim();
  if (markdown.isEmpty) return null;
  return CustomSection(
    id: _uuid.v4(),
    displayTitle: originalHeadingText,
    markdown: markdown,
  );
}

/// Builds the Lingue section (ticket 53, item 3): recognizes CEFR levels
/// (`A1`..`C2`) and "madrelingua"/"mother tongue" per line. A line with
/// exactly one recognized level is a certain proposal. When a language name
/// recurs with several different levels on the same line (Europass-style
/// per-skill breakdown: "Listening C2 Reading C2 Writing C1"), the most
/// frequent level is proposed and marked uncertain — it's a statistical
/// pick, not a direct read.
LingueSection? _buildLingue(
  String originalHeadingText,
  List<String> bodyLines,
  ImportProposalReportBuilder report,
  int startIndex,
) {
  final items = <LinguaItem>[];
  var index = startIndex;
  for (final rawLine in bodyLines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final levelMatches = _cefrLevelRe.allMatches(line).toList();
    if (levelMatches.isEmpty) {
      // No CEFR level on this line (e.g. a "MOTHER TONGUE(S):" sub-label in
      // a Europass-style block) — not structurable, but still evidence the
      // heuristics looked at, so it doesn't show up as a lost line.
      report.add('lingue.unclaimed', certain: false, sourceLines: [line]);
      continue;
    }

    final levels = <LivelloCefr>[];
    for (final m in levelMatches) {
      final token = (m.group(1) ?? m.group(2))!.toLowerCase();
      if (token == 'madrelingua' || token == 'mother tongue') {
        levels.add(LivelloCefr.madrelingua);
      } else {
        levels.add(_cefrWireToLevel[token]!);
      }
    }

    // Language name: whatever precedes the first level/separator token.
    final splitIdx = levelMatches.first.start;
    var lingua = line
        .substring(0, splitIdx)
        .trim()
        .replaceAll(RegExp(r'[\-:,]+$'), '')
        .trim();
    if (lingua.isEmpty) lingua = line;

    LivelloCefr livello;
    bool certain;
    if (levels.length == 1) {
      livello = levels.first;
      certain = true;
    } else {
      final counts = <LivelloCefr, int>{};
      for (final l in levels) {
        counts[l] = (counts[l] ?? 0) + 1;
      }
      final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
      livello = counts.entries.firstWhere((e) => e.value == maxCount).key;
      certain = false;
    }

    report.add('lingue[$index].livello', certain: certain, sourceLines: [line]);
    items.add(LinguaItem(id: _uuid.v4(), lingua: lingua, livello: livello));
    index++;
  }
  if (items.isEmpty) return null;
  return LingueSection(displayTitle: originalHeadingText, items: items);
}

/// Builds the Skill section (ticket 53, item 4): a line with 2+ occurrences
/// of the same repeated separator (`|`, `•`, `,`) becomes the `tags` list;
/// the rest of the block becomes free-text `markdown`.
SkillSection? _buildSkill(
  String originalHeadingText,
  List<String> bodyLines,
  ImportProposalReportBuilder report,
) {
  String? tagLine;
  final markdownLines = <String>[];
  for (final line in bodyLines) {
    if (tagLine == null &&
        (_repeatedPipeRe.hasMatch(line) ||
            _repeatedBulletRe.hasMatch(line) ||
            _repeatedCommaRe.hasMatch(line))) {
      tagLine = line;
      continue;
    }
    markdownLines.add(line);
  }

  List<String> tags = const [];
  if (tagLine != null) {
    final sep = tagLine.contains('|')
        ? '|'
        : (tagLine.contains('•') ? '•' : ',');
    tags = tagLine
        .split(sep)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    report.add('skill.tags', certain: true, sourceLines: [tagLine]);
  }

  final markdown = markdownLines.join('\n').trim();
  if (tags.isEmpty && markdown.isEmpty) return null;
  return SkillSection(
    displayTitle: originalHeadingText,
    data: SkillData(markdown: markdown.isEmpty ? null : markdown, tags: tags),
  );
}

CertificazioniSection _buildCertificazioni(
  List<String> bodyLines,
  ImportProposalReportBuilder report,
) {
  // Conservative: each non-empty line becomes a certification named after
  // itself, with no auto-filled dates (free-text certification lines rarely
  // isolate a date cleanly enough to trust).
  final items = <CertificazioneItem>[];
  for (final line in bodyLines) {
    if (line.trim().isEmpty) continue;
    report.add(
      'certificazioni[${items.length}].nome',
      certain: true,
      sourceLines: [line.trim()],
    );
    items.add(CertificazioneItem(id: _uuid.v4(), nome: line.trim(), ente: ''));
  }
  return CertificazioniSection(displayTitle: 'Certificazioni', items: items);
}
