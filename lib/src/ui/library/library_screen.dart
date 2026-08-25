/// Library screen — lists all CV variants.
///
/// This screen is the root of the app (ticket 07).  It is powered by
/// [LibraryCubit] and delegates navigation decisions (open variant, etc.)
/// to the parent via callbacks so the widget tree stays route-agnostic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../repository/cv_repository.dart';
import 'library_cubit.dart';

// ─────────────────────────── Screen ────────────────────────────────────────

/// Breakpoint (px) between wide (≥ 900) and narrow layout.
const _kWideBreakpoint = 900.0;

/// The Library screen widget.
///
/// Must be placed below a [BlocProvider<LibraryCubit>] (or supplied one via
/// [BlocProvider.value]).  [onOpenVariant] is called when the user taps
/// "Apri" on a variant card.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.onOpenVariant,
    this.onSettingsTapped,
  });

  final void Function(String variantId)? onOpenVariant;
  final VoidCallback? onSettingsTapped;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<LibraryCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV app'),
        centerTitle: false,
        actions: [
          if (widget.onSettingsTapped != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Impostazioni',
              onPressed: widget.onSettingsTapped,
            ),
        ],
      ),
      body: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          return switch (state) {
            LibraryInitial() || LibraryLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            LibraryError(:final message) => _ErrorBody(message: message),
            LibraryLoaded(:final variants) when variants.isEmpty =>
              _EmptyLibrary(onCreateNew: _handleCreateNew),
            LibraryLoaded(:final variants) => _LibraryGrid(
              variants: variants,
              onOpenVariant: widget.onOpenVariant,
              onCreateNew: _handleCreateNew,
            ),
          };
        },
      ),
    );
  }

  // ── handlers ───────────────────────────────────────────────────────────────

  Future<void> _handleCreateNew(BuildContext ctx) async {
    // Cache before any await to avoid using BuildContext across async gaps.
    final cubit = ctx.read<LibraryCubit>();
    final action = await _showNewVariantMenu(ctx);
    if (!mounted) return;
    if (action == _NewVariantAction.fromScratch) {
      final id = await cubit.createNew();
      if (mounted && id != null) widget.onOpenVariant?.call(id);
    } else if (action == _NewVariantAction.duplicate) {
      if (!mounted) return;
      await _showDuplicateFromNewDialog(context);
    }
    // fromPdf: handled in later tickets (import flow)
  }

  Future<_NewVariantAction?> _showNewVariantMenu(BuildContext ctx) {
    return showModalBottomSheet<_NewVariantAction>(
      context: ctx,
      builder: (_) => const _NewVariantMenuSheet(),
    );
  }

  Future<void> _showDuplicateFromNewDialog(BuildContext ctx) async {
    final cubit = ctx.read<LibraryCubit>();
    final state = cubit.state;
    if (state is! LibraryLoaded || state.variants.isEmpty) return;
    if (!mounted) return;

    final result = await showDialog<({String sourceId, String name})>(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _DuplicateFromNewDialog(variants: state.variants),
      ),
    );
    if (result == null || !mounted) return;
    final newId = await cubit.duplicateVariant(
      result.sourceId,
      newName: result.name,
    );
    if (mounted && newId != null) widget.onOpenVariant?.call(newId);
  }
}

// ─────────────────────────── Empty state ───────────────────────────────────

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onCreateNew});

  final Future<void> Function(BuildContext) onCreateNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Non hai ancora nessuna variante.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              child: FilledButton.icon(
                key: const Key('empty_create_from_scratch'),
                onPressed: () => onCreateNew(context),
                icon: const Icon(Icons.add),
                label: const Text('Crea CV da zero'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: OutlinedButton.icon(
                key: const Key('empty_import_pdf'),
                onPressed: () {/* PDF import — later ticket */},
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Importa da PDF esistente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Grid of cards ─────────────────────────────────

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    required this.variants,
    required this.onOpenVariant,
    required this.onCreateNew,
  });

  final List<VariantSummary> variants;
  final void Function(String)? onOpenVariant;
  final Future<void> Function(BuildContext) onCreateNew;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _kWideBreakpoint;
    final children = [
      _NewVariantCard(key: const Key('new_variant_card'), onTap: onCreateNew),
      ...variants.map(
        (v) => _VariantCard(
          key: Key('variant_card_${v.id}'),
          summary: v,
          onOpen: () => onOpenVariant?.call(v.id),
        ),
      ),
    ];

    if (wide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      separatorBuilder: (_, idx) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    );
  }
}

// ─────────────────────────── New variant card ───────────────────────────────

class _NewVariantCard extends StatelessWidget {
  const _NewVariantCard({super.key, required this.onTap});

  final Future<void> Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _kWideBreakpoint;
    final theme = Theme.of(context);
    return SizedBox(
      width: wide ? 200 : double.infinity,
      height: wide ? 120 : null,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Nuova variante',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Variant card ──────────────────────────────────

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    super.key,
    required this.summary,
    required this.onOpen,
  });

  final VariantSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _kWideBreakpoint;
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
              if (!summary.corrupt) ...[
                const SizedBox(height: 4),
                Text(
                  'aggiornato ${_relativeTime(summary.updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (summary.corrupt)
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'corrotta',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  key: Key('open_variant_${summary.id}'),
                  onPressed: summary.corrupt ? null : onOpen,
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

// ─────────────────────────── Variant popup menu ─────────────────────────────

class _VariantMenu extends StatelessWidget {
  const _VariantMenu({required this.summary});

  final VariantSummary summary;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_VariantMenuAction>(
      key: Key('variant_menu_${summary.id}'),
      tooltip: 'Opzioni',
      onSelected: (action) => _handle(context, action),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _VariantMenuAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rinomina'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: _VariantMenuAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Duplica'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: _VariantMenuAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Elimina'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(BuildContext ctx, _VariantMenuAction action) async {
    switch (action) {
      case _VariantMenuAction.rename:
        final cubit = ctx.read<LibraryCubit>();
        final newName = await showDialog<String>(
          context: ctx,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: _RenameDialog(
              currentName: summary.variantName,
              variantId: summary.id,
            ),
          ),
        );
        if (newName != null) {
          await cubit.renameVariant(summary.id, newName);
        }
      case _VariantMenuAction.duplicate:
        final cubit = ctx.read<LibraryCubit>();
        await cubit.duplicateVariant(summary.id);
      case _VariantMenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: ctx,
          builder: (_) => _DeleteConfirmDialog(variantName: summary.variantName),
        );
        if (confirmed == true) {
          if (!ctx.mounted) return;
          await ctx.read<LibraryCubit>().deleteVariant(summary.id);
        }
    }
  }
}

// ─────────────────────────── Dialogs ───────────────────────────────────────

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.currentName,
    required this.variantId,
  });

  final String currentName;
  final String variantId;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
    _ctrl.addListener(_validate);
  }

  void _validate() {
    final cubit = context.read<LibraryCubit>();
    final trimmed = _ctrl.text.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _error = 'Il nome non può essere vuoto';
      } else if (!cubit.isNameAvailable(
        _ctrl.text,
        excludeId: widget.variantId,
      )) {
        _error = 'Esiste già una variante con questo nome';
      } else {
        _error = null;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _error == null && _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Rinomina variante'),
      content: TextField(
        key: const Key('rename_field'),
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Nome variante',
          errorText: _error,
        ),
        onSubmitted: canSave ? (_) => _confirm() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('rename_confirm'),
          onPressed: canSave ? _confirm : null,
          child: const Text('Salva'),
        ),
      ],
    );
  }

  void _confirm() {
    Navigator.of(context).pop(_ctrl.text.trim());
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.variantName});

  final String variantName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Elimina variante'),
      content: Text(
        'Eliminare "$variantName"? Questa azione non può essere annullata.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('delete_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Elimina'),
        ),
      ],
    );
  }
}

class _DuplicateFromNewDialog extends StatefulWidget {
  const _DuplicateFromNewDialog({required this.variants});

  final List<VariantSummary> variants;

  @override
  State<_DuplicateFromNewDialog> createState() =>
      _DuplicateFromNewDialogState();
}

class _DuplicateFromNewDialogState extends State<_DuplicateFromNewDialog> {
  late String _selectedId;
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.variants.first.id;
    _ctrl = TextEditingController(
      text: _suggestName(widget.variants.first.variantName),
    );
    _ctrl.addListener(_validate);
  }

  String _suggestName(String base) {
    final cubit = context.read<LibraryCubit>();
    if (cubit.isNameAvailable('$base (2)')) return '$base (2)';
    for (var n = 3; n < 1000; n++) {
      final candidate = '$base ($n)';
      if (cubit.isNameAvailable(candidate)) return candidate;
    }
    return '$base (copia)';
  }

  void _validate() {
    final cubit = context.read<LibraryCubit>();
    final trimmed = _ctrl.text.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _error = 'Il nome non può essere vuoto';
      } else if (!cubit.isNameAvailable(_ctrl.text)) {
        _error = 'Esiste già una variante con questo nome';
      } else {
        _error = null;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _error == null && _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Duplica variante'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('duplicate_source_dropdown'),
            initialValue: _selectedId,
            decoration: const InputDecoration(labelText: 'Variante sorgente'),
            items: widget.variants
                .map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(v.variantName),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final variant = widget.variants.firstWhere((v) => v.id == id);
              setState(() {
                _selectedId = id;
                _ctrl.text = _suggestName(variant.variantName);
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('duplicate_name_field'),
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: 'Nome della copia',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('duplicate_confirm'),
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(
                    (sourceId: _selectedId, name: _ctrl.text.trim()),
                  )
              : null,
          child: const Text('Duplica'),
        ),
      ],
    );
  }
}

// ─────────────────────────── New variant menu sheet ────────────────────────

enum _NewVariantAction { fromScratch, fromPdf, duplicate }

class _NewVariantMenuSheet extends StatelessWidget {
  const _NewVariantMenuSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('new_from_scratch'),
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Da zero'),
            onTap: () =>
                Navigator.of(context).pop(_NewVariantAction.fromScratch),
          ),
          ListTile(
            key: const Key('new_from_pdf'),
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Da PDF esistente…'),
            onTap: () => Navigator.of(context).pop(_NewVariantAction.fromPdf),
          ),
          ListTile(
            key: const Key('new_duplicate'),
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Duplica una variante…'),
            onTap: () =>
                Navigator.of(context).pop(_NewVariantAction.duplicate),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Error body ────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<LibraryCubit>().load(),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Helpers ───────────────────────────────────────

enum _VariantMenuAction { rename, duplicate, delete }

/// Returns a relative-time string like "oggi", "ieri", "3 giorni fa".
String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'adesso';
  if (diff.inHours < 1) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24) return 'oggi';
  if (diff.inHours < 48) return 'ieri';
  if (diff.inDays < 7) return '${diff.inDays} giorni fa';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} sett fa';
  return DateFormat('d MMM y', 'it').format(dt.toLocal());
}
