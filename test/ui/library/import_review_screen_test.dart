/// Widget tests for [ImportReviewScreen] (ticket 52): uncertain fields are
/// highlighted, confirm/cancel create-or-not a variant via the pushed
/// [CvDocument], and "Da rivedere" lines can be assigned to a field.
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/json_codec.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:cv_app/src/pdf/import_proposal_report.dart';
import 'package:cv_app/src/ui/library/import_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CvDocument _docWith(List<CvSection> sections) => CvDocument(
  id: 'doc-1',
  createdAt: DateTime.utc(2000),
  updatedAt: DateTime.utc(2000),
  variantName: 'test',
  sections: sections,
);

/// Pushes [ImportReviewScreen] as the initial route and captures whatever
/// it eventually pops via [onResult].
Widget _harness({
  required CvDocument doc,
  required ImportProposalReport report,
  required void Function(CvDocument?) onResult,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          key: const Key('open_review'),
          onPressed: () async {
            final result = await Navigator.of(context).push<CvDocument>(
              MaterialPageRoute(
                builder: (_) => ImportReviewScreen(doc: doc, report: report),
              ),
            );
            onResult(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('ImportReviewScreen — riepilogo', () {
    testWidgets('mostra i conteggi delle sezioni riconosciute', (tester) async {
      final doc = _docWith([
        EsperienzeSection(
          displayTitle: 'Esperienze',
          items: [
            EsperienzaItem(
              id: 'e1',
              ruolo: '',
              azienda: '',
              startDate: YearMonth(2020, 1),
            ),
          ],
        ),
        FormazioneSection(displayTitle: 'Formazione', items: const []),
      ]);
      CvDocument? result;
      await tester.pumpWidget(
        _harness(
          doc: doc,
          report: const ImportProposalReport.empty(),
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      expect(find.text('Ho capito: 1 esperienza.'), findsOneWidget);
      expect(result, isNull); // not popped yet
    });
  });

  group('ImportReviewScreen — campi incerti', () {
    testWidgets('un campo incerto mostra l\'indicatore, uno certo no', (
      tester,
    ) async {
      final doc = _docWith([
        EsperienzeSection(
          displayTitle: 'Esperienze',
          items: [
            EsperienzaItem(
              id: 'e1',
              ruolo: '',
              azienda: '',
              startDate: YearMonth(2020, 1),
              descrizione: 'Testo dedotto',
            ),
          ],
        ),
      ]);
      final report = ImportProposalReport([
        FieldProposal(field: 'esperienze[0].descrizione', certain: false),
      ]);
      await tester.pumpWidget(
        _harness(doc: doc, report: report, onResult: (_) {}),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('uncertain_marker_esperienze[0].descrizione')),
        findsOneWidget,
      );
    });

    testWidgets('un dateRange incerto mostra l\'indicatore sul campo inizio', (
      tester,
    ) async {
      final doc = _docWith([
        EsperienzeSection(
          displayTitle: 'Esperienze',
          items: [
            EsperienzaItem(
              id: 'e1',
              ruolo: '',
              azienda: '',
              startDate: YearMonth(2020, 1),
            ),
          ],
        ),
      ]);
      final report = ImportProposalReport([
        FieldProposal(field: 'esperienze[0].dateRange', certain: false),
      ]);
      await tester.pumpWidget(
        _harness(doc: doc, report: report, onResult: (_) {}),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('uncertain_marker_esperienze[0].dateRange')),
        findsOneWidget,
      );
    });

    testWidgets('nessuna proposta incerta -> nessun indicatore', (
      tester,
    ) async {
      final doc = _docWith([
        ContattiSection(
          displayTitle: 'Contatti',
          data: ContattiData(email: 'a@b.com'),
        ),
      ]);
      final report = ImportProposalReport([
        FieldProposal(field: 'contatti.email', certain: true),
      ]);
      await tester.pumpWidget(
        _harness(doc: doc, report: report, onResult: (_) {}),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('uncertain_marker_contatti.email')),
        findsNothing,
      );
    });
  });

  group('ImportReviewScreen — conferma/annulla', () {
    testWidgets('conferma restituisce il documento (eventualmente corretto)', (
      tester,
    ) async {
      final doc = _docWith([
        ContattiSection(
          displayTitle: 'Contatti',
          data: ContattiData(email: 'a@b.com'),
        ),
      ]);
      CvDocument? result;
      await tester.pumpWidget(
        _harness(
          doc: doc,
          report: const ImportProposalReport.empty(),
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('field_contatti.email')),
        'corretto@b.com',
      );
      await tester.tap(find.byKey(const Key('import_review_confirm')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(
        result!.sections.whereType<ContattiSection>().single.data.email,
        'corretto@b.com',
      );
    });

    testWidgets(
      'correggere il periodo (dateRange) inline aggiorna il documento',
      (tester) async {
        final doc = _docWith([
          EsperienzeSection(
            displayTitle: 'Esperienze',
            items: [
              EsperienzaItem(
                id: 'e1',
                ruolo: '',
                azienda: '',
                startDate: YearMonth(2020, 1),
                endDate: YearMonth(2021, 3),
              ),
            ],
          ),
        ]);
        CvDocument? result;
        await tester.pumpWidget(
          _harness(
            doc: doc,
            report: const ImportProposalReport.empty(),
            onResult: (r) => result = r,
          ),
        );
        await tester.tap(find.byKey(const Key('open_review')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('field_esperienze[0].dateRange_start')),
          '03/2019',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('import_review_confirm')));
        await tester.pumpAndSettle();

        final item = result!.sections
            .whereType<EsperienzeSection>()
            .single
            .items
            .single;
        expect(item.startDate, YearMonth(2019, 3));
      },
    );

    testWidgets('annulla restituisce null: nessuna variante da creare', (
      tester,
    ) async {
      final doc = _docWith([
        ContattiSection(
          displayTitle: 'Contatti',
          data: ContattiData(email: 'a@b.com'),
        ),
      ]);
      var resultCaptured = false;
      CvDocument? result;
      await tester.pumpWidget(
        _harness(
          doc: doc,
          report: const ImportProposalReport.empty(),
          onResult: (r) {
            result = r;
            resultCaptured = true;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('import_review_cancel')));
      await tester.pumpAndSettle();

      expect(resultCaptured, true);
      expect(result, isNull);
    });
  });

  group('ImportReviewScreen — Da rivedere', () {
    testWidgets('assegnare una riga a un campo la sposta lì e la rimuove', (
      tester,
    ) async {
      final doc = _docWith([
        EsperienzeSection(
          displayTitle: 'Esperienze',
          items: [
            EsperienzaItem(
              id: 'e1',
              ruolo: '',
              azienda: '',
              startDate: YearMonth(2020, 1),
            ),
          ],
        ),
        CustomSection(
          id: 'review',
          displayTitle: 'Da rivedere',
          markdown: 'Riga orfana da assegnare',
        ),
      ]);
      CvDocument? result;
      await tester.pumpWidget(
        _harness(
          doc: doc,
          report: const ImportProposalReport.empty(),
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      expect(find.text('Da rivedere'), findsOneWidget);
      expect(find.text('Riga orfana da assegnare'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_line_assign')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esperienza 1').last);
      await tester.pumpAndSettle();

      // La riga sparisce dal pannello "Da rivedere"...
      expect(find.text('Riga orfana da assegnare'), findsNothing);
      expect(find.text('Da rivedere'), findsNothing);

      await tester.tap(find.byKey(const Key('import_review_confirm')));
      await tester.pumpAndSettle();

      // ...ed è finita nella descrizione dell'esperienza.
      final esperienza = result!.sections
          .whereType<EsperienzeSection>()
          .single
          .items
          .single;
      expect(esperienza.descrizione, 'Riga orfana da assegnare');
      expect(result!.sections.whereType<CustomSection>(), isEmpty);
    });
  });

  group('ImportReviewScreen — nessuna traccia del report su disco', () {
    testWidgets('il .cvapp confermato è identico a quello compilato a mano', (
      tester,
    ) async {
      final doc = _docWith([
        ContattiSection(
          displayTitle: 'Contatti',
          data: ContattiData(email: 'a@b.com'),
        ),
        EsperienzeSection(
          displayTitle: 'Esperienze',
          items: [
            EsperienzaItem(
              id: 'e1',
              ruolo: '',
              azienda: '',
              startDate: YearMonth(2020, 1),
              descrizione: 'Deduzione incerta',
            ),
          ],
        ),
      ]);
      final report = ImportProposalReport([
        FieldProposal(field: 'contatti.email', certain: true),
        FieldProposal(field: 'esperienze[0].descrizione', certain: false),
      ]);
      CvDocument? result;
      await tester.pumpWidget(
        _harness(doc: doc, report: report, onResult: (r) => result = r),
      );
      await tester.tap(find.byKey(const Key('open_review')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('import_review_confirm')));
      await tester.pumpAndSettle();

      // Lo stesso documento compilato a mano, senza mai passare da un
      // ImportProposalReport.
      final handFilled = _docWith([
        ContattiSection(
          displayTitle: 'Contatti',
          data: ContattiData(email: 'a@b.com'),
        ),
        EsperienzeSection(
          displayTitle: 'Esperienze',
          items: [
            EsperienzaItem(
              id: 'e1',
              ruolo: '',
              azienda: '',
              startDate: YearMonth(2020, 1),
              descrizione: 'Deduzione incerta',
            ),
          ],
        ),
      ]);

      final confirmedJson = CvDocumentCodec.toJsonString(result!);
      final handFilledJson = CvDocumentCodec.toJsonString(handFilled);
      expect(confirmedJson, handFilledJson);
      expect(confirmedJson, isNot(contains('certain')));
      expect(confirmedJson, isNot(contains('proposal')));
    });
  });
}
