/// Abstract filesystem seam used by [PathProviderCvRepository] (ticket 04)
/// and by E2E tests via DI (ticket 17, amendment 04/06).
///
/// Everything the repository needs to touch on disk goes through this
/// service so tests can inject an in-memory fake and E2E can inject a
/// controllable fake behind `--dart-define=E2E=true` without linking any
/// `dart:io`.
library;

import 'dart:typed_data';

/// Minimal filesystem contract, keyed by the `<uuid>` of the variant.
///
/// Files always live in the library directory `libraryDir` returned by
/// [ensureLibraryDir]. The service takes care of atomicity via tmp+rename;
/// callers just pass the bytes.
abstract class FileSystemService {
  /// Ensures the library directory exists and returns its absolute path.
  Future<String> ensureLibraryDir();

  /// Returns the ids (basenames without extension) of every `<uuid>.cvapp`
  /// currently in the library. Ignores stale `.cvapp.tmp` files.
  Future<List<String>> listVariantIds();

  /// Reads the bytes of `<id>.cvapp`. Throws [FileSystemMissingException]
  /// if the file does not exist.
  Future<Uint8List> read(String id);

  /// Atomically writes [bytes] to `<id>.cvapp` via a `.tmp` sibling +
  /// rename. If a crash happens between the write and the rename the
  /// original file (if any) survives untouched.
  Future<void> write(String id, Uint8List bytes);

  /// Deletes `<id>.cvapp`. No-op if missing.
  Future<void> delete(String id);

  /// True if `<id>.cvapp` exists.
  Future<bool> exists(String id);
}

class FileSystemMissingException implements Exception {
  final String id;
  FileSystemMissingException(this.id);
  @override
  String toString() => 'FileSystemMissingException: $id.cvapp not found';
}
