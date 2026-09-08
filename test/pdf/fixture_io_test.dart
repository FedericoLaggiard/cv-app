/// Round-trip tests for the fixture JSON serializer (ticket 50).
library;

import 'package:flutter_test/flutter_test.dart';

import 'fixture_io.dart';

void main() {
  group('PdfFixture JSON round-trip', () {
    test('encode -> decode preserves layoutFamily and pages', () {
      final fixture = PdfFixture(
        layoutFamily: LayoutFamily.singleColumn,
        pages: [
          FixturePage(
            pageIndex: 0,
            lines: [
              FixtureLine(text: 'Esperienze', height: 16),
              FixtureLine(text: 'Gennaio 2020 - Marzo 2022', height: 10),
            ],
          ),
          FixturePage(
            pageIndex: 1,
            lines: [FixtureLine(text: 'Continua', height: 10)],
          ),
        ],
      );

      final decoded = PdfFixture.decode(fixture.encode());

      expect(decoded, fixture);
      expect(decoded.layoutFamily, LayoutFamily.singleColumn);
      expect(decoded.pages[0].lines[0].text, 'Esperienze');
      expect(decoded.pages[0].lines[0].height, 16);
    });

    test('multiColumn layout family round-trips', () {
      final fixture = PdfFixture(
        layoutFamily: LayoutFamily.multiColumn,
        pages: const [],
      );
      expect(
        PdfFixture.decode(fixture.encode()).layoutFamily,
        LayoutFamily.multiColumn,
      );
    });

    test('unknown layoutFamily throws', () {
      expect(
        () => PdfFixture.decode('{"layoutFamily": "grid", "pages": []}'),
        throwsFormatException,
      );
    });
  });

  group('PdfFixture.toPages', () {
    test('maps each line to a PdfCharRect carrying text and height', () {
      final fixture = PdfFixture(
        layoutFamily: LayoutFamily.singleColumn,
        pages: [
          FixturePage(
            pageIndex: 0,
            lines: [FixtureLine(text: 'Contatti', height: 14)],
          ),
        ],
      );

      final pages = fixture.toPages();
      expect(pages, hasLength(1));
      expect(pages[0].pageIndex, 0);
      expect(pages[0].chars, hasLength(1));
      expect(pages[0].chars[0].text, 'Contatti');
      expect(pages[0].chars[0].height, 14);
    });
  });

  group('PdfFixture.allLines', () {
    test('flattens non-empty lines across pages in order, trimmed', () {
      final fixture = PdfFixture(
        layoutFamily: LayoutFamily.singleColumn,
        pages: [
          FixturePage(
            pageIndex: 0,
            lines: [
              FixtureLine(text: '  Prima riga  ', height: 10),
              FixtureLine(text: '', height: 10),
            ],
          ),
          FixturePage(
            pageIndex: 1,
            lines: [FixtureLine(text: 'Seconda riga', height: 10)],
          ),
        ],
      );

      expect(fixture.allLines, ['Prima riga', 'Seconda riga']);
    });
  });
}
