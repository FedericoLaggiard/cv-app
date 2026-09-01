/// Campo di testo rich (Markdown) riusabile per Sommario, blob Skill e
/// sezioni Custom (ticket 07/22 — Slice C).
///
/// Implementazione = **Approccio A** documentato dal ticket 06 come
/// fallback reversibile a `super_editor`: un `TextField` multi-linea +
/// toolbar custom che manipola direttamente la sintassi Markdown. Il testo
/// nel campo *è* già il Markdown salvato in `.cvapp`, senza nessuna
/// (de)serializzazione intermedia. Motivazione della scelta:
/// `docs/adr/0001-rich-text-field-fallback.md`.
///
/// API pubblica stabile per restare compatibile con un eventuale swap
/// futuro verso `super_editor`: `(value, onChanged, focusNode, key)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'markdown_text_ops.dart';
import 'rich_text_toolbar.dart';

class RichTextField extends StatefulWidget {
  const RichTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.fieldKey,
    this.placeholder,
    this.minLines = 3,
    this.maxLines,
  });

  /// Markdown corrente del campo.
  final String value;

  /// Chiamata a ogni edit con il nuovo Markdown.
  final ValueChanged<String> onChanged;

  final FocusNode? focusNode;

  /// Key del [TextField] interno, separata dalla key del widget (che serve
  /// da handle per [RichTextFieldState], es. per `TestHooks`).
  final Key? fieldKey;

  final String? placeholder;
  final int minLines;
  final int? maxLines;

  @override
  State<RichTextField> createState() => RichTextFieldState();
}

class RichTextFieldState extends State<RichTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  final UndoHistoryController _undoController = UndoHistoryController();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant RichTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: selection.baseOffset <= widget.value.length
            ? selection
            : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    _undoController.dispose();
    super.dispose();
  }

  /// Backdoor per `TestHooks.setEditorContent` (ticket 17): imposta il
  /// contenuto senza passare dalla tastiera virtuale.
  void setContentForTest(String markdown) {
    _controller.value = TextEditingValue(
      text: markdown,
      selection: TextSelection.collapsed(offset: markdown.length),
    );
    widget.onChanged(markdown);
  }

  void _applyEdit(TextEditResult result) {
    _controller.value = TextEditingValue(text: result.text, selection: result.selection);
    widget.onChanged(result.text);
  }

  void _toggleBold() =>
      _applyEdit(MarkdownTextOps.toggleInlineMarker(_controller.text, _controller.selection, '**'));

  void _toggleItalic() =>
      _applyEdit(MarkdownTextOps.toggleInlineMarker(_controller.text, _controller.selection, '_'));

  void _toggleUnorderedList() => _applyEdit(
      MarkdownTextOps.toggleList(_controller.text, _controller.selection, ordered: false));

  void _toggleOrderedList() => _applyEdit(
      MarkdownTextOps.toggleList(_controller.text, _controller.selection, ordered: true));

  void _clearFormatting() =>
      _applyEdit(MarkdownTextOps.clearFormatting(_controller.text, _controller.selection));

  Future<void> _insertLink() async {
    final selection = _controller.selection;
    final selectedText = selection.isValid && !selection.isCollapsed
        ? _controller.text.substring(selection.start, selection.end)
        : '';
    final result = await showDialog<_LinkDialogResult>(
      context: context,
      builder: (_) => _LinkDialog(initialLabel: selectedText),
    );
    if (result == null) return;
    _applyEdit(MarkdownTextOps.insertLink(
      _controller.text,
      _controller.selection,
      url: result.url,
      label: result.label.isEmpty ? result.url : result.label,
    ));
  }

  Future<void> _pasteAsPlainText() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null) return;
    final sel = _controller.selection;
    final start = sel.start < 0 ? _controller.text.length : sel.start;
    final end = sel.end < 0 ? _controller.text.length : sel.end;
    final newText = _controller.text.replaceRange(start, end, text);
    _applyEdit(TextEditResult(newText, TextSelection.collapsed(offset: start + text.length)));
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyB, meta: true): _BoldIntent(),
        SingleActivator(LogicalKeyboardKey.keyB, control: true): _BoldIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, meta: true): _ItalicIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, control: true): _ItalicIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): _LinkIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _LinkIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true, shift: true): _PastePlainIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): _PastePlainIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _BoldIntent: CallbackAction<_BoldIntent>(onInvoke: (_) {
            _toggleBold();
            return null;
          }),
          _ItalicIntent: CallbackAction<_ItalicIntent>(onInvoke: (_) {
            _toggleItalic();
            return null;
          }),
          _LinkIntent: CallbackAction<_LinkIntent>(onInvoke: (_) {
            _insertLink();
            return null;
          }),
          _PastePlainIntent: CallbackAction<_PastePlainIntent>(onInvoke: (_) {
            _pasteAsPlainText();
            return null;
          }),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_focused)
              RichTextToolbar(
                onBold: _toggleBold,
                onItalic: _toggleItalic,
                onUnorderedList: _toggleUnorderedList,
                onOrderedList: _toggleOrderedList,
                onLink: _insertLink,
                onClearFormatting: _clearFormatting,
                onPasteAsPlainText: _pasteAsPlainText,
              ),
            TextField(
              key: widget.fieldKey,
              controller: _controller,
              focusNode: _focusNode,
              undoController: _undoController,
              minLines: widget.minLines,
              maxLines: widget.maxLines ?? (widget.minLines < 8 ? 8 : widget.minLines),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: _focused
                      ? const BorderRadius.vertical(bottom: Radius.circular(4))
                      : BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoldIntent extends Intent {
  const _BoldIntent();
}

class _ItalicIntent extends Intent {
  const _ItalicIntent();
}

class _LinkIntent extends Intent {
  const _LinkIntent();
}

class _PastePlainIntent extends Intent {
  const _PastePlainIntent();
}

class _LinkDialogResult {
  const _LinkDialogResult(this.url, this.label);
  final String url;
  final String label;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initialLabel});
  final String initialLabel;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _urlController = TextEditingController();
  late final TextEditingController _labelController =
      TextEditingController(text: widget.initialLabel);

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  static const _hostlessSchemes = {'mailto', 'tel'};

  bool get _isValidUrl {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null || !uri.hasScheme) return false;
    if (_hostlessSchemes.contains(uri.scheme)) return uri.path.isNotEmpty;
    return uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aggiungi link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('rt_link_dialog_url'),
            controller: _urlController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://…',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rt_link_dialog_label'),
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Testo del link'),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('rt_link_dialog_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('rt_link_dialog_confirm'),
          onPressed: _isValidUrl
              ? () => Navigator.of(context).pop(
                    _LinkDialogResult(_urlController.text.trim(), _labelController.text.trim()),
                  )
              : null,
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}
