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

  /// Creates a new (empty) variant with the given [name].
  /// Throws [LibraryValidationException] if the name is blank or already
  /// taken (case-insensitive, trimmed).  Returns the new variant's id.
  Future<String?> createNewNamed(String name) async {
    _guardName(name);
    final doc = await _repo.create(initialVariantName: name.trim());
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

  /// Duplicates a variant with an explicit user-supplied [newName].
  /// Throws [LibraryValidationException] on validation failure.
  /// Returns the new variant's id.
  Future<String?> duplicateVariantAs(String id, String newName) async {
    _guardName(newName);
    final copy = await _repo.duplicate(id);
    await _repo.save(copy.copyWith(variantName: newName.trim()));
    return copy.id;
  }

  /// Returns the error message for [name] against the currently loaded
  /// library, or `null` if the name is valid.  [excludeId] skips the
  /// variant being renamed.
  ///
  /// Single source of truth for the "univocità hard, case-insensitive con
  /// trim" rule (ticket 14) — reused by dialogs and by [_guardName].
  String? validateName(String name, {String? excludeId}) {
    if (name.trim().isEmpty) {
      return 'Il nome non può essere vuoto';
    }
    if (!_isNameAvailable(name, excludeId: excludeId)) {
      return 'Esiste già una variante con questo nome';
    }
    return null;
  }

  /// Returns the next free `<base> (N)` suggestion for a duplicate of
  /// [baseName], starting at (2).  Matches the pattern spec'd in ticket 14.
  String suggestDuplicateName(String baseName) {
    final base = baseName.trim();
    for (var n = 2; n < 10000; n++) {
      final candidate = '$base ($n)';
      if (_isNameAvailable(candidate)) return candidate;
    }
    return '$base (copia)';
  }

  /// Returns the next free "Nuova variante N" suggestion (N ≥ 1).
  String suggestNewVariantName() {
    for (var n = 1; n < 10000; n++) {
      final candidate = 'Nuova variante $n';
      if (_isNameAvailable(candidate)) return candidate;
    }
    return 'Nuova variante';
  }

  // ── private helpers ───────────────────────────────────────────────────────

  bool _isNameAvailable(String name, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    final current = state;
    if (current is! LibraryLoaded) return true;
    return !current.variants.any(
      (v) =>
          v.variantName.trim().toLowerCase() == normalized &&
          v.id != excludeId,
    );
  }

  void _guardName(String name, {String? excludeId}) {
    final err = validateName(name, excludeId: excludeId);
    if (err != null) throw LibraryValidationException(err);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
