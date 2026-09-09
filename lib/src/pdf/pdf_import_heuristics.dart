/// Pure text→schema mapping heuristics for PDF auto-import (ticket 13, used
/// by [PdfImporter] in `pdf_importer.dart`, ticket 28).
///
/// Deliberately has no dependency on Flutter or `pdfrx` — the caller maps
/// whatever PDF-extraction library it uses into [PdfPageText]/[PdfCharRect],
/// so this module is `dart test`-able on its own and portable if the PDF
/// backend ever changes.
///
/// Philosophy (ticket 13): precision over recall. Never auto-fills
/// nome/cognome/headline, ruolo/azienda inside an Esperienza, or
/// titolo/istituto inside a Formazione — those need a human to extract from
/// the raw description text. Anything not confidently mapped lands in a
/// single custom section titled "Da rivedere".
library;

import 'package:uuid/uuid.dart';

import '../domain/cv_document.dart';
import '../domain/cv_section.dart';
import '../domain/enums.dart';
import '../domain/year_month.dart';

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

ContattiData _extractContacts(String fullText) {
  final email = _emailRe.firstMatch(fullText)?.group(0);
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
/// `1 of 2`, or a bare `1/2`.
final RegExp _paginationLineRe = RegExp(
  r'^(?:(?:page|pagina)\s*)?\d{1,4}\s*(?:/|-|di|of)\s*\d{1,4}$',
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

// -------------------- Item grouping --------------------

/// Splits a section's body lines into item blocks: a new item starts at
/// each line that looks like a date range, falling back to blank-line
/// separation, falling back to treating the whole block as one item.
List<List<String>> _groupIntoBlocks(List<String> lines) {
  if (lines.isEmpty) return [];

  final dateLineIndices = <int>[
    for (var i = 0; i < lines.length; i++)
      if (looksLikeDateRangeLine(lines[i])) i,
  ];

  if (dateLineIndices.isNotEmpty) {
    final blocks = <List<String>>[];
    for (var b = 0; b < dateLineIndices.length; b++) {
      final start = dateLineIndices[b];
      final end = b + 1 < dateLineIndices.length
          ? dateLineIndices[b + 1]
          : lines.length;
      blocks.add(lines.sublist(start, end));
    }
    // Any lines before the first date-range line: keep as their own block
    // (fallback below decides what to do with them via blank-line rule).
    if (dateLineIndices.first > 0) {
      blocks.insert(0, lines.sublist(0, dateLineIndices.first));
    }
    return blocks.where((b) => b.isNotEmpty).toList();
  }

  // Fallback: blank-line separated blocks. Callers pass lines that already
  // dropped truly-empty strings during flattening, so instead split when a
  // line looks like a standalone short header (heuristic: <=3 words) — kept
  // simple: if nothing else works, whole block is one item.
  return [lines];
}

// -------------------- Public entry point --------------------

/// Builds a best-effort [CvDocument] from extracted PDF pages, following
/// ticket 13's conservative signal-first / section-first strategy.
CvDocument buildFromPages(List<PdfPageText> pages) {
  final now = DateTime.now();
  final fullText = pages.map((p) => p.plainText).join('\n');
  final flat = _flatten(pages);

  final sections = <CvSection>[];

  final contacts = _extractContacts(fullText);
  if (contacts.email != null ||
      contacts.telefono != null ||
      contacts.link.isNotEmpty) {
    sections.add(ContattiSection(displayTitle: 'Contatti', data: contacts));
  }

  if (flat.isEmpty) {
    return CvDocument(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: '',
      sections: sections,
    );
  }

  final headings = _detectSectionHeadings(flat);

  final reviewBuffer = StringBuffer();

  if (headings.length < 2) {
    // Fallback anti-disastro: section-first disabled entirely.
    for (final l in flat) {
      reviewBuffer.writeln(l.text);
    }
  } else {
    // Everything before the first heading also goes to "Da rivedere".
    for (var i = 0; i < headings.first.startLine; i++) {
      reviewBuffer.writeln(flat[i].text);
    }

    for (var h = 0; h < headings.length; h++) {
      final section = headings[h];
      final bodyStart = section.startLine + 1;
      final bodyEnd = h + 1 < headings.length
          ? headings[h + 1].startLine
          : flat.length;
      final bodyLines = [
        for (var i = bodyStart; i < bodyEnd; i++) flat[i].text,
      ];

      switch (section.kind) {
        case SectionKind.esperienze:
          sections.add(_buildEsperienze(bodyLines, reviewBuffer));
        case SectionKind.formazione:
          sections.add(_buildFormazione(bodyLines, reviewBuffer));
        case SectionKind.certificazioni:
          sections.add(_buildCertificazioni(bodyLines));
        case SectionKind.lingue:
        case SectionKind.sommario:
        case SectionKind.skill:
          // Recognized as a heading but not confidently structurable into
          // typed fields (Lingue needs a CEFR level, Sommario/Skill are
          // free text) — ticket 13/51: becomes its own custom section
          // under the heading's original text, not an anonymous dump into
          // "Da rivedere".
          final unstructured = _buildUnstructuredCustomSection(
            flat[section.startLine].text,
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

  return CvDocument(
    id: _uuid.v4(),
    createdAt: now,
    updatedAt: now,
    variantName: '',
    sections: sections,
  );
}

EsperienzeSection _buildEsperienze(
  List<String> bodyLines,
  StringBuffer reviewBuffer,
) {
  final blocks = _groupIntoBlocks(bodyLines);
  final items = <EsperienzaItem>[];
  for (final block in blocks) {
    final dateLineIdx = block.indexWhere(looksLikeDateRangeLine);
    if (dateLineIdx == -1) {
      reviewBuffer.writeln('--- Esperienza non riconosciuta ---');
      for (final l in block) {
        reviewBuffer.writeln(l);
      }
      continue;
    }
    final range = tryParseDateRangeLine(block[dateLineIdx])!;
    final descriptionLines = [
      for (var i = 0; i < block.length; i++)
        if (i != dateLineIdx) block[i],
    ];
    items.add(
      EsperienzaItem(
        id: _uuid.v4(),
        ruolo: '',
        azienda: '',
        startDate: range.start,
        endDate: range.end,
        current: range.current,
        descrizione: descriptionLines.isEmpty
            ? null
            : descriptionLines.join('\n'),
      ),
    );
  }
  return EsperienzeSection(displayTitle: 'Esperienze', items: items);
}

FormazioneSection _buildFormazione(
  List<String> bodyLines,
  StringBuffer reviewBuffer,
) {
  final blocks = _groupIntoBlocks(bodyLines);
  final items = <FormazioneItem>[];
  for (final block in blocks) {
    final dateLineIdx = block.indexWhere(looksLikeDateRangeLine);
    if (dateLineIdx == -1) {
      reviewBuffer.writeln('--- Formazione non riconosciuta ---');
      for (final l in block) {
        reviewBuffer.writeln(l);
      }
      continue;
    }
    final range = tryParseDateRangeLine(block[dateLineIdx])!;
    final descriptionLines = [
      for (var i = 0; i < block.length; i++)
        if (i != dateLineIdx) block[i],
    ];
    items.add(
      FormazioneItem(
        id: _uuid.v4(),
        titolo: '',
        startDate: range.start,
        endDate: range.end,
        current: range.current,
        descrizione: descriptionLines.isEmpty
            ? null
            : descriptionLines.join('\n'),
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

CertificazioniSection _buildCertificazioni(List<String> bodyLines) {
  // Conservative: each non-empty line becomes a certification named after
  // itself, with no auto-filled dates (free-text certification lines rarely
  // isolate a date cleanly enough to trust).
  final items = <CertificazioneItem>[
    for (final line in bodyLines)
      if (line.trim().isNotEmpty)
        CertificazioneItem(id: _uuid.v4(), nome: line.trim(), ente: ''),
  ];
  return CertificazioniSection(displayTitle: 'Certificazioni', items: items);
}
