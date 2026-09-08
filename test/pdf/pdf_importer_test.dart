/// [PdfImporter.import] itself needs a real PDFium/pdfrx native module,
/// which requires platform native-asset wiring that `flutter test` doesn't
/// provide outside a running app (declared trust boundary, ticket 05/10 —
/// see the module doc comment). What *is* testable without that dependency
/// is the classification logic pulled out as [classifyOutcome]: given
/// already-extracted page text, does it correctly call empty/scanned/filled?
/// The `pdf_import_heuristics_test.dart` suite covers `filled`'s content in
/// depth; this file only checks the outcome-selection boundary.
library;

import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';
import 'package:cv_app/src/pdf/pdf_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyOutcome', () {
    test('nessun carattere estratto -> empty', () {
      final outcome = classifyOutcome(totalChars: 0, pageCount: 1, pages: []);
      expect(outcome, isA<EmptyOutcome>());
    });

    test('media caratteri/pagina sotto soglia -> scanned', () {
      final outcome = classifyOutcome(
        totalChars: 50,
        pageCount: 1,
        pages: [const PdfPageText(pageIndex: 0, chars: [])],
      );
      expect(outcome, isA<ScannedOutcome>());
    });

    test('media caratteri/pagina sopra soglia -> filled, heuristics applicate', () {
      final page = PdfPageText(
        pageIndex: 0,
        chars: [
          const PdfCharRect(
            text: 'mario.rossi@example.com',
            x: 0,
            y: 0,
            width: 100,
            height: 10,
          ),
        ],
      );
      final outcome = classifyOutcome(totalChars: 150, pageCount: 1, pages: [page]);
      expect(outcome, isA<FilledOutcome>());
      final contatti =
          (outcome as FilledOutcome).doc.sections.whereType<ContattiSection>().single;
      expect(contatti.data.email, 'mario.rossi@example.com');
    });

    test('soglia esatta (>= 100) conta come filled, non scanned', () {
      final outcome = classifyOutcome(
        totalChars: 100,
        pageCount: 1,
        pages: [const PdfPageText(pageIndex: 0, chars: [])],
      );
      expect(outcome, isA<FilledOutcome>());
    });
  });
}
