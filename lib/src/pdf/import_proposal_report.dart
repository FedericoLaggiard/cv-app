/// `ImportProposalReport` seam (ticket 52, ADR 0002): a transient companion
/// to the [CvDocument] produced by [PdfImporter.import]/`buildFromPages`.
///
/// Carries, per proposed field, a **binary** confidence (never a numeric
/// score — ticket 13) and the PDF source lines the proposal was derived
/// from. Consumed by the review step (`import_review_screen.dart`) to
/// highlight the fields the user should look at; discarded once the user
/// confirms. It never reaches `.cvapp` — see ADR 0002 for why.
library;

import 'package:flutter/foundation.dart';

/// One field the heuristics proposed a value for.
///
/// [field] is an opaque dotted/indexed path (`'contatti.email'`,
/// `'esperienze[0].descrizione'`, ...) — a display convention shared between
/// the heuristics that produce proposals and the review screen that reads
/// them, not a schema.
@immutable
class FieldProposal {
  final String field;
  final bool certain;
  final List<String> sourceLines;

  FieldProposal({
    required this.field,
    required this.certain,
    List<String> sourceLines = const [],
  }) : sourceLines = List.unmodifiable(sourceLines);

  @override
  bool operator ==(Object other) =>
      other is FieldProposal &&
      other.field == field &&
      other.certain == certain &&
      listEquals(other.sourceLines, sourceLines);

  @override
  int get hashCode => Object.hash(field, certain, Object.hashAll(sourceLines));

  @override
  String toString() =>
      'FieldProposal(field: $field, certain: $certain, '
      'sourceLines: $sourceLines)';
}

/// The full set of [FieldProposal]s produced for one PDF import.
@immutable
class ImportProposalReport {
  final List<FieldProposal> proposals;

  ImportProposalReport(List<FieldProposal> proposals)
    : proposals = List.unmodifiable(proposals);

  const ImportProposalReport.empty() : proposals = const [];

  /// Proposals marked uncertain — what the review step should highlight.
  List<FieldProposal> get uncertain => [
    for (final p in proposals)
      if (!p.certain) p,
  ];

  bool get hasUncertain => uncertain.isNotEmpty;

  /// The proposal for [field], or `null` if the heuristics never proposed
  /// anything for it (nothing to highlight — not the same as "certain").
  FieldProposal? forField(String field) {
    for (final p in proposals) {
      if (p.field == field) return p;
    }
    return null;
  }

  /// True only when a proposal exists for [field] and it is marked
  /// uncertain — the direct highlighting predicate the review screen uses.
  bool isUncertain(String field) => forField(field)?.certain == false;

  @override
  bool operator ==(Object other) =>
      other is ImportProposalReport && listEquals(other.proposals, proposals);

  @override
  int get hashCode => Object.hashAll(proposals);
}

/// Mutable accumulator used while building an [ImportProposalReport]
/// alongside a [CvDocument] — mirrors the `StringBuffer` "Da rivedere"
/// pattern already used by `pdf_import_heuristics.dart`.
class ImportProposalReportBuilder {
  final List<FieldProposal> _proposals = [];

  void add(
    String field, {
    required bool certain,
    List<String> sourceLines = const [],
  }) {
    _proposals.add(
      FieldProposal(field: field, certain: certain, sourceLines: sourceLines),
    );
  }

  ImportProposalReport build() => ImportProposalReport(_proposals);
}
