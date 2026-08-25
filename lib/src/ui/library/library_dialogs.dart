/// Dialogs used by the Library screen.
///
/// Each dialog validates against [LibraryCubit.validateName] so the
/// "univocità hard" rule (ticket 14) has a single source of truth.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repository/cv_repository.dart';
import 'library_cubit.dart';

// ─────────────────────────── Result types ──────────────────────────────────

/// Choice picked from the "Nuova variante" bottom sheet.
enum NewVariantAction { fromScratch, fromPdf, duplicate }

/// Result of the "Duplica da Nuova" dialog: source variant + new name.
class DuplicateSelection {
  final String sourceId;
  final String name;
  const DuplicateSelection({required this.sourceId, required this.name});
}

// ─────────────────────────── Shared name field ─────────────────────────────

/// A [TextField] bound to [controller] that shows the validation error from
/// [LibraryCubit.validateName].  Used by every dialog that takes a name.
class _NameField extends StatefulWidget {
  const _NameField({
    required this.controller,
    required this.labelText,
    required this.excludeId,
    this.autofocus = true,
    this.fieldKey,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String labelText;

  /// If set, the id of the variant being renamed — excluded from the clash
  /// check so its current name doesn't count as a conflict.
  final String? excludeId;
  final bool autofocus;
  final Key? fieldKey;
  final VoidCallback? onSubmit;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    final error = cubit.validateName(
      widget.controller.text,
      excludeId: widget.excludeId,
    );
    final canSubmit = error == null && widget.onSubmit != null;
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: error,
      ),
      onSubmitted: canSubmit ? (_) => widget.onSubmit!() : null,
    );
  }
}

/// Returns `true` when the name in [controller] is a valid (non-empty,
/// non-clashing) submission — used by dialog confirm buttons.
bool _canConfirm(
  BuildContext context,
  TextEditingController controller, {
  String? excludeId,
}) {
  return context
          .read<LibraryCubit>()
          .validateName(controller.text, excludeId: excludeId) ==
      null;
}

// ─────────────────────────── Name-only dialogs ─────────────────────────────

/// Base for the three "single name field" dialogs: rename, duplicate-from-card,
/// and create-from-scratch.  Each specialisation just changes the title,
/// initial text, and confirm-button label.
class _SingleNameDialog extends StatefulWidget {
  const _SingleNameDialog({
    required this.title,
    required this.initialName,
    required this.confirmLabel,
    required this.fieldKey,
    required this.confirmKey,
    this.excludeId,
  });

  final String title;
  final String initialName;
  final String confirmLabel;
  final Key fieldKey;
  final Key confirmKey;
  final String? excludeId;

  @override
  State<_SingleNameDialog> createState() => _SingleNameDialogState();
}

class _SingleNameDialogState extends State<_SingleNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_canConfirm(context, _ctrl, excludeId: widget.excludeId)) return;
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: _NameField(
        controller: _ctrl,
        labelText: 'Nome variante',
        excludeId: widget.excludeId,
        fieldKey: widget.fieldKey,
        onSubmit: _confirm,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: widget.confirmKey,
          onPressed: _canConfirm(context, _ctrl, excludeId: widget.excludeId)
              ? _confirm
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Shows the rename dialog for [variantId] (pre-populated with [currentName]).
/// Returns the trimmed new name, or `null` on cancel.
Future<String?> showRenameVariantDialog(
  BuildContext context, {
  required LibraryCubit cubit,
  required String variantId,
  required String currentName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _SingleNameDialog(
        title: 'Rinomina variante',
        initialName: currentName,
        confirmLabel: 'Salva',
        fieldKey: const Key('rename_field'),
        confirmKey: const Key('rename_confirm'),
        excludeId: variantId,
      ),
    ),
  );
}

/// Shows the "Duplica" dialog when triggered from a variant card's [⋯] menu:
/// pre-fills the name with the next free `<orig> (N)` suggestion.  Returns
/// the trimmed name, or `null` on cancel.
Future<String?> showDuplicateFromCardDialog(
  BuildContext context, {
  required LibraryCubit cubit,
  required String sourceName,
}) {
  final suggested = cubit.suggestDuplicateName(sourceName);
  return showDialog<String>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _SingleNameDialog(
        title: 'Duplica variante',
        initialName: suggested,
        confirmLabel: 'Duplica',
        fieldKey: const Key('duplicate_name_field'),
        confirmKey: const Key('duplicate_confirm'),
      ),
    ),
  );
}

/// Shows the "Da zero" dialog: single name field pre-filled with the next
/// free "Nuova variante N" suggestion.  Returns the trimmed name, or `null`
/// on cancel.
Future<String?> showNewVariantNameDialog(
  BuildContext context, {
  required LibraryCubit cubit,
}) {
  final suggested = cubit.suggestNewVariantName();
  return showDialog<String>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _SingleNameDialog(
        title: 'Nuova variante',
        initialName: suggested,
        confirmLabel: 'Crea',
        fieldKey: const Key('new_variant_name_field'),
        confirmKey: const Key('new_variant_confirm'),
      ),
    ),
  );
}

// ─────────────────────────── Delete confirm ────────────────────────────────

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

/// Shows the delete-confirmation dialog for [variantName].  Returns `true`
/// if the user confirmed, `false` or `null` otherwise.
Future<bool?> showDeleteVariantDialog(
  BuildContext context, {
  required String variantName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DeleteConfirmDialog(variantName: variantName),
  );
}

// ─────────────────────────── Duplicate from Nuova ──────────────────────────

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

  @override
  void initState() {
    super.initState();
    _selectedId = widget.variants.first.id;
    // Cubit is available in initState via BlocProvider.value above.
    _ctrl = TextEditingController();
    // Fill the initial suggestion in the first frame (cubit lookup needs
    // an inherited widget lookup, safe from initState via context.read).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<LibraryCubit>();
      _ctrl.text = cubit.suggestDuplicateName(widget.variants.first.variantName);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_canConfirm(context, _ctrl)) return;
    Navigator.of(context).pop(
      DuplicateSelection(sourceId: _selectedId, name: _ctrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              final cubit = context.read<LibraryCubit>();
              setState(() {
                _selectedId = id;
                _ctrl.text = cubit.suggestDuplicateName(variant.variantName);
              });
            },
          ),
          const SizedBox(height: 16),
          _NameField(
            controller: _ctrl,
            labelText: 'Nome della copia',
            excludeId: null,
            autofocus: false,
            fieldKey: const Key('duplicate_from_new_name_field'),
            onSubmit: _confirm,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('duplicate_from_new_confirm'),
          onPressed: _canConfirm(context, _ctrl) ? _confirm : null,
          child: const Text('Duplica'),
        ),
      ],
    );
  }
}

/// Shows the "Duplica" dialog when triggered from the "Nuova" card:
/// dropdown of source variants + editable name.  Returns `null` on cancel.
Future<DuplicateSelection?> showDuplicateFromNewDialog(
  BuildContext context, {
  required LibraryCubit cubit,
  required List<VariantSummary> variants,
}) {
  return showDialog<DuplicateSelection>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DuplicateFromNewDialog(variants: variants),
    ),
  );
}

// ─────────────────────────── New-variant sheet ─────────────────────────────

/// Bottom sheet shown when the user taps the "Nuova" card.  Offers the three
/// entry-point actions from ticket 07: Da zero / Da PDF esistente / Duplica.
///
/// "Da PDF esistente" is disabled because the PDF import flow lands with a
/// later ticket — but the entry point must exist in this slice per the spec.
class NewVariantMenuSheet extends StatelessWidget {
  const NewVariantMenuSheet({super.key});

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
                Navigator.of(context).pop(NewVariantAction.fromScratch),
          ),
          ListTile(
            key: const Key('new_from_pdf'),
            enabled: false,
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Da PDF esistente…'),
            subtitle: const Text('Disponibile in un prossimo aggiornamento'),
            onTap: () => Navigator.of(context).pop(NewVariantAction.fromPdf),
          ),
          ListTile(
            key: const Key('new_duplicate'),
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Duplica una variante…'),
            onTap: () =>
                Navigator.of(context).pop(NewVariantAction.duplicate),
          ),
        ],
      ),
    );
  }
}
