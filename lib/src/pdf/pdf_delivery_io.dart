/// Branch desktop/mobile di [defaultPdfDelivery] (ticket 24): share sheet
/// nativo su iOS/Android, dialog "Salva come…" su macOS/Windows.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_delivery.dart';

class _IoPdfDelivery implements PdfDelivery {
  const _IoPdfDelivery();

  @override
  Future<DeliveryResult> deliver(
    Uint8List pdf,
    String suggestedFileName,
  ) async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        return await _share(pdf, suggestedFileName);
      }
      if (Platform.isLinux) {
        // TODO(ticket-24): file_picker.saveFile() ha lacune note su Linux
        // desktop ("Further Notes" del ticket). Fallback documentato a
        // share_plus finché non risolto upstream; non blocca la delivery
        // sulle altre piattaforme.
        return await _share(pdf, suggestedFileName);
      }
      final uri = await FilePicker.saveFile(
        fileName: suggestedFileName,
        bytes: pdf,
        mimeType: 'application/pdf',
        dialogTitle: 'Salva come…',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      return uri == null ? const DeliveryCancelled() : const DeliverySuccess();
    } catch (e) {
      return DeliveryError(e.toString());
    }
  }

  Future<DeliveryResult> _share(Uint8List pdf, String suggestedFileName) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pdf,
            name: suggestedFileName,
            mimeType: 'application/pdf',
          ),
        ],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success ||
      ShareResultStatus.unavailable => const DeliverySuccess(),
      ShareResultStatus.dismissed => const DeliveryCancelled(),
    };
  }
}

PdfDelivery buildDefaultDelivery() => const _IoPdfDelivery();
