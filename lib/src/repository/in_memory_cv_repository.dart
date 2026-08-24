/// Pure-Dart in-memory implementation of [CvRepository].
///
/// Used for unit tests and as the default fake in dev builds. Everything
/// (create/save/delete/import) round-trips through the same JSON codec + GC
/// + validation pipeline that concrete backends use, so behavior stays
/// identical — the only difference is where bytes land.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../domain/cv_document.dart';
import '../domain/json_codec.dart';
import '../domain/validation.dart';
import 'cv_repository.dart';

class InMemoryCvRepository implements CvRepository {
  final Map<String, CvDocument> _byId = {};
  final StreamController<void> _bump = StreamController.broadcast();
  final Uuid _uuid;
  final DateTime Function() _now;

  InMemoryCvRepository({Uuid? uuid, DateTime Function()? now})
      : _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  @override
  Stream<List<VariantSummary>> watchAll() async* {
    yield _snapshot();
    await for (final _ in _bump.stream) {
      yield _snapshot();
    }
  }

  @override
  Stream<CvDocument> watch(String id) async* {
    final initial = _byId[id];
    if (initial == null) throw CvRepositoryNotFound(id);
    yield initial;
    await for (final _ in _bump.stream) {
      final doc = _byId[id];
      if (doc == null) return; // deleted → close the stream
      yield doc;
    }
  }

  @override
  Future<CvDocument> create({String? initialVariantName}) async {
    final now = _now().toUtc();
    final doc = CvDocument(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: initialVariantName ?? _defaultName(),
    );
    _byId[doc.id] = doc;
    _bump.add(null);
    return doc;
  }

  @override
  Future<CvDocument> duplicate(String id) async {
    final source = _byId[id];
    if (source == null) throw CvRepositoryNotFound(id);
    final now = _now().toUtc();
    final copy = source.copyWith(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: _duplicateName(source.variantName),
    );
    _byId[copy.id] = copy;
    _bump.add(null);
    return copy;
  }

  @override
  Future<void> save(CvDocument doc) async {
    // Auto-save pipeline: GC unreferenced assets, validate, stamp updatedAt.
    final gcd = garbageCollectAssets(doc);
    validate(gcd);
    final stamped = gcd.copyWith(updatedAt: _now().toUtc());
    _byId[stamped.id] = stamped;
    _bump.add(null);
  }

  @override
  Future<void> delete(String id) async {
    if (_byId.remove(id) == null) throw CvRepositoryNotFound(id);
    _bump.add(null);
  }

  @override
  Future<ImportResult> importFromBytes(Uint8List bytes) async {
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException catch (e) {
      return ImportCorrupt('not valid UTF-8: ${e.message}');
    }
    final CvDocument doc;
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
    if (_byId.containsKey(doc.id)) {
      return ImportConflict(existingId: doc.id, incoming: doc);
    }
    _byId[doc.id] = doc;
    _bump.add(null);
    return ImportSuccess(doc);
  }

  @override
  Future<Uint8List> exportToBytes(String id) async {
    final doc = _byId[id];
    if (doc == null) throw CvRepositoryNotFound(id);
    return Uint8List.fromList(utf8.encode(CvDocumentCodec.toJsonString(doc)));
  }

  // ------------------------ helpers ------------------------

  List<VariantSummary> _snapshot() {
    final list = _byId.values
        .map((d) => VariantSummary(
              id: d.id,
              variantName: d.variantName,
              updatedAt: d.updatedAt,
            ))
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  String _defaultName() {
    var i = 1;
    while (_byId.values.any(
      (d) => _normalize(d.variantName) == _normalize('Nuova variante $i'),
    )) {
      i++;
    }
    return 'Nuova variante $i';
  }

  /// Builds a duplicate name following ticket 14 rules: `<orig> (2)`, then
  /// `(3)`, ... until the first free slot. Match is case-insensitive+trim.
  String _duplicateName(String original) {
    final base = original.trim();
    for (var n = 2; n < 10000; n++) {
      final candidate = '$base ($n)';
      final norm = _normalize(candidate);
      final clash = _byId.values.any((d) => _normalize(d.variantName) == norm);
      if (!clash) return candidate;
    }
    return '$base (copy)';
  }

  String _normalize(String s) => s.trim().toLowerCase();

  /// Test helper: expose current keys.
  Iterable<String> get debugIds => _byId.keys;

  /// Test helper: force-inject a document (bypasses validation). Handy to
  /// simulate a `.cvapp` that would clash on import.
  void debugInsert(CvDocument doc) {
    _byId[doc.id] = doc;
    _bump.add(null);
  }
}
