/// Shell riusato da tutte le sezioni dell'editor (ticket 07).
///
/// Fornisce:
///  * header con drag handle, chevron di collapse, titolo editabile inline,
///    badge ⚠ del conteggio obbligatori mancanti, menu `[⋯]`
///    (Rimuovi sezione / Sposta su/giù/…);
///  * body collassabile;
///  * hook `onRename` per l'edit inline del `displayTitle`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';

class SectionShell extends StatelessWidget {
  const SectionShell({
    super.key,
    required this.index,
    required this.title,
    required this.child,
    required this.missingCount,
    required this.collapsed,
    this.canRemove = true,
    this.canRename = true,
    this.leading,
  });

  final int index;
  final String title;
  final Widget child;
  final int missingCount;
  final bool collapsed;
  final bool canRemove;
  final bool canRename;

  /// Widget aggiuntivo nell'header (prima del titolo, dopo il drag handle).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('section_card_$index'),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            index: index,
            title: title,
            missingCount: missingCount,
            collapsed: collapsed,
            canRemove: canRemove,
            canRename: canRename,
            leading: leading,
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.index,
    required this.title,
    required this.missingCount,
    required this.collapsed,
    required this.canRemove,
    required this.canRename,
    required this.leading,
  });

  final int index;
  final String title;
  final int missingCount;
  final bool collapsed;
  final bool canRemove;
  final bool canRename;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: Key('section_header_$index'),
      onTap: () =>
          context.read<EditorBloc>().add(SectionCollapseToggled(index)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_indicator, size: 20),
              ),
            ),
            Icon(
              collapsed ? Icons.chevron_right : Icons.keyboard_arrow_down,
              key: Key('section_chevron_$index'),
              size: 22,
            ),
            const SizedBox(width: 4),
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: canRename
                  ? _InlineTitleField(index: index, initialTitle: title)
                  : Text(title, style: theme.textTheme.titleMedium),
            ),
            if (missingCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Tooltip(
                  message: '$missingCount campi mancanti',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    key: Key('section_missing_badge_$index'),
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            _SectionMenu(
              index: index,
              canRemove: canRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineTitleField extends StatefulWidget {
  const _InlineTitleField({required this.index, required this.initialTitle});
  final int index;
  final String initialTitle;

  @override
  State<_InlineTitleField> createState() => _InlineTitleFieldState();
}

class _InlineTitleFieldState extends State<_InlineTitleField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
    _focus.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _InlineTitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.initialTitle != _controller.text) {
      _controller.text = widget.initialTitle;
    }
  }

  void _handleFocus() {
    if (!_focus.hasFocus && _editing) {
      _commit();
    }
  }

  void _commit() {
    setState(() => _editing = false);
    final newTitle = _controller.text.trim();
    if (newTitle.isEmpty) {
      _controller.text = widget.initialTitle;
      return;
    }
    if (newTitle == widget.initialTitle) return;
    final bloc = context.read<EditorBloc>();
    final state = bloc.state;
    if (state is! EditorReady) return;
    if (widget.index >= state.document.sections.length) return;
    // Ogni CvSection ha una copyWith che accetta displayTitle; ma la
    // classe base non lo espone tipizzato. Deleghiamo alla concrete via
    // pattern matching nel widget di sezione — qui invece riusiamo una
    // funzione di utilità (definita più sotto).
    final section = state.document.sections[widget.index];
    final replaced = _sectionWithTitle(section, newTitle);
    bloc.add(SectionAtIndexReplaced(widget.index, replaced));
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_editing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _editing = true);
          _focus.requestFocus();
        },
        child: Text(widget.initialTitle, style: theme.textTheme.titleMedium),
      );
    }
    return TextField(
      key: Key('section_title_field_${widget.index}'),
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focus.unfocus(),
      style: theme.textTheme.titleMedium,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({required this.index, required this.canRemove});
  final int index;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SectionAction>(
      key: Key('section_menu_$index'),
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => _handle(context, action),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _SectionAction.moveUp,
          child: Text('Sposta su'),
        ),
        const PopupMenuItem(
          value: _SectionAction.moveDown,
          child: Text('Sposta giù'),
        ),
        const PopupMenuItem(
          value: _SectionAction.moveTop,
          child: Text('Sposta in cima'),
        ),
        const PopupMenuItem(
          value: _SectionAction.moveBottom,
          child: Text('Sposta in fondo'),
        ),
        if (canRemove)
          const PopupMenuItem(
            value: _SectionAction.remove,
            child: Text('Rimuovi sezione'),
          ),
      ],
    );
  }

  Future<void> _handle(BuildContext context, _SectionAction action) async {
    final bloc = context.read<EditorBloc>();
    final state = bloc.state;
    if (state is! EditorReady) return;
    final last = state.document.sections.length - 1;
    switch (action) {
      case _SectionAction.moveUp:
        if (index > 0) bloc.add(SectionReordered(index, index - 1));
      case _SectionAction.moveDown:
        if (index < last) bloc.add(SectionReordered(index, index + 2));
      case _SectionAction.moveTop:
        if (index > 0) bloc.add(SectionReordered(index, 0));
      case _SectionAction.moveBottom:
        if (index < last) bloc.add(SectionReordered(index, last + 1));
      case _SectionAction.remove:
        final title = state.document.sections[index].displayTitle;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Rimuovere "$title"?'),
            content: const Text(
              'I dati della sezione verranno persi. Puoi riaggiungerla '
              'più tardi ma i dati non torneranno.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Rimuovi'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          bloc.add(SectionRemoved(index));
        }
    }
  }
}

enum _SectionAction { moveUp, moveDown, moveTop, moveBottom, remove }

// ─────────────────────────── displayTitle helper ───────────────────────────

/// Restituisce una copia della sezione con `displayTitle` sostituito.
/// Vive qui perché serve al rename inline nel [SectionShell].
CvSection _sectionWithTitle(CvSection section, String newTitle) {
  return switch (section) {
    AnagraficaSection() => section.copyWith(displayTitle: newTitle),
    ContattiSection() => section.copyWith(displayTitle: newTitle),
    SommarioSection() => section.copyWith(displayTitle: newTitle),
    EsperienzeSection() => section.copyWith(displayTitle: newTitle),
    FormazioneSection() => section.copyWith(displayTitle: newTitle),
    SkillSection() => section.copyWith(displayTitle: newTitle),
    LingueSection() => section.copyWith(displayTitle: newTitle),
    CertificazioniSection() => section.copyWith(displayTitle: newTitle),
    CustomSection() => section.copyWith(displayTitle: newTitle),
  };
}

