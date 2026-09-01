/// Widget test sul dialog `Esporta PDF` (ticket 24): campi obbligatori
/// mancanti → riepilogo mostrato + `Esporta comunque` visibile; scelta
/// template + locale → passata correttamente nell'[ExportChoice].
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/missing_required.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/pdf_exporter.dart';
import 'package:cv_app/src/ui/editor/widgets/export_pdf_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CvDocument _doc(List<CvSection> sections) => CvDocument(
  id: 'doc-1',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  variantName: 'v',
  sections: sections,
);

Future<ExportChoice?> _open(
  WidgetTester tester, {
  required CvDocument document,
  required MissingRequired missing,
}) async {
  ExportChoice? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            captured = await showExportPdfDialog(
              context,
              document: document,
              missing: missing,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('senza campi mancanti mostra "Esporta" e nessun riepilogo', (
    tester,
  ) async {
    await _open(
      tester,
      document: _doc(const [
        AnagraficaSection(
          displayTitle: 'Anagrafica',
          data: AnagraficaData(nome: 'Mario', cognome: 'Rossi'),
        ),
      ]),
      missing: MissingRequired.empty,
    );

    expect(find.text('Esporta'), findsOneWidget);
    expect(find.text('Esporta comunque'), findsNothing);
    expect(find.text('Campi obbligatori mancanti'), findsNothing);
  });

  testWidgets('con campi mancanti mostra il riepilogo e "Esporta comunque"', (
    tester,
  ) async {
    const section = AnagraficaSection(
      displayTitle: 'Anagrafica',
      data: AnagraficaData(nome: '', cognome: ''),
    );
    final missing = analyzeMissingRequired(_doc(const [section]));

    await _open(tester, document: _doc(const [section]), missing: missing);

    expect(find.text('Esporta comunque'), findsOneWidget);
    expect(find.text('Campi obbligatori mancanti'), findsOneWidget);
    expect(find.textContaining('Anagrafica:'), findsOneWidget);
  });

  testWidgets('il template default è Classico e la locale default è Italiano', (
    tester,
  ) async {
    final choice = await _openAndConfirm(tester);
    expect(choice!.template, TemplateId.classico);
    expect(choice.labelLocale, LabelLocale.it);
  });

  testWidgets('cambiare la lingua etichette a English la passa nella scelta', (
    tester,
  ) async {
    ExportChoice? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showExportPdfDialog(
                context,
                document: _doc(const []),
                missing: MissingRequired.empty,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_locale_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_confirm')));
    await tester.pumpAndSettle();

    expect(captured!.labelLocale, LabelLocale.en);
  });

  testWidgets('Annulla chiude il dialog restituendo null', (tester) async {
    ExportChoice? captured = const ExportChoice(
      template: TemplateId.classico,
      labelLocale: LabelLocale.en,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showExportPdfDialog(
                context,
                document: _doc(const []),
                missing: MissingRequired.empty,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });
}

Future<ExportChoice?> _openAndConfirm(WidgetTester tester) async {
  ExportChoice? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            captured = await showExportPdfDialog(
              context,
              document: _doc(const []),
              missing: MissingRequired.empty,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('export_confirm')));
  await tester.pumpAndSettle();
  return captured;
}
