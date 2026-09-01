/// Widget tests for LibraryScreen.
library;

import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/library/library_cubit.dart';
import 'package:cv_app/src/ui/library/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _wideSize = Size(1200, 900);
const _narrowSize = Size(480, 900);

/// Wraps [LibraryScreen] with the boilerplate providers.  Sets a fixed
/// [Size] on [MediaQuery] so responsive dispatch is deterministic.
Widget _makeApp({
  required LibraryCubit cubit,
  void Function(String)? onOpenVariant,
  Size size = _wideSize,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: BlocProvider.value(
        value: cubit,
        child: LibraryScreen(onOpenVariant: onOpenVariant),
      ),
    ),
  );
}

/// Builds a cubit and kicks off `load()` without awaiting — matches how
/// production wires the cubit via `BlocProvider.create: (_) => LibraryCubit(...)..load()`.
/// Inside `testWidgets`, the pending stream event is flushed by the caller's
/// first `pump`/`pumpAndSettle`.  Awaiting `load()` here would deadlock
/// because the stream event delivery happens in the fake async zone that
/// only advances on `tester.pump`.
LibraryCubit _loadedCubit(InMemoryCvRepository repo) {
  return LibraryCubit(repository: repo)..load();
}

LibraryCubit _emptyLoadedCubit() => _loadedCubit(InMemoryCvRepository());

/// Standard settle sequence for a Library screen driven by the stream-based
/// repository: one micro pump to run `initState().load()`, then a real-time
/// pump so the first snapshot flushes.
Future<void> _settleLibrary(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('LibraryScreen — empty state', () {
    testWidgets('shows a single "Crea la prima variante" CTA', (tester) async {
      final cubit = _emptyLoadedCubit();
      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      expect(find.byKey(const Key('empty_create_new')), findsOneWidget);
      expect(find.text('Non hai ancora nessuna variante.'), findsOneWidget);
    });
  });

  group('LibraryScreen — loaded state', () {
    testWidgets('shows variant cards for existing variants', (tester) async {
      final repo = InMemoryCvRepository();
      await repo.create(initialVariantName: 'Frontend Sr');
      await repo.create(initialVariantName: 'Backend Sr');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      expect(find.text('Frontend Sr'), findsOneWidget);
      expect(find.text('Backend Sr'), findsOneWidget);
      expect(find.byKey(const Key('new_variant_card')), findsOneWidget);
    });

    testWidgets('tapping Apri calls onOpenVariant with the correct id',
        (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'My CV');
      final cubit = _loadedCubit(repo);

      String? openedId;
      await tester.pumpWidget(
        _makeApp(cubit: cubit, onOpenVariant: (id) => openedId = id),
      );
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('open_variant_${doc.id}')));
      await tester.pump();

      expect(openedId, doc.id);
    });
  });

  group('LibraryScreen — variant [⋯] menu (wide)', () {
    testWidgets('popup menu exposes Rinomina/Duplica/Esporta/Elimina',
        (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'M');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Rinomina'), findsOneWidget);
      expect(find.text('Duplica'), findsOneWidget);
      expect(find.text('Esporta'), findsOneWidget);
      expect(find.text('Elimina'), findsOneWidget);
    });

    testWidgets('Duplica opens dialog with pre-filled "<orig> (2)" default',
        (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'Base');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplica'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('duplicate_name_field')),
      );
      expect(field.controller?.text, 'Base (2)');
      expect(find.byKey(const Key('duplicate_confirm')), findsOneWidget);
    });
  });

  group('LibraryScreen — variant [⋯] menu (narrow)', () {
    testWidgets('opens a bottom sheet on width < 900px', (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'M');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit, size: _narrowSize));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();

      // Bottom sheet, not popup menu — Flutter's public BottomSheet widget
      // is present, and the four action tiles are visible.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Rinomina'), findsOneWidget);
      expect(find.text('Duplica'), findsOneWidget);
      expect(find.text('Esporta'), findsOneWidget);
      expect(find.text('Elimina'), findsOneWidget);
    });
  });

  group('LibraryScreen — Da zero flow', () {
    testWidgets(
        'tapping Nuova → Da zero shows the name dialog with a valid default',
        (tester) async {
      final repo = InMemoryCvRepository();
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(const Key('empty_create_new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new_from_scratch')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('new_variant_name_field')),
      );
      expect(field.controller?.text, 'Nuova variante 1');
      expect(find.byKey(const Key('new_variant_confirm')), findsOneWidget);
    });

    testWidgets('Da PDF entry point is disabled', (tester) async {
      final cubit = _emptyLoadedCubit();
      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(const Key('empty_create_new')));
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(
        find.byKey(const Key('new_from_pdf')),
      );
      expect(tile.enabled, isFalse);
    });
  });

  group('LibraryScreen — delete flow', () {
    testWidgets('confirming delete removes the variant', (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'ToDelete');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('ToDelete'), findsNothing);
    });
  });

  group('LibraryScreen — rename flow', () {
    testWidgets('confirming rename updates the card title', (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'Old name');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rinomina'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('rename_field')),
        'New name',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rename_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Old name'), findsNothing);
      expect(find.text('New name'), findsOneWidget);
    });

    testWidgets(
        'rename dialog shows a live inline error and disables confirm on '
        'name collision', (tester) async {
      final repo = InMemoryCvRepository();
      await repo.create(initialVariantName: 'Taken');
      final doc = await repo.create(initialVariantName: 'Renaming me');
      final cubit = _loadedCubit(repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rinomina'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('rename_field')), 'Taken');
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('rename_field')),
      );
      expect(field.decoration?.errorText, isNotNull);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('rename_confirm')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('LibraryScreen — duplicate from card flow', () {
    testWidgets(
        'confirming Duplica creates the copy and navigates to it',
        (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'Base');
      final cubit = _loadedCubit(repo);

      String? openedId;
      await tester.pumpWidget(
        _makeApp(cubit: cubit, onOpenVariant: (id) => openedId = id),
      );
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplica'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('duplicate_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Base (2)'), findsOneWidget);
      expect(openedId, isNotNull);
      expect(openedId, isNot(doc.id));
    });
  });

  group('LibraryScreen — Duplica una variante… from + Nuova', () {
    testWidgets(
        'changing the source dropdown refills the name, and confirming '
        'creates the copy and navigates to it', (tester) async {
      final repo = InMemoryCvRepository();
      await repo.create(initialVariantName: 'Alpha');
      final b = await repo.create(initialVariantName: 'Beta');
      final cubit = _loadedCubit(repo);

      String? openedId;
      await tester.pumpWidget(
        _makeApp(cubit: cubit, onOpenVariant: (id) => openedId = id),
      );
      await _settleLibrary(tester);

      await tester.tap(find.byKey(const Key('new_variant_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new_duplicate')));
      await tester.pumpAndSettle();

      // Dropdown defaults to the most recently updated variant (Beta).
      final beforeField = tester.widget<TextField>(
        find.byKey(const Key('duplicate_from_new_name_field')),
      );
      expect(beforeField.controller?.text, 'Beta (2)');

      await tester.tap(find.byKey(const Key('duplicate_source_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha').last);
      await tester.pumpAndSettle();

      final afterField = tester.widget<TextField>(
        find.byKey(const Key('duplicate_from_new_name_field')),
      );
      expect(afterField.controller?.text, 'Alpha (2)');

      await tester.tap(find.byKey(const Key('duplicate_from_new_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Alpha (2)'), findsOneWidget);
      expect(openedId, isNotNull);
      expect(openedId, isNot(b.id));
    });
  });

  group('LibraryScreen — integration: duplicate then delete original', () {
    testWidgets(
        'duplicating a variant then deleting the original leaves only the '
        'copy', (tester) async {
      final repo = InMemoryCvRepository();
      final original = await repo.create(initialVariantName: 'Original');
      await repo.create(initialVariantName: 'Other');
      final cubit = _loadedCubit(repo);

      String? openedId;
      await tester.pumpWidget(
        _makeApp(cubit: cubit, onOpenVariant: (id) => openedId = id),
      );
      await _settleLibrary(tester);

      await tester.tap(find.byKey(Key('variant_menu_${original.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplica'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('duplicate_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Original (2)'), findsOneWidget);
      expect(openedId, isNotNull);

      await tester.tap(find.byKey(Key('variant_menu_${original.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsNothing);
      expect(find.text('Original (2)'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });
  });
}
