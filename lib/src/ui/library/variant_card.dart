/// Single variant card + the [⋯] actions menu.
///
/// The menu adapts to the viewport (ticket 14):
///  - width ≥ 900 px → anchored [PopupMenuButton];
///  - width  < 900 px → [showModalBottomSheet].
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repository/cv_repository.dart';
import 'library_cubit.dart';
import 'library_dialogs.dart';

/// Breakpoint (px) between wide (≥ 900) and narrow layout.  Shared by the
/// Library screen; kept here so the card's menu dispatch matches it.
const double kLibraryWideBreakpoint = 900.0;

enum VariantMenuAction { rename, duplicate, export, delete }

class VariantCard extends StatelessWidget {
  const VariantCard({
    super.key,
    required this.summary,
    required this.onOpen,
    required this.formatUpdatedAt,
  });

  final VariantSummary summary;
  final VoidCallback onOpen;
  final String Function(DateTime) formatUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kLibraryWideBreakpoint;
    final theme = Theme.of(context);

    return SizedBox(
      width: wide ? 200 : double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.variantName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _VariantMenu(summary: summary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'aggiornato ${formatUpdatedAt(summary.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  key: Key('open_variant_${summary.id}'),
                  onPressed: onOpen,
                  child: const Text('Apri'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantMenu extends StatelessWidget {
  const _VariantMenu({required this.summary});

  final VariantSummary summary;

  static const _items = <(VariantMenuAction, IconData, String)>[
    (VariantMenuAction.rename, Icons.edit_outlined, 'Rinomina'),
    (VariantMenuAction.duplicate, Icons.copy_outlined, 'Duplica'),
    (VariantMenuAction.export, Icons.ios_share_outlined, 'Esporta'),
    (VariantMenuAction.delete, Icons.delete_outline, 'Elimina'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kLibraryWideBreakpoint;
    final key = Key('variant_menu_${summary.id}');
    if (wide) {
      return PopupMenuButton<VariantMenuAction>(
        key: key,
        tooltip: 'Opzioni',
        onSelected: (action) => _handle(context, action),
        itemBuilder: (_) => [
          for (final (value, icon, label) in _items)
            PopupMenuItem(
              value: value,
              child: ListTile(
                leading: Icon(icon),
                title: Text(label),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
        ],
      );
    }
    // Narrow: bottom sheet with the same actions (ticket 14).
    return IconButton(
      key: key,
      tooltip: 'Opzioni',
      icon: const Icon(Icons.more_vert),
      onPressed: () async {
        final action = await showModalBottomSheet<VariantMenuAction>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, icon, label) in _items)
                  ListTile(
                    leading: Icon(icon),
                    title: Text(label),
                    onTap: () => Navigator.of(context).pop(value),
                  ),
              ],
            ),
          ),
        );
        if (action == null) return;
        if (!context.mounted) return;
        await _handle(context, action);
      },
    );
  }

  Future<void> _handle(BuildContext ctx, VariantMenuAction action) async {
    final cubit = ctx.read<LibraryCubit>();
    switch (action) {
      case VariantMenuAction.rename:
        final newName = await showRenameVariantDialog(
          ctx,
          cubit: cubit,
          variantId: summary.id,
          currentName: summary.variantName,
        );
        if (newName != null) {
          await cubit.renameVariant(summary.id, newName);
        }
      case VariantMenuAction.duplicate:
        final name = await showDuplicateFromCardDialog(
          ctx,
          cubit: cubit,
          sourceName: summary.variantName,
        );
        if (name != null) {
          await cubit.duplicateVariantAs(summary.id, name);
        }
      case VariantMenuAction.export:
        // Export UI (file picker + share sheet) lands with a later ticket.
        // The menu item is spec'd in ticket 07 so the entry point exists;
        // the actual bytes are produced by `CvRepository.exportToBytes`.
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Esporta: disponibile in un prossimo aggiornamento'),
          ),
        );
      case VariantMenuAction.delete:
        final confirmed = await showDeleteVariantDialog(
          ctx,
          variantName: summary.variantName,
        );
        if (confirmed == true) {
          await cubit.deleteVariant(summary.id);
        }
    }
  }
}
