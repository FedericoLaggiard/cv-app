/// Widget test per [RichTextField] (Slice C / ticket 22).
library;

import 'package:cv_app/src/ui/editor/widgets/rich_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('mostra il placeholder quando vuoto', (tester) async {
    await tester.pumpWidget(_app(RichTextField(
      value: '',
      placeholder: 'Scrivi un breve sommario…',
      onChanged: (_) {},
    )));

    expect(find.text('Scrivi un breve sommario…'), findsOneWidget);
  });

  testWidgets('la toolbar non è visibile finché il campo non ha focus',
      (tester) async {
    await tester.pumpWidget(_app(RichTextField(
      value: '',
      fieldKey: const Key('field'),
      onChanged: (_) {},
    )));

    expect(find.byKey(const Key('rt_toolbar_bold')), findsNothing);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    expect(find.byKey(const Key('rt_toolbar_bold')), findsOneWidget);
  });

  testWidgets('onChanged riceve il testo digitato (storage = markdown puro)',
      (tester) async {
    String? last;
    await tester.pumpWidget(_app(RichTextField(
      value: '',
      fieldKey: const Key('field'),
      onChanged: (v) => last = v,
    )));

    await tester.enterText(find.byKey(const Key('field')), 'Ciao mondo');
    expect(last, 'Ciao mondo');
  });

  testWidgets('bold/italic roundtrip via toolbar sulla selezione', (tester) async {
    String value = 'Ciao';
    late StateSetter setState;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, s) {
        setState = s;
        return RichTextField(
          value: value,
          fieldKey: const Key('field'),
          onChanged: (v) => setState(() => value = v),
        );
      },
    )));

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    final editableText = tester.state<EditableTextState>(find.byType(EditableText));
    editableText.userUpdateTextEditingValue(
      const TextEditingValue(text: 'Ciao', selection: TextSelection(baseOffset: 0, extentOffset: 4)),
      SelectionChangedCause.tap,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('rt_toolbar_bold')));
    await tester.pump();

    expect(value, '**Ciao**');
  });

  testWidgets(
      '"incolla come testo semplice" sostituisce la selezione col testo degli appunti',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'testo copiato'};
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    String value = '';
    late StateSetter setState;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, s) {
        setState = s;
        return RichTextField(
          value: value,
          fieldKey: const Key('field'),
          onChanged: (v) => setState(() => value = v),
        );
      },
    )));

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('rt_toolbar_paste_plain')));
    await tester.pumpAndSettle();

    expect(value, 'testo copiato');
  });

  group('round-trip Markdown rappresentativo', () {
    for (final snippet in const [
      '**grassetto**',
      '_corsivo_',
      '[link](https://example.dev)',
      '- uno\n- due\n- tre',
      '1. uno\n2. due',
      '**grassetto** e _corsivo_ con [link](https://example.dev)',
    ]) {
      testWidgets('"$snippet" sopravvive intatto al giro nel campo',
          (tester) async {
        String value = snippet;
        late StateSetter setState;
        await tester.pumpWidget(_app(StatefulBuilder(
          builder: (context, s) {
            setState = s;
            return RichTextField(
              value: value,
              fieldKey: const Key('field'),
              onChanged: (v) => setState(() => value = v),
            );
          },
        )));

        // Il valore visualizzato nel TextField è, byte per byte, il
        // Markdown salvato: nessuna (de)serializzazione intermedia.
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.controller.text, snippet);
      });
    }
  });

  testWidgets('setContentForTest imposta il contenuto e notifica onChanged',
      (tester) async {
    String? last;
    final key = GlobalKey<RichTextFieldState>();
    await tester.pumpWidget(_app(RichTextField(
      key: key,
      value: '',
      onChanged: (v) => last = v,
    )));

    key.currentState!.setContentForTest('impostato da test');
    await tester.pump();

    expect(last, 'impostato da test');
    expect(find.text('impostato da test'), findsOneWidget);
  });
}
