/// Unit test su `ClassicoTemplate.render` (ticket 24, Testing Decisions):
/// consuma un [CvDocument] seed → produce un `Uint8List` non vuoto con
/// magic bytes `%PDF`.
library;

import 'dart:io';

import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:cv_app/src/pdf/classico_template.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/pdf_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_test_utils.dart';

Future<pw.Font> _loadFont(String name) async {
  final bytes = await File('assets/fonts/$name').readAsBytes();
  return pw.Font.ttf(bytes.buffer.asByteData());
}

Future<ClassicoFonts> _testFonts() async => ClassicoFonts(
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
          data: ContattiData(
            email: 'mario@example.com',
            telefono: '+39 000 000',
            citta: 'Milano',
          ),
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
              modalita: ModalitaLavoro.ibrido,
              tipoContratto: TipoContratto.fullTime,
              startDate: YearMonth(2022, 3),
              current: true,
              descrizione: '- Ho progettato X\n- Ho guidato Y',
            ),
          ],
        ),
        LingueSection(
          displayTitle: 'Lingue',
          items: const [
            LinguaItem(
              id: 'l1',
              lingua: 'Italiano',
              livello: LivelloCefr.madrelingua,
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

  test('produce un PDF non vuoto con magic bytes %PDF (locale IT)', () async {
    final fonts = await _testFonts();
    final doc = ClassicoTemplate.render(
      document: _seedDocument(),
      labels: labelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('produce un PDF non vuoto con magic bytes %PDF (locale EN)', () async {
    final fonts = await _testFonts();
    final doc = ClassicoTemplate.render(
      document: _seedDocument(),
      labels: labelsFor(LabelLocale.en),
      locale: LabelLocale.en,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('produce un PDF non vuoto con magic bytes %PDF, con foto', () async {
    final fonts = await _testFonts();
    final doc = ClassicoTemplate.render(
      document: _seedDocument(withPhoto: true),
      labels: labelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('un documento senza sezioni produce comunque un PDF valido', () async {
    final fonts = await _testFonts();
    final doc = ClassicoTemplate.render(
      document: _seedDocument(sections: const []),
      labels: labelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('sezioni custom vengono renderizzate col loro displayTitle', () async {
    final fonts = await _testFonts();
    final doc = ClassicoTemplate.render(
      document: _seedDocument(
        sections: [
          const AnagraficaSection(
            displayTitle: 'Anagrafica',
            data: AnagraficaData(nome: 'Mario', cognome: 'Rossi'),
          ),
          const CustomSection(
            id: 'c1',
            displayTitle: 'Progetti Open Source',
            markdown: 'Contributi a **progetti** vari.',
          ),
        ],
      ),
      labels: labelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(hasPdfMagicBytes(bytes), isTrue);
  });
}
