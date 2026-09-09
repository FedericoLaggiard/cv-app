/// Unit tests for [ImportProposalReport] (ticket 52, ADR 0002): the
/// transient confidence + provenance seam consumed by the review screen.
library;

import 'package:cv_app/src/pdf/import_proposal_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImportProposalReport', () {
    test('vuoto: nessun campo, nessun incerto', () {
      const report = ImportProposalReport.empty();
      expect(report.proposals, isEmpty);
      expect(report.hasUncertain, false);
      expect(report.forField('contatti.email'), null);
      expect(report.isUncertain('contatti.email'), false);
    });

    test('forField restituisce la proposta con quel path', () {
      final report = ImportProposalReport([
        FieldProposal(
          field: 'contatti.email',
          certain: true,
          sourceLines: ['mario@example.com'],
        ),
      ]);
      final proposal = report.forField('contatti.email');
      expect(proposal, isNotNull);
      expect(proposal!.certain, true);
      expect(proposal.sourceLines, ['mario@example.com']);
      expect(report.forField('contatti.telefono'), null);
    });

    test('isUncertain è true solo per una proposta marcata incerta', () {
      final report = ImportProposalReport([
        FieldProposal(field: 'esperienze[0].dateRange', certain: true),
        FieldProposal(field: 'esperienze[0].descrizione', certain: false),
      ]);
      expect(report.isUncertain('esperienze[0].dateRange'), false);
      expect(report.isUncertain('esperienze[0].descrizione'), true);
      // Nessuna proposta per questo campo: non è "incerto", è assente.
      expect(report.isUncertain('esperienze[1].descrizione'), false);
    });

    test('uncertain filtra solo le proposte incerte', () {
      final report = ImportProposalReport([
        FieldProposal(field: 'a', certain: true),
        FieldProposal(field: 'b', certain: false),
        FieldProposal(field: 'c', certain: false),
      ]);
      expect(report.uncertain.map((p) => p.field), ['b', 'c']);
      expect(report.hasUncertain, true);
    });
  });

  group('ImportProposalReportBuilder', () {
    test('accumula le proposte in ordine', () {
      final builder = ImportProposalReportBuilder();
      builder.add('contatti.email', certain: true, sourceLines: ['x@y.com']);
      builder.add('esperienze[0].descrizione', certain: false);
      final report = builder.build();

      expect(report.proposals, hasLength(2));
      expect(report.proposals.first.field, 'contatti.email');
      expect(report.proposals.last.certain, false);
    });
  });

  group('FieldProposal', () {
    test('uguaglianza per valore', () {
      final a = FieldProposal(
        field: 'contatti.email',
        certain: true,
        sourceLines: ['x@y.com'],
      );
      final b = FieldProposal(
        field: 'contatti.email',
        certain: true,
        sourceLines: ['x@y.com'],
      );
      final c = FieldProposal(field: 'contatti.email', certain: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
