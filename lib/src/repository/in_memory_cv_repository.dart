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
  Stream<List<VariantSummary>> watchAll() {
    StreamSubscription<void>? bumpSub;
    final controller = StreamController<List<VariantSummary>>(
      onCancel: () => bumpSub?.cancel(),
    );
    controller.onListen = () {
      // Subscribe to _bump BEFORE adding the first snapshot so that no
      // mutation events are missed between the first yield and the consumer
      // processing it (avoids the async* `await for` race condition).
      bumpSub = _bump.stream.listen((_) {
        if (!controller.isClosed) controller.add(_snapshot());
      });
      controller.add(_snapshot());
    };
    return controller.stream;
  }

  @override
  Stream<CvDocument> watch(String id) {
    // StreamController esplicito invece di `async*` + `await for`: cancellare
    // la subscription di un `async*` fermo su `await for` di un broadcast
    // stream non si sblocca finché quello stream non emette di nuovo (bug
    // di cancellazione dei generator asincroni, non specifico di Dart 3.13
    // ma emerso misurando i tempi dei test dopo l'upgrade del ticket 19).
    // Stesso pattern già usato da `watchAll()` qui sopra.
    StreamSubscription<void>? bumpSub;
    final controller = StreamController<CvDocument>(
      // `scheduleMicrotask` invece di chiamare `.cancel()` a bruciapelo:
      // cancellare una subscription su `_bump` (broadcast) da dentro
      // l'`onCancel` sincrono di *questo* controller — a sua volta invocato
      // da dentro il dispatch dell'evento iniziale di `.first` — deadlocka
      // il test runner (verificato: senza il defer l'isolate si blocca a
      // CPU zero). Un giro di microtask rompe la rientranza.
      onCancel: () => scheduleMicrotask(() => bumpSub?.cancel()),
    );
    controller.onListen = () {
      final initial = _byId[id];
      if (initial == null) {
        controller.addError(CvRepositoryNotFound(id));
        controller.close();
        return;
      }
      bumpSub = _bump.stream.listen((_) {
        if (controller.isClosed) return;
        final doc = _byId[id];
        if (doc == null) {
          controller.close(); // deleted → close the stream
          return;
        }
        controller.add(doc);
      });
      controller.add(initial);
    };
    return controller.stream;
  }

  @override
  Future<CvDocument> create({String? initialVariantName}) async {
    final now = _now().toUtc();
    final name = initialVariantName ?? _defaultName();
    if (initialVariantName != null && _nameClashes(name)) {
      throw DuplicateVariantNameException(name.trim());
    }
    final doc = CvDocument(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      variantName: name,
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
    if (_nameClashes(doc.variantName, excludeId: doc.id)) {
      throw DuplicateVariantNameException(doc.variantName.trim());
    }
    final gcd = garbageCollectAssets(doc);
    validateStructure(gcd);
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
      validateStructure(doc);
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

  bool _nameClashes(String name, {String? excludeId}) {
    final norm = _normalize(name);
    return _byId.values.any(
      (d) => d.id != excludeId && _normalize(d.variantName) == norm,
    );
  }

  /// Test helper: expose current keys.
  Iterable<String> get debugIds => _byId.keys;

  /// Test helper: force-inject a document (bypasses validation). Handy to
  /// simulate a `.cvapp` that would clash on import.
  void debugInsert(CvDocument doc) {
    _byId[doc.id] = doc;
    _bump.add(null);
  }
}
