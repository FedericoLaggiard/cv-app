/// One-off fixture-capture harness for the PDF-import conversion-rate
/// corpus (ticket 50 — Spec M).
///
/// **Never runs in CI.** `pdfrx` needs the native-asset wiring a plain
/// `flutter test` doesn't provide (see the doc-comment on
/// `PdfImporter.import` in `lib/src/pdf/pdf_importer.dart`), so this only
/// runs manually via a real Flutter run on macOS:
///
/// ```
/// CV_APP_CAPTURE_PDF=/absolute/path/to/real_cv.pdf \
/// CV_APP_CAPTURE_NAME=europass_it_02 \
/// CV_APP_CAPTURE_LAYOUT=single_column \
/// flutter test integration_test/capture_fixtures_test.dart -d macos
/// ```
///
/// It writes the extracted lines/heights to
/// `test/pdf/fixtures/<name>.json`, running automatic anonymization
/// (`anonymizer.dart`) on email/phone/LinkedIn/GitHub matches only.
///
/// **The source PDF never enters the repo, in any form.** Before
/// committing the frozen fixture, whoever ran the capture MUST:
///
/// 1. Open `test/pdf/fixtures/<name>.json` and hand-redact any remaining
///    free-text PII (name, headline, address, employer names if
///    sensitive) — replace with placeholders of the same rough shape.
/// 2. Write `test/pdf/fixtures/<name>.golden.json` by hand, looking at the
///    original PDF, using the field paths documented in
///    `test/pdf/conversion_scoring.dart`.
/// 3. Never commit `test/pdf/fixtures/.anonymization_map.json` (it's
///    gitignored — it's the key to un-anonymizing every fixture captured
///    with it).
library;

import 'dart:io';

import 'package:cv_app/src/pdf/pdf_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/pdf/anonymizer.dart';
import '../test/pdf/fixture_io.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cattura una fixture reale da un PDF locale (manuale)', (
    tester,
  ) async {
    final pdfPath = Platform.environment['CV_APP_CAPTURE_PDF'];
    if (pdfPath == null || pdfPath.isEmpty) {
      // ignore: avoid_print
      print(
        '[capture] CV_APP_CAPTURE_PDF non impostata: skip. '
        'Vedi il doc-comment di questo file per come lanciare una cattura reale.',
      );
      return;
    }

    final name = Platform.environment['CV_APP_CAPTURE_NAME'];
    if (name == null || name.isEmpty) {
      fail('CV_APP_CAPTURE_NAME è richiesta insieme a CV_APP_CAPTURE_PDF.');
    }

    final layoutWire =
        Platform.environment['CV_APP_CAPTURE_LAYOUT'] ?? 'single_column';
    final layoutFamily = LayoutFamily.fromWire(layoutWire);
    final password = Platform.environment['CV_APP_CAPTURE_PASSWORD'];

    final bytes = await File(pdfPath).readAsBytes();
    final pages = await const PdfImporter().extractPages(
      bytes,
      password: password,
    );

    final anonymizationMap = AnonymizationMap.load(
      'test/pdf/fixtures/.anonymization_map.json',
    );

    final fixture = PdfFixture(
      layoutFamily: layoutFamily,
      pages: [
        for (final page in pages)
          FixturePage(
            pageIndex: page.pageIndex,
            lines: [
              for (final char in page.chars)
                FixtureLine(
                  text: anonymizeLine(char.text, anonymizationMap),
                  height: char.height,
                ),
            ],
          ),
      ],
    );

    anonymizationMap.save();

    final outFile = File('test/pdf/fixtures/$name.json');
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(fixture.encode());

    // ignore: avoid_print
    print(
      '[capture] Scritta ${outFile.path} (${fixture.pages.length} pagine).',
    );
    // ignore: avoid_print
    print(
      '[capture] Ora: 1) rileggi il JSON e redigi a mano ogni PII libera '
      'residua; 2) scrivi $name.golden.json guardando il PDF originale.',
    );
  });
}
