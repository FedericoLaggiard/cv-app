/// Widget tests per EditorScreen (ticket 07 / slice editor strutturato).
library;

import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _wideSize = Size(1200, 900);
const _narrowSize = Size(480, 900);

/// Oltre il debounce di auto-save (800 ms) del bloc.
const _oltreIlDebounce = Duration(seconds: 1);

Widget _makeApp({
  required InMemoryCvRepository repository,
  required String variantId,
  VoidCallback? onBack,
  Size size = _wideSize,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: EditorScreen(
        variantId: variantId,
        repository: repository,
        onBack: onBack,
      ),
    ),
  );
}

/// Crea una variante e ci scrive dentro [sections]. Passa dal `save()` del
/// repository di proposito: se un giorno il salvataggio tornasse a
/// rifiutare le bozze incomplete, questi test fallirebbero qui.
Future<String> _seed(
  InMemoryCvRepository repo,
  List<CvSection> sections, {
  String name = 'Variante',
}) async {
  final doc = await repo.create(initialVariantName: name);
  if (sections.isNotEmpty) {
    await repo.save(doc.copyWith(sections: sections));
  }
  return doc.id;
}

/// Una pump per far partire `EditorStarted`, una per lasciar arrivare il
/// primo snapshot dallo stream del repository.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

const _anagraficaVuota = AnagraficaSection(
  displayTitle: 'Anagrafica',
  data: AnagraficaData(nome: '', cognome: ''),
);

const _anagraficaPiena = AnagraficaSection(
  displayTitle: 'Anagrafica',
  data: AnagraficaData(nome: 'Mario', cognome: 'Rossi'),
);

void main() {
  group('EditorScreen — caricamento', () {
    testWidgets('id sconosciuto → schermata di errore', (tester) async {
      await tester.pumpWidget(_makeApp(
        repository: InMemoryCvRepository(),
        variantId: 'non-esiste',
      ));
      await _settle(tester);

      expect(find.textContaining('Errore:'), findsOneWidget);
    });

    testWidgets('variante esistente → nome nella top bar', (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, const [], name: 'Frontend Sr');

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      expect(find.byKey(const Key('editor_variant_name')), findsOneWidget);
      expect(find.text('Frontend Sr'), findsOneWidget);
      expect(find.byKey(const Key('save_indicator_saved')), findsOneWidget);
    });
  });

  group('EditorScreen — sezioni', () {
    testWidgets('rende una card per sezione con i campi del form',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [_anagraficaPiena]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      expect(find.byKey(const Key('section_card_0')), findsOneWidget);
      expect(find.byKey(const Key('anagrafica_nome_0')), findsOneWidget);
      expect(find.byKey(const Key('anagrafica_cognome_0')), findsOneWidget);
    });

    testWidgets('badge ⚠ solo sulle sezioni con obbligatori mancanti',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [
        _anagraficaVuota,
        const SommarioSection(displayTitle: 'Sommario', markdown: ''),
      ]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      expect(find.byKey(const Key('section_missing_badge_0')), findsOneWidget);
      expect(find.byKey(const Key('section_missing_badge_1')), findsNothing);
    });

    testWidgets('il chevron dell\'header collassa la sezione', (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [_anagraficaPiena]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);
      expect(find.byKey(const Key('anagrafica_nome_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('section_chevron_0')));
      await tester.pump();

      expect(find.byKey(const Key('anagrafica_nome_0')), findsNothing);
      expect(find.byKey(const Key('section_card_0')), findsOneWidget);
    });

    testWidgets('il badge resta visibile su una sezione collassata',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [_anagraficaVuota]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('section_chevron_0')));
      await tester.pump();

      expect(find.byKey(const Key('anagrafica_nome_0')), findsNothing);
      expect(find.byKey(const Key('section_missing_badge_0')), findsOneWidget);
    });

    testWidgets('Comprimi tutte / Espandi tutte agiscono su tutte',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [
        _anagraficaPiena,
        ContattiSection(displayTitle: 'Contatti', data: ContattiData()),
      ]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('sidebar_collapse_all')));
      await tester.pump();
      expect(find.byKey(const Key('anagrafica_nome_0')), findsNothing);
      expect(find.byKey(const Key('contatti_email_1')), findsNothing);

      await tester.tap(find.byKey(const Key('sidebar_expand_all')));
      await tester.pump();
      expect(find.byKey(const Key('anagrafica_nome_0')), findsOneWidget);
      expect(find.byKey(const Key('contatti_email_1')), findsOneWidget);
    });
  });

  group('EditorScreen — indice', () {
    testWidgets('elenca le sezioni nell\'ordine del documento',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [
        _anagraficaPiena,
        const SommarioSection(displayTitle: 'Sommario', markdown: ''),
      ]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      expect(find.byKey(const Key('index_entry_0')), findsOneWidget);
      expect(find.byKey(const Key('index_entry_1')), findsOneWidget);
      expect(find.byKey(const Key('index_entry_2')), findsNothing);
    });

    testWidgets('il jump-to riespande una sezione collassata',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [_anagraficaPiena]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('section_chevron_0')));
      await tester.pump();
      expect(find.byKey(const Key('anagrafica_nome_0')), findsNothing);

      await tester.tap(find.byKey(const Key('index_entry_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('anagrafica_nome_0')), findsOneWidget);
    });

    testWidgets('sotto i 900px l\'indice vive in un bottom sheet',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [_anagraficaPiena]);

      await tester.pumpWidget(_makeApp(
        repository: repo,
        variantId: id,
        size: _narrowSize,
      ));
      await _settle(tester);

      expect(find.byKey(const Key('index_entry_0')), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('index_entry_0')), findsOneWidget);
    });
  });

  group('EditorScreen — aggiunta sezioni', () {
    testWidgets('il dialog aggiunge una sezione fissa mancante',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, const []);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('sidebar_add_section')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_section_fixed_anagrafica')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_section_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('section_card_0')), findsOneWidget);
      expect(find.byKey(const Key('anagrafica_nome_0')), findsOneWidget);
      // Bozza incompleta: il badge si accende ma il salvataggio non rompe.
      expect(find.byKey(const Key('section_missing_badge_0')), findsOneWidget);

      await tester.pump(_oltreIlDebounce);
      expect(find.byKey(const Key('save_indicator_error')), findsNothing);
    });

    testWidgets('il dialog aggiunge una sezione custom col titolo scelto',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, const []);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('editor_add_section')));
      await tester.pumpAndSettle();

      // Con zero sezioni il dialog elenca tutte e 8 le fisse: il radio
      // "Sezione personalizzata" finisce sotto la piega del dialog.
      await tester
          .ensureVisible(find.byKey(const Key('add_section_custom_radio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_section_custom_radio')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('add_section_custom_title')),
        'Pubblicazioni',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_section_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('index_entry_0')), findsOneWidget);
      expect(find.text('Pubblicazioni'), findsWidgets);

      await tester.pump(_oltreIlDebounce);
    });
  });

  group('EditorScreen — auto-save', () {
    testWidgets('digitare marca Modificato, poi Salvato dopo il debounce',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, [_anagraficaPiena]);

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);
      expect(find.byKey(const Key('save_indicator_saved')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('anagrafica_nome_0')),
        'Luigi',
      );
      await tester.pump();
      expect(find.byKey(const Key('save_indicator_dirty')), findsOneWidget);

      await tester.pump(_oltreIlDebounce);
      await tester.pump();

      expect(find.byKey(const Key('save_indicator_saved')), findsOneWidget);
      final salvato = await repo.watch(id).first;
      final anagrafica = salvato.sections.single as AnagraficaSection;
      expect(anagrafica.data.nome, 'Luigi');
    });

    testWidgets('aggiungere una voce vuota non rompe il salvataggio',
        (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(
        repo,
        [EsperienzeSection(displayTitle: 'Esperienze')],
      );

      await tester.pumpWidget(_makeApp(repository: repo, variantId: id));
      await _settle(tester);

      // Una voce appena creata ha ruolo e azienda vuoti: è la situazione
      // che faceva fallire l'auto-save prima dello split della validazione.
      await tester.tap(find.byKey(const Key('esperienze_add_0')));
      await tester.pump();
      expect(find.byKey(const Key('section_missing_badge_0')), findsOneWidget);

      await tester.pump(_oltreIlDebounce);
      await tester.pump();

      expect(find.byKey(const Key('save_indicator_error')), findsNothing);
      expect(find.byKey(const Key('save_indicator_saved')), findsOneWidget);

      final salvato = await repo.watch(id).first;
      final esperienze = salvato.sections.single as EsperienzeSection;
      expect(esperienze.items, hasLength(1));
      expect(esperienze.items.single.ruolo, isEmpty);
    });
  });

  group('EditorScreen — navigazione', () {
    testWidgets('il back invoca onBack', (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seed(repo, const []);
      var tornatoIndietro = false;

      await tester.pumpWidget(_makeApp(
        repository: repo,
        variantId: id,
        onBack: () => tornatoIndietro = true,
      ));
      await _settle(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(tornatoIndietro, isTrue);
    });
  });
}
