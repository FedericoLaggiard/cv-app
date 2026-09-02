/// Widget test su `TemplatePicker` (ticket 25, Testing Decisions): 3
/// thumbnail visibili, tap evidenzia la selezione, callback `onChanged`
/// chiamata col `TemplateId` giusto.
library;

import 'package:cv_app/src/pdf/pdf_exporter.dart';
import 'package:cv_app/src/ui/editor/widgets/template_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required TemplateId selected,
  required ValueChanged<TemplateId> onChanged,
  Size size = const Size(800, 600),
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(size: size),
      child: SizedBox(
        width: size.width,
        child: TemplatePicker(selected: selected, onChanged: onChanged),
      ),
    ),
  ),
);

void main() {
  testWidgets('mostra le 3 thumbnail dei template', (tester) async {
    await tester.pumpWidget(
      _harness(selected: TemplateId.classico, onChanged: (_) {}),
    );

    for (final template in TemplateId.values) {
      expect(
        find.byKey(Key('template_picker_option_${template.wire}')),
        findsOneWidget,
      );
      expect(find.text(template.displayName), findsOneWidget);
    }
  });

  testWidgets('la thumbnail selezionata mostra il check di conferma', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(selected: TemplateId.moderno, onChanged: (_) {}),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tap su una thumbnail chiama onChanged col TemplateId giusto', (
    tester,
  ) async {
    TemplateId? changed;
    await tester.pumpWidget(
      _harness(
        selected: TemplateId.classico,
        onChanged: (v) => changed = v,
      ),
    );

    await tester.tap(find.byKey(const Key('template_picker_option_minimal')));
    await tester.pumpAndSettle();

    expect(changed, TemplateId.minimal);
  });

  testWidgets('sotto i 600px cade a lista verticale', (tester) async {
    await tester.pumpWidget(
      _harness(
        selected: TemplateId.classico,
        onChanged: (_) {},
        size: const Size(360, 640),
      ),
    );

    expect(find.byKey(const Key('template_picker_list')), findsOneWidget);
    expect(find.byKey(const Key('template_picker_grid')), findsNothing);
  });

  testWidgets('sopra i 600px mostra la griglia', (tester) async {
    await tester.pumpWidget(
      _harness(
        selected: TemplateId.classico,
        onChanged: (_) {},
        size: const Size(800, 600),
      ),
    );

    expect(find.byKey(const Key('template_picker_grid')), findsOneWidget);
    expect(find.byKey(const Key('template_picker_list')), findsNothing);
  });
}
