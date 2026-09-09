/// Unit tests for the conversion-rate scoring logic (ticket 50).
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversion_scoring.dart';

void main() {
  group('scoreConversion', () {
    test('caso perfetto: 100% recall, 100% precisione', () {
      final expected = {
        'contatti.email': 'a@b.com',
        'esperienze[0].ruolo': 'Dev',
      };
      final score = scoreConversion(expected: expected, proposed: expected);

      expect(score.recall, 1.0);
      expect(score.precision, 1.0);
      expect(score.correctCount, 2);
    });

    test('caso a zero proposte: recall 0, precisione 100% per convenzione', () {
      final score = scoreConversion(
        expected: {'contatti.email': 'a@b.com'},
        proposed: {},
      );

      expect(score.recall, 0.0);
      expect(score.precision, 1.0);
    });

    test(
      'proposte sbagliate abbassano la precisione senza toccare il recall',
      () {
        final score = scoreConversion(
          expected: {'contatti.email': 'a@b.com'},
          proposed: {'contatti.email': 'a@b.com', 'contatti.telefono': '123'},
        );

        expect(score.recall, 1.0);
        expect(score.precision, 0.5);
      },
    );

    test('nessun campo atteso -> recall indefinito (null)', () {
      final score = scoreConversion(
        expected: {},
        proposed: {'contatti.email': 'a@b.com'},
      );
      expect(score.recall, isNull);
      expect(score.precision, 0.0);
    });

    test('confronto normalizza trim/whitespace/case', () {
      final score = scoreConversion(
        expected: {'esperienze[0].descrizione': "Riga uno\nRiga  due"},
        proposed: {'esperienze[0].descrizione': '  RIGA UNO Riga due  '},
      );
      expect(score.recall, 1.0);
    });

    test('breakdown per sezione conta solo i campi di quella sezione', () {
      final score = scoreConversion(
        expected: {'contatti.email': 'a@b.com', 'esperienze[0].ruolo': 'Dev'},
        proposed: {'contatti.email': 'a@b.com'},
      );

      expect(score.bySection['contatti']!.recall, 1.0);
      expect(score.bySection['esperienze']!.recall, 0.0);
      expect(score.bySection['esperienze']!.precision, 1.0); // zero proposte
    });
  });

  group('flattenDocument', () {
    test(
      'non include ruolo/azienda/titolo mai valorizzati (stringa vuota)',
      () {
        final doc = CvDocument(
          id: '1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          variantName: '',
          sections: [
            EsperienzeSection(
              displayTitle: 'Esperienze',
              items: [
                EsperienzaItem(
                  id: 'e1',
                  ruolo: '',
                  azienda: '',
                  startDate: YearMonth(2020, 1),
                ),
              ],
            ),
          ],
        );

        final fields = flattenDocument(doc);

        expect(fields.containsKey('esperienze[0].ruolo'), false);
        expect(fields.containsKey('esperienze[0].azienda'), false);
        expect(fields['esperienze[0].startDate'], '2020-01');
        expect(fields['esperienze[0].current'], 'false');
      },
    );

    test('estrae contatti ed è vuoto quando la sezione manca', () {
      final doc = CvDocument(
        id: '1',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        variantName: '',
        sections: [
          ContattiSection(
            displayTitle: 'Contatti',
            data: ContattiData(
              email: 'a@b.com',
              link: [Link(label: 'GitHub', url: 'https://github.com/x')],
            ),
          ),
        ],
      );

      final fields = flattenDocument(doc);
      expect(fields['contatti.email'], 'a@b.com');
      expect(fields['contatti.link[0]'], 'https://github.com/x');
    });
  });
}
