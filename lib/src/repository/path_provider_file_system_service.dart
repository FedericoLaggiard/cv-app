/// Concrete [FileSystemService] backed by `dart:io` + `path_provider`.
///
/// Not imported on web (guarded by conditional import in
/// `cv_repository_factory.dart`).
///
/// Layout: `<appSupport>/library/<uuid>.cvapp` on desktop/mobile
/// (`getApplicationSupportDirectory` on macOS/Windows/Linux,
/// `getApplicationDocumentsDirectory` on iOS/Android per ticket 04's
/// per-platform table).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'file_system_service.dart';

class PathProviderFileSystemService implements FileSystemService {
  /// Optional override for tests: if set, [ensureLibraryDir] returns it
  /// verbatim instead of resolving through `path_provider`.
  final String? overrideLibraryDir;

  PathProviderFileSystemService({this.overrideLibraryDir});

  String? _resolvedDir;

  @override
  Future<String> ensureLibraryDir() async {
    if (_resolvedDir != null) return _resolvedDir!;
    final base = overrideLibraryDir ?? await _resolveBaseDir();
    final dir = Directory('$base${Platform.pathSeparator}library');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _resolvedDir = dir.path;
    return _resolvedDir!;
  }

  Future<String> _resolveBaseDir() async {
    // iOS/Android: sandbox app private documents (invisible to the user).
    // macOS/Windows/Linux: application support directory (hidden, per-app).
    final Directory dir;
    if (Platform.isIOS || Platform.isAndroid) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationSupportDirectory();
    }
    return dir.path;
  }

  @override
  Future<List<String>> listVariantIds() async {
    final dirPath = await ensureLibraryDir();
    final dir = Directory(dirPath);
    if (!await dir.exists()) return const [];
    final ids = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.endsWith('.cvapp')) continue;
      if (name.endsWith('.cvapp.tmp')) continue;
      ids.add(name.substring(0, name.length - '.cvapp'.length));
    }
    return ids;
  }

  @override
  Future<Uint8List> read(String id) async {
    final path = await _pathFor(id);
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemMissingException(id);
    }
    return file.readAsBytes();
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    final path = await _pathFor(id);
    final tmp = File('$path.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    // rename() is atomic on the same volume on POSIX and on Windows since
    // ReplaceFileW semantics used by dart:io. On a crash between the
    // write and the rename, the original `<id>.cvapp` survives.
    await tmp.rename(path);
  }

  @override
  Future<void> delete(String id) async {
    final path = await _pathFor(id);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> exists(String id) async {
    final path = await _pathFor(id);
    return File(path).exists();
  }

  Future<String> _pathFor(String id) async {
    final dir = await ensureLibraryDir();
    return '$dir${Platform.pathSeparator}$id.cvapp';
  }
}
