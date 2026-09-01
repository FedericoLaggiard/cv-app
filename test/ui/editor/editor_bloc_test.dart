import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/repository/cv_repository.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/editor/editor_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Costruisce una variante di test caricata nel repo e ritorna il suo id.
Future<String> _seedVariant(InMemoryCvRepository repo, {String name = 'Test'}) async {
  final doc = await repo.create(initialVariantName: name);
  return doc.id;
}

/// Debounce cortissimo per rendere i test rapidi ma con timing verificabile.
const _testDebounce = Duration(milliseconds: 40);

/// Attesa "molliccia" per lasciar processare gli eventi async del Bloc dopo
/// il timer di auto-save.
Future<void> _pumpEventLoop([int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('EditorBloc — loading', () {
    test('EditorStarted → EditorReady con il documento del repo', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo, name: 'Alpha');
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);

      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      final s = bloc.state;
      expect(s, isA<EditorReady>());
      final r = s as EditorReady;
      expect(r.document.variantName, 'Alpha');
      expect(r.dirty, isFalse);
      expect(r.saveStatus.isIdle, isTrue);
      expect(r.collapsed, isEmpty);

      await bloc.close();
    });

    test('EditorStarted su id sconosciuto → EditorLoadError', () async {
      final repo = InMemoryCvRepository();
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);

      bloc.add(const EditorStarted('missing-id'));
      await _pumpEventLoop();

      expect(bloc.state, isA<EditorLoadError>());
      await bloc.close();
    });
  });

  group('EditorBloc — eliminazione della variante aperta (ticket 23)', () {
    test('delete della variante aperta altrove → EditorDeleted', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo, name: 'Alpha');
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);

      bloc.add(EditorStarted(id));
      await _pumpEventLoop();
      expect(bloc.state, isA<EditorReady>());

      await repo.delete(id);
      await _pumpEventLoop();

      expect(bloc.state, isA<EditorDeleted>());
      await bloc.close();
    });
  });

  group('EditorBloc — mutazioni e auto-save', () {
    test('VariantNameChanged → dirty=true, save dopo debounce, dirty=false',
        () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo, name: 'Iniziale');
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      bloc.add(const VariantNameChanged('Nuovo nome'));
      await _pumpEventLoop();

      var s = bloc.state as EditorReady;
      expect(s.dirty, isTrue);
      expect(s.document.variantName, 'Nuovo nome');
      expect(s.saveStatus.isIdle, isTrue);

      // aspetta oltre il debounce → auto save
      await Future<void>.delayed(_testDebounce * 3);
      await _pumpEventLoop();

      s = bloc.state as EditorReady;
      expect(s.dirty, isFalse, reason: 'dopo save non deve essere dirty');
      expect(s.saveStatus.isIdle, isTrue);

      // il repo deve avere il nuovo nome
      final saved = await repo.watch(id).first;
      expect(saved.variantName, 'Nuovo nome');

      await bloc.close();
    });

    test('mutazioni rapide → una sola save con l\'ultimo valore', () async {
      final repo = _CountingRepo(InMemoryCvRepository());
      final id = await _seedVariant(repo._inner, name: 'X');
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      // 3 mutazioni entro il debounce
      bloc.add(const VariantNameChanged('uno'));
      await Future<void>.delayed(_testDebounce ~/ 4);
      bloc.add(const VariantNameChanged('due'));
      await Future<void>.delayed(_testDebounce ~/ 4);
      bloc.add(const VariantNameChanged('tre'));

      // aspetta oltre l'ultimo debounce
      await Future<void>.delayed(_testDebounce * 3);
      await _pumpEventLoop();

      expect(repo.saveCount, 1);
      final s = bloc.state as EditorReady;
      expect(s.document.variantName, 'tre');
      expect(s.dirty, isFalse);

      await bloc.close();
    });

    test('SectionAdded.fixed aggiunge sezione fissa in coda', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      final before = (bloc.state as EditorReady).document.sections.length;
      bloc.add(const SectionAdded.fixed(SectionKind.lingue));
      await _pumpEventLoop();

      final s = bloc.state as EditorReady;
      expect(s.document.sections.length, before + 1);
      expect(s.document.sections.last, isA<LingueSection>());
      expect(s.dirty, isTrue);

      await bloc.close();
    });

    test('SectionAdded.custom aggiunge sezione custom con titolo', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      bloc.add(const SectionAdded.custom('Volontariato'));
      await _pumpEventLoop();

      final s = bloc.state as EditorReady;
      final last = s.document.sections.last;
      expect(last, isA<CustomSection>());
      expect((last as CustomSection).displayTitle, 'Volontariato');

      await bloc.close();
    });

    test('SectionRemoved rimappa gli indici collapsed', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      // Aggiungi qualche sezione così ci sono indici da rimappare. Servono
      // almeno 3 sezioni: con solo 2, l'indice "0" e l'indice "ultimo dopo
      // la rimozione" coincidono e le due expect sotto si contraddicono.
      bloc.add(const SectionAdded.fixed(SectionKind.lingue));
      bloc.add(const SectionAdded.fixed(SectionKind.certificazioni));
      bloc.add(const SectionAdded.fixed(SectionKind.skill));
      await _pumpEventLoop();

      final total = (bloc.state as EditorReady).document.sections.length;
      // Collassa sezione 0 e ultima
      bloc.add(const SectionCollapseToggled(0));
      bloc.add(SectionCollapseToggled(total - 1));
      await _pumpEventLoop();

      final beforeCollapsed = (bloc.state as EditorReady).collapsed;
      expect(beforeCollapsed, containsAll(<int>{0, total - 1}));

      // Rimuove la prima → l'indice `total-1` deve diventare `total-2`.
      bloc.add(const SectionRemoved(0));
      await _pumpEventLoop();

      final afterCollapsed = (bloc.state as EditorReady).collapsed;
      expect(afterCollapsed.contains(0), isFalse);
      expect(afterCollapsed.contains(total - 2), isTrue);

      await bloc.close();
    });

    test('SectionReordered sposta e rimappa collapsed', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      // Servono almeno 2 sezioni: con una sola, spostarla "in fondo" è un
      // no-op e l'indice "0" coincide con "n-1", contraddicendo le expect
      // sotto.
      bloc.add(const SectionAdded.fixed(SectionKind.lingue));
      bloc.add(const SectionAdded.fixed(SectionKind.certificazioni));
      await _pumpEventLoop();

      final beforeSections =
          [...(bloc.state as EditorReady).document.sections];
      final first = beforeSections.first;
      final n = beforeSections.length;

      bloc.add(const SectionCollapseToggled(0));
      await _pumpEventLoop();

      // Sposta la prima in fondo (ReorderableListView passa newIndex = length).
      bloc.add(SectionReordered(0, n));
      await _pumpEventLoop();

      final s = bloc.state as EditorReady;
      expect(s.document.sections.last, first);
      // Il collapse della sezione originariamente 0 deve seguirla → indice n-1.
      expect(s.collapsed.contains(n - 1), isTrue);
      expect(s.collapsed.contains(0), isFalse);

      await bloc.close();
    });

    test('SectionCollapseToggled toggla senza marcare dirty', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      bloc.add(const SectionCollapseToggled(0));
      await _pumpEventLoop();
      var s = bloc.state as EditorReady;
      expect(s.collapsed.contains(0), isTrue);
      expect(s.dirty, isFalse);

      bloc.add(const SectionCollapseToggled(0));
      await _pumpEventLoop();
      s = bloc.state as EditorReady;
      expect(s.collapsed.contains(0), isFalse);

      await bloc.close();
    });

    test('AllSectionsCollapseSet(true/false) opera su tutte le sezioni',
        () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      final n = (bloc.state as EditorReady).document.sections.length;
      bloc.add(const AllSectionsCollapseSet(true));
      await _pumpEventLoop();
      expect((bloc.state as EditorReady).collapsed.length, n);

      bloc.add(const AllSectionsCollapseSet(false));
      await _pumpEventLoop();
      expect((bloc.state as EditorReady).collapsed, isEmpty);

      await bloc.close();
    });

    test('SectionExpanded rimuove solo l\'indice richiesto', () async {
      final repo = InMemoryCvRepository();
      final id = await _seedVariant(repo);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      // Un documento appena creato non ha sezioni: ne serve almeno una da
      // collassare, altrimenti "rimuove solo l'indice richiesto" non ha
      // niente da rimuovere.
      bloc.add(const SectionAdded.fixed(SectionKind.lingue));
      bloc.add(const SectionAdded.fixed(SectionKind.certificazioni));
      await _pumpEventLoop();

      bloc.add(const AllSectionsCollapseSet(true));
      await _pumpEventLoop();
      final beforeN = (bloc.state as EditorReady).collapsed.length;

      bloc.add(const SectionExpanded(0));
      await _pumpEventLoop();

      final s = bloc.state as EditorReady;
      expect(s.collapsed.length, beforeN - 1);
      expect(s.collapsed.contains(0), isFalse);

      await bloc.close();
    });
  });

  group('EditorBloc — errori di save', () {
    test('save fallita → SaveStatus.error; retry re-tenta la save', () async {
      final inner = InMemoryCvRepository();
      final id = await _seedVariant(inner);
      final repo = _FailingSaveRepo(inner);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();

      repo.failNext = true;
      bloc.add(const VariantNameChanged('Boom'));
      await Future<void>.delayed(_testDebounce * 3);
      await _pumpEventLoop();

      var s = bloc.state as EditorReady;
      expect(s.saveStatus.isError, isTrue);
      expect(s.dirty, isTrue, reason: 'errore lascia dirty per riprovare');

      // Retry con successo
      repo.failNext = false;
      bloc.add(const SaveRetryRequested());
      await _pumpEventLoop();

      s = bloc.state as EditorReady;
      expect(s.saveStatus.isIdle, isTrue);
      expect(s.dirty, isFalse);

      await bloc.close();
    });

    test('save() throws CvRepositoryNotFound (delete-race) → EditorDeleted, '
        'non SaveStatus.error', () async {
      final inner = InMemoryCvRepository();
      final id = await _seedVariant(inner);
      final repo = _NotFoundOnSaveRepo(inner);
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);
      bloc.add(EditorStarted(id));
      await _pumpEventLoop();
      expect(bloc.state, isA<EditorReady>());

      repo.throwNotFoundNext = true;
      bloc.add(const VariantNameChanged('Race'));
      await Future<void>.delayed(_testDebounce * 3);
      await _pumpEventLoop();

      expect(bloc.state, isA<EditorDeleted>());
      await bloc.close();
    });

    test(
        'delete tra EditorStarted e il primo snapshot → EditorDeleted, non '
        'blocca su EditorLoading', () async {
      final repo = _DeletedBeforeFirstEmitRepo();
      final bloc = EditorBloc(repository: repo, debounce: _testDebounce);

      bloc.add(const EditorStarted('raced-id'));
      await _pumpEventLoop();

      expect(bloc.state, isA<EditorDeleted>());
      await bloc.close();
    });
  });
}

// ─────────────────── Test doubles ──────────────────────────────────────────

/// Wrapper che conta le save reindirizzate a un InMemoryCvRepository interno.
class _CountingRepo implements CvRepository {
  final InMemoryCvRepository _inner;
  int saveCount = 0;
  _CountingRepo(this._inner);

  @override
  Future<void> save(doc) async {
    saveCount++;
    await _inner.save(doc);
  }

  @override
  Stream<List<VariantSummary>> watchAll() => _inner.watchAll();
  @override
  Stream<CvDocument> watch(String id) => _inner.watch(id);
  @override
  Future<CvDocument> create({String? initialVariantName}) =>
      _inner.create(initialVariantName: initialVariantName);
  @override
  Future<CvDocument> duplicate(String id) => _inner.duplicate(id);
  @override
  Future<void> delete(String id) => _inner.delete(id);
  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) =>
      _inner.importFromBytes(bytes);
  @override
  Future<Uint8List> exportToBytes(String id) => _inner.exportToBytes(id);
}

/// Repo che permette di far fallire la prossima save on-demand.
class _FailingSaveRepo implements CvRepository {
  final InMemoryCvRepository _inner;
  bool failNext = false;
  _FailingSaveRepo(this._inner);

  @override
  Future<void> save(doc) async {
    if (failNext) {
      failNext = false;
      throw StateError('save simulata fallita');
    }
    await _inner.save(doc);
  }

  @override
  Stream<List<VariantSummary>> watchAll() => _inner.watchAll();
  @override
  Stream<CvDocument> watch(String id) => _inner.watch(id);
  @override
  Future<CvDocument> create({String? initialVariantName}) =>
      _inner.create(initialVariantName: initialVariantName);
  @override
  Future<CvDocument> duplicate(String id) => _inner.duplicate(id);
  @override
  Future<void> delete(String id) => _inner.delete(id);
  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) =>
      _inner.importFromBytes(bytes);
  @override
  Future<Uint8List> exportToBytes(String id) => _inner.exportToBytes(id);
}

/// Repo che simula una save() che perde la race con un delete concorrente:
/// lo `watch()` sottostante resta aperto (il delete non è passato
/// dall'`_inner` repo), solo `save()` alza `CvRepositoryNotFound` on-demand.
class _NotFoundOnSaveRepo implements CvRepository {
  final InMemoryCvRepository _inner;
  bool throwNotFoundNext = false;
  _NotFoundOnSaveRepo(this._inner);

  @override
  Future<void> save(doc) async {
    if (throwNotFoundNext) {
      throwNotFoundNext = false;
      throw CvRepositoryNotFound(doc.id);
    }
    await _inner.save(doc);
  }

  @override
  Stream<List<VariantSummary>> watchAll() => _inner.watchAll();
  @override
  Stream<CvDocument> watch(String id) => _inner.watch(id);
  @override
  Future<CvDocument> create({String? initialVariantName}) =>
      _inner.create(initialVariantName: initialVariantName);
  @override
  Future<CvDocument> duplicate(String id) => _inner.duplicate(id);
  @override
  Future<void> delete(String id) => _inner.delete(id);
  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) =>
      _inner.importFromBytes(bytes);
  @override
  Future<Uint8List> exportToBytes(String id) => _inner.exportToBytes(id);
}

/// Repo il cui `watch()` chiude subito lo stream senza mai emettere un
/// documento né un errore — simula una `delete` che vince la race col primo
/// snapshot (variante esistente al momento di `EditorStarted`, sparita prima
/// che arrivi il primo documento).
class _DeletedBeforeFirstEmitRepo implements CvRepository {
  @override
  Stream<CvDocument> watch(String id) => const Stream.empty();

  @override
  Stream<List<VariantSummary>> watchAll() => const Stream.empty();
  @override
  Future<void> save(doc) async {}
  @override
  Future<CvDocument> create({String? initialVariantName}) =>
      throw UnimplementedError();
  @override
  Future<CvDocument> duplicate(String id) => throw UnimplementedError();
  @override
  Future<void> delete(String id) async {}
  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) =>
      throw UnimplementedError();
  @override
  Future<Uint8List> exportToBytes(String id) => throw UnimplementedError();
}

// Assicura che `Uuid` sia disponibile (importato più su) — usato indirettamente
// dai default sections e dagli id delle sezioni custom.
// ignore: unused_element
const _ = Uuid;
