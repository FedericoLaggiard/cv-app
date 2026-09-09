/// No-lost-lines invariant (ticket 50, user story 6): every line
/// `buildFromPages` reads must end up somewhere traceable — a structured
/// field, "Da rivedere", a recognized section heading (consumed
/// structurally by design, not content), or (ticket 53) evidence a
/// heuristic actually looked at, per the accompanying [ImportProposalReport]
/// — a line the aggressive per-document vote considered but decided *not*
/// to use (e.g. the losing candidate in an ambiguous ruolo/azienda pair)
/// still needs a home, even though it never lands in the document's text.
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/pdf/import_proposal_report.dart';
import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';

/// Every text fragment [doc] actually carries: structured field values,
/// item descriptions, and custom-section (i.e. "Da rivedere") markdown.
Iterable<String> _documentTextFragments(CvDocument doc) sync* {
  for (final section in doc.sections) {
    switch (section) {
      case AnagraficaSection(:final data):
        yield data.nome;
        yield data.cognome;
        if (data.headline != null) yield data.headline!;
      case ContattiSection(:final data):
        if (data.email != null) yield data.email!;
        if (data.telefono != null) yield data.telefono!;
        for (final link in data.link) {
          yield link.url;
        }
      case EsperienzeSection(:final items):
        for (final it in items) {
          yield it.ruolo;
          yield it.azienda;
          if (it.descrizione != null) yield it.descrizione!;
        }
      case FormazioneSection(:final items):
        for (final it in items) {
          yield it.titolo;
          if (it.istituto != null) yield it.istituto!;
          if (it.descrizione != null) yield it.descrizione!;
        }
      case CertificazioniSection(:final items):
        for (final it in items) {
          yield it.nome;
        }
      case SkillSection(:final data):
        if (data.markdown != null) yield data.markdown!;
        for (final tag in data.tags) {
          yield tag;
        }
      case LingueSection(:final items):
        for (final it in items) {
          yield it.lingua;
        }
      case CustomSection(:final markdown):
        yield markdown;
      case SommarioSection():
        break;
    }
  }
}

/// Lines from a fixture that aren't traceable into [doc], aren't a
/// recognized section heading, and aren't cited as evidence in [report].
/// Empty means the invariant holds.
List<String> findLostLines(
  List<String> lines,
  CvDocument doc, [
  ImportProposalReport? report,
]) {
  final haystack = _documentTextFragments(doc).join('\n');
  final evidence = {
    for (final p in report?.proposals ?? const <FieldProposal>[])
      for (final s in p.sourceLines) s,
  };
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
    if (evidence.contains(line)) continue;
    lost.add(line);
  }
  return lost;
}
