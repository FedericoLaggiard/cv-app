/// Backdoor per i test E2E (ticket 17): permette di impostare il contenuto
/// di un [RichTextField] senza passare dalla tastiera virtuale/IME dei
/// simulatori.
///
/// No-op in build di produzione: attivo solo con `--dart-define=E2E=true`.
/// Per usarla, costruire il `RichTextField` passando come `key` una
/// `GlobalKey<RichTextFieldState>` nota al chiamante.
library;

import 'package:flutter/widgets.dart';

import 'widgets/rich_text_field.dart';

class TestHooks {
  TestHooks._();

  static const bool e2eEnabled = bool.fromEnvironment('E2E');

  static void setEditorContent(
    GlobalKey<RichTextFieldState> key,
    String markdown,
  ) {
    if (!e2eEnabled) return;
    key.currentState?.setContentForTest(markdown);
  }
}
