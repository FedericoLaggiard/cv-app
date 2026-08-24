import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/json_codec.dart';
import 'package:cv_app/src/repository/cv_repository.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:flutter_test/flutter_test.dart';

InMemoryCvRepository _repo() {
  var clock = DateTime.utc(2026, 1, 1);
  return InMemoryCvRepository(
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
  group('create', () {
    test('generates a UUID, timestamps, and default name', () async {
      final repo = _repo();
      final doc = await repo.create();
      expect(doc.id, isNotEmpty);
      expect(doc.schemaVersion, currentSchemaVersion);
      expect(doc.variantName, 'Nuova variante 1');
      expect(doc.createdAt, doc.updatedAt);
      expect(doc.sections, isEmpty);
    });

    test('subsequent create auto-increments default name', () async {
      final repo = _repo();
      final a = await repo.create();
      final b = await repo.create();
      expect(a.variantName, 'Nuova variante 1');
      expect(b.variantName, 'Nuova variante 2');
    });

    test('honours initialVariantName', () async {
      final repo = _repo();
      final doc = await repo.create(initialVariantName: 'Backend senior');
      expect(doc.variantName, 'Backend senior');
    });
  });

  group('duplicate', () {
    test('rigenera id + timestamps + nome (2)', () async {
      final repo = _repo();
      final a = await repo.create(initialVariantName: 'Full-stack');
      final dup = await repo.duplicate(a.id);
      expect(dup.id, isNot(a.id));
      expect(dup.variantName, 'Full-stack (2)');
      expect(dup.createdAt, dup.updatedAt);
      expect(dup.createdAt.isAfter(a.updatedAt), isTrue);
    });

    test('itera fino al primo slot libero', () async {
      final repo = _repo();
      final a = await repo.create(initialVariantName: 'X');
      await repo.duplicate(a.id); // X (2)
      final third = await repo.duplicate(a.id); // X (3)
      expect(third.variantName, 'X (3)');
    });

    test('throws if id unknown', () async {
      final repo = _repo();
      await expectLater(
        repo.duplicate('does-not-exist'),
        throwsA(isA<CvRepositoryNotFound>()),
      );
    });
  });

  group('save', () {
    test('updates updatedAt on every save', () async {
      final repo = _repo();
      final a = await repo.create(initialVariantName: 'A');
      final before = a.updatedAt;
      await repo.save(a);
      final after = (await repo.watch(a.id).first).updatedAt;
      expect(after.isAfter(before), isTrue);
    });

    test('rejects invalid document', () async {
      final repo = _repo();
      final a = await repo.create();
      final bad = a.copyWith(variantName: '   ');
      await expectLater(repo.save(bad), throwsA(anything));
    });
  });

  group('delete', () {
    test('removes the document and closes watch()', () async {
      final repo = _repo();
      final a = await repo.create();
      final events = <CvDocument>[];
      final sub = repo.watch(a.id).listen(events.add);

      await Future<void>.delayed(Duration.zero);
      await repo.delete(a.id);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.first.id, a.id);
      expect(repo.debugIds, isEmpty);
    });

    test('throws if id unknown', () async {
      final repo = _repo();
      await expectLater(
        repo.delete('nope'),
        throwsA(isA<CvRepositoryNotFound>()),
      );
    });
  });

  group('watchAll', () {
    test('emits ordered snapshots on mutation', () async {
      final repo = _repo();
      final future = repo.watchAll().take(3).toList();
      // Give the listener a microtask to attach + receive the initial snapshot.
      await Future<void>.delayed(Duration.zero);
      final a = await repo.create(initialVariantName: 'A');
      final b = await repo.create(initialVariantName: 'B');
      final snapshots = await future;

      expect(snapshots.first, isEmpty);
      expect(snapshots.last.map((s) => s.variantName), ['B', 'A']);
      expect(snapshots.last.map((s) => s.id), containsAll([a.id, b.id]));
    });
  });

  group('importFromBytes', () {
    test('ImportSuccess for a fresh document', () async {
      final repo = _repo();
      final other = _repo();
      final source = await other.create(initialVariantName: 'Fresca');
      final bytes = _encode(source);

      final result = await repo.importFromBytes(bytes);
      expect(result, isA<ImportSuccess>());
      expect((result as ImportSuccess).doc.id, source.id);
      expect(repo.debugIds, contains(source.id));
    });

    test('ImportConflict when id already in library', () async {
      final repo = _repo();
      final existing = await repo.create(initialVariantName: 'Vecchia');
      final bytes = _encode(existing.copyWith(variantName: 'Rinominata'));

      final result = await repo.importFromBytes(bytes);
      expect(result, isA<ImportConflict>());
      final conflict = result as ImportConflict;
      expect(conflict.existingId, existing.id);
      expect(conflict.incoming.variantName, 'Rinominata');
    });

    test('ImportCorrupt on malformed JSON', () async {
      final repo = _repo();
      final bytes = Uint8List.fromList(utf8.encode('not json'));
      final result = await repo.importFromBytes(bytes);
      expect(result, isA<ImportCorrupt>());
    });

    test('ImportCorrupt on unknown fields (strict mode)', () async {
      final repo = _repo();
      final other = _repo();
      final source = await other.create(initialVariantName: 'Sorgente');
      final json =
          jsonDecode(CvDocumentCodec.toJsonString(source)) as Map<String, dynamic>;
      json['spurio'] = 'x';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));

      final result = await repo.importFromBytes(bytes);
      expect(result, isA<ImportCorrupt>());
    });

    test('ImportCorrupt on schemaVersion > current', () async {
      final repo = _repo();
      final other = _repo();
      final source = await other.create();
      final json =
          jsonDecode(CvDocumentCodec.toJsonString(source)) as Map<String, dynamic>;
      json['schemaVersion'] = currentSchemaVersion + 1;
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));

      final result = await repo.importFromBytes(bytes);
      expect(result, isA<ImportCorrupt>());
    });
  });

  group('exportToBytes', () {
    test('produces bytes that parse back into an equal document', () async {
      final repo = _repo();
      final doc = await repo.create(initialVariantName: 'Round');
      final bytes = await repo.exportToBytes(doc.id);
      final parsed = CvDocumentCodec.fromJsonString(utf8.decode(bytes));
      expect(parsed.id, doc.id);
      expect(parsed.variantName, 'Round');
    });

    test('throws on unknown id', () async {
      final repo = _repo();
      await expectLater(
        repo.exportToBytes('nope'),
        throwsA(isA<CvRepositoryNotFound>()),
      );
    });
  });
}
