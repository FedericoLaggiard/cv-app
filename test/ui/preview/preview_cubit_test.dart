import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/pdf_exporter.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/preview/preview_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

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

Future<String> _seed(InMemoryCvRepository repo, {String name = 'Test'}) async {
  final doc = await repo.create(initialVariantName: name);
  return doc.id;
}

Future<void> _pump([int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('PreviewCubit', () {
    test('inizializzazione: PreviewReady col documento del repo, non stale', () async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, name: 'Alpha');
      final cubit = PreviewCubit(
        repository: repo,
        variantId: id,
        pdfExporter: _FakePdfExporter(),
      );
      await _pump();

      final s = cubit.state;
      expect(s, isA<PreviewReady>());
      final r = s as PreviewReady;
      expect(r.document.variantName, 'Alpha');
      expect(r.templateId, TemplateId.classico);
      expect(r.labelLocale, LabelLocale.it);
      expect(r.stale, isFalse);

      await cubit.close();
    });

    test('id sconosciuto → PreviewLoadError', () async {
      final repo = InMemoryCvRepository();
      final cubit = PreviewCubit(
        repository: repo,
        variantId: 'missing-id',
        pdfExporter: _FakePdfExporter(),
      );
      await _pump();

      expect(cubit.state, isA<PreviewLoadError>());
      await cubit.close();
    });

    test('documento modificato altrove propaga e marca stale senza rigenerare', () async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, name: 'Alpha');
      final cubit = PreviewCubit(
        repository: repo,
        variantId: id,
        pdfExporter: _FakePdfExporter(),
      );
      await _pump();

      final before = cubit.state as PreviewReady;
      expect(before.renderGeneration, 0);

      final doc = await repo.watch(id).first;
      await repo.save(doc.copyWith(variantName: 'Beta'));
      await _pump();

      final after = cubit.state as PreviewReady;
      expect(after.document.variantName, 'Beta');
      expect(after.stale, isTrue);
      // Nessuna rigenerazione automatica: i committed restano quelli
      // iniziali e la generation non cambia.
      expect(after.renderGeneration, 0);
      expect(after.renderedDocument.variantName, 'Alpha');

      await cubit.close();
    });

    test('templateChanged marca stale; regenerate riallinea e incrementa la generation', () async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final cubit = PreviewCubit(
        repository: repo,
        variantId: id,
        pdfExporter: _FakePdfExporter(),
      );
      await _pump();

      cubit.templateChanged(TemplateId.moderno);
      var s = cubit.state as PreviewReady;
      expect(s.templateId, TemplateId.moderno);
      expect(s.stale, isTrue);
      expect(s.renderedTemplate, TemplateId.classico);

      cubit.regenerate();
      s = cubit.state as PreviewReady;
      expect(s.stale, isFalse);
      expect(s.renderedTemplate, TemplateId.moderno);
      expect(s.renderGeneration, 1);

      await cubit.close();
    });

    test('labelLocaleChanged marca stale', () async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final cubit = PreviewCubit(
        repository: repo,
        variantId: id,
        pdfExporter: _FakePdfExporter(),
      );
      await _pump();

      cubit.labelLocaleChanged(LabelLocale.en);
      final s = cubit.state as PreviewReady;
      expect(s.labelLocale, LabelLocale.en);
      expect(s.stale, isTrue);

      await cubit.close();
    });

    test('buildPdf renderizza sempre gli input committed, non quelli correnti', () async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final exporter = _FakePdfExporter();
      final cubit = PreviewCubit(
        repository: repo,
        variantId: id,
        pdfExporter: exporter,
      );
      await _pump();

      cubit.templateChanged(TemplateId.minimal);
      final bytes = await cubit.buildPdf(PdfPageFormat.a4);

      expect(bytes, isNotEmpty);
      expect(exporter.calls, 1);
      // Non ancora rigenerato: il render usa ancora il template committed
      // (classico), non la nuova selezione (minimal).
      expect(exporter.lastTemplate, TemplateId.classico);

      cubit.regenerate();
      await cubit.buildPdf(PdfPageFormat.a4);
      expect(exporter.lastTemplate, TemplateId.minimal);

      await cubit.close();
    });

    test('buildPdf propaga un errore di render come PreviewRenderException', () async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo);
      final cubit = PreviewCubit(
        repository: repo,
        variantId: id,
        pdfExporter: _FakePdfExporter(error: StateError('font mancante')),
      );
      await _pump();

      await expectLater(
        () => cubit.buildPdf(PdfPageFormat.a4),
        throwsA(
          isA<PreviewRenderException>().having(
            (e) => e.message,
            'message',
            contains('font mancante'),
          ),
        ),
      );

      await cubit.close();
    });
  });
}
