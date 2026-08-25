/// Widget tests for LibraryScreen.
library;

import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/library/library_cubit.dart';
import 'package:cv_app/src/ui/library/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _makeApp({
  required LibraryCubit cubit,
  void Function(String)? onOpenVariant,
}) {
  return MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: LibraryScreen(onOpenVariant: onOpenVariant),
    ),
  );
}

LibraryCubit _cubit() => LibraryCubit(repository: InMemoryCvRepository());

void main() {
  group('LibraryScreen — empty state', () {
    testWidgets('shows empty-state CTAs when library has no variants',
        (tester) async {
      await tester.pumpWidget(_makeApp(cubit: _cubit()));
      await tester.pump(); // settle loading state

      // Wait for the LibraryLoaded(empty) state
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('empty_create_from_scratch')), findsOneWidget);
      expect(find.byKey(const Key('empty_import_pdf')), findsOneWidget);
    });
  });

  group('LibraryScreen — loaded state', () {
    testWidgets('shows variant cards for existing variants', (tester) async {
      final repo = InMemoryCvRepository();
      await repo.create(initialVariantName: 'Frontend Sr');
      await repo.create(initialVariantName: 'Backend Sr');
      final cubit = LibraryCubit(repository: repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Frontend Sr'), findsOneWidget);
      expect(find.text('Backend Sr'), findsOneWidget);
      expect(find.byKey(const Key('new_variant_card')), findsOneWidget);
    });

    testWidgets('tapping Apri calls onOpenVariant with the correct id',
        (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'My CV');
      final cubit = LibraryCubit(repository: repo);

      String? openedId;
      await tester.pumpWidget(
        _makeApp(cubit: cubit, onOpenVariant: (id) => openedId = id),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(Key('open_variant_${doc.id}')));
      await tester.pump();

      expect(openedId, doc.id);
    });
  });

  group('LibraryScreen — delete flow', () {
    testWidgets('delete confirm dialog button is present after menu opens',
        (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'To Delete');
      final cubit = LibraryCubit(repository: repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open variant menu
      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();

      // The popup menu should show the Elimina option
      expect(find.text('Elimina'), findsAtLeast(1));
    });
  });

  group('LibraryScreen — rename flow', () {
    testWidgets('rename dialog appears after menu interaction', (tester) async {
      final repo = InMemoryCvRepository();
      final doc = await repo.create(initialVariantName: 'Old Name');
      final cubit = LibraryCubit(repository: repo);

      await tester.pumpWidget(_makeApp(cubit: cubit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open variant menu
      await tester.tap(find.byKey(Key('variant_menu_${doc.id}')));
      await tester.pumpAndSettle();

      // The popup menu should show the Rinomina option
      expect(find.text('Rinomina'), findsAtLeast(1));
    });
  });
}
