/// Uscita del PDF generato: mobile → share sheet, Web → download,
/// desktop → dialog "Salva come…" (ticket 24).
///
/// Conditional import identico al pattern di
/// `repository/cv_repository_factory.dart`: tiene `dart:io` fuori dal
/// bundle Web e `dart:html`/browser API fuori da desktop/mobile.
library;

import 'dart:typed_data';

import 'pdf_delivery_io.dart'
    if (dart.library.html) 'pdf_delivery_web.dart'
    as impl;

sealed class DeliveryResult {
  const DeliveryResult();
}

/// Il PDF è stato consegnato (share sheet completato, download avviato,
/// file scritto su disco).
class DeliverySuccess extends DeliveryResult {
  const DeliverySuccess();
}

/// L'utente ha annullato il dialog di share/save senza completare.
class DeliveryCancelled extends DeliveryResult {
  const DeliveryCancelled();
}

/// La delivery è fallita (es. permessi FS negati). [message] è
/// human-readable, mostrato all'utente (user story 14 del ticket 24).
class DeliveryError extends DeliveryResult {
  final String message;
  const DeliveryError(this.message);
}

abstract class PdfDelivery {
  Future<DeliveryResult> deliver(Uint8List pdf, String suggestedFileName);
}

/// Restituisce la [PdfDelivery] concreta per la piattaforma corrente.
PdfDelivery defaultPdfDelivery() => impl.buildDefaultDelivery();
