import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cv_app/src/ui/editor/widgets/markdown_text_ops.dart';

TextSelection _sel(int start, int end) =>
    TextSelection(baseOffset: start, extentOffset: end);

void main() {
  group('toggleInlineMarker — bold/italic roundtrip', () {
    test('avvolge la selezione con il marker', () {
      final r = MarkdownTextOps.toggleInlineMarker('Ciao mondo', _sel(0, 4), '**');
      expect(r.text, '**Ciao** mondo');
      expect(r.selection, _sel(2, 6));
    });

    test('rimuove il marker se già applicato (roundtrip)', () {
      final applied = MarkdownTextOps.toggleInlineMarker('Ciao mondo', _sel(0, 4), '**');
      final removed = MarkdownTextOps.toggleInlineMarker(applied.text, applied.selection, '**');
      expect(removed.text, 'Ciao mondo');
      expect(removed.selection, _sel(0, 4));
    });

    test('selezione vuota inserisce marker vuoto e posiziona il cursore in mezzo', () {
      final r = MarkdownTextOps.toggleInlineMarker('abc', const TextSelection.collapsed(offset: 3), '_');
      expect(r.text, 'abc__');
      expect(r.selection, const TextSelection.collapsed(offset: 4));
    });
  });

  group('toggleList', () {
    test('applica il prefisso puntato su ogni riga selezionata', () {
      final r = MarkdownTextOps.toggleList('riga1\nriga2', _sel(0, 11), ordered: false);
      expect(r.text, '- riga1\n- riga2');
    });

    test('applica il prefisso numerato incrementale', () {
      final r = MarkdownTextOps.toggleList('a\nb\nc', _sel(0, 5), ordered: true);
      expect(r.text, '1. a\n2. b\n3. c');
    });

    test('rimuove il prefisso se già applicato (roundtrip)', () {
      final applied = MarkdownTextOps.toggleList('riga1\nriga2', _sel(0, 11), ordered: false);
      final removed = MarkdownTextOps.toggleList(applied.text, applied.selection, ordered: false);
      expect(removed.text, 'riga1\nriga2');
    });

    test('passare da puntato a numerato sostituisce il prefisso', () {
      final ul = MarkdownTextOps.toggleList('riga1\nriga2', _sel(0, 11), ordered: false);
      final ol = MarkdownTextOps.toggleList(ul.text, ul.selection, ordered: true);
      expect(ol.text, '1. riga1\n2. riga2');
    });

    test('funziona con il cursore collassato su una singola riga', () {
      final r = MarkdownTextOps.toggleList('sola riga', const TextSelection.collapsed(offset: 3), ordered: false);
      expect(r.text, '- sola riga');
    });
  });

  group('insertLink', () {
    test('inserisce [label](url) al posto della selezione', () {
      final r = MarkdownTextOps.insertLink('Contatti: ', _sel(10, 10), url: 'https://x.dev', label: 'sito');
      expect(r.text, 'Contatti: [sito](https://x.dev)');
      expect(r.selection, TextSelection.collapsed(offset: r.text.length));
    });
  });

  group('clearFormatting', () {
    test('rimuove bold/italic/link dalla selezione', () {
      const text = '**bold** e _italic_ e [link](https://x.dev)';
      final r = MarkdownTextOps.clearFormatting(text, _sel(0, text.length));
      expect(r.text, 'bold e italic e link');
    });

    test('rimuove i prefissi di lista dalla selezione', () {
      const text = '- uno\n- due';
      final r = MarkdownTextOps.clearFormatting(text, _sel(0, text.length));
      expect(r.text, 'uno\ndue');
    });
  });
}
