/// `PhotoNormalizer` — seam per l'ingest della foto profilo (ticket 26).
///
/// Accetta bytes grezzi da file picker/camera, rifiuta i formati non
/// supportati prima del decode, e produce un JPEG ridimensionato
/// (max 800×800, no upscaling) sotto un hard-cap di 500 KB, riprovando a
/// qualità decrescente quando serve.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';

/// Dimensione massima (lato lungo) dopo il resize, in pixel.
const int kMaxPhotoDimension = 800;

/// Hard-cap dimensione file dopo l'encode, in byte.
const int kMaxPhotoBytes = 500 * 1024;

/// Matrice di qualità JPEG provata in ordine finché il risultato non sta
/// sotto [kMaxPhotoBytes].
const List<int> kPhotoQualityLadder = [85, 75, 65];

/// Esito riuscito di [PhotoNormalizer.ingest].
@immutable
class NormalizedPhoto {
  final Uint8List jpegBytes;
  final int width;
  final int height;
  final int sizeBytes;

  const NormalizedPhoto({
    required this.jpegBytes,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });
}

/// Errore sealed per i casi di rifiuto di [PhotoNormalizer.ingest].
sealed class PhotoNormalizationError implements Exception {
  const PhotoNormalizationError();
}

/// Formato non supportato (HEIC/GIF/SVG/BMP/TIFF/altro), rifiutato prima
/// del decode.
///
/// Porta il [mimeType] rilevato, non una frase pronta: la copy utente la
/// compone il widget, così questo seam non possiede stringhe di
/// presentazione (e la i18n della Slice J avrà un dato su cui lavorare
/// invece di un messaggio già tradotto).
class RejectedFormat extends PhotoNormalizationError {
  final String mimeType;
  const RejectedFormat(this.mimeType);

  @override
  String toString() => 'RejectedFormat: $mimeType';
}

/// Bytes che dichiarano un mime accettato ma non sono un'immagine
/// decodificabile (file corrotto o mime mentito).
class UndecodableFile extends PhotoNormalizationError {
  const UndecodableFile();

  @override
  String toString() => 'UndecodableFile';
}

/// Anche al gradino di qualità più basso della matrice ([kPhotoQualityLadder])
/// il JPEG risultante supera [kMaxPhotoBytes].
class TooLargeAfterRetries extends PhotoNormalizationError {
  final int lastAttemptBytes;
  const TooLargeAfterRetries(this.lastAttemptBytes);

  @override
  String toString() => 'TooLargeAfterRetries($lastAttemptBytes bytes)';
}

/// Mime type accettati in ingresso (whitelist esplicita, ticket 26).
const Set<String> kAcceptedPhotoMimeTypes = {
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
};

/// Mime dedotto dall'estensione di [fileName].
///
/// Mappa anche i formati *non* accettati che l'utente può realisticamente
/// scegliere (HEIC dalla libreria iOS, GIF, SVG, BMP, TIFF): serve a farli
/// arrivare al rifiuto con un nome vero invece che come
/// `application/octet-stream`, così il messaggio può dire *quale* formato ha
/// scelto (ticket 26, user story 5). Estensione assente o sconosciuta →
/// `application/octet-stream`, e tocca ai magic bytes
/// ([sniffPhotoMimeType]) l'ultima parola.
String photoMimeTypeForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 || dot == fileName.length - 1
      ? null
      : fileName.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'gif' => 'image/gif',
    'svg' => 'image/svg+xml',
    'bmp' => 'image/bmp',
    'tif' || 'tiff' => 'image/tiff',
    _ => 'application/octet-stream',
  };
}

/// Riconosce il mime dai magic bytes, per i soli formati accettati.
///
/// Fallback quando il picker non dà un'estensione utile (file senza
/// estensione, o estensione che mente): il ticket 26 chiede di preferire il
/// mime del picker e di ripiegare sui magic bytes. `null` quando i bytes non
/// sono uno dei formati accettati — il chiamante lo tratta come "non
/// supportato" senza tentare il decode.
String? sniffPhotoMimeType(Uint8List bytes) {
  bool startsWith(List<int> magic, {int offset = 0}) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  // WebP: "RIFF" .... "WEBP"
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const [0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return 'image/webp';
  }
  return null;
}

class PhotoNormalizer {
  const PhotoNormalizer();

  /// Ingerisce [rawBytes] con [mimeType] dichiarato (dal file/camera
  /// picker) e produce un JPEG normalizzato pronto per lo storage in
  /// `CvDocument.assets`.
  ///
  /// Lancia [RejectedFormat] se il mime dichiarato non è in
  /// [kAcceptedPhotoMimeTypes] (rifiuto **prima** del decode, nessun costo
  /// di parsing sprecato su un formato già escluso), [UndecodableFile] se i
  /// bytes non sono decodificabili nonostante un mime accettato, e
  /// [TooLargeAfterRetries] se anche l'ultimo gradino di
  /// [kPhotoQualityLadder] non basta a stare sotto [kMaxPhotoBytes].
  Future<NormalizedPhoto> ingest({
    required Uint8List rawBytes,
    required String mimeType,
  }) async {
    final normalizedMime = mimeType.toLowerCase().trim();
    if (!kAcceptedPhotoMimeTypes.contains(normalizedMime)) {
      throw RejectedFormat(normalizedMime);
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(rawBytes);
    } catch (_) {
      // Bytes troppo corti/malformati possono far esplodere un decoder
      // (es. PSD legge un header a lunghezza fissa) invece di restituire
      // `null` come contratto documentato di `decodeImage` — qualunque
      // eccezione qui vuol dire "non decodificabile", non un bug nostro.
      decoded = null;
    }
    if (decoded == null) {
      throw const UndecodableFile();
    }

    final resized = _resize(decoded);

    Uint8List? best;
    for (final quality in kPhotoQualityLadder) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      if (encoded.lengthInBytes <= kMaxPhotoBytes) {
        best = encoded;
        break;
      }
      best = encoded; // tieni l'ultimo tentativo per il messaggio d'errore
    }

    if (best == null || best.lengthInBytes > kMaxPhotoBytes) {
      throw TooLargeAfterRetries(best?.lengthInBytes ?? 0);
    }

    return NormalizedPhoto(
      jpegBytes: best,
      width: resized.width,
      height: resized.height,
      sizeBytes: best.lengthInBytes,
    );
  }

  /// Resize al massimo lato lungo [kMaxPhotoDimension], preservando
  /// l'aspect ratio, mai in upscaling.
  img.Image _resize(img.Image source) {
    final longSide = source.width > source.height
        ? source.width
        : source.height;
    if (longSide <= kMaxPhotoDimension) return source;
    return source.width >= source.height
        ? img.copyResize(source, width: kMaxPhotoDimension)
        : img.copyResize(source, height: kMaxPhotoDimension);
  }
}
