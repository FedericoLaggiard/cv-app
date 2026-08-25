/// LibraryCubit — state management for the Library screen.
///
/// Watches [CvRepository.watchAll] and exposes mutation commands (create,
/// delete, rename, duplicate) that keep the state in sync.  Navigation
/// decisions (routing to the Editor on create/duplicate) are left to the UI
/// layer — every mutation returns the affected variant id so the caller can
/// decide whether to navigate.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repository/cv_repository.dart';

// ─────────────────────────── States ────────────────────────────────────────

sealed class LibraryState {
  const LibraryState();
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  final List<VariantSummary> variants;
  const LibraryLoaded(this.variants);

  @override
  bool operator ==(Object other) =>
      other is LibraryLoaded && _listEq(other.variants, variants);

  @override
  int get hashCode => Object.hashAll(variants.map((v) => v.id));
}

class LibraryError extends LibraryState {
  final String message;
  const LibraryError(this.message);
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ─────────────────────────── Exception ─────────────────────────────────────

/// Thrown by [LibraryCubit] when a user-supplied value fails validation
/// (e.g. blank or duplicate variant name).
class LibraryValidationException implements Exception {
  final String message;
  const LibraryValidationException(this.message);
  @override
  String toString() => 'LibraryValidationException: $message';
}

// ─────────────────────────── Cubit ─────────────────────────────────────────

class LibraryCubit extends Cubit<LibraryState> {
  final CvRepository _repo;
  StreamSubscription<List<VariantSummary>>? _sub;

  LibraryCubit({required CvRepository repository})
      : _repo = repository,
        super(const LibraryInitial());

  // ── public API ────────────────────────────────────────────────────────────

  /// Start watching the repository.  Emits [LibraryLoading] then [LibraryLoaded]
  /// (and every subsequent update from the repo stream).
  Future<void> load() async {
    emit(const LibraryLoading());
    await _sub?.cancel();

    final ready = Completer<void>();
    _sub = _repo.watchAll().listen(
      (variants) {
        emit(LibraryLoaded(variants));
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object e) {
        emit(LibraryError(e.toString()));
        if (!ready.isCompleted) ready.complete();
      },
      cancelOnError: false,
    );
    return ready.future;
  }

  /// Creates a new (empty) variant, optionally with [variantName].
  /// Returns the new variant's id.  The repository stream will push a fresh
  /// [LibraryLoaded] automatically.
  Future<String?> createNew({String? variantName}) async {
    final doc = await _repo.create(initialVariantName: variantName);
    return doc.id;
  }

  /// Hard-deletes a variant by [id].
  Future<void> deleteVariant(String id) => _repo.delete(id);

  /// Renames a variant.  Throws [LibraryValidationException] if [newName] is
  /// blank or already taken by another variant (case-insensitive, trimmed).
  Future<void> renameVariant(String id, String newName) async {
    _guardName(newName, excludeId: id);
    final doc = await _repo.watch(id).first;
    await _repo.save(doc.copyWith(variantName: newName.trim()));
  }

  /// Duplicates a variant.  If [newName] is given it is validated and used as
  /// the copy's name; otherwise the repository chooses the default incremental
  /// name (`<orig> (2)`, `(3)`, …).  Returns the new variant's id.
  Future<String?> duplicateVariant(String id, {String? newName}) async {
    if (newName != null) {
      _guardName(newName);
      // Duplicate via repo (gets a new UUID + timestamps), then rename.
      final copy = await _repo.duplicate(id);
      await _repo.save(copy.copyWith(variantName: newName.trim()));
      return copy.id;
    }
    final copy = await _repo.duplicate(id);
    return copy.id;
  }

  /// Returns `true` if [name] (trimmed, case-insensitive) is not already used
  /// by another variant in the current loaded state.
  ///
  /// [excludeId] is the id of the variant being renamed (its current name is
  /// not treated as a conflict).
  bool isNameAvailable(String name, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    final current = state;
    if (current is! LibraryLoaded) return true;
    return !current.variants.any(
      (v) =>
          v.variantName.trim().toLowerCase() == normalized &&
          v.id != excludeId,
    );
  }

  // ── private helpers ───────────────────────────────────────────────────────

  void _guardName(String name, {String? excludeId}) {
    if (name.trim().isEmpty) {
      throw const LibraryValidationException('Il nome non può essere vuoto');
    }
    if (!isNameAvailable(name, excludeId: excludeId)) {
      throw LibraryValidationException(
        'Esiste già una variante con il nome "${name.trim()}"',
      );
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
