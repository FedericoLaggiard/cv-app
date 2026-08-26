/// Library screen — lists all CV variants.
///
/// Root of the app (ticket 07).  Powered by [LibraryCubit] and delegates
/// "open variant" to the parent via [onOpenVariant] so the widget tree stays
/// route-agnostic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../repository/cv_repository.dart';
import 'library_cubit.dart';
import 'library_dialogs.dart';
import 'variant_card.dart';

/// The Library screen widget.
///
/// Must be placed below a [BlocProvider<LibraryCubit>] whose cubit has
/// already been asked to `load()` (production wires that via
/// `BlocProvider.create: (_) => LibraryCubit(...)..load()`; tests either
/// do the same or preload their own cubit and inject it via
/// [BlocProvider.value]).  [onOpenVariant] is called when the user taps
/// "Apri" on a variant card or creates/duplicates a variant.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.onOpenVariant});

  final void Function(String variantId)? onOpenVariant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV app'),
        centerTitle: false,
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
              onOpenVariant: onOpenVariant,
              onCreateNew: _handleCreateNew,
            ),
          };
        },
      ),
    );
  }

  // ── handlers ───────────────────────────────────────────────────────────────

  Future<void> _handleCreateNew(BuildContext ctx) async {
    final cubit = ctx.read<LibraryCubit>();
    final action = await showModalBottomSheet<NewVariantAction>(
      context: ctx,
      builder: (_) => const NewVariantMenuSheet(),
    );
    if (action == null || !ctx.mounted) return;
    switch (action) {
      case NewVariantAction.fromScratch:
        final name = await showNewVariantNameDialog(ctx, cubit: cubit);
        if (name == null || !ctx.mounted) return;
        final id = await cubit.createNewNamed(name);
        if (id != null) onOpenVariant?.call(id);
      case NewVariantAction.duplicate:
        await _handleDuplicateFromNew(ctx, cubit);
      case NewVariantAction.fromPdf:
        // Disabled in the sheet; kept in the enum for the later PDF-import
        // ticket.  Reaching this branch should be impossible in practice.
        break;
    }
  }

  Future<void> _handleDuplicateFromNew(
    BuildContext ctx,
    LibraryCubit cubit,
  ) async {
    final state = cubit.state;
    if (state is! LibraryLoaded || state.variants.isEmpty) return;
    final result = await showDuplicateFromNewDialog(
      ctx,
      cubit: cubit,
      variants: state.variants,
    );
    if (result == null) return;
    final newId = await cubit.duplicateVariantAs(result.sourceId, result.name);
    if (newId != null) onOpenVariant?.call(newId);
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
                key: const Key('empty_create_new'),
                onPressed: () => onCreateNew(context),
                icon: const Icon(Icons.add),
                label: const Text('Crea la prima variante'),
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
    final wide = MediaQuery.sizeOf(context).width >= kLibraryWideBreakpoint;
    final children = <Widget>[
      _NewVariantCard(key: const Key('new_variant_card'), onTap: onCreateNew),
      ...variants.map(
        (v) => VariantCard(
          key: Key('variant_card_${v.id}'),
          summary: v,
          onOpen: () => onOpenVariant?.call(v.id),
          formatUpdatedAt: _relativeTime,
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

class _NewVariantCard extends StatelessWidget {
  const _NewVariantCard({super.key, required this.onTap});

  final Future<void> Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kLibraryWideBreakpoint;
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Nuova variante',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
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

/// Returns a relative-time string like "adesso", "oggi", "3 giorni fa".
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
