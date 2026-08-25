/// In-memory fake of [FileSystemService] for unit tests.
///
/// Simulates atomic tmp+rename semantics: [write] writes to `.tmp`, then
/// swaps into place. Tests can call [crashBeforeRename] to leave a stale
/// tmp behind and confirm the original file survives.
library;

import 'dart:typed_data';

import 'package:cv_app/src/repository/file_system_service.dart';

class FakeFileSystemService implements FileSystemService {
  final Map<String, Uint8List> files = {};
  final Map<String, Uint8List> tmp = {};

  bool failNextRename = false;

  @override
  Future<String> ensureLibraryDir() async => '/fake/library';

  @override
  Future<List<String>> listVariantIds() async => files.keys.toList()..sort();

  @override
  Future<Uint8List> read(String id) async {
    final bytes = files[id];
    if (bytes == null) throw FileSystemMissingException(id);
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    tmp[id] = Uint8List.fromList(bytes);
    if (failNextRename) {
      failNextRename = false;
      throw StateError('simulated crash between write and rename');
    }
    files[id] = tmp.remove(id)!;
  }

  @override
  Future<void> delete(String id) async {
    files.remove(id);
    tmp.remove(id);
  }

  @override
  Future<bool> exists(String id) async => files.containsKey(id);

  /// Test helper: force-inject raw bytes (e.g. malformed JSON) to simulate
  /// a corrupt file the repository has to surface as `corrupt: true`.
  void inject(String id, Uint8List bytes) {
    files[id] = Uint8List.fromList(bytes);
  }
}
