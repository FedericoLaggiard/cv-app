/// Unit test su `PhotoNormalizer.ingest` (ticket 26, Testing Decisions).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cv_app/src/photo/photo_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidJpeg(int width, int height, {int quality = 90}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(0x33, 0x66, 0x99));
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

Uint8List _solidPng(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(0xaa, 0x22, 0x44));
  return Uint8List.fromList(img.encodePng(image));
}

/// Rumore pseudo-casuale seedato: quasi incomprimibile a qualunque livello
/// JPEG, usato per esercitare il caso limite `TooLargeAfterRetries`.
Uint8List _noiseImageBytes(int width, int height) {
  final random = Random(42);
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  const normalizer = PhotoNormalizer();

  test('rifiuta un mime HEIC prima del decode', () async {
    expect(
      () => normalizer.ingest(
        rawBytes: Uint8List(0),
        mimeType: 'image/heic',
      ),
      throwsA(isA<RejectedFormat>()),
    );
  });

  test('rifiuta GIF/SVG/BMP/TIFF', () async {
    for (final mime in [
      'image/gif',
      'image/svg+xml',
      'image/bmp',
      'image/tiff',
    ]) {
      expect(
        () => normalizer.ingest(rawBytes: Uint8List(0), mimeType: mime),
        throwsA(isA<RejectedFormat>()),
        reason: mime,
      );
    }
  });

  test(
    'JPG 3000x2000 viene ridimensionato a 800 sul lato lungo, JPEG, sotto 500 KB',
    () async {
      final raw = _solidJpeg(3000, 2000);
      final result = await normalizer.ingest(
        rawBytes: raw,
        mimeType: 'image/jpeg',
      );
      expect(result.width, 800);
      expect(result.height, 533);
      expect(result.sizeBytes, lessThanOrEqualTo(kMaxPhotoBytes));
      expect(result.sizeBytes, result.jpegBytes.lengthInBytes);
    },
  );

  test('PNG grande viene convertito a JPEG Q=85 sotto 500 KB', () async {
    final raw = _solidPng(1200, 1200);
    final result = await normalizer.ingest(
      rawBytes: raw,
      mimeType: 'image/png',
    );
    expect(result.width, kMaxPhotoDimension);
    expect(result.height, kMaxPhotoDimension);
    expect(result.sizeBytes, lessThanOrEqualTo(kMaxPhotoBytes));
    // JPEG magic bytes (SOI marker).
    expect(result.jpegBytes[0], 0xFF);
    expect(result.jpegBytes[1], 0xD8);
  });

  test('non fa upscaling di un\'immagine più piccola del target', () async {
    final raw = _solidPng(200, 100);
    final result = await normalizer.ingest(
      rawBytes: raw,
      mimeType: 'image/png',
    );
    expect(result.width, 200);
    expect(result.height, 100);
  });

  test(
    'immagine estrema che non scende sotto 500 KB nemmeno a Q=65 → TooLargeAfterRetries',
    () async {
      final raw = _noiseImageBytes(kMaxPhotoDimension, kMaxPhotoDimension);
      expect(
        () => normalizer.ingest(rawBytes: raw, mimeType: 'image/png'),
        throwsA(isA<TooLargeAfterRetries>()),
      );
    },
  );

  group('sniffPhotoMimeType', () {
    test('riconosce JPEG, PNG e WebP dai magic bytes', () {
      expect(sniffPhotoMimeType(_solidJpeg(8, 8)), 'image/jpeg');
      expect(sniffPhotoMimeType(_solidPng(8, 8)), 'image/png');
      // Header WebP minimo: "RIFF" + size + "WEBP".
      final webp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // size (irrilevante per lo sniff)
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(sniffPhotoMimeType(webp), 'image/webp');
    });

    test('null su formati non accettati o bytes troppo corti', () {
      // GIF87a — formato fuori whitelist.
      final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]);
      expect(sniffPhotoMimeType(gif), isNull);
      expect(sniffPhotoMimeType(Uint8List(0)), isNull);
      expect(sniffPhotoMimeType(Uint8List.fromList([0xFF])), isNull);
    });
  });

  test('bytes non decodificabili con mime accettato → UndecodableFile', () async {
    expect(
      () => normalizer.ingest(
        rawBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        mimeType: 'image/png',
      ),
      throwsA(isA<UndecodableFile>()),
    );
  });
}
