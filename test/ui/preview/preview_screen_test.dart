/// Widget test per [PreviewScreen] (ticket 27, Testing Decisions).
library;

import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/pdf_delivery.dart';
import 'package:cv_app/src/pdf/pdf_exporter.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/preview/preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePdfExporter implements PdfExporter {
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
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

class _FakePdfDelivery implements PdfDelivery {
  int calls = 0;

  @override
  Future<DeliveryResult> deliver(
    Uint8List pdf,
    String suggestedFileName,
  ) async {
    calls++;
    return const DeliverySuccess();
  }
}

Future<String> _seed(InMemoryCvRepository repo, {String name = 'Variante'}) async {
  final doc = await repo.create(initialVariantName: name);
  return doc.id;
}

/// `PdfPreview` mostra uno spinner con animazione infinita mentre il
/// `build` future è in volo: `pumpAndSettle` non termina mai in sua
/// presenza, quindi qui pompiamo un numero di frame fisso.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('entra con documento → prima render chiamata', (tester) async {
    final repo = InMemoryCvRepository();
    final id = await _seed(repo);
    final exporter = _FakePdfExporter();

    await tester.pumpWidget(
      MaterialApp(
        home: PreviewScreen(
          variantId: id,
          repository: repo,
          pdfExporter: exporter,
        ),
      ),
    );
    await _settle(tester);

    expect(exporter.calls, 1);
    expect(exporter.lastTemplate, TemplateId.classico);
    expect(exporter.lastLocale, LabelLocale.it);
    expect(find.byKey(const Key('preview_stale_banner')), findsNothing);
  });

  testWidgets(
    'cambio template → staleness true + banner, senza rigenerare',
    (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final exporter = _FakePdfExporter();

      await tester.pumpWidget(
        MaterialApp(
          home: PreviewScreen(
            variantId: id,
            repository: repo,
            pdfExporter: exporter,
          ),
        ),
      );
      await _settle(tester);
      expect(exporter.calls, 1);

      await tester.tap(
        find.byKey(const Key('template_picker_option_moderno')),
      );
      await _settle(tester);

      expect(find.byKey(const Key('preview_stale_banner')), findsOneWidget);
      // Nessuna rigenerazione automatica.
      expect(exporter.calls, 1);
    },
  );

  testWidgets(
    'premi Aggiorna → nuova render con il nuovo TemplateId',
    (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final exporter = _FakePdfExporter();

      await tester.pumpWidget(
        MaterialApp(
          home: PreviewScreen(
            variantId: id,
            repository: repo,
            pdfExporter: exporter,
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(const Key('template_picker_option_moderno')),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('preview_refresh_button')));
      await _settle(tester);

      expect(exporter.calls, 2);
      expect(exporter.lastTemplate, TemplateId.moderno);
      expect(find.byKey(const Key('preview_stale_banner')), findsNothing);
    },
  );

  testWidgets(
    'premi Esporta → dialog Slice E aperto con default pre-riempiti',
    (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final exporter = _FakePdfExporter();
      final delivery = _FakePdfDelivery();

      await tester.pumpWidget(
        MaterialApp(
          home: PreviewScreen(
            variantId: id,
            repository: repo,
            pdfExporter: exporter,
            pdfDelivery: delivery,
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(
        find.byKey(const Key('template_picker_option_minimal')),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('preview_export_pdf')));
      await _settle(tester);

      expect(find.byKey(const Key('export_confirm')), findsOneWidget);
      // Eredita la selezione corrente della preview (minimal), anche se
      // non ancora rigenerata/committed.
      expect(
        find.descendant(
          of: find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byKey(const Key('template_picker_option_minimal')),
          ),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('export_confirm')));
      await _settle(tester);

      expect(exporter.lastTemplate, TemplateId.minimal);
      expect(delivery.calls, 1);
    },
  );

  testWidgets(
    'documento modificato dallo stream watch(id) → banner senza rigenerare',
    (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, name: 'Alpha');
      final exporter = _FakePdfExporter();

      await tester.pumpWidget(
        MaterialApp(
          home: PreviewScreen(
            variantId: id,
            repository: repo,
            pdfExporter: exporter,
          ),
        ),
      );
      await _settle(tester);
      expect(exporter.calls, 1);

      final doc = await repo.watch(id).first;
      await repo.save(doc.copyWith(variantName: 'Beta'));
      await _settle(tester);

      expect(find.byKey(const Key('preview_stale_banner')), findsOneWidget);
      expect(exporter.calls, 1);
    },
  );
}
