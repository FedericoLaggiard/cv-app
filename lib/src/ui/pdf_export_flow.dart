/// Flusso condiviso "apri dialog Esporta PDF → render → delivery" (ticket
/// 24), usato sia dalla top bar dell'Editor sia dal pulsante `Esporta`
/// della preview PDF (ticket 27) così le due entry point non duplicano
/// spinner/gestione errori.
library;

import 'package:flutter/material.dart';

import '../domain/cv_document.dart';
import '../domain/missing_required.dart';
import '../pdf/filename_sanitizer.dart';
import '../pdf/label_locale.dart';
import '../pdf/pdf_delivery.dart';
import '../pdf/pdf_exporter.dart';
import 'editor/widgets/export_pdf_dialog.dart';

/// Mostra il dialog di export, poi renderizza e consegna il PDF scelto.
/// Mostra uno spinner bloccante durante il render/delivery e uno SnackBar
/// solo in caso di errore.
Future<void> runPdfExportFlow(
  BuildContext context, {
  required CvDocument document,
  required MissingRequired missing,
  required PdfExporter pdfExporter,
  PdfDelivery? pdfDelivery,
  LabelLocale initialLabelLocale = LabelLocale.it,
  TemplateId initialTemplate = TemplateId.classico,
}) async {
  final choice = await showExportPdfDialog(
    context,
    document: document,
    missing: missing,
    initialLabelLocale: initialLabelLocale,
    initialTemplate: initialTemplate,
  );
  if (choice == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  DeliveryResult result;
  try {
    final bytes = await pdfExporter.render(
      document: document,
      template: choice.template,
      labelLocale: choice.labelLocale,
    );
    final suggestedName = '${sanitizeFileName(document.variantName)}.pdf';
    result = await (pdfDelivery ?? defaultPdfDelivery()).deliver(
      bytes,
      suggestedName,
    );
  } catch (e) {
    result = DeliveryError(e.toString());
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  final message = switch (result) {
    DeliverySuccess() => null,
    DeliveryCancelled() => null,
    DeliveryError(:final message) => 'Export PDF fallito: $message',
  };
  if (message != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
