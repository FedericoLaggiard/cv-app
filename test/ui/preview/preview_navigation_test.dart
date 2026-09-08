/// Integration test: editor → apri preview → back → posizione scroll
/// editor conservata (ticket 27, Testing Decisions).
library;

import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/editor/editor_screen.dart';
import 'package:cv_app/src/ui/preview/preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abbastanza sezioni + una viewport bassa per garantire che il body
/// dell'editor sia effettivamente scrollabile.
Future<String> _seedScrollable(InMemoryCvRepository repo) async {
  final doc = await repo.create(initialVariantName: 'Variante');
  await repo.save(
    doc.copyWith(
      sections: [
        for (var i = 0; i < 12; i++)
          CustomSection(id: 'c$i', displayTitle: 'Sezione $i', markdown: 'x' * 400),
      ],
    ),
  );
  return doc.id;
}

void main() {
  testWidgets(
    'back dalla preview torna all\'editor con lo stesso scroll offset',
    (tester) async {
      final repo = InMemoryCvRepository();
      final id = await _seedScrollable(repo);

      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => EditorScreen(
                variantId: id,
                repository: repo,
                onPreview: (variantId) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PreviewScreen(
                      variantId: variantId,
                      repository: repo,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scrollable = find
          .descendant(
            of: find.byType(ReorderableListView),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(300);
      await tester.pump();

      final offsetBefore =
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offsetBefore, 300);

      await tester.tap(find.byKey(const Key('editor_preview_pdf')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('preview_template_picker')), findsOneWidget);

      await tester.tap(find.byType(BackButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('editor_preview_pdf')), findsOneWidget);
      final offsetAfter =
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offsetAfter, offsetBefore);
    },
  );
}
