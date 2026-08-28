/// `TextField` che tiene sotto controllo un [TextEditingController] locale
/// ma sincronizza il valore solo quando `initialText` cambia esternamente
/// (nuova versione del documento) e il testo corrente diverge.
///
/// Preserva selezione/cursore mentre l'utente digita e non triggera
/// callback su cambi programmatici.
library;

import 'package:flutter/material.dart';

class EditableTextField extends StatefulWidget {
  const EditableTextField({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.label,
    this.hintText,
    this.required = false,
    this.hasError = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String initialText;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hintText;
  final bool required;
  final bool hasError;
  final TextInputType? keyboardType;
  final int? maxLines;

  @override
  State<EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<EditableTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant EditableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != _controller.text) {
      // Aggiorna solo se il testo diverge (evita di sovrascrivere la
      // digitazione quando il Bloc emette lo stesso valore appena inviato).
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: selection.baseOffset <= widget.initialText.length
            ? selection
            : TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.label != null && widget.required ? '${widget.label} *' : widget.label;
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: widget.hintText,
        isDense: true,
        border: const OutlineInputBorder(),
        errorText: widget.hasError && _controller.text.trim().isEmpty ? '' : null,
      ),
    );
  }
}
