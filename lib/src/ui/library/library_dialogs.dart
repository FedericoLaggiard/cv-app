/// Dialogs used by the Library screen — all [StatelessWidget]s backed by
/// small form cubits ([NameFieldCubit], [DuplicateFromNewCubit]) that
/// own their [TextEditingController]s and their validation state.  This
/// keeps the widget tree stateless while [Cubit.close] handles disposal.
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

// ─────────────────────────── NameFieldCubit ────────────────────────────────

class NameFieldState {
  /// `null` = valid, non-null = human-readable error message.
  final String? error;
  const NameFieldState(this.error);

  bool get isValid => error == null;

  @override
  bool operator ==(Object other) =>
      other is NameFieldState && other.error == error;
  @override
  int get hashCode => error.hashCode;
}

/// Owns a [TextEditingController] and re-validates against
/// [LibraryCubit.validateName] on every keystroke.  Disposal of the
/// controller happens in [close].
class NameFieldCubit extends Cubit<NameFieldState> {
  final TextEditingController controller;
  final LibraryCubit _library;
  final String? _excludeId;

  NameFieldCubit({
    required LibraryCubit libraryCubit,
    required String initialText,
    String? excludeId,
  })  : controller = TextEditingController(text: initialText)
          ..selection = TextSelection(
            baseOffset: 0,
            extentOffset: initialText.length,
          ),
        _library = libraryCubit,
        _excludeId = excludeId,
        super(NameFieldState(
          libraryCubit.validateName(initialText, excludeId: excludeId),
        )) {
    controller.addListener(_onChange);
  }

  void _onChange() {
    emit(NameFieldState(
      _library.validateName(controller.text, excludeId: _excludeId),
    ));
  }

  /// Overwrites the field text and re-validates immediately.  Used by
  /// [DuplicateFromNewCubit] when the source dropdown changes.
  void setText(String next) {
    controller.text = next;
    // The listener re-emits automatically.
  }

  String get trimmedText => controller.text.trim();

  @override
  Future<void> close() {
    controller.removeListener(_onChange);
    controller.dispose();
    return super.close();
  }
}

// ─────────────────────────── Single-name dialog ────────────────────────────

/// A stateless dialog with one name field + Annulla / [confirmLabel] actions.
/// Wraps everything in a [BlocProvider] for its own [NameFieldCubit], which
/// owns the [TextEditingController] and lives exactly as long as the dialog.
class _SingleNameDialog extends StatelessWidget {
  const _SingleNameDialog({
    required this.libraryCubit,
    required this.title,
    required this.initialName,
    required this.confirmLabel,
    required this.fieldKey,
    required this.confirmKey,
    this.excludeId,
  });

  final LibraryCubit libraryCubit;
  final String title;
  final String initialName;
  final String confirmLabel;
  final Key fieldKey;
  final Key confirmKey;
  final String? excludeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NameFieldCubit>(
      create: (_) => NameFieldCubit(
        libraryCubit: libraryCubit,
        initialText: initialName,
        excludeId: excludeId,
      ),
      child: _SingleNameDialogBody(
        title: title,
        confirmLabel: confirmLabel,
        fieldKey: fieldKey,
        confirmKey: confirmKey,
      ),
    );
  }
}

class _SingleNameDialogBody extends StatelessWidget {
  const _SingleNameDialogBody({
    required this.title,
    required this.confirmLabel,
    required this.fieldKey,
    required this.confirmKey,
  });

  final String title;
  final String confirmLabel;
  final Key fieldKey;
  final Key confirmKey;

  void _confirm(BuildContext context) {
    final field = context.read<NameFieldCubit>();
    if (!field.state.isValid) return;
    Navigator.of(context).pop(field.trimmedText);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: _NameFieldView(
        fieldKey: fieldKey,
        labelText: 'Nome variante',
        onSubmit: () => _confirm(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        BlocBuilder<NameFieldCubit, NameFieldState>(
          builder: (context, state) => FilledButton(
            key: confirmKey,
            onPressed: state.isValid ? () => _confirm(context) : null,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}

/// The [TextField] that reads from an ambient [NameFieldCubit] (owns the
/// controller) and rebuilds when validation state changes.  Kept as a
/// [StatelessWidget]: the controller lifetime is the cubit's, not this
/// widget's.
class _NameFieldView extends StatelessWidget {
  const _NameFieldView({
    required this.fieldKey,
    required this.labelText,
    required this.onSubmit,
    this.autofocus = true,
  });

  final Key fieldKey;
  final String labelText;
  final VoidCallback onSubmit;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NameFieldCubit, NameFieldState>(
      builder: (context, state) {
        final cubit = context.read<NameFieldCubit>();
        return TextField(
          key: fieldKey,
          controller: cubit.controller,
          autofocus: autofocus,
          decoration: InputDecoration(
            labelText: labelText,
            errorText: state.error,
          ),
          onSubmitted: state.isValid ? (_) => onSubmit() : null,
        );
      },
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
    builder: (_) => _SingleNameDialog(
      libraryCubit: cubit,
      title: 'Rinomina variante',
      initialName: currentName,
      confirmLabel: 'Salva',
      fieldKey: const Key('rename_field'),
      confirmKey: const Key('rename_confirm'),
      excludeId: variantId,
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
    builder: (_) => _SingleNameDialog(
      libraryCubit: cubit,
      title: 'Duplica variante',
      initialName: suggested,
      confirmLabel: 'Duplica',
      fieldKey: const Key('duplicate_name_field'),
      confirmKey: const Key('duplicate_confirm'),
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
    builder: (_) => _SingleNameDialog(
      libraryCubit: cubit,
      title: 'Nuova variante',
      initialName: suggested,
      confirmLabel: 'Crea',
      fieldKey: const Key('new_variant_name_field'),
      confirmKey: const Key('new_variant_confirm'),
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

// ─────────────────────────── DuplicateFromNewCubit ─────────────────────────

class DuplicateFromNewState {
  final String selectedId;
  const DuplicateFromNewState(this.selectedId);

  @override
  bool operator ==(Object other) =>
      other is DuplicateFromNewState && other.selectedId == selectedId;
  @override
  int get hashCode => selectedId.hashCode;
}

/// Owns the dropdown selection AND the name field's cubit for the
/// "Duplica da Nuova" dialog — the two are coupled because changing the
/// source auto-refills the name.
class DuplicateFromNewCubit extends Cubit<DuplicateFromNewState> {
  final LibraryCubit _library;
  final List<VariantSummary> _variants;
  late final NameFieldCubit nameField;

  DuplicateFromNewCubit({
    required LibraryCubit libraryCubit,
    required List<VariantSummary> variants,
  })  : _library = libraryCubit,
        _variants = variants,
        super(DuplicateFromNewState(variants.first.id)) {
    nameField = NameFieldCubit(
      libraryCubit: libraryCubit,
      initialText: libraryCubit.suggestDuplicateName(variants.first.variantName),
    );
  }

  void selectSource(String id) {
    final variant = _variants.firstWhere((v) => v.id == id);
    nameField.setText(_library.suggestDuplicateName(variant.variantName));
    emit(DuplicateFromNewState(id));
  }

  @override
  Future<void> close() async {
    await nameField.close();
    return super.close();
  }
}

// ─────────────────────────── Duplicate from Nuova dialog ───────────────────

class _DuplicateFromNewDialog extends StatelessWidget {
  const _DuplicateFromNewDialog({
    required this.libraryCubit,
    required this.variants,
  });

  final LibraryCubit libraryCubit;
  final List<VariantSummary> variants;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DuplicateFromNewCubit>(
      create: (_) => DuplicateFromNewCubit(
        libraryCubit: libraryCubit,
        variants: variants,
      ),
      child: _DuplicateFromNewDialogBody(variants: variants),
    );
  }
}

class _DuplicateFromNewDialogBody extends StatelessWidget {
  const _DuplicateFromNewDialogBody({required this.variants});

  final List<VariantSummary> variants;

  void _confirm(BuildContext context) {
    final form = context.read<DuplicateFromNewCubit>();
    if (!form.nameField.state.isValid) return;
    Navigator.of(context).pop(DuplicateSelection(
      sourceId: form.state.selectedId,
      name: form.nameField.trimmedText,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final form = context.read<DuplicateFromNewCubit>();
    return AlertDialog(
      title: const Text('Duplica variante'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<DuplicateFromNewCubit, DuplicateFromNewState>(
            builder: (context, state) => DropdownButtonFormField<String>(
              key: const Key('duplicate_source_dropdown'),
              initialValue: state.selectedId,
              decoration:
                  const InputDecoration(labelText: 'Variante sorgente'),
              items: variants
                  .map(
                    (v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(v.variantName),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null) form.selectSource(id);
              },
            ),
          ),
          const SizedBox(height: 16),
          BlocProvider<NameFieldCubit>.value(
            value: form.nameField,
            child: _NameFieldView(
              fieldKey: const Key('duplicate_from_new_name_field'),
              labelText: 'Nome della copia',
              autofocus: false,
              onSubmit: () => _confirm(context),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        BlocProvider<NameFieldCubit>.value(
          value: form.nameField,
          child: BlocBuilder<NameFieldCubit, NameFieldState>(
            builder: (context, state) => FilledButton(
              key: const Key('duplicate_from_new_confirm'),
              onPressed:
                  state.isValid ? () => _confirm(context) : null,
              child: const Text('Duplica'),
            ),
          ),
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
    builder: (_) => _DuplicateFromNewDialog(
      libraryCubit: cubit,
      variants: variants,
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
