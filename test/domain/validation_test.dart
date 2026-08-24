import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/validation.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

CvDocument _emptyDoc({List<CvSection> sections = const []}) => CvDocument(
      id: 'doc-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      variantName: 'v',
      sections: sections,
    );

void main() {
  group('validate — displayTitle uniqueness (case-insensitive + trim)', () {
    test('accepts distinct titles', () {
      final doc = _emptyDoc(sections: [
        const SommarioSection(displayTitle: 'Profilo', markdown: 'x'),
        CustomSection(
            id: 'c1', displayTitle: 'Pubblicazioni', markdown: 'x'),
      ]);
      expect(() => validate(doc), returnsNormally);
    });

    test('rejects duplicates ignoring case + surrounding whitespace', () {
      final doc = _emptyDoc(sections: [
        const SommarioSection(displayTitle: 'Profilo', markdown: 'x'),
        CustomSection(
            id: 'c1', displayTitle: '  profilo  ', markdown: 'x'),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('rejects empty / whitespace-only displayTitle', () {
      final doc = _emptyDoc(sections: [
        const SommarioSection(displayTitle: '   ', markdown: 'x'),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });
  });

  group('validate — kind uniqueness for fixed sections', () {
    test('rejects two Sommario sections', () {
      final doc = _emptyDoc(sections: [
        const SommarioSection(displayTitle: 'A', markdown: 'x'),
        const SommarioSection(displayTitle: 'B', markdown: 'y'),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('allows many custom sections', () {
      final doc = _emptyDoc(sections: [
        CustomSection(id: '1', displayTitle: 'A', markdown: 'x'),
        CustomSection(id: '2', displayTitle: 'B', markdown: 'y'),
        CustomSection(id: '3', displayTitle: 'C', markdown: 'z'),
      ]);
      expect(() => validate(doc), returnsNormally);
    });
  });

  group('validate — required item fields', () {
    test('esperienza requires ruolo + azienda + startDate (types enforce startDate)', () {
      final doc = _emptyDoc(sections: [
        EsperienzeSection(displayTitle: 'Esperienze', items: [
          EsperienzaItem(
            id: 'x',
            ruolo: '  ',
            azienda: 'ACME',
            startDate: YearMonth(2020, 1),
          ),
        ]),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('anagrafica requires nome + cognome', () {
      final doc = _emptyDoc(sections: [
        const AnagraficaSection(
          displayTitle: 'A',
          data: AnagraficaData(nome: '', cognome: 'X'),
        ),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('custom section id must be non-empty', () {
      final doc = _emptyDoc(sections: [
        CustomSection(id: '', displayTitle: 'A', markdown: 'x'),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('duplicate item id inside a list is rejected', () {
      final doc = _emptyDoc(sections: [
        EsperienzeSection(displayTitle: 'E', items: [
          EsperienzaItem(
              id: 'same',
              ruolo: 'A',
              azienda: 'B',
              startDate: YearMonth(2020, 1)),
          EsperienzaItem(
              id: 'same',
              ruolo: 'C',
              azienda: 'D',
              startDate: YearMonth(2021, 1)),
        ]),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });
  });

  group('validate — variantName', () {
    test('rejects empty variantName', () {
      final doc = CvDocument(
        id: 'x',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        variantName: '   ',
      );
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });
  });

  group('garbageCollectAssets', () {
    test('removes unreferenced assets on save', () {
      final doc = _emptyDoc(sections: [
        AnagraficaSection(
          displayTitle: 'A',
          data: AnagraficaData(
            nome: 'N',
            cognome: 'C',
            foto: AssetRef('keep'),
          ),
        ),
      ]).copyWith(assets: {
        'keep': Asset(mimeType: 'image/jpeg', data: 'A'),
        'orphan': Asset(mimeType: 'image/png', data: 'B'),
      });

      final gc = garbageCollectAssets(doc);
      expect(gc.assets.keys, ['keep']);
    });

    test('leaves assets untouched when everything is referenced', () {
      final doc = _emptyDoc(sections: [
        AnagraficaSection(
          displayTitle: 'A',
          data: AnagraficaData(nome: 'N', cognome: 'C', foto: AssetRef('a1')),
        ),
      ]).copyWith(assets: {'a1': Asset(mimeType: 'image/jpeg', data: 'x')});

      final gc = garbageCollectAssets(doc);
      expect(gc.assets.keys, ['a1']);
    });

    test('empties assets when no references at all', () {
      final doc = _emptyDoc().copyWith(assets: {
        'orphan': Asset(mimeType: 'image/jpeg', data: 'x'),
      });
      final gc = garbageCollectAssets(doc);
      expect(gc.assets, isEmpty);
    });
  });
}
