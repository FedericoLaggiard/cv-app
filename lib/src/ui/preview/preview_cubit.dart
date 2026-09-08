/// PreviewCubit — stato per la preview PDF a pagina piena (ticket 27,
/// Spec H).
///
/// Distingue gli input "correnti" (`document`, `templateId`,
/// `labelLocale`, che seguono l'editor e le scelte dell'utente in tempo
/// reale) dagli input "committed" (`renderedDocument`, `renderedTemplate`,
/// `renderedLocale`, cioè quelli effettivamente usati per l'ultimo
/// render). `stale` è vero quando i due insiemi divergono — la
/// rigenerazione è sempre manuale (ticket 07 + costo su Web), quindi solo
/// [regenerate] li riallinea.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';

import '../../domain/cv_document.dart';
import '../../pdf/label_locale.dart';
import '../../pdf/pdf_exporter.dart';
import '../../repository/cv_repository.dart';

sealed class PreviewState {
  const PreviewState();
}

class PreviewLoading extends PreviewState {
  const PreviewLoading();
}

class PreviewLoadError extends PreviewState {
  final String message;
  const PreviewLoadError(this.message);
}

/// La variante aperta in preview è stata eliminata altrove (stesso caso
/// di `EditorDeleted`, ticket 23 — multi-finestra su desktop). La UI
/// reagisce tornando all'editor/libreria.
class PreviewDeleted extends PreviewState {
  const PreviewDeleted();
}

class PreviewReady extends PreviewState {
  final CvDocument document;
  final TemplateId templateId;
  final LabelLocale labelLocale;

  final CvDocument renderedDocument;
  final TemplateId renderedTemplate;
  final LabelLocale renderedLocale;

  /// Incrementato a ogni [PreviewCubit.regenerate]; usato come `Key` del
  /// widget `PdfPreview` per forzare un nuovo render (didUpdateWidget di
  /// `PdfPreview` confronta l'identità del callback `build`, non il suo
  /// output, quindi la key è il modo affidabile per invalidare la cache).
  final int renderGeneration;

  const PreviewReady({
    required this.document,
    required this.templateId,
    required this.labelLocale,
    required this.renderedDocument,
    required this.renderedTemplate,
    required this.renderedLocale,
    required this.renderGeneration,
  });

  /// True quando il documento corrente o la scelta di template/lingua
  /// divergono da quanto effettivamente renderizzato l'ultima volta.
  bool get stale =>
      document != renderedDocument ||
      templateId != renderedTemplate ||
      labelLocale != renderedLocale;

  PreviewReady copyWith({
    CvDocument? document,
    TemplateId? templateId,
    LabelLocale? labelLocale,
    CvDocument? renderedDocument,
    TemplateId? renderedTemplate,
    LabelLocale? renderedLocale,
    int? renderGeneration,
  }) => PreviewReady(
    document: document ?? this.document,
    templateId: templateId ?? this.templateId,
    labelLocale: labelLocale ?? this.labelLocale,
    renderedDocument: renderedDocument ?? this.renderedDocument,
    renderedTemplate: renderedTemplate ?? this.renderedTemplate,
    renderedLocale: renderedLocale ?? this.renderedLocale,
    renderGeneration: renderGeneration ?? this.renderGeneration,
  );

  @override
  bool operator ==(Object other) =>
      other is PreviewReady &&
      other.document == document &&
      other.templateId == templateId &&
      other.labelLocale == labelLocale &&
      other.renderedDocument == renderedDocument &&
      other.renderedTemplate == renderedTemplate &&
      other.renderedLocale == renderedLocale &&
      other.renderGeneration == renderGeneration;

  @override
  int get hashCode => Object.hash(
    document,
    templateId,
    labelLocale,
    renderedDocument,
    renderedTemplate,
    renderedLocale,
    renderGeneration,
  );
}

/// Il render di [PreviewCubit.buildPdf] è fallito. Il chiamante (il box
/// `Errore anteprima [Riprova]` mostrato via `PdfPreview.onError`) mostra
/// [message] e offre `regenerate()` come retry.
class PreviewRenderException implements Exception {
  final String message;
  const PreviewRenderException(this.message);
  @override
  String toString() => message;
}

class PreviewCubit extends Cubit<PreviewState> {
  final CvRepository _repo;
  final PdfExporter pdfExporter;
  StreamSubscription<CvDocument>? _sub;

  PreviewCubit({
    required CvRepository repository,
    required String variantId,
    required this.pdfExporter,
    TemplateId initialTemplate = TemplateId.classico,
    LabelLocale initialLabelLocale = LabelLocale.it,
  }) : _repo = repository,
       super(const PreviewLoading()) {
    _sub = _repo.watch(variantId).listen(
      (doc) => _onDocument(doc, initialTemplate, initialLabelLocale),
      onError: (Object err) => emit(PreviewLoadError(err.toString())),
      onDone: () {
        // Lo stream si chiude anche quando `watch()` non trova subito
        // l'id: in quel caso `onError` ha già portato lo stato a
        // `PreviewLoadError` prima che questo `onDone` scatti, quindi il
        // branch sotto non attiva su quel path.
        if (state is PreviewReady || state is PreviewLoading) {
          emit(const PreviewDeleted());
        }
      },
    );
  }

  void _onDocument(
    CvDocument doc,
    TemplateId initialTemplate,
    LabelLocale initialLabelLocale,
  ) {
    final s = state;
    if (s is PreviewReady) {
      emit(s.copyWith(document: doc));
    } else {
      emit(
        PreviewReady(
          document: doc,
          templateId: initialTemplate,
          labelLocale: initialLabelLocale,
          renderedDocument: doc,
          renderedTemplate: initialTemplate,
          renderedLocale: initialLabelLocale,
          renderGeneration: 0,
        ),
      );
    }
  }

  void templateChanged(TemplateId template) {
    final s = state;
    if (s is! PreviewReady) return;
    emit(s.copyWith(templateId: template));
  }

  void labelLocaleChanged(LabelLocale locale) {
    final s = state;
    if (s is! PreviewReady) return;
    emit(s.copyWith(labelLocale: locale));
  }

  /// Riallinea i valori "committed" a quelli correnti e fa ripartire il
  /// render (via il cambio di `renderGeneration`, letto come `Key` dal
  /// widget `PdfPreview`).
  void regenerate() {
    final s = state;
    if (s is! PreviewReady) return;
    emit(
      s.copyWith(
        renderedDocument: s.document,
        renderedTemplate: s.templateId,
        renderedLocale: s.labelLocale,
        renderGeneration: s.renderGeneration + 1,
      ),
    );
  }

  /// `LayoutCallback` per `PdfPreview.build`. Renderizza sempre gli input
  /// "committed" (mai quelli correnti), così un cambio di template/lingua
  /// non filtra nel PDF mostrato finché l'utente non preme `Aggiorna`.
  Future<Uint8List> buildPdf(PdfPageFormat format) async {
    final s = state;
    if (s is! PreviewReady) return Uint8List(0);
    try {
      return await pdfExporter.render(
        document: s.renderedDocument,
        template: s.renderedTemplate,
        labelLocale: s.renderedLocale,
      );
    } catch (e) {
      throw PreviewRenderException(e.toString());
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
