/// Conversion-rate scoring (ticket 50 — "Tasso di conversione" in
/// CONTEXT.md): flattens a produced [CvDocument] into field paths, and
/// compares them against a hand-written golden's field paths to compute
/// recall + precision, with a per-section breakdown.
///
/// One field, one vote (deliberate ticket 50 decision): no per-section
/// weighting, so the number is dominated by Esperienze — that's where the
/// user's manual work concentrates, so it should be. The breakdown below is
/// diagnostic, not the objective.
///
/// **Known limitation**: list items (`esperienze[i]`, `formazione[i]`,
/// `certificazioni[i]`) are matched to the golden by *position*, not by
/// content. On a fixture where `buildFromPages` groups items in a
/// different order than the golden's hand-authored order, correctly
/// extracted fields can score as wrong purely from index misalignment —
/// understating recall/precision rather than measuring the real gap. Not a
/// concern for the current clean single-item-per-date-line corpus, but
/// worth revisiting (e.g. content-based matching) once messier real
/// documents join the corpus.
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';

/// Trim, collapse whitespace, lowercase — applied to both sides before
/// comparing two field values (ticket 50 implementation decision).
String normalizeFieldValue(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Flattens the fields [buildFromPages] can populate into `path -> value`,
/// skipping anything null/empty (an absent field is "not proposed", not
/// "proposed as empty"). Covers Contatti/Esperienze/Formazione/
/// Certificazioni, including `ruolo`/`azienda`/`titolo`/`istituto` (ticket
/// 53 auto-fills these; ticket 13 never did). Anagrafica/Skill/Lingue are
/// intentionally left out of scoring for now — their heuristics (ticket 53
/// items 2-4) are covered by dedicated unit tests instead, so an ungraded
/// proposal there can't drag down this corpus's precision.
Map<String, String> flattenDocument(CvDocument doc) {
  final fields = <String, String>{};

  void put(String key, String? value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    fields[key] = trimmed;
  }

  for (final section in doc.sections) {
    switch (section) {
      case ContattiSection(:final data):
        put('contatti.email', data.email);
        put('contatti.telefono', data.telefono);
        for (var i = 0; i < data.link.length; i++) {
          put('contatti.link[$i]', data.link[i].url);
        }
      case EsperienzeSection(:final items):
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          put('esperienze[$i].ruolo', it.ruolo);
          put('esperienze[$i].azienda', it.azienda);
          put('esperienze[$i].startDate', it.startDate.toString());
          put('esperienze[$i].endDate', it.endDate?.toString());
          put('esperienze[$i].current', it.current.toString());
          put('esperienze[$i].descrizione', it.descrizione);
        }
      case FormazioneSection(:final items):
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          put('formazione[$i].titolo', it.titolo);
          put('formazione[$i].istituto', it.istituto);
          put('formazione[$i].startDate', it.startDate?.toString());
          put('formazione[$i].endDate', it.endDate?.toString());
          put('formazione[$i].descrizione', it.descrizione);
        }
      case CertificazioniSection(:final items):
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          put('certificazioni[$i].nome', it.nome);
          put('certificazioni[$i].ente', it.ente);
        }
      case AnagraficaSection() ||
          SommarioSection() ||
          SkillSection() ||
          LingueSection() ||
          CustomSection():
        break; // Never auto-filled structurally (ticket 13) — no fields here.
    }
  }
  return fields;
}

/// Recall/precision for one section (the path segment before the first
/// `.`/`[`), plus the raw counts they're derived from.
class SectionScore {
  final int expectedCount;
  final int correctCount;
  final int proposedCount;

  const SectionScore({
    required this.expectedCount,
    required this.correctCount,
    required this.proposedCount,
  });

  /// `null` when the golden expects nothing in this section — undefined,
  /// not zero.
  double? get recall =>
      expectedCount == 0 ? null : correctCount / expectedCount;

  /// Convention (ticket 50): proposing nothing scores 100% precision —
  /// nothing was proposed wrong.
  double get precision =>
      proposedCount == 0 ? 1.0 : correctCount / proposedCount;
}

/// Overall conversion-rate score for one fixture/golden pair.
class ConversionScore {
  final int expectedCount;
  final int correctCount;
  final int proposedCount;
  final Map<String, SectionScore> bySection;

  const ConversionScore({
    required this.expectedCount,
    required this.correctCount,
    required this.proposedCount,
    required this.bySection,
  });

  double? get recall =>
      expectedCount == 0 ? null : correctCount / expectedCount;

  double get precision =>
      proposedCount == 0 ? 1.0 : correctCount / proposedCount;
}

String _sectionOf(String fieldPath) {
  final idx = fieldPath.indexOf(RegExp(r'[.\[]'));
  return idx == -1 ? fieldPath : fieldPath.substring(0, idx);
}

/// Scores [proposed] (from [flattenDocument]) against [expected] (from a
/// [Golden]'s `fields`). A field is "correct" if its normalized value
/// matches the golden's normalized value exactly — see
/// [normalizeFieldValue].
ConversionScore scoreConversion({
  required Map<String, String> expected,
  required Map<String, String> proposed,
}) {
  final sectionKeys = {
    ...expected.keys.map(_sectionOf),
    ...proposed.keys.map(_sectionOf),
  };

  final bySection = <String, SectionScore>{};
  var correctTotal = 0;

  for (final section in sectionKeys) {
    var expectedCount = 0;
    var correctCount = 0;
    for (final entry in expected.entries) {
      if (_sectionOf(entry.key) != section) continue;
      expectedCount++;
      final proposedValue = proposed[entry.key];
      if (proposedValue != null &&
          normalizeFieldValue(proposedValue) ==
              normalizeFieldValue(entry.value)) {
        correctCount++;
      }
    }
    final proposedCount = proposed.keys
        .where((k) => _sectionOf(k) == section)
        .length;

    bySection[section] = SectionScore(
      expectedCount: expectedCount,
      correctCount: correctCount,
      proposedCount: proposedCount,
    );
    correctTotal += correctCount;
  }

  return ConversionScore(
    expectedCount: expected.length,
    correctCount: correctTotal,
    proposedCount: proposed.length,
    bySection: bySection,
  );
}
