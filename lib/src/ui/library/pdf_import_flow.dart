/// "Da PDF esistente" flow (ticket 28): file picker → [PdfImporter] →
/// scanned/encrypted/empty/filled handling → new variant → open editor.
///
/// Mirrors the `showNewVariantNameDialog`/`_handleDuplicateFromNew` pattern
/// already used by `library_screen.dart`/`library_dialogs.dart` for the
/// other two "+ Nuova" entry points, and the injectable-picker seam from
/// `profile_photo_field.dart`'s `defaultPickPhotoFile`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/cv_document.dart';
import '../../pdf/filename_sanitizer.dart';
import '../../pdf/pdf_importer.dart';
import 'library_cubit.dart';

/// Bytes + display name of the PDF chosen by the user.
@immutable
class PickedPdfFile {
  final Uint8List bytes;
  final String name;
  const PickedPdfFile(this.bytes, this.name);
}

/// Default picker: file system, filtered to `.pdf`.
Future<PickedPdfFile?> defaultPickPdfFile() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (files.isEmpty) return null;
  final file = files.first;
  final bytes = await file.readAsBytes();
  return PickedPdfFile(bytes, file.name);
}

/// Runs the whole "Da PDF esistente" flow: pick → import → outcome
/// handling → open editor on the resulting variant. No-ops if the user
/// cancels at any step.
Future<void> runPdfImportFlow(
  BuildContext context, {
  required LibraryCubit cubit,
  required void Function(String variantId)? onOpenVariant,
  Future<PickedPdfFile?> Function() pickFile = defaultPickPdfFile,
  PdfImporter importer = const PdfImporter(),
}) async {
  final picked = await pickFile();
  if (picked == null || !context.mounted) return;

  final baseName = sanitizeFileName(
    picked.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
  );

  String? password;
  while (true) {
    if (!context.mounted) return;
    final outcome = await _importWithLoadingDialog(
      context,
      importer: importer,
      bytes: picked.bytes,
      password: password,
    );
    if (!context.mounted || outcome == null) return; // cancelled

    switch (outcome) {
      case EncryptedOutcome():
        final entered = await _showPasswordDialog(
          context,
          wrongPassword: password != null,
        );
        if (entered == null || !context.mounted) return;
        password = entered;
        continue;
      case ScannedOutcome():
        if (!await _showScannedDialog(context)) return;
        if (!context.mounted) return;
        await _createAndOpen(
          context,
          cubit: cubit,
          onOpenVariant: onOpenVariant,
          doc: _emptyNamedDocument(baseName),
        );
        return;
      case EmptyOutcome():
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non ho trovato testo da importare')),
        );
        await _createAndOpen(
          context,
          cubit: cubit,
          onOpenVariant: onOpenVariant,
          doc: _emptyNamedDocument(baseName),
        );
        return;
      case FilledOutcome(:final doc):
        await _createAndOpen(
          context,
          cubit: cubit,
          onOpenVariant: onOpenVariant,
          doc: doc.copyWith(variantName: baseName),
        );
        return;
    }
  }
}

const _uuid = Uuid();

CvDocument _emptyNamedDocument(String name) {
  final now = DateTime.now();
  return CvDocument(
    id: _uuid.v4(),
    createdAt: now,
    updatedAt: now,
    variantName: name,
  );
}

Future<void> _createAndOpen(
  BuildContext context, {
  required LibraryCubit cubit,
  required void Function(String variantId)? onOpenVariant,
  required CvDocument doc,
}) async {
  final id = await cubit.createFromImport(doc);
  if (id != null) onOpenVariant?.call(id);
}

/// Runs [importer.import] behind a cancellable "Analizzo il PDF…" dialog.
/// Returns `null` if the user cancels (the dialog is popped, but the
/// underlying import isn't force-aborted — its eventual result is simply
/// ignored).
Future<ImportOutcome?> _importWithLoadingDialog(
  BuildContext context, {
  required PdfImporter importer,
  required Uint8List bytes,
  required String? password,
}) async {
  var cancelled = false;
  final future = importer.import(bytes, password: password);

  if (!context.mounted) return null;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Text('Analizzo il PDF…')),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('pdf_import_cancel_loading'),
              onPressed: () {
                cancelled = true;
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    ),
  );

  final outcome = await future;

  if (!cancelled && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  return cancelled ? null : outcome;
}

Future<String?> _showPasswordDialog(
  BuildContext context, {
  required bool wrongPassword,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('PDF protetto da password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wrongPassword)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Password errata, riprova.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextField(
            key: const Key('pdf_import_password_field'),
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (v) => Navigator.of(dialogCtx).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('pdf_import_password_submit'),
          onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
          child: const Text('Sblocca'),
        ),
      ],
    ),
  );
}

/// Returns `true` if the user chose "Crea CV da zero".
Future<bool> _showScannedDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('PDF scansionato'),
      content: const Text(
        'Il PDF sembra un\'immagine scansionata: non riesco a leggerne il '
        'testo automaticamente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('pdf_import_scanned_from_scratch'),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text('Crea CV da zero'),
        ),
      ],
    ),
  );
  return result ?? false;
}
