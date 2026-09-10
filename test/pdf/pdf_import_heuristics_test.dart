/// Unit tests for the pure PDF-import heuristics module (ticket 28/13).
library;

import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a single-page fixture: one [PdfCharRect] per line, with normal
/// lines at [normalHeight] and heading lines at [headingHeight] (must be
/// larger, so the geometric-proxy median split picks them out).
PdfPageText page(
  List<String> lines, {
  Set<int> headingLines = const {},
  double normalHeight = 10,
  double headingHeight = 16,
}) {
  return PdfPageText(
    pageIndex: 0,
    chars: [
      for (var i = 0; i < lines.length; i++)
        PdfCharRect(
          text: lines[i],
          x: 0,
          y: i.toDouble(),
          width: 100,
          height: headingLines.contains(i) ? headingHeight : normalHeight,
        ),
    ],
  );
}

void main() {
  group('tryParseFreeTextYearMonth', () {
    final cases = <String, YearMonth?>{
      'gennaio 2020': YearMonth(2020, 1),
      'Gennaio 2020': YearMonth(2020, 1),
      'gen 2020': YearMonth(2020, 1),
      'January 2020': YearMonth(2020, 1),
      'Jan 2020': YearMonth(2020, 1),
      '01/2020': YearMonth(2020, 1),
      '1/2020': YearMonth(2020, 1),
      '01-2020': YearMonth(2020, 1),
      'dicembre 2021': YearMonth(2021, 12),
      '1 Jun 2024': YearMonth(2024, 6),
      '30 SEP 2007': YearMonth(2007, 9),
      '01/06/2024': YearMonth(2024, 6),
      'not a date': null,
      '': null,
      '13/2020': null,
      '32 Jun 2024': null,
      '1 Foo 2024': null,
      '2024': null,
    };

    for (final entry in cases.entries) {
      test('"${entry.key}" -> ${entry.value}', () {
        expect(tryParseFreeTextYearMonth(entry.key), entry.value);
      });
    }
  });

  // Il dizionario dei mesi e' una tabella compilata a mano che cresce a ogni
  // lingua o abbreviazione aggiunta, e una voce sbagliata non fa crashare
  // nulla: produce una data plausibile ma sbagliata, per giunta marcata
  // `certain: true` nel report, quindi il passo di revisione non la
  // evidenzierebbe. Il baseline di mutation testing (ticket 22/53) ha trovato
  // 27 voci su 44 che nessun test toccava: le attese qui sotto sono scritte a
  // mano di proposito, per non ridursi a rileggere la stessa tabella.
  group('tryParseFreeTextYearMonth — ogni voce del dizionario dei mesi', () {
    const monthWords = <String, int>{
      'gennaio': 1,
      'gen': 1,
      'january': 1,
      'jan': 1,
      'febbraio': 2,
      'feb': 2,
      'february': 2,
      'marzo': 3,
      'mar': 3,
      'march': 3,
      'aprile': 4,
      'apr': 4,
      'april': 4,
      'maggio': 5,
      'mag': 5,
      'may': 5,
      'giugno': 6,
      'giu': 6,
      'june': 6,
      'jun': 6,
      'luglio': 7,
      'lug': 7,
      'july': 7,
      'jul': 7,
      'agosto': 8,
      'ago': 8,
      'august': 8,
      'aug': 8,
      'settembre': 9,
      'set': 9,
      'sep': 9,
      'september': 9,
      'sept': 9,
      'ottobre': 10,
      'ott': 10,
      'october': 10,
      'oct': 10,
      'novembre': 11,
      'nov': 11,
      'november': 11,
      'dicembre': 12,
      'dic': 12,
      'december': 12,
      'dec': 12,
    };

    test('il dizionario copre 44 voci: se ne aggiungi una, aggiungila qui', () {
      expect(monthWords, hasLength(44));
    });

    for (final entry in monthWords.entries) {
      test('"${entry.key} 2020" -> mese ${entry.value}', () {
        expect(
          tryParseFreeTextYearMonth('${entry.key} 2020'),
          YearMonth(2020, entry.value),
        );
      });
    }
  });

  group('tryParseDateRangeLine', () {
    test('trattino semplice', () {
      final r = tryParseDateRangeLine('Gennaio 2020 - Marzo 2022');
      expect(r?.start, YearMonth(2020, 1));
      expect(r?.end, YearMonth(2022, 3));
      expect(r?.current, false);
    });

    test('en-dash', () {
      final r = tryParseDateRangeLine('01/2020 – 03/2022');
      expect(r?.start, YearMonth(2020, 1));
      expect(r?.end, YearMonth(2022, 3));
    });

    test('em-dash', () {
      final r = tryParseDateRangeLine('Jan 2020 — Mar 2022');
      expect(r?.start, YearMonth(2020, 1));
      expect(r?.end, YearMonth(2022, 3));
    });

    test('"in corso" apre la data di fine', () {
      final r = tryParseDateRangeLine('Marzo 2022 - in corso');
      expect(r?.start, YearMonth(2022, 3));
      expect(r?.end, null);
      expect(r?.current, true);
    });

    test('"present" apre la data di fine', () {
      final r = tryParseDateRangeLine('Mar 2022 - Present');
      expect(r?.current, true);
    });

    test('solo data di inizio', () {
      final r = tryParseDateRangeLine('Gennaio 2020');
      expect(r?.start, YearMonth(2020, 1));
      expect(r?.end, null);
      expect(r?.current, false);
    });

    test('testo non riconosciuto restituisce null', () {
      expect(tryParseDateRangeLine('Senior Backend Engineer'), null);
    });
  });

  group('buildFromPages — contatti (signal-first)', () {
    test('estrae email, telefono, LinkedIn, GitHub e URL generico', () {
      final (doc, _) = buildFromPages([
        page([
          'Mario Rossi',
          'mario.rossi@example.com',
          '+39 333 1234567',
          'linkedin.com/in/mariorossi',
          'github.com/mariorossi',
          'mariorossi.dev',
        ]),
      ]);

      final contatti = doc.sections.whereType<ContattiSection>().single.data;
      expect(contatti.email, 'mario.rossi@example.com');
      expect(contatti.telefono, isNotNull);
      expect(
        contatti.link.any((l) => l.url.contains('linkedin.com/in/mariorossi')),
        true,
      );
      expect(
        contatti.link.any((l) => l.url.contains('github.com/mariorossi')),
        true,
      );
      expect(contatti.link.any((l) => l.url.contains('mariorossi.dev')), true);
    });

    test('nessun segnale di contatto -> nessuna sezione Contatti', () {
      final (doc, _) = buildFromPages([
        page(['Testo qualunque senza contatti riconoscibili']),
      ]);
      expect(doc.sections.whereType<ContattiSection>(), isEmpty);
    });
  });

  group('buildFromPages — sezione Esperienze', () {
    test('3 item separati da righe data', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze', // heading
            'Gennaio 2020 - Marzo 2021',
            'Sviluppo backend in Dart.',
            'Aprile 2021 - Dicembre 2022',
            'Team lead su un progetto mobile.',
            'Gennaio 2023 - in corso',
            'Staff engineer.',
            'Formazione', // heading
            'Gennaio 2015 - Luglio 2018',
            'Laurea triennale.',
          ],
          headingLines: {0, 7},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(esperienze, hasLength(3));
      expect(esperienze[0].startDate, YearMonth(2020, 1));
      expect(esperienze[0].endDate, YearMonth(2021, 3));
      expect(esperienze[0].ruolo, '');
      expect(esperienze[0].azienda, '');
      expect(esperienze[0].descrizione, contains('Sviluppo backend'));
      expect(esperienze[2].current, true);
      expect(esperienze[2].endDate, null);

      final formazione = doc.sections
          .whereType<FormazioneSection>()
          .single
          .items;
      expect(formazione, hasLength(1));
      expect(formazione[0].startDate, YearMonth(2015, 1));
      expect(formazione[0].endDate, YearMonth(2018, 7));
    });

    test('rileva i titoli sulla mediana della propria pagina, non globale', () {
      // Pagina 1 ha font piccoli (titolo appena sopra la mediana di
      // pagina); pagina 2 ha font molto più grandi. Una mediana globale
      // sarebbe dominata dalla pagina 2 e perderebbe il titolo di pagina 1.
      final pageA = page(
        ['Esperienze', 'Gennaio 2020 - Marzo 2021', 'Testo.'],
        headingLines: {0},
        normalHeight: 10,
        headingHeight: 14,
      );
      final pageB = PdfPageText(
        pageIndex: 1,
        chars: [
          const PdfCharRect(
            text: 'Formazione',
            x: 0,
            y: 0,
            width: 100,
            height: 34,
          ),
          const PdfCharRect(
            text: 'Gennaio 2015 - Luglio 2018',
            x: 0,
            y: 1,
            width: 100,
            height: 30,
          ),
          const PdfCharRect(text: 'Testo.', x: 0, y: 2, width: 100, height: 30),
        ],
      );

      final (doc, _) = buildFromPages([pageA, pageB]);

      expect(
        doc.sections.whereType<EsperienzeSection>().single.items,
        hasLength(1),
      );
      expect(
        doc.sections.whereType<FormazioneSection>().single.items,
        hasLength(1),
      );
    });

    test(
      'propone ruolo/azienda da un connettore esplicito "presso" (ticket 53)',
      () {
        final (doc, report) = buildFromPages([
          page(
            [
              'Esperienze',
              'Senior Backend Engineer presso Acme Corp',
              'Gennaio 2020 - Marzo 2021',
              'Certificazioni',
              'AWS Certified',
            ],
            headingLines: {0, 3},
          ),
        ]);

        final esperienze = doc.sections
            .whereType<EsperienzeSection>()
            .single
            .items;
        expect(esperienze.single.ruolo, 'Senior Backend Engineer');
        expect(esperienze.single.azienda, 'Acme Corp');
        // Keyword-disambiguated explicit match — certain, not vote-derived.
        expect(report.isUncertain('esperienze[0].ruolo'), false);
        expect(report.isUncertain('esperienze[0].azienda'), false);
      },
    );
  });

  group('buildFromPages — fallback anti-disastro', () {
    test('meno di 2 titoli riconosciuti -> tutto in "Da rivedere"', () {
      final (doc, _) = buildFromPages([
        page([
          'Un CV con un solo titolo riconosciuto',
          'Esperienze',
          'testo libero',
        ]),
      ]);

      expect(doc.sections.whereType<EsperienzeSection>(), isEmpty);
      final review = doc.sections.whereType<CustomSection>().single;
      expect(review.displayTitle, 'Da rivedere');
      expect(review.markdown, contains('testo libero'));
    });

    test('pagina vuota -> nessuna sezione', () {
      final (doc, _) = buildFromPages([page([])]);
      expect(doc.sections, isEmpty);
    });

    test('PDF con soli link -> sezione Contatti popolata', () {
      final (doc, _) = buildFromPages([
        page(['mariorossi.dev', 'github.com/mariorossi']),
      ]);
      final contatti = doc.sections.whereType<ContattiSection>().single;
      expect(contatti.data.link, isNotEmpty);
    });
  });

  group('buildFromPages — item non riconosciuto finisce in Da rivedere', () {
    test('blocco Esperienze senza data riconoscibile', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Un blocco di testo senza alcuna data riconoscibile qui dentro',
            'Formazione',
            'Gennaio 2015 - Luglio 2018',
          ],
          headingLines: {0, 2},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(esperienze, isEmpty);

      final review = doc.sections.whereType<CustomSection>().single;
      expect(review.markdown, contains('senza alcuna data riconoscibile'));
    });
  });

  group('buildFromPages — link spazzatura (ticket 51)', () {
    test('una riga skill reale del corpus non produce link', () {
      final (doc, _) = buildFromPages([
        page([
          '• Web & Backend: JavaScript (ES6+), React.js, Redux, Redux-Saga, '
              'Node.js, Vue.js, HTML5, CSS3, JSON/XML',
        ]),
      ]);
      final contatti = doc.sections.whereType<ContattiSection>();
      expect(contatti, isEmpty);
    });

    test('un nome puntato non produce link', () {
      final (doc, _) = buildFromPages([
        page(['Istituto A.B. Rossi']),
      ]);
      expect(doc.sections.whereType<ContattiSection>(), isEmpty);
    });

    test('un dominio con TLD in allowlist resta riconosciuto', () {
      final (doc, _) = buildFromPages([
        page(['mariorossi.dev']),
      ]);
      final contatti = doc.sections.whereType<ContattiSection>().single;
      expect(contatti.data.link.single.url, contains('mariorossi.dev'));
    });

    test(
      'uno schema http(s) esplicito resta riconosciuto a prescindere dal TLD',
      () {
        final (doc, _) = buildFromPages([
          page(['https://esempio.exotic']),
        ]);
        final contatti = doc.sections.whereType<ContattiSection>().single;
        expect(contatti.data.link.single.url, contains('esempio.exotic'));
      },
    );
  });

  group('buildFromPages — footer/paginazione (ticket 51)', () {
    test('righe "Page N/M" vengono scartate', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            'Prima riga.',
            'Page 1/2',
          ],
          headingLines: {0},
        ),
        page(
          [
            'Seconda riga.',
            'Page 2/2',
            'Formazione',
            'Gennaio 2015 - Luglio 2018',
          ],
          headingLines: {2},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(esperienze.single.descrizione, isNot(contains('Page')));
    });

    test('un intervallo di anni "2019-2022" bare non viene scambiato per '
        'paginazione', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            '2019-2022',
            'Formazione',
            'Gennaio 2015 - Luglio 2018',
          ],
          headingLines: {0, 3},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(esperienze.single.descrizione, contains('2019-2022'));
    });

    test('un footer ricorrente identico su più pagine viene scartato', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            'Prima riga.',
            'Mario Rossi — CV',
          ],
          headingLines: {0},
        ),
        page(
          [
            'Formazione',
            'Gennaio 2015 - Luglio 2018',
            'Seconda riga.',
            'Mario Rossi — CV',
          ],
          headingLines: {0},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(
        esperienze.single.descrizione,
        isNot(contains('Mario Rossi — CV')),
      );
      final formazione = doc.sections
          .whereType<FormazioneSection>()
          .single
          .items;
      expect(formazione.single.descrizione, isNot(contains('Mario Rossi')));
    });

    test('una riga non ricorrente in fondo pagina resta nel contenuto', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            'Ultima riga unica.',
            'Formazione',
            'Gennaio 2015 - Luglio 2018',
          ],
          headingLines: {0, 3},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(esperienze.single.descrizione, contains('Ultima riga unica'));
    });
  });

  group('buildFromPages — dizionario titoli con "&" (ticket 51)', () {
    test('"EDUCATION & TRAINING" è riconosciuto come Formazione', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            'Testo.',
            'EDUCATION & TRAINING',
            'Gennaio 2015 - Luglio 2018',
            'Testo.',
          ],
          headingLines: {0, 3},
        ),
      ]);

      expect(
        doc.sections.whereType<FormazioneSection>().single.items,
        hasLength(1),
      );
    });
  });

  group('buildFromPages — sezioni riconosciute ma non strutturabili (ticket 51)', () {
    test('Sommario diventa una sezione custom col titolo originale', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'ABOUT ME',
            'Testo di presentazione libero.',
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            'Testo.',
          ],
          headingLines: {0, 2},
        ),
      ]);

      final custom = doc.sections.whereType<CustomSection>().where(
        (s) => s.displayTitle == 'ABOUT ME',
      );
      expect(custom, hasLength(1));
      expect(custom.single.markdown, contains('Testo di presentazione'));
    });

    test('Skill con una riga a separatori ripetuti diventa tags strutturati (ticket 53)', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Esperienze',
            'Gennaio 2020 - Marzo 2021',
            'Testo.',
            'SKILLS',
            'Dart, Flutter, SQL',
          ],
          headingLines: {0, 3},
        ),
      ]);

      final skill = doc.sections.whereType<SkillSection>().single;
      expect(skill.displayTitle, 'SKILLS');
      expect(skill.data.tags, ['Dart', 'Flutter', 'SQL']);
    });

    test(
      'Lingue con CEFR/madrelingua diventa LinguaItem strutturati (ticket 53)',
      () {
        final (doc, _) = buildFromPages([
          page(
            [
              'Esperienze',
              'Gennaio 2020 - Marzo 2021',
              'Testo.',
              'Lingue',
              'Italiano - Madrelingua',
            ],
            headingLines: {0, 3},
          ),
        ]);

        final lingue = doc.sections.whereType<LingueSection>().single;
        expect(lingue.displayTitle, 'Lingue');
        expect(lingue.items.single.lingua, 'Italiano');
        expect(lingue.items.single.livello, LivelloCefr.madrelingua);
      },
    );
  });

  group('buildFromPages — voto per-documento ruolo/azienda (ticket 53)', () {
    // Every block below hands the *next* block its precedingLines by
    // ending with a 2-line azienda/ruolo pair right before the next date
    // line — mirroring how [_groupIntoItemBlocks] peeks at a block's own
    // trailing content.
    test(
      'ordine azienda-prima: i blocchi ambigui ereditano "far = azienda"',
      () {
        final (doc, report) = buildFromPages([
          page(
            [
              'Esperienze', // 0
              'Gennaio 2018 - Marzo 2019', // 1 (block0 date)
              'Testo descrittivo primo.', // 2
              'Beta Inc', // 3  (far: company marker -> block1's azienda)
              'Solutions Architect', // 4  (near: role vocab -> block1's ruolo)
              'Aprile 2019 - Maggio 2020', // 5 (block1 date)
              'Testo descrittivo secondo.', // 6
              'Gamma Ltd', // 7  (far -> block2's azienda)
              'Platform Manager', // 8  (near -> block2's ruolo)
              'Giugno 2020 - Luglio 2021', // 9 (block2 date)
              'Testo descrittivo terzo.', // 10
              'Nord Ovest', // 11 (far, no vocab -> ambiguous)
              'Coordinamento interno', // 12 (near, no vocab -> ambiguous)
              'Agosto 2021 - Settembre 2022', // 13 (block3 date)
              'Testo descrittivo quarto.', // 14
              'Formazione', // 15
              'Gennaio 2015 - Luglio 2018', // 16
              'Laurea.', // 17
            ],
            headingLines: {0, 15},
          ),
        ]);

        final items = doc.sections.whereType<EsperienzeSection>().single.items;
        expect(items[1].azienda, 'Beta Inc');
        expect(items[1].ruolo, 'Solutions Architect');
        expect(items[2].azienda, 'Gamma Ltd');
        expect(items[2].ruolo, 'Platform Manager');
        // No direct signal on block3's pair: the document-wide majority
        // (far = azienda, established by blocks 1 and 2) fills it in, marked
        // uncertain — a statistical pick, not a direct match.
        expect(items[3].azienda, 'Nord Ovest');
        expect(items[3].ruolo, 'Coordinamento interno');
        expect(report.isUncertain('esperienze[3].azienda'), true);
        expect(report.isUncertain('esperienze[3].ruolo'), true);
        expect(report.isUncertain('esperienze[1].azienda'), false);
      },
    );

    test(
      'ordine ruolo-prima: i blocchi ambigui ereditano "near = azienda"',
      () {
        final (doc, report) = buildFromPages([
          page(
            [
              'Esperienze', // 0
              'Gennaio 2018 - Marzo 2019', // 1
              'Testo descrittivo primo.', // 2
              'Solutions Architect', // 3 (far: role vocab -> ruolo)
              'Beta Inc', // 4 (near: company marker -> azienda)
              'Aprile 2019 - Maggio 2020', // 5
              'Testo descrittivo secondo.', // 6
              'Platform Manager', // 7 (far -> ruolo)
              'Gamma Ltd', // 8 (near -> azienda)
              'Giugno 2020 - Luglio 2021', // 9
              'Testo descrittivo terzo.', // 10
              'Coordinamento interno', // 11 (far, ambiguous)
              'Nord Ovest', // 12 (near, ambiguous)
              'Agosto 2021 - Settembre 2022', // 13
              'Testo descrittivo quarto.', // 14
              'Formazione', // 15
              'Gennaio 2015 - Luglio 2018', // 16
              'Laurea.', // 17
            ],
            headingLines: {0, 15},
          ),
        ]);

        final items = doc.sections.whereType<EsperienzeSection>().single.items;
        expect(items[3].azienda, 'Nord Ovest');
        expect(items[3].ruolo, 'Coordinamento interno');
        expect(report.isUncertain('esperienze[3].azienda'), true);
      },
    );

    test(
      'documento misto senza maggioranza chiara -> ricade su entrambi vuoti',
      () {
        final (doc, _) = buildFromPages([
          page(
            [
              'Esperienze', // 0
              'Gennaio 2018 - Marzo 2019', // 1
              'Testo descrittivo primo.', // 2
              'Beta Inc', // 3 (far=azienda)
              'Solutions Architect', // 4 (near=ruolo)
              'Aprile 2019 - Maggio 2020', // 5
              'Testo descrittivo secondo.', // 6
              'Platform Manager', // 7 (far=ruolo)
              'Gamma Ltd', // 8 (near=azienda) — opposite order, ties the vote
              'Giugno 2020 - Luglio 2021', // 9
              'Testo descrittivo terzo.', // 10
              'Nord Ovest', // 11 (ambiguous)
              'Coordinamento interno', // 12 (ambiguous)
              'Agosto 2021 - Settembre 2022', // 13
              'Testo descrittivo quarto.', // 14
              'Formazione', // 15
              'Gennaio 2015 - Luglio 2018', // 16
              'Laurea.', // 17
            ],
            headingLines: {0, 15},
          ),
        ]);

        final items = doc.sections.whereType<EsperienzeSection>().single.items;
        expect(items[3].azienda, '');
        expect(items[3].ruolo, '');
      },
    );

    test('documento con un solo blocco ambiguo -> nessun voto, resta vuoto', () {
      final (doc, _) = buildFromPages([
        page(
          [
            'Nord Ovest', // 0 (leading, ambiguous, no other block to vote from)
            'Coordinamento interno', // 1
            'Esperienze', // 2
            'Gennaio 2018 - Marzo 2019', // 3
            'Testo.', // 4
            'Formazione', // 5
            'Gennaio 2015 - Luglio 2018', // 6
            'Laurea.', // 7
          ],
          headingLines: {2, 5},
        ),
      ]);

      final items = doc.sections.whereType<EsperienzeSection>().single.items;
      expect(items.single.azienda, '');
      expect(items.single.ruolo, '');
    });
  });

  group('buildFromPages — nome/cognome (ticket 53)', () {
    test('prima riga del documento, prima di ogni heading', () {
      final (doc, report) = buildFromPages([
        page(
          [
            'Anna Bianchi', // 0
            'Esperienze', // 1
            'Gennaio 2020 - Marzo 2021', // 2
            'Testo.', // 3
            'Formazione', // 4
            'Gennaio 2015 - Luglio 2018', // 5
            'Laurea.', // 6
          ],
          headingLines: {1, 4},
        ),
      ]);

      final anagrafica = doc.sections.whereType<AnagraficaSection>().single;
      expect(anagrafica.data.nome, 'Anna');
      expect(anagrafica.data.cognome, 'Bianchi');
      expect(report.isUncertain('anagrafica.nome'), false);
    });

    test('nome composto (>2 token) è marcato incerto', () {
      final (doc, report) = buildFromPages([
        page(
          [
            'Maria Grazia Del Bianco', // 0
            'Esperienze', // 1
            'Gennaio 2020 - Marzo 2021', // 2
            'Testo.', // 3
            'Formazione', // 4
            'Gennaio 2015 - Luglio 2018', // 5
            'Laurea.', // 6
          ],
          headingLines: {1, 4},
        ),
      ]);

      final anagrafica = doc.sections.whereType<AnagraficaSection>().single;
      expect(anagrafica.data.nome, 'Maria');
      expect(anagrafica.data.cognome, 'Grazia Del Bianco');
      expect(report.isUncertain('anagrafica.cognome'), true);
    });
  });

  group(
    'buildFromPages — sezione custom da heading non riconosciuto (ticket 53)',
    () {
      test(
        'un titolo ALL-CAPS non nel dizionario diventa sezione custom propria',
        () {
          final (doc, _) = buildFromPages([
            page(
              [
                'Esperienze', // 0
                'Gennaio 2020 - Marzo 2021', // 1
                'Testo.', // 2
                'PROGETTI', // 3
                'App di gestione spese personale.', // 4
                'Formazione', // 5
                'Gennaio 2015 - Luglio 2018', // 6
                'Laurea.', // 7
              ],
              headingLines: {0, 3, 5},
            ),
          ]);

          final progetti = doc.sections.whereType<CustomSection>().where(
            (s) => s.displayTitle == 'PROGETTI',
          );
          expect(progetti, hasLength(1));
          expect(
            progetti.single.markdown,
            contains('App di gestione spese personale.'),
          );
        },
      );
    },
  );
}
