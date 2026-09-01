/// Wiring del pulsante `Esporta PDF` nella top bar dell'editor (ticket 24):
/// apre il dialog, e alla conferma chiama [PdfExporter] + [PdfDelivery]
/// iniettati, mostrando uno SnackBar solo in caso di errore.
library;

import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/pdf_delivery.dart';
import 'package:cv_app/src/pdf/pdf_exporter.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePdfExporter implements PdfExporter {
  _FakePdfExporter({this.error});
  final Object? error;
  int calls = 0;
  TemplateId? lastTemplate;
  LabelLocale? lastLocale;

  @override
  Future<Uint8List> render({
    required CvDocument document,
    required TemplateId template,
    required LabelLocale labelLocale,
  }) async {
    calls++;
    lastTemplate = template;
    lastLocale = labelLocale;
    if (error != null) throw error!;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

class _FakePdfDelivery implements PdfDelivery {
  _FakePdfDelivery(this.result);
  final DeliveryResult result;
  int calls = 0;
  String? lastFileName;

  @override
  Future<DeliveryResult> deliver(
    Uint8List pdf,
    String suggestedFileName,
  ) async {
    calls++;
    lastFileName = suggestedFileName;
    return result;
  }
}

Future<String> _seed(
  InMemoryCvRepository repo, {
  String name = 'Variante',
}) async {
  final doc = await repo.create(initialVariantName: name);
  return doc.id;
}

void main() {
  testWidgets('Esporta PDF: conferma nel dialog chiama exporter + delivery', (
    tester,
  ) async {
    final repo = InMemoryCvRepository();
    final id = await _seed(repo, name: 'Backend Senior IT');
    final exporter = _FakePdfExporter();
    final delivery = _FakePdfDelivery(const DeliverySuccess());

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          variantId: id,
          repository: repo,
          pdfExporter: exporter,
          pdfDelivery: delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_export_pdf')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export_confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('export_confirm')));
    await tester.pumpAndSettle();

    expect(exporter.calls, 1);
    expect(exporter.lastTemplate, TemplateId.classico);
    expect(exporter.lastLocale, LabelLocale.it);
    expect(delivery.calls, 1);
    expect(delivery.lastFileName, 'Backend Senior IT.pdf');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Esporta PDF: un errore di delivery mostra uno SnackBar', (
    tester,
  ) async {
    final repo = InMemoryCvRepository();
    final id = await _seed(repo);
    final exporter = _FakePdfExporter();
    final delivery = _FakePdfDelivery(const DeliveryError('permessi negati'));

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          variantId: id,
          repository: repo,
          pdfExporter: exporter,
          pdfDelivery: delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_export_pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('permessi negati'), findsOneWidget);
  });

  testWidgets(
    'Esporta PDF: un errore di rendering (exporter) mostra uno SnackBar',
    (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final exporter = _FakePdfExporter(error: StateError('font mancante'));
      final delivery = _FakePdfDelivery(const DeliverySuccess());

      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            variantId: id,
            repository: repo,
            pdfExporter: exporter,
            pdfDelivery: delivery,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editor_export_pdf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export_confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('font mancante'), findsOneWidget);
      expect(delivery.calls, 0);
    },
  );

  testWidgets('Esporta PDF: annullare il dialog non chiama exporter/delivery', (
    tester,
  ) async {
    final repo = InMemoryCvRepository();
    final id = await _seed(repo);
    final exporter = _FakePdfExporter();
    final delivery = _FakePdfDelivery(const DeliverySuccess());

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          variantId: id,
          repository: repo,
          pdfExporter: exporter,
          pdfDelivery: delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_export_pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(exporter.calls, 0);
    expect(delivery.calls, 0);
  });
}
