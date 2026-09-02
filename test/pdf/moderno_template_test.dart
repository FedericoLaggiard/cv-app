/// Unit test su `ModernoTemplate.render` (ticket 25, Testing Decisions):
/// consuma un [CvDocument] seed → produce un `Uint8List` non vuoto con
/// magic bytes `%PDF`, con foto presente e assente; verifica che la banda
/// laterale non compaia da pagina 2 in poi su un documento lungo.
library;

import 'dart:io';

import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:cv_app/src/pdf/moderno_template.dart';
import 'package:cv_app/src/pdf/pdf_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_test_utils.dart';

Future<pw.Font> _loadFont(String name) async {
  final bytes = await File('assets/fonts/$name').readAsBytes();
  return pw.Font.ttf(bytes.buffer.asByteData());
}

Future<InterFonts> _testFonts() async => InterFonts(
  regular: await _loadFont('Inter-Regular.ttf'),
  semiBold: await _loadFont('Inter-SemiBold.ttf'),
  italic: await _loadFont('Inter-Italic.ttf'),
  bold: await _loadFont('Inter-Bold.ttf'),
  boldItalic: await _loadFont('Inter-BoldItalic.ttf'),
);

const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

CvDocument _seedDocument({
  List<CvSection>? sections,
  bool withPhoto = false,
}) => CvDocument(
  id: 'doc-1',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  variantName: 'Backend Senior IT',
  assets: withPhoto ? {'photo-1': const Asset(mimeType: 'image/png', data: _tinyPngBase64)} : const {},
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
              startDate: YearMonth(2022, 3),
              current: true,
              descrizione: '- Ho progettato X\n- Ho guidato Y',
            ),
          ],
        ),
        LingueSection(
          displayTitle: 'Lingue',
          items: const [
            LinguaItem(id: 'l1', lingua: 'Italiano', livello: LivelloCefr.madrelingua),
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
    final fonts = await _testFonts();
    final doc = ModernoTemplate.render(
      document: _seedDocument(),
      labels: modernoLabelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('produce un PDF non vuoto con magic bytes %PDF, con foto', () async {
    final fonts = await _testFonts();
    final doc = ModernoTemplate.render(
      document: _seedDocument(withPhoto: true),
      labels: modernoLabelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test('un documento senza sezioni produce comunque un PDF valido', () async {
    final fonts = await _testFonts();
    final doc = ModernoTemplate.render(
      document: _seedDocument(sections: const []),
      labels: modernoLabelsFor(LabelLocale.it),
      locale: LabelLocale.it,
      fonts: fonts,
    );
    final bytes = await doc.save();
    expect(hasPdfMagicBytes(bytes), isTrue);
  });

  test(
    'documento lungo forza più pagine e la banda (CONTATTI) compare solo '
    'sulla prima pagina',
    () async {
      final fonts = await _testFonts();
      final manyEsperienze = [
        for (var i = 0; i < 25; i++)
          EsperienzaItem(
            id: 'e$i',
            ruolo: 'Ruolo numero $i molto lungo per riempire la pagina',
            azienda: 'Azienda $i',
            luogo: 'Città $i',
            startDate: YearMonth(2010 + i % 10, 1),
            endDate: YearMonth(2011 + i % 10, 6),
            descrizione:
                '- Attività A molto dettagliata per il ruolo $i\n'
                '- Attività B ancora più dettagliata\n'
                '- Attività C con parecchio testo per allungare il blocco',
          ),
      ];
      final doc = ModernoTemplate.render(
        document: _seedDocument(
          sections: [
            const AnagraficaSection(
              displayTitle: 'Anagrafica',
              data: AnagraficaData(nome: 'Mario', cognome: 'Rossi'),
            ),
            ContattiSection(
              displayTitle: 'Contatti',
              data: ContattiData(email: 'mario@example.com'),
            ),
            const SommarioSection(displayTitle: 'Sommario', markdown: 'Breve intro.'),
            EsperienzeSection(displayTitle: 'Esperienze', items: manyEsperienze),
          ],
        ),
        labels: modernoLabelsFor(LabelLocale.it),
        locale: LabelLocale.it,
        fonts: fonts,
        compress: false,
      );
      final bytes = await doc.save();
      expect(hasPdfMagicBytes(bytes), isTrue);
      expect(pdfPageCount(bytes), greaterThan(1));

      // Il fill della banda (`ModernoTheme.bandBackground`, #1f2d3d) è
      // disegnato una volta sola nel content stream (operatore colore
      // `rg`): siccome la banda esiste solo sulla prima pagina, la sua
      // assenza dal resto del documento conferma strutturalmente che non
      // si ripete da pagina 2 in poi (ticket 25, Testing Decisions).
      final bandColorOperator = '0.12157 0.17647 0.23922 rg';
      expect(pdfCountOccurrences(bytes, bandColorOperator), 1);
    },
  );
}
