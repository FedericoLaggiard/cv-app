import 'dart:convert';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/domain/json_codec.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

// Example from ticket 03, extended to cover every kind.
const _fixture = '''
{
  "schemaVersion": 1,
  "id": "8f3c9a10-9b1c-4b2e-9b83-2c1b8d6e2f0a",
  "createdAt": "2026-08-22T15:00:00.000Z",
  "updatedAt": "2026-08-22T15:12:47.000Z",
  "variantName": "Full-stack senior",
  "sections": [
    {
      "kind": "anagrafica",
      "displayTitle": "Dati personali",
      "data": {
        "nome": "Federico",
        "cognome": "Laggiard",
        "foto": { "assetId": "b0e7c4d2-3a1f-4d9c-88a1-3fa1c6d0b2e2" }
      }
    },
    {
      "kind": "contatti",
      "displayTitle": "Contatti",
      "data": {
        "email": "me@example.com",
        "link": [{"label": "LinkedIn", "url": "https://linkedin.com/in/x"}]
      }
    },
    {
      "kind": "sommario",
      "displayTitle": "Profilo",
      "data": "Sviluppatore full-stack con **10 anni**"
    },
    {
      "kind": "esperienze",
      "displayTitle": "Esperienze",
      "data": [
        {
          "id": "1c7a1b6e-2f3d-4a1b-9c0e-5d6e7f8a9b0c",
          "ruolo": "Senior Engineer",
          "azienda": "ACME",
          "startDate": "2023-05",
          "current": true,
          "descrizione": "- Progettato"
        }
      ]
    },
    {
      "kind": "formazione",
      "displayTitle": "Formazione",
      "data": [
        {
          "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          "titolo": "Laurea",
          "startDate": "2015-09",
          "endDate": "2018-07"
        }
      ]
    },
    {
      "kind": "skill",
      "displayTitle": "Skill",
      "data": { "markdown": "**Dart**", "tags": ["dart", "flutter"] }
    },
    {
      "kind": "lingue",
      "displayTitle": "Lingue",
      "data": [
        { "id": "aa11aaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "lingua": "Italiano", "livello": "madrelingua" },
        { "id": "bb22bbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "lingua": "English", "livello": "c1" }
      ]
    },
    {
      "kind": "certificazioni",
      "displayTitle": "Certificazioni",
      "data": [
        {
          "id": "cc33cccc-cccc-cccc-cccc-cccccccccccc",
          "nome": "AWS Solutions Architect",
          "ente": "AWS",
          "dataConseguimento": "2022-03"
        }
      ]
    },
    {
      "kind": "custom",
      "id": "d1e2f3a4-5b6c-7d8e-9f0a-1b2c3d4e5f60",
      "displayTitle": "Pubblicazioni",
      "data": "- *A framework*, IEEE 2024"
    }
  ],
  "assets": {
    "b0e7c4d2-3a1f-4d9c-88a1-3fa1c6d0b2e2": {
      "mimeType": "image/jpeg",
      "data": "AAAA"
    }
  }
}
''';

void main() {
  group('JSON codec — parse full fixture', () {
    late CvDocument doc;

    setUp(() {
      doc = CvDocumentCodec.fromJsonString(_fixture);
    });

    test('reads root metadata', () {
      expect(doc.schemaVersion, 1);
      expect(doc.id, '8f3c9a10-9b1c-4b2e-9b83-2c1b8d6e2f0a');
      expect(doc.variantName, 'Full-stack senior');
      expect(doc.createdAt.toUtc().toIso8601String(),
          '2026-08-22T15:00:00.000Z');
    });

    test('has 9 ordered sections in the correct kinds', () {
      expect(
        doc.sections.map((s) => s.kind).toList(),
        [
          SectionKind.anagrafica,
          SectionKind.contatti,
          SectionKind.sommario,
          SectionKind.esperienze,
          SectionKind.formazione,
          SectionKind.skill,
          SectionKind.lingue,
          SectionKind.certificazioni,
          SectionKind.custom,
        ],
      );
    });

    test('anagrafica has foto AssetRef', () {
      final s = doc.sections.first as AnagraficaSection;
      expect(s.displayTitle, 'Dati personali');
      expect(s.data.nome, 'Federico');
      expect(s.data.foto?.assetId, 'b0e7c4d2-3a1f-4d9c-88a1-3fa1c6d0b2e2');
    });

    test('esperienze item parses startDate + current', () {
      final s = doc.sections[3] as EsperienzeSection;
      expect(s.items.single.startDate, YearMonth(2023, 5));
      expect(s.items.single.current, isTrue);
      expect(s.items.single.endDate, isNull);
    });

    test('skill data has markdown + tags', () {
      final s = doc.sections[5] as SkillSection;
      expect(s.data.markdown, '**Dart**');
      expect(s.data.tags, ['dart', 'flutter']);
    });

    test('custom section has id and markdown blob', () {
      final s = doc.sections.last as CustomSection;
      expect(s.id, 'd1e2f3a4-5b6c-7d8e-9f0a-1b2c3d4e5f60');
      expect(s.markdown, '- *A framework*, IEEE 2024');
    });

    test('assets store present', () {
      expect(doc.assets, hasLength(1));
      expect(doc.assets.values.first.mimeType, 'image/jpeg');
    });
  });

  group('JSON codec — round-trip', () {
    test('parse -> encode -> parse is idempotent', () {
      final a = CvDocumentCodec.fromJsonString(_fixture);
      final encoded = CvDocumentCodec.toJsonString(a);
      final b = CvDocumentCodec.fromJsonString(encoded);
      expect(b, a);
    });

    test('minified output has no whitespace', () {
      final a = CvDocumentCodec.fromJsonString(_fixture);
      final encoded = CvDocumentCodec.toJsonString(a);
      expect(encoded.contains('\n'), isFalse);
      expect(encoded.contains('  '), isFalse);
    });
  });

  group('JSON codec — strict unknown fields', () {
    test('rejects unknown key at root', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      json['foo'] = 'bar';
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects unknown key inside section wrapper', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      (json['sections'] as List).first['extra'] = 1;
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects unknown key inside a section data payload', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      final anagr =
          ((json['sections'] as List).first as Map)['data'] as Map;
      anagr['stipendio'] = 100000;
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects unknown key inside a list item', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      final esp = ((json['sections'] as List)[3] as Map)['data'] as List;
      (esp.first as Map)['boh'] = true;
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects unknown asset key', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      final assets = json['assets'] as Map;
      final firstAsset = assets.values.first as Map;
      firstAsset['sha256'] = 'x';
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });
  });

  group('JSON codec — schemaVersion policy', () {
    test('rejects a newer schemaVersion (refuse-if-newer)', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      json['schemaVersion'] = currentSchemaVersion + 1;
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaTooNewException>()),
      );
    });

    test('rejects a non-integer schemaVersion', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      json['schemaVersion'] = '1';
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects missing schemaVersion', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      json.remove('schemaVersion');
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });
  });

  group('JSON codec — hard errors on garbage input', () {
    test('throws on non-JSON', () {
      expect(
        () => CvDocumentCodec.fromJsonString('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on JSON array (not object) root', () {
      expect(
        () => CvDocumentCodec.fromJsonString('[]'),
        throwsA(isA<CvSchemaException>()),
      );
    });

    test('rejects unknown kind', () {
      final json = jsonDecode(_fixture) as Map<String, dynamic>;
      (json['sections'] as List).add({
        'kind': 'progetti',
        'displayTitle': 'Progetti',
        'data': '',
      });
      expect(
        () => CvDocumentCodec.fromJsonMap(json),
        throwsA(isA<CvSchemaException>()),
      );
    });
  });
}
