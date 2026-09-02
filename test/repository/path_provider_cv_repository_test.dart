import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/json_codec.dart';
import 'package:cv_app/src/repository/cv_repository.dart';
import 'package:cv_app/src/repository/path_provider_cv_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_file_system_service.dart';

PathProviderCvRepository _repo(FakeFileSystemService fs) {
  var clock = DateTime.utc(2026, 1, 1);
  return PathProviderCvRepository(
    fs: fs,
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
  group('create + persist', () {
    test('writes <uuid>.cvapp to library and streams the snapshot', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final doc = await repo.create(initialVariantName: 'A');
      expect(fs.files.keys, [doc.id]);
      final snap = await repo.watchAll().first;
      expect(snap.map((s) => s.variantName), ['A']);
    });

    test('save updates updatedAt and rewrites the file', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final a = await repo.create(initialVariantName: 'A');
      final before = a.updatedAt;
      await repo.save(a);
      final after = (await repo.watch(a.id).first).updatedAt;
      expect(after.isAfter(before), isTrue);
    });

    test('failure between write and rename leaves original intact', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final a = await repo.create(initialVariantName: 'Stable');

      final originalBytes = Uint8List.fromList(fs.files[a.id]!);
      fs.failNextRename = true;

      await expectLater(
        repo.save(a.copyWith(variantName: 'MidAir')),
        throwsA(anything),
      );

      // The persisted file still holds the pre-crash content.
      expect(fs.files[a.id], originalBytes);
      // And a `.tmp` twin remains as forensic evidence.
      expect(fs.tmp.containsKey(a.id), isTrue);
    });
  });

  group('duplicate + naming collisions', () {
    test('produces "<orig> (2)" then iterates', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final a = await repo.create(initialVariantName: 'X');
      final dup1 = await repo.duplicate(a.id);
      final dup2 = await repo.duplicate(a.id);
      expect(dup1.variantName, 'X (2)');
      expect(dup2.variantName, 'X (3)');
    });
  });

  group('delete', () {
    test('removes the file and closes watch()', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final a = await repo.create();
      await repo.delete(a.id);
      expect(fs.files, isEmpty);
    });

    test('throws on unknown id', () async {
      final repo = _repo(FakeFileSystemService());
      await expectLater(
          repo.delete('nope'), throwsA(isA<CvRepositoryNotFound>()));
    });

    test('save() after delete() throws CvRepositoryNotFound and does not '
        'resurrect the file', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final a = await repo.create(initialVariantName: 'A');
      await repo.delete(a.id);

      await expectLater(
        repo.save(a),
        throwsA(isA<CvRepositoryNotFound>()),
      );
      expect(fs.files, isEmpty);
    });

    test(
        'save() racing a concurrent delete() still throws '
        'CvRepositoryNotFound even if the compensating cleanup delete '
        'itself fails', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final a = await repo.create(initialVariantName: 'A');

      // Simulate delete() landing on this repo instance while save()'s
      // write is still in flight, then make the post-race compensating
      // delete fail too — the swallowed-error path should not surface as
      // anything other than the expected CvRepositoryNotFound.
      fs.onWriteBeforeComplete = () async {
        await repo.delete(a.id);
        fs.failNextDelete = true;
      };

      await expectLater(
        repo.save(a),
        throwsA(isA<CvRepositoryNotFound>()),
      );
      expect(fs.files, isEmpty);
    });
  });

  group('bootstrap: recover from files on disk', () {
    test('picks up pre-existing files on first watchAll', () async {
      final fs = FakeFileSystemService();
      final seed = _repo(fs);
      final a = await seed.create(initialVariantName: 'A');
      final b = await seed.create(initialVariantName: 'B');

      // Fresh repo instance over the same FS: should see both variants.
      final reopened = _repo(fs);
      final snap = await reopened.watchAll().first;
      expect(snap.map((s) => s.id).toSet(), {a.id, b.id});
    });

    test(
        'concurrent callers observe the fully-populated cache (bootstrap race)',
        () async {
      final fs = FakeFileSystemService();
      final seed = _repo(fs);
      final a = await seed.create(initialVariantName: 'A');
      final b = await seed.create(initialVariantName: 'B');

      // Two independent async callers hit the fresh repo at the same tick.
      final reopened = _repo(fs);
      final snapsFuture = reopened.watchAll().first;
      final watchFuture = reopened.watch(a.id).first;
      final results = await Future.wait([snapsFuture, watchFuture]);
      final snap = results[0] as List<VariantSummary>;
      final doc = results[1] as CvDocument;

      expect(snap.map((s) => s.id).toSet(), {a.id, b.id});
      expect(doc.id, a.id);
    });
  });

  group('corrupt files', () {
    test('surface as VariantSummary(corrupt: true) and cannot be watched',
        () async {
      final fs = FakeFileSystemService();
      fs.inject('bad-id', Uint8List.fromList(utf8.encode('not json')));
      final repo = _repo(fs);
      final snap = await repo.watchAll().first;
      expect(snap, hasLength(1));
      expect(snap.first.corrupt, isTrue);
      await expectLater(
        repo.watch('bad-id').first,
        throwsA(isA<CvRepositoryNotFound>()),
      );
    });

    test('exportRawCorrupt returns the original bytes for repair', () async {
      final fs = FakeFileSystemService();
      final raw = Uint8List.fromList(utf8.encode('{"variantName":"Broken"}'));
      fs.inject('bad-id', raw);
      final repo = _repo(fs);
      await repo.watchAll().first; // trigger bootstrap
      final bytes = await repo.exportRawCorrupt('bad-id');
      expect(bytes, raw);
    });

    test('best-effort variantName recovery for the Libreria row', () async {
      final fs = FakeFileSystemService();
      // Missing required fields → validation fails → corrupt, but the
      // name should still show through.
      fs.inject(
        'bad-id',
        Uint8List.fromList(utf8.encode('{"variantName":"Recovered","x":1}')),
      );
      final repo = _repo(fs);
      final snap = await repo.watchAll().first;
      expect(snap.first.variantName, 'Recovered');
    });

    test('delete works on corrupt entries', () async {
      final fs = FakeFileSystemService();
      fs.inject('bad', Uint8List.fromList(utf8.encode('garbage')));
      final repo = _repo(fs);
      await repo.watchAll().first;
      await repo.delete('bad');
      expect(fs.files, isEmpty);
    });
  });

  group('import', () {
    test('ImportSuccess for a fresh document persists to FS', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final elsewhere = _repo(FakeFileSystemService());
      final source = await elsewhere.create(initialVariantName: 'Fresca');

      final result = await repo.importFromBytes(_encode(source));
      expect(result, isA<ImportSuccess>());
      expect(fs.files, contains(source.id));
    });

    test('ImportConflict on UUID collision (does NOT overwrite)', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final existing = await repo.create(initialVariantName: 'Vecchia');
      final incoming = existing.copyWith(variantName: 'Rinominata');

      final beforeBytes = Uint8List.fromList(fs.files[existing.id]!);
      final result = await repo.importFromBytes(_encode(incoming));
      expect(result, isA<ImportConflict>());
      final conflict = result as ImportConflict;
      expect(conflict.existingId, existing.id);
      // Original file untouched: conflict is decided upstream (ticket 03).
      expect(fs.files[existing.id], beforeBytes);
    });

    test(
        'ImportSuccess with silent auto-rename on variantName collision '
        '(ticket 14 amendment)', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      // Pre-existing variant named "Frontend Senior".
      await repo.create(initialVariantName: 'Frontend Senior');

      // Import a *different* UUID with the same human name.
      final elsewhere = _repo(FakeFileSystemService());
      final incoming = await elsewhere.create(initialVariantName: 'Frontend Senior');

      final result = await repo.importFromBytes(_encode(incoming));
      expect(result, isA<ImportSuccess>());
      final imported = (result as ImportSuccess).doc;
      expect(imported.variantName, 'Frontend Senior (2)');
      expect(imported.id, incoming.id);
    });

    test('auto-rename is case-insensitive + trim', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      await repo.create(initialVariantName: 'MyRole');

      final elsewhere = _repo(FakeFileSystemService());
      final incoming = await elsewhere.create(initialVariantName: '  myrole  ');
      final result = await repo.importFromBytes(_encode(incoming));
      expect(result, isA<ImportSuccess>());
      // The auto-rename normalizes the base (trim), so leading/trailing
      // spaces on the incoming name are dropped before the suffix.
      expect((result as ImportSuccess).doc.variantName, 'myrole (2)');
    });

    test('ImportCorrupt on malformed JSON', () async {
      final repo = _repo(FakeFileSystemService());
      final result = await repo.importFromBytes(
        Uint8List.fromList(utf8.encode('not json')),
      );
      expect(result, isA<ImportCorrupt>());
    });
  });

  group('exportToBytes', () {
    test('round-trips through the codec', () async {
      final fs = FakeFileSystemService();
      final repo = _repo(fs);
      final doc = await repo.create(initialVariantName: 'Round');
      final bytes = await repo.exportToBytes(doc.id);
      final parsed = CvDocumentCodec.fromJsonString(utf8.decode(bytes));
      expect(parsed.id, doc.id);
      expect(parsed.variantName, 'Round');
    });
  });
}
