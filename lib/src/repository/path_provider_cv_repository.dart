/// Desktop/mobile [CvRepository] implementation on top of a
/// [FileSystemService] (ticket 04).
///
/// * one `<uuid>.cvapp` file per variant in the library dir
/// * atomic writes via tmp+rename (delegated to [FileSystemService.write])
/// * corrupted files surface as `VariantSummary(corrupt: true)` and are
///   *not* apribili in editor (ticket 04 § "File corrotto / illeggibile")
/// * import auto-renames on variantName collision (ticket 14 amendment
///   to ticket 04), keeping `ImportConflict` for UUID collisions only.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../domain/cv_document.dart';
import '../domain/json_codec.dart';
import '../domain/validation.dart';
import 'cv_repository.dart';
import 'file_system_service.dart';

class PathProviderCvRepository implements CvRepository {
  final FileSystemService _fs;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// In-process cache: id → parsed document. Populated lazily by
  /// [watch] / [watchAll] and refreshed on every mutation.
  final Map<String, CvDocument> _cache = {};

  /// Ids known to be corrupt (parse/validation failed at read time).
  final Set<String> _corrupt = {};

  /// Cached variantName last read for corrupt ids (best-effort: we try to
  /// pull it out of the raw bytes so the Libreria row is still
  /// recognizable). Falls back to the id.
  final Map<String, String> _corruptNames = {};

  final StreamController<void> _bump = StreamController.broadcast();

  Future<void>? _bootstrapping;
  bool _bootstrapDone = false;

  PathProviderCvRepository({
    required FileSystemService fs,
    Uuid? uuid,
    DateTime Function()? now,
  })  : _fs = fs,
        _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  // ------------------------ bootstrap ------------------------

  Future<void> _bootstrap() {
    if (_bootstrapDone) return Future.value();
    // Cache the in-flight future so concurrent callers await the same
    // single load instead of racing past an early flag flip and hitting
    // a partially-populated cache.
    return _bootstrapping ??= _runBootstrap();
  }

  Future<void> _runBootstrap() async {
    try {
      final ids = await _fs.listVariantIds();
      for (final id in ids) {
        await _loadInto(id);
      }
      _bootstrapDone = true;
    } finally {
      // On failure, clear the in-flight future so a later call can retry
      // instead of silently returning against an empty cache.
      if (!_bootstrapDone) _bootstrapping = null;
    }
  }

  Future<void> _loadInto(String id) async {
    final Uint8List bytes;
    try {
      bytes = await _fs.read(id);
    } on FileSystemMissingException {
      _cache.remove(id);
      _corrupt.remove(id);
      _corruptNames.remove(id);
      return;
    }
    try {
      final source = utf8.decode(bytes);
      final doc = CvDocumentCodec.fromJsonString(source);
      validate(doc);
      _cache[id] = doc;
      _corrupt.remove(id);
      _corruptNames.remove(id);
    } catch (_) {
      _cache.remove(id);
      _corrupt.add(id);
      _corruptNames[id] = _extractVariantNameLoose(bytes) ?? id;
    }
  }

  /// Best-effort variantName recovery for a corrupt file: we look for
  /// `"variantName":"..."` in the raw JSON without going through the strict
  /// codec, so even a file with unknown-field or schemaVersion errors can
  /// still show a human name in the Libreria row.
  String? _extractVariantNameLoose(Uint8List bytes) {
    try {
      final s = utf8.decode(bytes);
      final m = RegExp(r'"variantName"\s*:\s*"((?:\\.|[^"\\])*)"').firstMatch(s);
      if (m == null) return null;
      // Unescape the minimal JSON string escapes we care about.
      return m.group(1)!.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    } catch (_) {
      return null;
    }
  }

  // ------------------------ streams ------------------------

  @override
  Stream<List<VariantSummary>> watchAll() async* {
    await _bootstrap();
    yield _snapshot();
    await for (final _ in _bump.stream) {
      yield _snapshot();
    }
  }

  @override
  Stream<CvDocument> watch(String id) async* {
    await _bootstrap();
    final initial = _cache[id];
    if (initial == null) throw CvRepositoryNotFound(id);
    yield initial;
    await for (final _ in _bump.stream) {
      final doc = _cache[id];
      if (doc == null) return; // deleted → close the stream
      yield doc;
    }
  }

  List<VariantSummary> _snapshot() {
    final list = <VariantSummary>[
      for (final d in _cache.values)
        VariantSummary(
          id: d.id,
          variantName: d.variantName,
          updatedAt: d.updatedAt,
        ),
      for (final id in _corrupt)
        VariantSummary(
          id: id,
          variantName: _corruptNames[id] ?? id,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          corrupt: true,
        ),
    ];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  // ------------------------ mutations ------------------------

  @override
  Future<CvDocument> create({String? initialVariantName}) async {
    await _bootstrap();
    final now = _now().toUtc();
    final doc = CvDocument(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: initialVariantName ?? _defaultName(),
    );
    await _persist(doc);
    return doc;
  }

  @override
  Future<CvDocument> duplicate(String id) async {
    await _bootstrap();
    final source = _cache[id];
    if (source == null) throw CvRepositoryNotFound(id);
    final now = _now().toUtc();
    final copy = source.copyWith(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: _duplicateName(source.variantName),
    );
    await _persist(copy);
    return copy;
  }

  @override
  Future<void> save(CvDocument doc) async {
    await _bootstrap();
    final gcd = garbageCollectAssets(doc);
    validate(gcd);
    final stamped = gcd.copyWith(updatedAt: _now().toUtc());
    await _persist(stamped);
  }

  @override
  Future<void> delete(String id) async {
    await _bootstrap();
    final wasKnown = _cache.remove(id) != null || _corrupt.remove(id);
    _corruptNames.remove(id);
    if (!wasKnown) throw CvRepositoryNotFound(id);
    await _fs.delete(id);
    _bump.add(null);
  }

  Future<void> _persist(CvDocument doc) async {
    final bytes =
        Uint8List.fromList(utf8.encode(CvDocumentCodec.toJsonString(doc)));
    await _fs.write(doc.id, bytes);
    _cache[doc.id] = doc;
    _corrupt.remove(doc.id);
    _corruptNames.remove(doc.id);
    _bump.add(null);
  }

  // ------------------------ import / export ------------------------

  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) async {
    await _bootstrap();
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException catch (e) {
      return ImportCorrupt('not valid UTF-8: ${e.message}');
    }
    CvDocument doc;
    try {
      doc = CvDocumentCodec.fromJsonString(source);
      validate(doc);
    } on FormatException catch (e) {
      return ImportCorrupt('malformed JSON: ${e.message}');
    } on CvSchemaException catch (e) {
      return ImportCorrupt(e.toString());
    } on CvValidationException catch (e) {
      return ImportCorrupt(e.toString());
    }
    if (_cache.containsKey(doc.id) || _corrupt.contains(doc.id)) {
      return ImportConflict(existingId: doc.id, incoming: doc);
    }
    // Amendment ticket 14: on variantName collision auto-rename with (N)
    // silently. UUID conflict is handled above; here we know the id is
    // fresh but the human name might already be taken.
    final resolved = _resolveVariantNameOnImport(doc);
    await _persist(resolved);
    return ImportSuccess(resolved);
  }

  CvDocument _resolveVariantNameOnImport(CvDocument doc) {
    if (!_nameTakenByOthers(doc.variantName, exceptId: doc.id)) return doc;
    final base = doc.variantName.trim();
    final unique = _findFreeSuffixedName(base, exceptId: doc.id);
    return doc.copyWith(variantName: unique);
  }

  @override
  Future<Uint8List> exportToBytes(String id) async {
    await _bootstrap();
    final doc = _cache[id];
    if (doc == null) throw CvRepositoryNotFound(id);
    return Uint8List.fromList(utf8.encode(CvDocumentCodec.toJsonString(doc)));
  }

  /// Returns the raw bytes of a corrupt file so the "Esporta grezzo" action
  /// can hand them to the user for out-of-app repair (ticket 04).
  Future<Uint8List> exportRawCorrupt(String id) async {
    await _bootstrap();
    if (!_corrupt.contains(id)) {
      throw CvRepositoryNotFound(id);
    }
    return _fs.read(id);
  }

  // ------------------------ naming helpers ------------------------

  String _defaultName() {
    var i = 1;
    while (_nameTakenByOthers('Nuova variante $i', exceptId: null)) {
      i++;
    }
    return 'Nuova variante $i';
  }

  String _duplicateName(String original) =>
      _findFreeSuffixedName(original.trim(), exceptId: null);

  String _findFreeSuffixedName(String base, {required String? exceptId}) {
    for (var n = 2; n < 10000; n++) {
      final candidate = '$base ($n)';
      if (!_nameTakenByOthers(candidate, exceptId: exceptId)) return candidate;
    }
    return '$base (copy)';
  }

  bool _nameTakenByOthers(String candidate, {required String? exceptId}) {
    final norm = _normalize(candidate);
    for (final entry in _cache.entries) {
      if (entry.key == exceptId) continue;
      if (_normalize(entry.value.variantName) == norm) return true;
    }
    return false;
  }

  String _normalize(String s) => s.trim().toLowerCase();

  // ------------------------ test hooks ------------------------

  @visibleForTesting
  Iterable<String> get debugIds => _cache.keys;

  @visibleForTesting
  Iterable<String> get debugCorruptIds => _corrupt;

  /// Discards the in-process cache so the next stream/mutation re-reads
  /// from the filesystem. Used by tests that mutate the FS out-of-band.
  @visibleForTesting
  Future<void> debugRefresh() async {
    _bootstrapDone = false;
    _bootstrapping = null;
    _cache.clear();
    _corrupt.clear();
    _corruptNames.clear();
    await _bootstrap();
    _bump.add(null);
  }
}
