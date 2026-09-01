/// Toolbar di formattazione per [RichTextField] — azioni:
/// bold, italic, elenco puntato, elenco numerato, link, rimuovi
/// formattazione, incolla come testo semplice.
library;

import 'package:flutter/material.dart';

class RichTextToolbar extends StatelessWidget {
  const RichTextToolbar({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onUnorderedList,
    required this.onOrderedList,
    required this.onLink,
    required this.onClearFormatting,
    required this.onPasteAsPlainText,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnorderedList;
  final VoidCallback onOrderedList;
  final VoidCallback onLink;
  final VoidCallback onClearFormatting;
  final VoidCallback onPasteAsPlainText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback onPressed, Key key) =>
        IconButton(
          key: key,
          icon: Icon(icon, size: 20),
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
        );

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Icons.format_bold, 'Grassetto (Cmd/Ctrl+B)', onBold,
                const Key('rt_toolbar_bold')),
            button(Icons.format_italic, 'Corsivo (Cmd/Ctrl+I)', onItalic,
                const Key('rt_toolbar_italic')),
            button(Icons.format_list_bulleted, 'Elenco puntato', onUnorderedList,
                const Key('rt_toolbar_ul')),
            button(Icons.format_list_numbered, 'Elenco numerato', onOrderedList,
                const Key('rt_toolbar_ol')),
            button(Icons.link, 'Link (Cmd/Ctrl+K)', onLink, const Key('rt_toolbar_link')),
            button(Icons.format_clear, 'Rimuovi formattazione', onClearFormatting,
                const Key('rt_toolbar_clear')),
            button(Icons.content_paste_go, 'Incolla come testo semplice (Cmd/Ctrl+Shift+V)',
                onPasteAsPlainText, const Key('rt_toolbar_paste_plain')),
          ],
        ),
      ),
    );
  }
}
