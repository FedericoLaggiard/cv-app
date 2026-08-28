/// Web [CvRepository] implementation on top of IndexedDB via `idb_shim`
/// (ticket 04 § "Layout web (IndexedDB)").
///
/// * DB name: `cvapp`.
/// * Single object store: `variants`, key = `id` UUID, value = the full
///   CV JSON tree (assets base64 included).
/// * Index: `by_updatedAt` on `value.updatedAt`, for the "Libreria"
///   ordered snapshot.
///
/// Corrupt entries (rare on web — structured clone is lossless) surface
/// exactly like on desktop/mobile: a `VariantSummary(corrupt: true)` row
/// with the raw JSON preserved for "Esporta grezzo".
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../domain/cv_document.dart';
import '../domain/json_codec.dart';
import '../domain/validation.dart';
import 'cv_repository.dart';

const _dbName = 'cvapp';
const _storeName = 'variants';
const _indexUpdatedAt = 'by_updatedAt';
const _dbVersion = 1;

class IdbCvRepository implements CvRepository {
  final IdbFactory _factory;
  final Uuid _uuid;
  final DateTime Function() _now;

  Database? _db;
  final StreamController<void> _bump = StreamController.broadcast();

  IdbCvRepository({
    required IdbFactory factory,
    Uuid? uuid,
    DateTime Function()? now,
  })  : _factory = factory,
        _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    _db = await _factory.open(
      _dbName,
      version: _dbVersion,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          final store = db.createObjectStore(_storeName);
          store.createIndex(_indexUpdatedAt, 'updatedAt', unique: false);
        }
      },
    );
    return _db!;
  }

  Future<void> close() async {
    _db?.close();
    _db = null;
  }

  // ------------------------ streams ------------------------

  @override
  Stream<List<VariantSummary>> watchAll() async* {
    yield await _snapshot();
    await for (final _ in _bump.stream) {
      yield await _snapshot();
    }
  }

  @override
  Stream<CvDocument> watch(String id) async* {
    final initial = await _readDoc(id);
    if (initial == null) throw CvRepositoryNotFound(id);
    yield initial;
    await for (final _ in _bump.stream) {
      final doc = await _readDoc(id);
      if (doc == null) return; // deleted → close the stream
      yield doc;
    }
  }

  Future<List<VariantSummary>> _snapshot() async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    final rows = <VariantSummary>[];
    final cursorStream = store.openCursor(autoAdvance: true);
    await for (final cursor in cursorStream) {
      final key = cursor.key as String;
      final rawValue = cursor.value;
      final parsed = _tryParse(rawValue);
      if (parsed != null) {
        rows.add(VariantSummary(
          id: parsed.id,
          variantName: parsed.variantName,
          updatedAt: parsed.updatedAt,
        ));
      } else {
        rows.add(VariantSummary(
          id: key,
          variantName: _looseVariantName(rawValue) ?? key,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          corrupt: true,
        ));
      }
    }
    await tx.completed;
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(rows);
  }

  Future<CvDocument?> _readDoc(String id) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    final raw = await store.getObject(id);
    await tx.completed;
    if (raw == null) return null;
    return _tryParse(raw);
  }

  CvDocument? _tryParse(Object? raw) {
    if (raw == null) return null;
    try {
      final json = _asJsonString(raw);
      final doc = CvDocumentCodec.fromJsonString(json);
      validateStructure(doc);
      return doc;
    } catch (_) {
      return null;
    }
  }

  String _asJsonString(Object raw) {
    if (raw is String) return raw;
    // idb_shim stores structured Map/List trees; re-encode to feed the
    // strict codec which is the single validation gate.
    return jsonEncode(raw);
  }

  String? _looseVariantName(Object? raw) {
    if (raw == null) return null;
    if (raw is Map && raw['variantName'] is String) {
      return raw['variantName'] as String;
    }
    if (raw is String) {
      final m = RegExp(r'"variantName"\s*:\s*"((?:\\.|[^"\\])*)"')
          .firstMatch(raw);
      if (m != null) return m.group(1)!;
    }
    return null;
  }

  // ------------------------ mutations ------------------------

  @override
  Future<CvDocument> create({String? initialVariantName}) async {
    final now = _now().toUtc();
    final name = initialVariantName ?? await _defaultName();
    final doc = CvDocument(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: name,
    );
    await _persist(doc);
    return doc;
  }

  @override
  Future<CvDocument> duplicate(String id) async {
    final source = await _readDoc(id);
    if (source == null) throw CvRepositoryNotFound(id);
    final now = _now().toUtc();
    final copy = source.copyWith(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: await _duplicateName(source.variantName),
    );
    await _persist(copy);
    return copy;
  }

  @override
  Future<void> save(CvDocument doc) async {
    final gcd = garbageCollectAssets(doc);
    validateStructure(gcd);
    final stamped = gcd.copyWith(updatedAt: _now().toUtc());
    await _persist(stamped);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    final store = tx.objectStore(_storeName);
    final existing = await store.getObject(id);
    if (existing == null) {
      await tx.completed;
      throw CvRepositoryNotFound(id);
    }
    await store.delete(id);
    await tx.completed;
    _bump.add(null);
  }

  Future<void> _persist(CvDocument doc) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    final store = tx.objectStore(_storeName);
    // Store as a decoded JSON tree so the `by_updatedAt` index can pick
    // up `updatedAt` as a scalar. Round-trip through the codec keeps
    // strict-mode invariants (minified, canonical field order).
    final tree =
        jsonDecode(CvDocumentCodec.toJsonString(doc)) as Map<String, dynamic>;
    await store.put(tree, doc.id);
    await tx.completed;
    _bump.add(null);
  }

  // ------------------------ import / export ------------------------

  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) async {
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException catch (e) {
      return ImportCorrupt('not valid UTF-8: ${e.message}');
    }
    CvDocument doc;
    try {
      doc = CvDocumentCodec.fromJsonString(source);
      validateStructure(doc);
    } on FormatException catch (e) {
      return ImportCorrupt('malformed JSON: ${e.message}');
    } on CvSchemaException catch (e) {
      return ImportCorrupt(e.toString());
    } on CvValidationException catch (e) {
      return ImportCorrupt(e.toString());
    }
    final db = await _open();
    final existing = await (db
            .transaction(_storeName, idbModeReadOnly)
            .objectStore(_storeName)
            .getObject(doc.id));
    if (existing != null) {
      return ImportConflict(existingId: doc.id, incoming: doc);
    }
    // Amendment ticket 14: variantName collision → auto-rename with (N).
    final resolved = await _resolveVariantNameOnImport(doc);
    await _persist(resolved);
    return ImportSuccess(resolved);
  }

  Future<CvDocument> _resolveVariantNameOnImport(CvDocument doc) async {
    if (!await _nameTakenByOthers(doc.variantName, exceptId: doc.id)) {
      return doc;
    }
    final base = doc.variantName.trim();
    final unique = await _findFreeSuffixedName(base, exceptId: doc.id);
    return doc.copyWith(variantName: unique);
  }

  @override
  Future<Uint8List> exportToBytes(String id) async {
    final doc = await _readDoc(id);
    if (doc == null) throw CvRepositoryNotFound(id);
    return Uint8List.fromList(utf8.encode(CvDocumentCodec.toJsonString(doc)));
  }

  /// Raw bytes of a corrupt entry, for the "Esporta grezzo" flow.
  Future<Uint8List> exportRawCorrupt(String id) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    final raw = await store.getObject(id);
    await tx.completed;
    if (raw == null) throw CvRepositoryNotFound(id);
    if (_tryParse(raw) != null) {
      // Not corrupt → route through the normal export.
      throw StateError('id $id is not corrupt; use exportToBytes()');
    }
    return Uint8List.fromList(utf8.encode(_asJsonString(raw)));
  }

  // ------------------------ naming helpers ------------------------

  Future<String> _defaultName() async {
    var i = 1;
    while (await _nameTakenByOthers('Nuova variante $i', exceptId: null)) {
      i++;
    }
    return 'Nuova variante $i';
  }

  Future<String> _duplicateName(String original) =>
      _findFreeSuffixedName(original.trim(), exceptId: null);

  Future<String> _findFreeSuffixedName(String base,
      {required String? exceptId}) async {
    for (var n = 2; n < 10000; n++) {
      final candidate = '$base ($n)';
      if (!await _nameTakenByOthers(candidate, exceptId: exceptId)) {
        return candidate;
      }
    }
    return '$base (copy)';
  }

  Future<bool> _nameTakenByOthers(String candidate,
      {required String? exceptId}) async {
    final norm = _normalize(candidate);
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadOnly);
    final store = tx.objectStore(_storeName);
    var taken = false;
    await for (final cursor
        in store.openCursor(autoAdvance: true)) {
      if (cursor.key == exceptId) continue;
      final rawName = _looseVariantName(cursor.value);
      if (rawName != null && _normalize(rawName) == norm) {
        taken = true;
        break;
      }
    }
    await tx.completed;
    return taken;
  }

  String _normalize(String s) => s.trim().toLowerCase();

  // ------------------------ test hooks ------------------------

  @visibleForTesting
  Future<void> debugInjectRaw(String id, Object value) async {
    final db = await _open();
    final tx = db.transaction(_storeName, idbModeReadWrite);
    await tx.objectStore(_storeName).put(value, id);
    await tx.completed;
    _bump.add(null);
  }
}
