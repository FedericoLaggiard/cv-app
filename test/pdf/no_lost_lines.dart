/// No-lost-lines invariant (ticket 50, user story 6): every line
/// `buildFromPages` reads must end up somewhere traceable — a structured
/// field, "Da rivedere", or a recognized section heading (consumed
/// structurally by design, not content).
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';

/// Every text fragment [doc] actually carries: structured field values,
/// item descriptions, and custom-section (i.e. "Da rivedere") markdown.
Iterable<String> _documentTextFragments(CvDocument doc) sync* {
  for (final section in doc.sections) {
    switch (section) {
      case ContattiSection(:final data):
        if (data.email != null) yield data.email!;
        if (data.telefono != null) yield data.telefono!;
        for (final link in data.link) {
          yield link.url;
        }
      case EsperienzeSection(:final items):
        for (final it in items) {
          if (it.descrizione != null) yield it.descrizione!;
        }
      case FormazioneSection(:final items):
        for (final it in items) {
          if (it.descrizione != null) yield it.descrizione!;
        }
      case CertificazioniSection(:final items):
        for (final it in items) {
          yield it.nome;
        }
      case CustomSection(:final markdown):
        yield markdown;
      case AnagraficaSection() ||
          SommarioSection() ||
          SkillSection() ||
          LingueSection():
        break;
    }
  }
}

/// Lines from a fixture that aren't traceable into [doc] and aren't a
/// recognized section heading. Empty means the invariant holds.
List<String> findLostLines(List<String> lines, CvDocument doc) {
  final haystack = _documentTextFragments(doc).join('\n');
  final lost = <String>[];
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (isRecognizedSectionHeading(line)) continue;
    // A date-range line is consumed into typed startDate/endDate/current
    // fields, not copied verbatim — still "ended up in a field", just not
    // as text (ticket 50).
    if (looksLikeDateRangeLine(line)) continue;
    if (haystack.contains(line)) continue;
    lost.add(line);
  }
  return lost;
}
