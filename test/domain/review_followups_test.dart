import 'dart:convert';

import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/domain/calendar_date.dart';
import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/json_codec.dart';
import 'package:cv_app/src/domain/validation.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

CvDocument _doc({List<CvSection> sections = const []}) => CvDocument(
      id: 'doc-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      variantName: 'v',
      sections: sections,
    );

void main() {
  group('dataNascita — CalendarDate round-trip is timezone-safe', () {
    test('parses YYYY-MM-DD and re-emits it byte-identical', () {
      final json = {
        'schemaVersion': 1,
        'id': 'd',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'variantName': 'v',
        'sections': [
          {
            'kind': 'anagrafica',
            'displayTitle': 'A',
            'data': {
              'nome': 'X',
              'cognome': 'Y',
              'dataNascita': '1990-05-14',
            },
          },
        ],
      };
      final doc = CvDocumentCodec.fromJsonMap(json);
      final a = doc.sections.first as AnagraficaSection;
      expect(a.data.dataNascita, CalendarDate(1990, 5, 14));

      final encoded = CvDocumentCodec.toJsonMap(doc);
      final backAnagr =
          (encoded['sections'] as List).first as Map<String, dynamic>;
      expect((backAnagr['data'] as Map)['dataNascita'], '1990-05-14');
    });

    test('rejects malformed dataNascita', () {
      final json = {
        'schemaVersion': 1,
        'id': 'd',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'variantName': 'v',
        'sections': [
          {
            'kind': 'anagrafica',
            'displayTitle': 'A',
            'data': {
              'nome': 'X',
              'cognome': 'Y',
              'dataNascita': '14/05/1990',
            },
          },
        ],
      };
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });
  });

  group('createdAt / updatedAt must be UTC', () {
    Map<String, dynamic> base() => {
          'schemaVersion': 1,
          'id': 'd',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'variantName': 'v',
          'sections': <Object>[],
        };

    test('rejects naive local ISO datetime', () {
      final json = base()..['createdAt'] = '2026-01-01T00:00:00';
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects non-UTC offset', () {
      final json = base()..['updatedAt'] = '2026-01-01T00:00:00+02:00';
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('accepts explicit +00:00 as a UTC variant', () {
      final json = base()..['createdAt'] = '2026-01-01T00:00:00+00:00';
      expect(CvDocumentCodec.fromJsonMap(json).createdAt.isUtc, isTrue);
    });
  });

  group('validate — custom section id uniqueness', () {
    test('rejects duplicate custom ids', () {
      final doc = _doc(sections: [
        CustomSection(id: 'same', displayTitle: 'A', markdown: 'x'),
        CustomSection(id: 'same', displayTitle: 'B', markdown: 'y'),
      ]);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('accepts distinct custom ids', () {
      final doc = _doc(sections: [
        CustomSection(id: '1', displayTitle: 'A', markdown: 'x'),
        CustomSection(id: '2', displayTitle: 'B', markdown: 'y'),
      ]);
      expect(() => validate(doc), returnsNormally);
    });
  });

  group('copyWith — clearing nullable fields with sentinel', () {
    test('AnagraficaData.copyWith(foto: null) clears the photo', () {
      const a = AnagraficaData(
          nome: 'N', cognome: 'C', foto: AssetRef('some'));
      final cleared = a.copyWith(foto: null);
      expect(cleared.foto, isNull);
      expect(a.foto, isNotNull); // original untouched
    });

    test('AnagraficaData.copyWith with no args preserves foto', () {
      const a = AnagraficaData(
          nome: 'N', cognome: 'C', foto: AssetRef('keep'));
      expect(a.copyWith(nome: 'X').foto?.assetId, 'keep');
    });

    test('EsperienzaItem.copyWith(endDate: null) clears endDate', () {
      final e = EsperienzaItem(
        id: '1',
        ruolo: 'R',
        azienda: 'A',
        startDate: YearMonth(2020, 1),
        endDate: YearMonth(2022, 3),
      );
      final cleared = e.copyWith(endDate: null, current: true);
      expect(cleared.endDate, isNull);
      expect(cleared.current, isTrue);
      expect(e.endDate, isNotNull);
    });

    test('driving asset GC via copyWith clearing works end-to-end', () async {
      final doc = _doc(sections: [
        const AnagraficaSection(
          displayTitle: 'A',
          data: AnagraficaData(
              nome: 'N', cognome: 'C', foto: AssetRef('remove')),
        ),
      ]).copyWith(assets: {
        'remove': Asset(mimeType: 'image/jpeg', data: 'x'),
      });

      final sec = doc.sections.first as AnagraficaSection;
      final updated = doc.copyWith(sections: [
        sec.copyWith(data: sec.data.copyWith(foto: null)),
      ]);
      final gc = garbageCollectAssets(updated);
      expect(gc.assets, isEmpty);
    });
  });

  // Sanity: existing minified round-trip still holds even with new UTC rules.
  test('round-trip preserves createdAt/updatedAt as UTC strings', () {
    final doc = _doc();
    final str = CvDocumentCodec.toJsonString(doc);
    expect(str.contains('"createdAt":"2026-01-01T00:00:00.000Z"'), isTrue);
    final back = CvDocumentCodec.fromJsonString(str);
    expect(back.createdAt, doc.createdAt);

    // Cheap paranoia check: no whitespace, valid JSON.
    expect(jsonDecode(str), isA<Map<String, dynamic>>());
  });
}
