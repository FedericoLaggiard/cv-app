/// Unit test su `MinimalTemplate.render` (ticket 25, Testing Decisions):
/// consuma un [CvDocument] seed → produce un `Uint8List` non vuoto con
/// magic bytes `%PDF`, con foto presente e assente (la foto è sempre
/// ignorata by design, vedi ticket 08).
library;

import 'dart:io';

import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/minimal_template.dart';
import 'package:cv_app/src/pdf/pdf_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_test_utils.dart';

Future<pw.Font> _loadFont(String name) async {
  final bytes = await File('assets/fonts/$name').readAsBytes();
  return pw.Font.ttf(bytes.buffer.asByteData());
}

Future<InterFonts> _labelFont() async => InterFonts(
  regular: await _loadFont('Inter-Regular.ttf'),
  semiBold: await _loadFont('Inter-SemiBold.ttf'),
  italic: await _loadFont('Inter-Italic.ttf'),
  bold: await _loadFont('Inter-Bold.ttf'),
  boldItalic: await _loadFont('Inter-BoldItalic.ttf'),
);

Future<ClassicoFonts> _bodyFonts() async => ClassicoFonts(
  regular: await _loadFont('EBGaramond-Regular.ttf'),
  semiBold: await _loadFont('EBGaramond-SemiBold.ttf'),
  italic: await _loadFont('EBGaramond-Italic.ttf'),
  bold: await _loadFont('EBGaramond-Bold.ttf'),
  boldItalic: await _loadFont('EBGaramond-BoldItalic.ttf'),
);

const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

CvDocument _seedDocument({List<CvSection>? sections, bool withPhoto = false}) =>
    CvDocument(
      id: 'doc-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      variantName: 'Backend Senior IT',
      assets: withPhoto
          ? {'photo-1': const Asset(mimeType: 'image/png', data: _tinyPngBase64)}
          : const {},
      sections:
          sections ??
          [
            AnagraficaSection(
              displayTitle: 'Anagrafica',
              data: AnagraficaData(
                nome: 'Mario',
                cognome: 'Rossi',
                headline: 'Senior Backend Engineer',
                foto: withPhoto ? const AssetRef('photo-1') : null,
              ),
            ),
            ContattiSection(
              displayTitle: 'Contatti',
              data: ContattiData(email: 'mario@example.com', citta: 'Milano'),
            ),
            const SommarioSection(
              displayTitle: 'Sommario',
              markdown: 'Ingegnere con **10 anni** di esperienza.',
            ),
            EsperienzeSection(
              displayTitle: 'Esperienze',
              items: [
                EsperienzaItem(
                  id: 'e1',
                  ruolo: 'Senior Backend Engineer',
                  azienda: 'Acme SpA',
                  luogo: 'Milano',
                  startDate: YearMonth(2022, 3),
                  current: true,
                  descrizione: '- Ho progettato X\n- Ho guidato Y',
                ),
              ],
            ),
            SkillSection(
              displayTitle: 'Skill',
              data: SkillData(tags: const ['Go', 'Kubernetes']),
            ),
          ],
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('produce un PDF non vuoto con magic bytes %PDF, senza foto', () async {
    final doc = MinimalTemplate.render(
      document: _seedDocument(),
      labels: minimalLabelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      labelFont: await _labelFont(),
      bodyFonts: await _bodyFonts(),
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('produce un PDF non vuoto con magic bytes %PDF, con foto (ignorata)', () async {
    final doc = MinimalTemplate.render(
      document: _seedDocument(withPhoto: true),
      labels: minimalLabelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      labelFont: await _labelFont(),
      bodyFonts: await _bodyFonts(),
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('un documento senza sezioni produce comunque un PDF valido', () async {
    final doc = MinimalTemplate.render(
      document: _seedDocument(sections: const []),
      labels: minimalLabelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      labelFont: await _labelFont(),
      bodyFonts: await _bodyFonts(),
    );
    final bytes = await doc.save();
    expect(hasPdfMagicBytes(bytes), isTrue);
  });
}
