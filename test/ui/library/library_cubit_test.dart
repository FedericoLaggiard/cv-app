/// Unit tests for LibraryCubit.
library;

import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/library/library_cubit.dart';
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

/// Subscribes to [cubit] stream, runs [act], and returns the next
/// [LibraryLoaded] state.  Subscribing BEFORE [act] guarantees no
/// emission is missed.
Future<LibraryLoaded> _nextLoaded(
  LibraryCubit cubit,
  Future<void> Function() act,
) async {
  final future = cubit.stream
      .where((s) => s is LibraryLoaded)
      .cast<LibraryLoaded>()
      .first
      .timeout(const Duration(seconds: 5));
  await act();
  return future;
}

/// Waits until cubit emits a [LibraryLoaded] state satisfying [predicate].
Future<LibraryLoaded> _waitFor(
  LibraryCubit cubit,
  bool Function(LibraryLoaded) predicate,
) {
  return cubit.stream
      .where((s) => s is LibraryLoaded)
      .cast<LibraryLoaded>()
      .where(predicate)
      .first
      .timeout(const Duration(seconds: 5));
}

void main() {
  group('LibraryCubit — initial load', () {
    test('emits loading then loaded with empty list when repo is empty',
        () async {
      final cubit = LibraryCubit(repository: _repo());
      final states = <LibraryState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.load();
      await sub.cancel();

      expect(states, [
        isA<LibraryLoading>(),
        isA<LibraryLoaded>().having((s) => s.variants, 'variants', isEmpty),
      ]);
    });

    test('emits loaded with existing variants', () async {
      final repo = _repo();
      await repo.create(initialVariantName: 'Alpha');
      final cubit = LibraryCubit(repository: repo);
      await cubit.load();

      final state = cubit.state as LibraryLoaded;
      expect(state.variants.map((v) => v.variantName).toList(), ['Alpha']);
    });
  });

  group('LibraryCubit — createNewNamed', () {
    test('creates a variant with the given name and emits new loaded state',
        () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();

      final state = await _nextLoaded(cubit, () async {
        await cubit.createNewNamed('Backend senior');
      });

      expect(state.variants.length, 1);
      expect(state.variants.first.variantName, 'Backend senior');
    });

    test('throws LibraryValidationException on blank name', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();

      await expectLater(
        cubit.createNewNamed('   '),
        throwsA(isA<LibraryValidationException>()),
      );
    });

    test('throws LibraryValidationException on duplicate name', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      await cubit.createNewNamed('Alpha');
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      await expectLater(
        cubit.createNewNamed('ALPHA'),
        throwsA(isA<LibraryValidationException>()),
      );
    });
  });

  group('LibraryCubit — deleteVariant', () {
    test('removes a variant from state', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      final id = (await cubit.createNewNamed('X'))!;
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      final afterDelete = await _nextLoaded(cubit, () async {
        await cubit.deleteVariant(id);
      });

      expect(afterDelete.variants, isEmpty);
    });
  });

  group('LibraryCubit — renameVariant', () {
    test('renames an existing variant', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      final id = (await cubit.createNewNamed('Old'))!;
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      final afterRename = await _nextLoaded(cubit, () async {
        await cubit.renameVariant(id, 'Renamed');
      });

      expect(afterRename.variants.first.variantName, 'Renamed');
    });

    test('throws LibraryValidationException on blank name', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      final id = (await cubit.createNewNamed('X'))!;
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      await expectLater(
        cubit.renameVariant(id, '   '),
        throwsA(isA<LibraryValidationException>()),
      );
    });

    test(
        'throws LibraryValidationException on duplicate name '
        '(case-insensitive)', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      await cubit.createNewNamed('Alpha');
      final bId = (await cubit.createNewNamed('Beta'))!;
      await _waitFor(cubit, (s) => s.variants.length == 2);

      await expectLater(
        cubit.renameVariant(bId, 'ALPHA'),
        throwsA(isA<LibraryValidationException>()),
      );
    });
  });

  group('LibraryCubit — duplicateVariantAs', () {
    test('duplicates with an explicit name', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      final id = (await cubit.createNewNamed('Src'))!;
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      // duplicateVariantAs does 2 repo ops (dup + rename) → 2 stream events.
      // Wait for the state that actually has the renamed variant.
      await cubit.duplicateVariantAs(id, 'Custom copy');
      final afterDup = await _waitFor(
        cubit,
        (s) => s.variants.any((v) => v.variantName == 'Custom copy'),
      );

      expect(
        afterDup.variants.map((v) => v.variantName),
        containsAll(['Src', 'Custom copy']),
      );
    });

    test('rejects duplicate name collision', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      final id = (await cubit.createNewNamed('Src'))!;
      await cubit.createNewNamed('Taken');
      await _waitFor(cubit, (s) => s.variants.length == 2);

      await expectLater(
        cubit.duplicateVariantAs(id, 'Taken'),
        throwsA(isA<LibraryValidationException>()),
      );
    });
  });

  group('LibraryCubit — validateName', () {
    test('returns error string for existing names (case-insensitive)',
        () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      await cubit.createNewNamed('Alpha');
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      expect(cubit.validateName('alpha'), isNotNull);
      expect(cubit.validateName('ALPHA'), isNotNull);
      expect(cubit.validateName('Beta'), isNull);
    });

    test('returns error for blank names', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();

      expect(cubit.validateName(''), isNotNull);
      expect(cubit.validateName('   '), isNotNull);
    });

    test('excludeId lets the current name be reused during a rename',
        () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      final id = (await cubit.createNewNamed('Alpha'))!;
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      expect(cubit.validateName('Alpha', excludeId: id), isNull);
    });

    test('returns null when library is not yet loaded', () {
      final cubit = LibraryCubit(repository: _repo());
      expect(cubit.validateName('Anything'), isNull);
    });
  });

  group('LibraryCubit — name suggestions', () {
    test('suggestDuplicateName follows the "<base> (N)" pattern', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      await cubit.createNewNamed('Alpha');
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      expect(cubit.suggestDuplicateName('Alpha'), 'Alpha (2)');
    });

    test('suggestDuplicateName skips taken slots case-insensitively',
        () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();
      await cubit.createNewNamed('Alpha');
      await cubit.createNewNamed('ALPHA (2)');
      await _waitFor(cubit, (s) => s.variants.length == 2);

      expect(cubit.suggestDuplicateName('Alpha'), 'Alpha (3)');
    });

    test('suggestNewVariantName returns the first free slot', () async {
      final cubit = LibraryCubit(repository: _repo());
      await cubit.load();

      expect(cubit.suggestNewVariantName(), 'Nuova variante 1');

      await cubit.createNewNamed('Nuova variante 1');
      await _waitFor(cubit, (s) => s.variants.isNotEmpty);

      expect(cubit.suggestNewVariantName(), 'Nuova variante 2');
    });
  });
}
