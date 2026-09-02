/// Genera le 3 thumbnail PNG statiche usate da `TemplatePicker` (ticket 25)
/// in `assets/template_thumbnails/{classico,moderno,minimal}.png`.
///
/// **Perché non un rendering reale del PDF**: `printing`'s `Printing.raster`
/// (la via ovvia per PDF → immagine) passa da un platform channel nativo e
/// richiede quindi un engine Flutter realmente in esecuzione su un target
/// (desktop/mobile/web) — non è invocabile da uno script Dart offline né
/// da `flutter test` headless. Renderizzare i tre `CvTemplate` reali e
/// rasterizzarli in CI/offline non è quindi praticabile con lo stack
/// attuale (ticket 08/24/25 non introducono un rasterizzatore PDF→immagine
/// puro-Dart, e aggiungerne uno solo per le thumbnail sarebbe una
/// dipendenza pesante per un asset esplicitamente "non pixel-perfect",
/// vedi Testing Decisions del ticket 25).
///
/// **Cosa genera questo script**: non uno screenshot del template reale,
/// ma un piccolo mockup vettoriale disegnato a mano con `package:image`
/// (pura Dart, nessun binding Flutter/piattaforma) che riproduce i tratti
/// distintivi di ciascun layout — abbastanza per orientare la scelta a
/// colpo d'occhio nel selettore, esplicitamente NON un'anteprima fedele
/// del contenuto renderizzato. Da rigenerare (`dart run
/// tool/generate_thumbnails.dart`) se questi tratti cambiano.
library;

import 'dart:io';

import 'package:image/image.dart' as img;

const _width = 240;
const _height = 340; // ~ proporzione A4 (210x297)

void main() {
  final outDir = Directory('assets/template_thumbnails');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  _write(outDir, 'classico.png', _classico());
  _write(outDir, 'moderno.png', _moderno());
  _write(outDir, 'minimal.png', _minimal());

  stdout.writeln('Thumbnail generate in ${outDir.path}');
}

void _write(Directory dir, String name, img.Image image) {
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('  ${file.path}');
}

img.Image _blankPage() {
  final image = img.Image(width: _width, height: _height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  img.drawRect(
    image,
    x1: 0,
    y1: 0,
    x2: _width - 1,
    y2: _height - 1,
    color: img.ColorRgb8(0xdd, 0xdd, 0xdd),
  );
  return image;
}

void _textLine(
  img.Image image, {
  required int x,
  required int y,
  required int width,
  int height = 4,
  required img.Color color,
}) {
  img.fillRect(
    image,
    x1: x,
    y1: y,
    x2: x + width,
    y2: y + height,
    color: color,
  );
}

/// Classico: singola colonna full-width, solo neri/grigi, foto in alto a
/// destra (ticket 08).
img.Image _classico() {
  final image = _blankPage();
  final gray900 = img.ColorRgb8(0x11, 0x11, 0x11);
  final gray400 = img.ColorRgb8(0x88, 0x88, 0x88);
  final gray200 = img.ColorRgb8(0xcc, 0xcc, 0xcc);
  final margin = 18;

  // Nome + headline.
  _textLine(image, x: margin, y: 24, width: 90, height: 10, color: gray900);
  _textLine(image, x: margin, y: 40, width: 70, height: 5, color: gray400);

  // Foto placeholder in alto a destra.
  img.drawRect(
    image,
    x1: _width - margin - 34,
    y1: 20,
    x2: _width - margin,
    y2: 62,
    color: gray400,
  );

  // Hairline separatore.
  _textLine(image, x: margin, y: 64, width: _width - margin * 2, height: 1, color: gray200);

  // Corpo: righe piene larghezza.
  var y = 78;
  for (var i = 0; i < 14; i++) {
    final w = i.isEven ? _width - margin * 2 : (_width - margin * 2) * 0.7;
    _textLine(image, x: margin, y: y, width: w.round(), height: 4, color: gray200);
    y += 10;
  }
  return image;
}

/// Moderno: banda laterale sinistra scura + colonna principale bianca con
/// accent blu (ticket 08).
img.Image _moderno() {
  final image = _blankPage();
  final bandBg = img.ColorRgb8(0x1f, 0x2d, 0x3d);
  final accent = img.ColorRgb8(0x2b, 0x6c, 0xb0);
  final bandText = img.ColorRgb8(0xe6, 0xec, 0xf1);
  final gray200 = img.ColorRgb8(0xdd, 0xdd, 0xdd);
  final bandWidth = (_width * 0.32).round();

  img.fillRect(image, x1: 0, y1: 0, x2: bandWidth, y2: _height, color: bandBg);

  // Foto circolare nella banda.
  img.fillCircle(
    image,
    x: bandWidth ~/ 2,
    y: 34,
    radius: 18,
    color: img.ColorRgb8(0x3a, 0x4a, 0x5c),
  );
  _textLine(image, x: 10, y: 60, width: bandWidth - 20, height: 6, color: bandText);
  var by = 80;
  for (var i = 0; i < 6; i++) {
    _textLine(image, x: 10, y: by, width: bandWidth - 24, height: 3, color: bandText);
    by += 9;
  }

  // Colonna principale: barretta accent + header + righe.
  final mainX = bandWidth + 14;
  img.fillRect(image, x1: mainX, y1: 26, x2: mainX + 3, y2: 34, color: accent);
  _textLine(image, x: mainX + 8, y: 27, width: 60, height: 6, color: accent);
  var y = 44;
  for (var i = 0; i < 14; i++) {
    final w = i.isEven
        ? _width - mainX - 14
        : (_width - mainX - 14) * 0.7;
    _textLine(image, x: mainX, y: y, width: w.round(), height: 4, color: gray200);
    y += 10;
  }
  return image;
}

/// Minimal: singola colonna stretta e centrata, zero colori (ticket 08).
img.Image _minimal() {
  final image = _blankPage();
  final gray400 = img.ColorRgb8(0x99, 0x99, 0x99);
  final gray200 = img.ColorRgb8(0xdd, 0xdd, 0xdd);
  final margin = (_width * 0.22).round();
  final colWidth = _width - margin * 2;

  _textLine(image, x: margin, y: 40, width: (colWidth * 0.7).round(), height: 8, color: gray400);
  _textLine(image, x: margin, y: 54, width: (colWidth * 0.5).round(), height: 4, color: gray400);

  var y = 80;
  for (var i = 0; i < 12; i++) {
    final w = i.isEven ? colWidth : (colWidth * 0.65);
    _textLine(image, x: margin, y: y, width: w.round(), height: 3, color: gray200);
    y += 12;
  }
  return image;
}
