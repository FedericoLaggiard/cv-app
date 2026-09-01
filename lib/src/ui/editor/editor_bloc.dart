/// EditorBloc — stato per una singola variante aperta nell'editor.
///
/// Regole (dal ticket 07 e Slice B):
///  - `CvRepository.watch(id)` per la lettura iniziale;
///  - `CvRepository.save(doc)` per la scrittura;
///  - debounce ~800 ms sull'auto-save: ogni mutazione riavvia un timer,
///    quando scade parte una `save`;
///  - stato di collapse per sezione è tenuto qui in memoria, non serializzato
///    nel `.cvapp` (ticket 07);
///  - eventi granulari per navigazione UI (add/remove/reorder sezioni, add
///    sezione custom, cambio nome variante) e un evento generico
///    [SectionAtIndexReplaced] per mutazioni di campo, così le widget di
///    sezione compongono la nuova sezione con `copyWith` e la restituiscono
///    al Bloc senza esplodere l'API.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/cv_document.dart';
import '../../domain/cv_section.dart';
import '../../domain/enums.dart';
import '../../domain/missing_required.dart';
import '../../repository/cv_repository.dart';

// ─────────────────────────── Save status ───────────────────────────────────

enum SaveStatusKind { idle, saving, error }

class SaveStatus {
  final SaveStatusKind kind;
  final String? errorMessage;
  const SaveStatus._(this.kind, this.errorMessage);

  static const idle = SaveStatus._(SaveStatusKind.idle, null);
  static const saving = SaveStatus._(SaveStatusKind.saving, null);
  factory SaveStatus.error(String message) =>
      SaveStatus._(SaveStatusKind.error, message);

  bool get isSaving => kind == SaveStatusKind.saving;
  bool get isError => kind == SaveStatusKind.error;
  bool get isIdle => kind == SaveStatusKind.idle;

  @override
  bool operator ==(Object other) =>
      other is SaveStatus &&
      other.kind == kind &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(kind, errorMessage);
}

// ─────────────────────────── State ─────────────────────────────────────────

sealed class EditorState {
  const EditorState();
}

class EditorInitial extends EditorState {
  const EditorInitial();
}

class EditorLoading extends EditorState {
  const EditorLoading();
}

class EditorLoadError extends EditorState {
  final String message;
  const EditorLoadError(this.message);
}

/// La variante aperta è stata eliminata altrove (ticket 23, user story 11 —
/// caso raro multi-finestra su desktop). La UI reagisce tornando alla
/// Libreria.
class EditorDeleted extends EditorState {
  const EditorDeleted();
}

class EditorReady extends EditorState {
  final CvDocument document;
  final SaveStatus saveStatus;

  /// True quando ci sono modifiche non ancora persistite (timer di
  /// debounce armato o `save()` in volo).
  final bool dirty;

  /// Set degli indici di sezione al momento collassati.
  final Set<int> collapsed;

  final MissingRequired missing;

  const EditorReady({
    required this.document,
    required this.saveStatus,
    required this.dirty,
    required this.collapsed,
    required this.missing,
  });

  EditorReady copyWith({
    CvDocument? document,
    SaveStatus? saveStatus,
    bool? dirty,
    Set<int>? collapsed,
    MissingRequired? missing,
  }) =>
      EditorReady(
        document: document ?? this.document,
        saveStatus: saveStatus ?? this.saveStatus,
        dirty: dirty ?? this.dirty,
        collapsed: collapsed ?? this.collapsed,
        missing: missing ?? this.missing,
      );

  bool isCollapsed(int index) => collapsed.contains(index);

  @override
  bool operator ==(Object other) =>
      other is EditorReady &&
      other.document == document &&
      other.saveStatus == saveStatus &&
      other.dirty == dirty &&
      _setEq(other.collapsed, collapsed);
  @override
  int get hashCode => Object.hash(
        document,
        saveStatus,
        dirty,
        Object.hashAllUnordered(collapsed),
      );
}

bool _setEq(Set<int> a, Set<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}

// ─────────────────────────── Events ────────────────────────────────────────

sealed class EditorEvent {
  const EditorEvent();
}

class EditorStarted extends EditorEvent {
  final String variantId;
  const EditorStarted(this.variantId);
}

class _DocumentReceived extends EditorEvent {
  final CvDocument doc;
  const _DocumentReceived(this.doc);
}

class _DocumentStreamErrored extends EditorEvent {
  final Object error;
  const _DocumentStreamErrored(this.error);
}

/// Il repo ha chiuso lo stream di `watch(id)`: la variante è stata
/// eliminata (da qui o da un'altra finestra/tab).
class _DocumentDeleted extends EditorEvent {
  const _DocumentDeleted();
}

class VariantNameChanged extends EditorEvent {
  final String name;
  const VariantNameChanged(this.name);
}

/// Sostituisce la sezione all'indice [index] con [newSection]. Usato dai
/// form di sezione per propagare qualunque mutazione di campo.
class SectionAtIndexReplaced extends EditorEvent {
  final int index;
  final CvSection newSection;
  const SectionAtIndexReplaced(this.index, this.newSection);
}

/// Aggiunge una sezione fissa `kind` con `displayTitle` di default,
/// oppure una sezione custom con `displayTitle` fornito.
class SectionAdded extends EditorEvent {
  final SectionKind kind;
  final String? customDisplayTitle;
  const SectionAdded.fixed(this.kind) : customDisplayTitle = null;
  const SectionAdded.custom(String title)
      : kind = SectionKind.custom,
        customDisplayTitle = title;
}

class SectionRemoved extends EditorEvent {
  final int index;
  const SectionRemoved(this.index);
}

class SectionReordered extends EditorEvent {
  final int oldIndex;
  final int newIndex;
  const SectionReordered(this.oldIndex, this.newIndex);
}

class SectionCollapseToggled extends EditorEvent {
  final int index;
  const SectionCollapseToggled(this.index);
}

class AllSectionsCollapseSet extends EditorEvent {
  final bool collapse;
  const AllSectionsCollapseSet(this.collapse);
}

/// Espande la sezione target (usato dal jump-to dell'indice).
class SectionExpanded extends EditorEvent {
  final int index;
  const SectionExpanded(this.index);
}

class SaveRetryRequested extends EditorEvent {
  const SaveRetryRequested();
}

class _AutoSaveFired extends EditorEvent {
  const _AutoSaveFired();
}

// ─────────────────────────── Bloc ──────────────────────────────────────────

/// Ritardo del debounce di auto-save (ticket 04).
const Duration kAutoSaveDebounce = Duration(milliseconds: 800);

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final CvRepository _repo;
  final Uuid _uuid;
  final Duration _debounce;

  StreamSubscription<CvDocument>? _sub;
  Timer? _saveTimer;

  /// Ignora il prossimo snapshot dal repo dopo una save nostra: la save
  /// ci ha già mostrato il documento corretto in stato pulito, e il
  /// bump del repo lo restituirebbe con la sola differenza di
  /// `updatedAt` sovrascrivendo cambi utente arrivati nel frattempo.
  bool _pendingEchoSuppression = false;

  EditorBloc({
    required CvRepository repository,
    Uuid? uuid,
    this._debounce = kAutoSaveDebounce,
  })  : _repo = repository,
        _uuid = uuid ?? const Uuid(),
        super(const EditorInitial()) {
    on<EditorStarted>(_onStarted);
    on<_DocumentReceived>(_onDocumentReceived);
    on<_DocumentStreamErrored>(_onStreamErrored);
    on<_DocumentDeleted>(_onDocumentDeleted);
    on<VariantNameChanged>(_onVariantNameChanged);
    on<SectionAtIndexReplaced>(_onSectionReplaced);
    on<SectionAdded>(_onSectionAdded);
    on<SectionRemoved>(_onSectionRemoved);
    on<SectionReordered>(_onSectionReordered);
    on<SectionCollapseToggled>(_onCollapseToggled);
    on<AllSectionsCollapseSet>(_onAllCollapseSet);
    on<SectionExpanded>(_onSectionExpanded);
    on<SaveRetryRequested>(_onSaveRetry);
    on<_AutoSaveFired>(_onAutoSaveFired);
  }

  Future<void> _onStarted(EditorStarted e, Emitter<EditorState> emit) async {
    emit(const EditorLoading());
    await _sub?.cancel();
    _sub = _repo.watch(e.variantId).listen(
          (doc) => add(_DocumentReceived(doc)),
          onError: (Object err) => add(_DocumentStreamErrored(err)),
          onDone: () => add(const _DocumentDeleted()),
        );
  }

  void _onDocumentDeleted(_DocumentDeleted e, Emitter<EditorState> emit) {
    // Lo stream si chiude anche quando `watch()` non trova subito l'id:
    // in quel caso `_onStreamErrored` ha già portato lo stato a
    // `EditorLoadError` prima che questo evento venga processato, quindi
    // il branch sotto non scatta. Se invece siamo ancora `EditorLoading`
    // (nessun errore ricevuto) o `EditorReady`, il documento esisteva ed
    // è stato eliminato altrove — comprende sia il caso "era aperto ed è
    // sparito" sia la corsa rara in cui la delete arriva prima del primo
    // snapshot.
    if (state is EditorReady || state is EditorLoading) {
      emit(const EditorDeleted());
    }
  }

  void _onDocumentReceived(_DocumentReceived e, Emitter<EditorState> emit) {
    if (_pendingEchoSuppression) {
      _pendingEchoSuppression = false;
      final s = state;
      if (s is EditorReady) {
        // Aggiorniamo solo lo `updatedAt` (nostro documento locale
        // usa già i valori utente); così se l'utente ha continuato
        // a digitare non gli soffiamo via i cambi.
        emit(s.copyWith(
          document: s.document.copyWith(updatedAt: e.doc.updatedAt),
        ));
        return;
      }
    }
    final missing = analyzeMissingRequired(e.doc);
    final s = state;
    if (s is EditorReady) {
      emit(s.copyWith(document: e.doc, missing: missing));
    } else {
      emit(EditorReady(
        document: e.doc,
        saveStatus: SaveStatus.idle,
        dirty: false,
        collapsed: const <int>{},
        missing: missing,
      ));
    }
  }

  void _onStreamErrored(_DocumentStreamErrored e, Emitter<EditorState> emit) {
    if (state is EditorReady) return; // già caricato → ignora
    emit(EditorLoadError(e.error.toString()));
  }

  // ── mutazioni ────────────────────────────────────────────────────────────

  void _mutate(
    Emitter<EditorState> emit,
    CvDocument Function(CvDocument) mutator, {
    Set<int>? Function(Set<int> current)? collapsedMutator,
  }) {
    final s = state;
    if (s is! EditorReady) return;
    final newDoc = mutator(s.document);
    final newCollapsed =
        collapsedMutator?.call(s.collapsed) ?? s.collapsed;
    emit(s.copyWith(
      document: newDoc,
      dirty: true,
      collapsed: newCollapsed,
      missing: analyzeMissingRequired(newDoc),
    ));
    _scheduleAutoSave();
  }

  void _onVariantNameChanged(
      VariantNameChanged e, Emitter<EditorState> emit) {
    _mutate(emit, (d) => d.copyWith(variantName: e.name));
  }

  void _onSectionReplaced(
      SectionAtIndexReplaced e, Emitter<EditorState> emit) {
    _mutate(emit, (d) {
      if (e.index < 0 || e.index >= d.sections.length) return d;
      final next = [...d.sections];
      next[e.index] = e.newSection;
      return d.copyWith(sections: next);
    });
  }

  void _onSectionAdded(SectionAdded e, Emitter<EditorState> emit) {
    _mutate(emit, (d) {
      final CvSection section;
      if (e.kind == SectionKind.custom) {
        section = CustomSection(
          id: _uuid.v4(),
          displayTitle: e.customDisplayTitle!.trim(),
          markdown: '',
        );
      } else {
        section = _defaultSectionFor(e.kind);
      }
      return d.copyWith(sections: [...d.sections, section]);
    });
  }

  void _onSectionRemoved(SectionRemoved e, Emitter<EditorState> emit) {
    _mutate(emit, (d) {
      if (e.index < 0 || e.index >= d.sections.length) return d;
      final next = [...d.sections]..removeAt(e.index);
      return d.copyWith(sections: next);
    }, collapsedMutator: (c) {
      // Rimappa gli indici collapsed: chi era > index scende di 1,
      // l'indice rimosso viene tolto.
      final out = <int>{};
      for (final i in c) {
        if (i == e.index) continue;
        out.add(i > e.index ? i - 1 : i);
      }
      return out;
    });
  }

  void _onSectionReordered(
      SectionReordered e, Emitter<EditorState> emit) {
    _mutate(emit, (d) {
      var newIndex = e.newIndex;
      final list = [...d.sections];
      if (e.oldIndex < 0 || e.oldIndex >= list.length) return d;
      // Compensa il pattern ReorderableListView (post-remove index).
      if (newIndex > e.oldIndex) newIndex -= 1;
      if (newIndex < 0 || newIndex > list.length - 1) {
        newIndex = list.length - 1;
      }
      final item = list.removeAt(e.oldIndex);
      list.insert(newIndex, item);
      return d.copyWith(sections: list);
    }, collapsedMutator: (c) => _remapCollapsedForReorder(c, e.oldIndex, e.newIndex));
  }

  Set<int> _remapCollapsedForReorder(
      Set<int> collapsed, int oldIndex, int rawNewIndex) {
    var newIndex = rawNewIndex;
    if (newIndex > oldIndex) newIndex -= 1;
    final out = <int>{};
    for (final i in collapsed) {
      if (i == oldIndex) {
        out.add(newIndex);
      } else {
        var v = i;
        if (v > oldIndex) v -= 1;
        if (v >= newIndex) v += 1;
        out.add(v);
      }
    }
    return out;
  }

  void _onCollapseToggled(
      SectionCollapseToggled e, Emitter<EditorState> emit) {
    final s = state;
    if (s is! EditorReady) return;
    final next = {...s.collapsed};
    if (!next.remove(e.index)) next.add(e.index);
    emit(s.copyWith(collapsed: next));
  }

  void _onAllCollapseSet(
      AllSectionsCollapseSet e, Emitter<EditorState> emit) {
    final s = state;
    if (s is! EditorReady) return;
    if (e.collapse) {
      emit(s.copyWith(
          collapsed: {for (var i = 0; i < s.document.sections.length; i++) i}));
    } else {
      emit(s.copyWith(collapsed: const <int>{}));
    }
  }

  void _onSectionExpanded(
      SectionExpanded e, Emitter<EditorState> emit) {
    final s = state;
    if (s is! EditorReady) return;
    if (!s.collapsed.contains(e.index)) return;
    final next = {...s.collapsed}..remove(e.index);
    emit(s.copyWith(collapsed: next));
  }

  // ── save ─────────────────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, () => add(const _AutoSaveFired()));
  }

  Future<void> _onAutoSaveFired(
      _AutoSaveFired e, Emitter<EditorState> emit) async {
    final s = state;
    if (s is! EditorReady) return;
    emit(s.copyWith(saveStatus: SaveStatus.saving));
    final saving = s.document;
    try {
      _pendingEchoSuppression = true;
      await _repo.save(saving);
      final cur = state;
      if (cur is EditorReady) {
        // Se l'utente ha modificato durante la save, `dirty` resta true
        // e il timer già armato farà partire un nuovo save.
        final stillDirty = cur.document != saving;
        emit(cur.copyWith(
          saveStatus: SaveStatus.idle,
          dirty: stillDirty,
        ));
      }
    } on CvRepositoryNotFound {
      // La variante è stata cancellata altrove mentre questa save era in
      // volo (race save/delete, indipendente dal ticket 23): niente da
      // segnalare come errore recuperabile, il documento non esiste più.
      _pendingEchoSuppression = false;
      if (state is EditorReady) emit(const EditorDeleted());
    } catch (err) {
      _pendingEchoSuppression = false;
      final cur = state;
      if (cur is EditorReady) {
        emit(cur.copyWith(saveStatus: SaveStatus.error(err.toString())));
      }
    }
  }

  Future<void> _onSaveRetry(
      SaveRetryRequested e, Emitter<EditorState> emit) async {
    _saveTimer?.cancel();
    await _onAutoSaveFired(const _AutoSaveFired(), emit);
  }

  @override
  Future<void> close() async {
    _saveTimer?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}

/// Costruisce una sezione fissa vuota per `kind` con `displayTitle` di
/// default (nome canonico italiano). Le sezioni-lista partono vuote; le
/// sezioni con dati (`Anagrafica`, `Contatti`, `Skill`, `Sommario`) con
/// campi vuoti.
CvSection _defaultSectionFor(SectionKind kind) {
  switch (kind) {
    case SectionKind.anagrafica:
      return const AnagraficaSection(
        displayTitle: 'Anagrafica',
        data: AnagraficaData(nome: '', cognome: ''),
      );
    case SectionKind.contatti:
      return ContattiSection(
        displayTitle: 'Contatti',
        data: ContattiData(),
      );
    case SectionKind.sommario:
      return const SommarioSection(
        displayTitle: 'Sommario',
        markdown: '',
      );
    case SectionKind.esperienze:
      return EsperienzeSection(displayTitle: 'Esperienze');
    case SectionKind.formazione:
      return FormazioneSection(displayTitle: 'Formazione');
    case SectionKind.skill:
      return SkillSection(
        displayTitle: 'Skill',
        data: SkillData(),
      );
    case SectionKind.lingue:
      return LingueSection(displayTitle: 'Lingue');
    case SectionKind.certificazioni:
      return CertificazioniSection(displayTitle: 'Certificazioni');
    case SectionKind.custom:
      throw ArgumentError('use SectionAdded.custom for custom sections');
  }
}
