/// Unit tests for the pure PDF-import heuristics module (ticket 28/13).
library;

import 'package:cv_app/src/domain/cv_section.dart';
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
      final doc = buildFromPages([
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
      final doc = buildFromPages([
        page(['Testo qualunque senza contatti riconoscibili']),
      ]);
      expect(doc.sections.whereType<ContattiSection>(), isEmpty);
    });
  });

  group('buildFromPages — sezione Esperienze', () {
    test('3 item separati da righe data', () {
      final doc = buildFromPages([
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

      final doc = buildFromPages([pageA, pageB]);

      expect(
        doc.sections.whereType<EsperienzeSection>().single.items,
        hasLength(1),
      );
      expect(
        doc.sections.whereType<FormazioneSection>().single.items,
        hasLength(1),
      );
    });

    test('non riempie mai ruolo/azienda/titolo/istituto', () {
      final doc = buildFromPages([
        page(
          [
            'Esperienze',
            'Senior Backend Engineer presso Acme Corp',
            'Gennaio 2020 - Marzo 2021',
            'Formazione',
            'Laurea in Informatica presso Università di Bologna',
            'Gennaio 2015 - Luglio 2018',
          ],
          headingLines: {0, 3},
        ),
      ]);

      final esperienze = doc.sections
          .whereType<EsperienzeSection>()
          .single
          .items;
      expect(esperienze.single.ruolo, '');
      expect(esperienze.single.azienda, '');

      final formazione = doc.sections
          .whereType<FormazioneSection>()
          .single
          .items;
      expect(formazione.single.titolo, '');
      expect(formazione.single.istituto, null);
    });
  });

  group('buildFromPages — fallback anti-disastro', () {
    test('meno di 2 titoli riconosciuti -> tutto in "Da rivedere"', () {
      final doc = buildFromPages([
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
      final doc = buildFromPages([page([])]);
      expect(doc.sections, isEmpty);
    });

    test('PDF con soli link -> sezione Contatti popolata', () {
      final doc = buildFromPages([
        page(['mariorossi.dev', 'github.com/mariorossi']),
      ]);
      final contatti = doc.sections.whereType<ContattiSection>().single;
      expect(contatti.data.link, isNotEmpty);
    });
  });

  group('buildFromPages — item non riconosciuto finisce in Da rivedere', () {
    test('blocco Esperienze senza data riconoscibile', () {
      final doc = buildFromPages([
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
      final doc = buildFromPages([
        page([
          '• Web & Backend: JavaScript (ES6+), React.js, Redux, Redux-Saga, '
              'Node.js, Vue.js, HTML5, CSS3, JSON/XML',
        ]),
      ]);
      final contatti = doc.sections.whereType<ContattiSection>();
      expect(contatti, isEmpty);
    });

    test('un nome puntato non produce link', () {
      final doc = buildFromPages([
        page(['Istituto A.B. Rossi']),
      ]);
      expect(doc.sections.whereType<ContattiSection>(), isEmpty);
    });

    test('un dominio con TLD in allowlist resta riconosciuto', () {
      final doc = buildFromPages([
        page(['mariorossi.dev']),
      ]);
      final contatti = doc.sections.whereType<ContattiSection>().single;
      expect(contatti.data.link.single.url, contains('mariorossi.dev'));
    });

    test(
      'uno schema http(s) esplicito resta riconosciuto a prescindere dal TLD',
      () {
        final doc = buildFromPages([
          page(['https://esempio.exotic']),
        ]);
        final contatti = doc.sections.whereType<ContattiSection>().single;
        expect(contatti.data.link.single.url, contains('esempio.exotic'));
      },
    );
  });

  group('buildFromPages — footer/paginazione (ticket 51)', () {
    test('righe "Page N/M" vengono scartate', () {
      final doc = buildFromPages([
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
      final doc = buildFromPages([
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
      final doc = buildFromPages([
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
      final doc = buildFromPages([
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
      final doc = buildFromPages([
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

  group(
    'buildFromPages — sezioni riconosciute ma non strutturabili (ticket 51)',
    () {
      test('Sommario diventa una sezione custom col titolo originale', () {
        final doc = buildFromPages([
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

      test('Skill diventa una sezione custom col titolo originale', () {
        final doc = buildFromPages([
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

        final custom = doc.sections.whereType<CustomSection>().where(
          (s) => s.displayTitle == 'SKILLS',
        );
        expect(custom, hasLength(1));
        expect(custom.single.markdown, contains('Dart, Flutter, SQL'));
      });

      test('Lingue diventa una sezione custom col titolo originale', () {
        final doc = buildFromPages([
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

        final custom = doc.sections.whereType<CustomSection>().where(
          (s) => s.displayTitle == 'Lingue',
        );
        expect(custom, hasLength(1));
        expect(custom.single.markdown, contains('Italiano - Madrelingua'));
      });
    },
  );
}
