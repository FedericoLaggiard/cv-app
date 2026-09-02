/// Dialog `Esporta PDF` (ticket 24, amendment ticket 25): scelta template
/// (griglia di thumbnail, ticket 25) + lingua etichette, riepilogo
/// bloccante-**soft** dei campi obbligatori mancanti con `Esporta
/// comunque` sempre disponibile (nessun blocco duro).
library;

import 'package:flutter/material.dart';

import '../../../domain/cv_document.dart';
import '../../../domain/missing_required.dart';
import '../../../pdf/label_locale.dart';
import '../../../pdf/pdf_exporter.dart';
import 'template_picker.dart';

class ExportChoice {
  final TemplateId template;
  final LabelLocale labelLocale;
  const ExportChoice({required this.template, required this.labelLocale});
}

/// Mostra il dialog. `initialLabelLocale` è il default proposto (lingua
/// UI corrente dell'app, ticket 15 — hard-coded a IT finché il ticket 15
/// non atterra completamente).
Future<ExportChoice?> showExportPdfDialog(
  BuildContext context, {
  required CvDocument document,
  required MissingRequired missing,
  LabelLocale initialLabelLocale = LabelLocale.it,
}) {
  return showDialog<ExportChoice>(
    context: context,
    builder: (_) => _ExportPdfDialog(
      document: document,
      missing: missing,
      initialLabelLocale: initialLabelLocale,
    ),
  );
}

class _ExportPdfDialog extends StatefulWidget {
  const _ExportPdfDialog({
    required this.document,
    required this.missing,
    required this.initialLabelLocale,
  });

  final CvDocument document;
  final MissingRequired missing;
  final LabelLocale initialLabelLocale;

  @override
  State<_ExportPdfDialog> createState() => _ExportPdfDialogState();
}

class _ExportPdfDialogState extends State<_ExportPdfDialog> {
  TemplateId _template = TemplateId.classico;
  late LabelLocale _locale = widget.initialLabelLocale;

  @override
  Widget build(BuildContext context) {
    final missingSections = widget.missing.perSection.entries
        .where((e) => e.value > 0)
        .toList();

    return AlertDialog(
      title: const Text('Esporta PDF'),
      content: SizedBox(
        // Larghezza esplicita: `TemplatePicker` usa `LayoutBuilder` per il
        // breakpoint <600px (ticket 25), e `LayoutBuilder` non supporta il
        // calcolo delle dimensioni intrinseche che `AlertDialog`
        // userebbe altrimenti per dimensionare il contenuto.
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Template', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TemplatePicker(
                key: const Key('export_template_picker'),
                selected: _template,
                onChanged: (v) => setState(() => _template = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LabelLocale>(
                key: const Key('export_locale_dropdown'),
                initialValue: _locale,
                decoration: const InputDecoration(
                  labelText: 'Lingua etichette',
                ),
                items: [
                  for (final l in LabelLocale.values)
                    DropdownMenuItem(value: l, child: Text(l.displayName)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _locale = v);
                },
              ),
              if (missingSections.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Campi obbligatori mancanti',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final entry in missingSections)
                  Padding(
                    key: Key('export_missing_section_${entry.key}'),
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Text(
                      '${widget.document.sections[entry.key].displayTitle}: '
                      '${entry.value} ${entry.value == 1 ? "campo mancante" : "campi mancanti"}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('export_confirm'),
          onPressed: () =>
              Navigator.of(context)
                  .pop(ExportChoice(template: _template, labelLocale: _locale)),
          child: Text(
            missingSections.isNotEmpty ? 'Esporta comunque' : 'Esporta',
          ),
        ),
      ],
    );
  }
}
