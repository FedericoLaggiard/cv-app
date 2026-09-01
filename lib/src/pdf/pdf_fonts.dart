/// Caricamento dei font embeddati per il template Classico (ticket 08/24).
///
/// EB Garamond (SIL OFL, vedi `assets/fonts/EBGaramond-OFL.txt`), asset
/// bundle Flutter, embed via `pw.Font.ttf()` — nessun font di sistema, per
/// riproducibilità cross-platform del PDF.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class ClassicoFonts {
  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font italic;
  final pw.Font bold;
  final pw.Font boldItalic;

  const ClassicoFonts({
    required this.regular,
    required this.semiBold,
    required this.italic,
    required this.bold,
    required this.boldItalic,
  });

  static Future<ClassicoFonts> load() async {
    final regular = await _loadFont('assets/fonts/EBGaramond-Regular.ttf');
    final semiBold = await _loadFont('assets/fonts/EBGaramond-SemiBold.ttf');
    final italic = await _loadFont('assets/fonts/EBGaramond-Italic.ttf');
    final bold = await _loadFont('assets/fonts/EBGaramond-Bold.ttf');
    final boldItalic = await _loadFont(
      'assets/fonts/EBGaramond-BoldItalic.ttf',
    );
    return ClassicoFonts(
      regular: regular,
      semiBold: semiBold,
      italic: italic,
      bold: bold,
      boldItalic: boldItalic,
    );
  }

  static Future<pw.Font> _loadFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }
}
