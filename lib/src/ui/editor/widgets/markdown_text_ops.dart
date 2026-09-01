/// Operazioni di editing testuale che applicano/rimuovono sintassi Markdown
/// su una selezione di testo semplice (Approccio A, vedi
/// `docs/adr/0001-rich-text-field-fallback.md`).
///
/// Il testo manipolato *è* già il Markdown salvato in `.cvapp`: non c'è
/// nessun passaggio di (de)serializzazione verso un document model.
library;

import 'package:flutter/widgets.dart';

/// Esito di un'operazione di editing: nuovo testo + nuova selezione da
/// applicare al [TextEditingController].
class TextEditResult {
  const TextEditResult(this.text, this.selection);

  final String text;
  final TextSelection selection;
}

class MarkdownTextOps {
  MarkdownTextOps._();

  /// Avvolge (o rimuove, se già presente) la selezione con [marker] su
  /// entrambi i lati, es. `**` per il grassetto, `_` per il corsivo.
  static TextEditResult toggleInlineMarker(
    String text,
    TextSelection selection,
    String marker,
  ) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final start = sel.start;
    final end = sel.end;
    final before = text.substring(0, start);
    final selected = text.substring(start, end);
    final after = text.substring(end);
    final mLen = marker.length;

    // Il marker può stare appena fuori dalla selezione (l'utente ha
    // riselezionato solo il testo "interno" dopo un primo toggle).
    final hasOuterMarker = start - mLen >= 0 &&
        text.substring(start - mLen, start) == marker &&
        end + mLen <= text.length &&
        text.substring(end, end + mLen) == marker;
    if (hasOuterMarker) {
      final newText = text.substring(0, start - mLen) + selected + text.substring(end + mLen);
      return TextEditResult(
        newText,
        TextSelection(baseOffset: start - mLen, extentOffset: start - mLen + selected.length),
      );
    }

    final alreadyWrapped = selected.length >= 2 * mLen &&
        selected.startsWith(marker) &&
        selected.endsWith(marker);

    if (alreadyWrapped) {
      final inner = selected.substring(marker.length, selected.length - marker.length);
      return TextEditResult(
        '$before$inner$after',
        TextSelection(baseOffset: start, extentOffset: start + inner.length),
      );
    }

    final newText = '$before$marker$selected$marker$after';
    final newSelection = selected.isEmpty
        ? TextSelection.collapsed(offset: start + marker.length)
        : TextSelection(
            baseOffset: start + marker.length,
            extentOffset: start + marker.length + selected.length,
          );
    return TextEditResult(newText, newSelection);
  }

  /// Applica/rimuove il prefisso di lista (`- ` o `1. `) su tutte le righe
  /// toccate dalla selezione.
  static TextEditResult toggleList(
    String text,
    TextSelection selection, {
    required bool ordered,
  }) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final anchorEnd = sel.end > sel.start ? sel.end - 1 : sel.start;
    final blockStart = _lineStart(text, sel.start);
    final blockEnd = _lineEnd(text, anchorEnd);
    final block = text.substring(blockStart, blockEnd);
    final lines = block.split('\n');

    final marker = ordered ? RegExp(r'^\d+\. ') : RegExp(r'^- ');
    final alreadyApplied = lines.every((l) => marker.hasMatch(l));

    final List<String> newLines;
    if (alreadyApplied) {
      newLines = [for (final l in lines) l.replaceFirst(marker, '')];
    } else {
      newLines = [
        for (var i = 0; i < lines.length; i++)
          '${ordered ? '${i + 1}. ' : '- '}${_stripListPrefix(lines[i])}',
      ];
    }

    final newBlock = newLines.join('\n');
    final newText = text.substring(0, blockStart) + newBlock + text.substring(blockEnd);
    return TextEditResult(
      newText,
      TextSelection(baseOffset: blockStart, extentOffset: blockStart + newBlock.length),
    );
  }

  /// Inserisce un link Markdown `[label](url)` al posto della selezione.
  static TextEditResult insertLink(
    String text,
    TextSelection selection, {
    required String url,
    required String label,
  }) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final markdown = '[$label]($url)';
    final newText = '$before$markdown$after';
    return TextEditResult(newText, TextSelection.collapsed(offset: before.length + markdown.length));
  }

  /// Rimuove la formattazione Markdown di base (bold/italic/link/liste)
  /// dalla sola selezione, lasciando il testo semplice.
  static TextEditResult clearFormatting(String text, TextSelection selection) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    var cleaned = text.substring(sel.start, sel.end);
    cleaned = cleaned.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
    cleaned = cleaned.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m[1]!);
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?<!\*)\*([^*]+?)\*(?!\*)'), (m) => m[1]!);
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?<!_)_([^_]+?)_(?!_)'), (m) => m[1]!);
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!);
    cleaned = cleaned.replaceAll(RegExp(r'^(- |\d+\. )', multiLine: true), '');
    final newText = text.substring(0, sel.start) + cleaned + text.substring(sel.end);
    return TextEditResult(
      newText,
      TextSelection(baseOffset: sel.start, extentOffset: sel.start + cleaned.length),
    );
  }

  static String _stripListPrefix(String line) =>
      line.replaceFirst(RegExp(r'^(- |\d+\. )'), '');

  static int _lineStart(String text, int offset) {
    if (offset <= 0) return 0;
    final idx = text.lastIndexOf('\n', offset - 1);
    return idx == -1 ? 0 : idx + 1;
  }

  static int _lineEnd(String text, int offset) {
    final idx = text.indexOf('\n', offset);
    return idx == -1 ? text.length : idx;
  }
}
