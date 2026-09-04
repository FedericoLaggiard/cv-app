/// PreviewScreen — route a pagina piena `/editor/:variantId/preview`
/// (ticket 27, Spec H).
///
/// Strip di thumbnail template + dropdown lingua etichette in cima,
/// `PdfPreview` di `printing` sotto. La rigenerazione è sempre manuale
/// (banner `Anteprima non aggiornata` + `Aggiorna`): vedi
/// [PreviewCubit] per la logica di staleness.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../domain/missing_required.dart';
import '../../pdf/label_locale.dart';
import '../../pdf/pdf_delivery.dart';
import '../../pdf/pdf_exporter.dart';
import '../../repository/cv_repository.dart';
import '../editor/widgets/template_picker.dart';
import '../pdf_export_flow.dart';
import 'preview_cubit.dart';

class PreviewScreen extends StatelessWidget {
  const PreviewScreen({
    super.key,
    required this.variantId,
    required this.repository,
    this.onBack,
    this.pdfExporter = const DefaultPdfExporter(),
    this.pdfDelivery,
    this.initialTemplate = TemplateId.classico,
    this.initialLabelLocale = LabelLocale.it,
  });

  final String variantId;
  final CvRepository repository;
  final VoidCallback? onBack;

  /// Iniettabile per i test; di default il template Classico via `pdf`.
  final PdfExporter pdfExporter;

  /// Iniettabile per i test; `null` risolve alla delivery di piattaforma
  /// al momento dell'export (non può essere un default costante).
  final PdfDelivery? pdfDelivery;

  /// Selezione iniziale di template/lingua per la preview (ticket 07:
  /// lingua UI corrente, hard-coded a IT finché il ticket 15 non atterra
  /// completamente).
  final TemplateId initialTemplate;
  final LabelLocale initialLabelLocale;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PreviewCubit>(
      create: (_) => PreviewCubit(
        repository: repository,
        variantId: variantId,
        pdfExporter: pdfExporter,
        initialTemplate: initialTemplate,
        initialLabelLocale: initialLabelLocale,
      ),
      child: _PreviewView(
        onBack: onBack,
        pdfExporter: pdfExporter,
        pdfDelivery: pdfDelivery,
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({this.onBack, required this.pdfExporter, this.pdfDelivery});
  final VoidCallback? onBack;
  final PdfExporter pdfExporter;
  final PdfDelivery? pdfDelivery;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PreviewCubit, PreviewState>(
      builder: (context, state) => switch (state) {
        PreviewLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        PreviewLoadError(:final message) => Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: onBack),
            title: const Text('Anteprima PDF'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Errore: $message', textAlign: TextAlign.center),
            ),
          ),
        ),
        PreviewReady() => _PreviewReadyView(
          state: state,
          onBack: onBack,
          pdfExporter: pdfExporter,
          pdfDelivery: pdfDelivery,
        ),
      },
    );
  }
}

class _PreviewReadyView extends StatelessWidget {
  const _PreviewReadyView({
    required this.state,
    this.onBack,
    required this.pdfExporter,
    this.pdfDelivery,
  });
  final PreviewReady state;
  final VoidCallback? onBack;
  final PdfExporter pdfExporter;
  final PdfDelivery? pdfDelivery;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PreviewCubit>();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: onBack ?? () => Navigator.maybePop(context),
        ),
        title: const Text('Anteprima PDF'),
        actions: [
          FilledButton.icon(
            key: const Key('preview_export_pdf'),
            onPressed: () => runPdfExportFlow(
              context,
              document: state.document,
              missing: analyzeMissingRequired(state.document),
              pdfExporter: pdfExporter,
              pdfDelivery: pdfDelivery,
              initialTemplate: state.templateId,
              initialLabelLocale: state.labelLocale,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Esporta'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TemplatePicker(
              key: const Key('preview_template_picker'),
              selected: state.templateId,
              onChanged: cubit.templateChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<LabelLocale>(
              key: const Key('preview_locale_dropdown'),
              initialValue: state.labelLocale,
              decoration: const InputDecoration(labelText: 'Lingua etichette'),
              items: [
                for (final l in LabelLocale.values)
                  DropdownMenuItem(value: l, child: Text(l.displayName)),
              ],
              onChanged: (v) {
                if (v != null) cubit.labelLocaleChanged(v);
              },
            ),
          ),
          if (state.stale) _StaleBanner(onRefresh: cubit.regenerate),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: PdfPreview(
                key: ValueKey(state.renderGeneration),
                build: cubit.buildPdf,
                // L'export vero passa dal flusso condiviso
                // (dialog + PdfDelivery, ticket 24): qui disabilitiamo le
                // azioni native di `printing` per non avere due percorsi
                // di uscita del PDF che divergono (nome file, sanitizzazione).
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                onError: (context, error) => _PreviewErrorBox(
                  message: error.toString(),
                  onRetry: cubit.regenerate,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('preview_stale_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Anteprima non aggiornata')),
          TextButton(
            key: const Key('preview_refresh_button'),
            onPressed: onRefresh,
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );
  }
}

class _PreviewErrorBox extends StatelessWidget {
  const _PreviewErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const Key('preview_error_box'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              'Errore anteprima',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('preview_error_retry'),
              onPressed: onRetry,
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
