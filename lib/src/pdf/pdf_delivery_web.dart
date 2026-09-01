/// Branch Web di [defaultPdfDelivery] (ticket 24): `Printing.sharePdf`
/// avvia il download del blob nel browser.
library;

import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'pdf_delivery.dart';

class _WebPdfDelivery implements PdfDelivery {
  const _WebPdfDelivery();

  @override
  Future<DeliveryResult> deliver(
    Uint8List pdf,
    String suggestedFileName,
  ) async {
    try {
      final started = await Printing.sharePdf(
        bytes: pdf,
        filename: suggestedFileName,
      );
      return started ? const DeliverySuccess() : const DeliveryCancelled();
    } catch (e) {
      return DeliveryError(e.toString());
    }
  }
}

PdfDelivery buildDefaultDelivery() => const _WebPdfDelivery();
