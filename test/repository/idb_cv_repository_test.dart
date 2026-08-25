import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/json_codec.dart';
import 'package:cv_app/src/repository/cv_repository.dart';
import 'package:cv_app/src/repository/idb_cv_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';

IdbCvRepository _repo() {
  var clock = DateTime.utc(2026, 1, 1);
  // A fresh in-memory factory per test avoids cross-test leakage. The
  // sembast-memory backing is process-local, isolated by factory instance.
  final factory = newIdbFactoryMemory();
  return IdbCvRepository(
    factory: factory,
    now: () {
      final t = clock;
      clock = clock.add(const Duration(seconds: 1));
      return t;
    },
  );
}

Uint8List _encode(CvDocument doc) =>
    Uint8List.fromList(utf8.encode(CvDocumentCodec.toJsonString(doc)));

void main() {
  group('create + streams', () {
    test('emits ordered snapshots on mutation (updatedAt desc)', () async {
      final repo = _repo();
      final future = repo.watchAll().take(3).toList();
      await Future<void>.delayed(Duration.zero);
      final a = await repo.create(initialVariantName: 'A');
      final b = await repo.create(initialVariantName: 'B');
      final snapshots = await future;
      expect(snapshots.first, isEmpty);
      expect(snapshots.last.map((s) => s.variantName), ['B', 'A']);
      expect(snapshots.last.map((s) => s.id), containsAll([a.id, b.id]));
    });

    test('watch(id) closes when the doc is deleted', () async {
      final repo = _repo();
      final a = await repo.create();
      final events = <CvDocument>[];
      final sub = repo.watch(a.id).listen(events.add);
      await Future<void>.delayed(Duration.zero);
      await repo.delete(a.id);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events.first.id, a.id);
    });
  });

  group('save / duplicate / delete', () {
    test('duplicate iterates suffixes', () async {
      final repo = _repo();
      final a = await repo.create(initialVariantName: 'X');
      final d1 = await repo.duplicate(a.id);
      final d2 = await repo.duplicate(a.id);
      expect(d1.variantName, 'X (2)');
      expect(d2.variantName, 'X (3)');
    });

    test('save updates updatedAt', () async {
      final repo = _repo();
      final a = await repo.create(initialVariantName: 'A');
      final before = a.updatedAt;
      await repo.save(a);
      final after = (await repo.watch(a.id).first).updatedAt;
      expect(after.isAfter(before), isTrue);
    });

    test('delete throws on unknown id', () async {
      final repo = _repo();
      await expectLater(
        repo.delete('nope'),
        throwsA(isA<CvRepositoryNotFound>()),
      );
    });
  });

  group('import', () {
    test('ImportSuccess for a fresh document', () async {
      final repo = _repo();
      final other = _repo();
      final source = await other.create(initialVariantName: 'Fresca');
      final result = await repo.importFromBytes(_encode(source));
      expect(result, isA<ImportSuccess>());
      expect((result as ImportSuccess).doc.id, source.id);
    });

    test('ImportConflict on UUID collision', () async {
      final repo = _repo();
      final existing = await repo.create(initialVariantName: 'Vecchia');
      final incoming = existing.copyWith(variantName: 'Rinominata');
      final result = await repo.importFromBytes(_encode(incoming));
      expect(result, isA<ImportConflict>());
    });

    test('auto-rename on variantName collision (ticket 14 amendment)',
        () async {
      final repo = _repo();
      await repo.create(initialVariantName: 'Frontend Senior');
      final elsewhere = _repo();
      final incoming =
          await elsewhere.create(initialVariantName: 'Frontend Senior');
      final result = await repo.importFromBytes(_encode(incoming));
      expect(result, isA<ImportSuccess>());
      expect(
        (result as ImportSuccess).doc.variantName,
        'Frontend Senior (2)',
      );
    });

    test('ImportCorrupt on malformed JSON', () async {
      final repo = _repo();
      final result = await repo.importFromBytes(
        Uint8List.fromList(utf8.encode('nope')),
      );
      expect(result, isA<ImportCorrupt>());
    });
  });

  group('corrupt entries', () {
    test('malformed value in the store surfaces as corrupt', () async {
      final repo = _repo();
      await repo.debugInjectRaw('bad', 'garbage string');
      final snap = await repo.watchAll().first;
      expect(snap.map((s) => s.corrupt), contains(true));
    });

    test('exportRawCorrupt returns the raw payload', () async {
      final repo = _repo();
      await repo.debugInjectRaw('bad', '{"variantName":"Broken","x":1}');
      final bytes = await repo.exportRawCorrupt('bad');
      expect(utf8.decode(bytes), contains('Broken'));
    });
  });

  group('exportToBytes', () {
    test('round-trips through the codec', () async {
      final repo = _repo();
      final doc = await repo.create(initialVariantName: 'Round');
      final bytes = await repo.exportToBytes(doc.id);
      final parsed = CvDocumentCodec.fromJsonString(utf8.decode(bytes));
      expect(parsed.id, doc.id);
      expect(parsed.variantName, 'Round');
    });
  });
}
