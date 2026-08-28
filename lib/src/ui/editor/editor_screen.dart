/// Editor CV — schermata principale (ticket 07 / Slice B).
///
/// Layout responsive:
///  * ≥ 900 px: due colonne (sidebar-indice + scroll unico);
///  * < 900 px: colonna singola con bottom-sheet indice attivato dal
///    pulsante ☰ nella top bar.
///
/// Ogni sezione è un widget dedicato che parla al [EditorBloc] tramite
/// `SectionAtIndexReplaced`. Il riordino globale usa un
/// `ReorderableListView` in cui il drag handle vive nell'header di ogni
/// sezione (`SectionShell`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/cv_section.dart';
import '../../repository/cv_repository.dart';
import 'editor_bloc.dart';
import 'widgets/add_section_dialog.dart';
import 'widgets/anagrafica_form.dart';
import 'widgets/certificazioni_form.dart';
import 'widgets/contatti_form.dart';
import 'widgets/editable_text_field.dart';
import 'widgets/esperienze_form.dart';
import 'widgets/formazione_form.dart';
import 'widgets/lingue_form.dart';
import 'widgets/section_shell.dart';
import 'widgets/skill_form.dart';

/// Breakpoint tra layout largo e mobile (ticket 07).
const double kEditorWideBreakpoint = 900;

/// Restituisce (creandola alla prima richiesta) la [GlobalKey] della
/// sezione all'indice dato, così il jump-to dell'indice può portarla in
/// vista con `Scrollable.ensureVisible`.
typedef SectionKeyLookup = GlobalKey Function(int index);

class EditorScreen extends StatelessWidget {
  const EditorScreen({
    super.key,
    required this.variantId,
    required this.repository,
    this.onBack,
  });

  final String variantId;
  final CvRepository repository;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      create: (_) =>
          EditorBloc(repository: repository)..add(EditorStarted(variantId)),
      child: _EditorView(onBack: onBack),
    );
  }
}

class _EditorView extends StatelessWidget {
  const _EditorView({this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        return switch (state) {
          EditorInitial() || EditorLoading() =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          EditorLoadError(:final message) => Scaffold(
              appBar: AppBar(
                leading: BackButton(onPressed: onBack),
                title: const Text('Editor'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Errore: $message',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          EditorReady() => _EditorReadyView(state: state, onBack: onBack),
        };
      },
    );
  }
}

class _EditorReadyView extends StatefulWidget {
  const _EditorReadyView({required this.state, this.onBack});
  final EditorReady state;
  final VoidCallback? onBack;

  @override
  State<_EditorReadyView> createState() => _EditorReadyViewState();
}

class _EditorReadyViewState extends State<_EditorReadyView> {
  /// Una [GlobalKey] per sezione, usata dal jump-to dell'indice per
  /// portare la sezione in vista. Vive qui, sopra entrambe le colonne,
  /// perché la sidebar e il corpo dell'editor sono rami separati
  /// dell'albero: la funzione viene passata a mano (e non via
  /// [InheritedWidget]) così funziona anche dal bottom sheet, che è una
  /// route a sé e non vedrebbe nessun ancestor condiviso.
  final Map<int, GlobalKey> _keys = {};

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kEditorWideBreakpoint;
    return Scaffold(
      appBar: _EditorTopBar(
        state: state,
        wide: wide,
        onBack: widget.onBack,
        keyFor: _keyFor,
      ),
      body: wide
          ? _WideLayout(state: state, keyFor: _keyFor)
          : _MobileLayout(state: state, keyFor: _keyFor),
    );
  }
}

// ─────────────────────────── Top bar ───────────────────────────────────────

class _EditorTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditorTopBar({
    required this.state,
    required this.wide,
    required this.keyFor,
    this.onBack,
  });

  final EditorReady state;
  final bool wide;
  final SectionKeyLookup keyFor;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: BackButton(onPressed: onBack ?? () => Navigator.maybePop(context)),
      title: Row(
        children: [
          if (!wide)
            IconButton(
              tooltip: 'Indice',
              icon: const Icon(Icons.menu),
              onPressed: () => _openIndexSheet(context, state, keyFor),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: EditableTextField(
              key: const Key('editor_variant_name'),
              initialText: state.document.variantName,
              onChanged: (v) =>
                  context.read<EditorBloc>().add(VariantNameChanged(v)),
            ),
          ),
        ],
      ),
      titleSpacing: 8,
      actions: [
        _SaveIndicator(status: state.saveStatus, dirty: state.dirty),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.status, required this.dirty});
  final SaveStatus status;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (status.isError) {
      return TextButton.icon(
        key: const Key('save_indicator_error'),
        onPressed: () =>
            context.read<EditorBloc>().add(const SaveRetryRequested()),
        icon: Icon(Icons.warning_amber_rounded,
            color: theme.colorScheme.error),
        label: Text('Errore [Riprova]',
            style: TextStyle(color: theme.colorScheme.error)),
      );
    }
    if (status.isSaving) {
      return const Row(
        key: Key('save_indicator_saving'),
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 6),
          Text('Salvataggio…'),
        ],
      );
    }
    if (dirty) {
      return const Row(
        key: Key('save_indicator_dirty'),
        children: [
          Icon(Icons.circle, size: 10),
          SizedBox(width: 6),
          Text('Modificato'),
        ],
      );
    }
    return const Row(
      key: Key('save_indicator_saved'),
      children: [
        Icon(Icons.check, size: 16),
        SizedBox(width: 4),
        Text('Salvato'),
      ],
    );
  }
}

// ─────────────────────────── Layouts ───────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.state, required this.keyFor});
  final EditorReady state;
  final SectionKeyLookup keyFor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 240,
          child: _Sidebar(state: state, keyFor: keyFor),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _EditorBody(state: state, keyFor: keyFor)),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.state, required this.keyFor});
  final EditorReady state;
  final SectionKeyLookup keyFor;

  @override
  Widget build(BuildContext context) {
    return _EditorBody(state: state, keyFor: keyFor);
  }
}

Future<void> _openIndexSheet(
  BuildContext context,
  EditorReady state,
  SectionKeyLookup keyFor,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => BlocProvider.value(
      value: context.read<EditorBloc>(),
      child: SafeArea(
        child: _Sidebar(
          state: state,
          keyFor: keyFor,
          onJumpTo: () => Navigator.of(sheetCtx).pop(),
        ),
      ),
    ),
  );
}

// ─────────────────────────── Sidebar / indice ──────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    required this.keyFor,
    this.onJumpTo,
  });
  final EditorReady state;
  final SectionKeyLookup keyFor;
  final VoidCallback? onJumpTo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Indice', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: state.document.sections.length,
              itemBuilder: (_, i) {
                final s = state.document.sections[i];
                final missing = state.missing.countForSection(i);
                return ListTile(
                  key: Key('index_entry_$i'),
                  dense: true,
                  title: Text(s.displayTitle),
                  trailing: missing > 0
                      ? Icon(Icons.warning_amber_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.error)
                      : null,
                  onTap: () {
                    context
                        .read<EditorBloc>()
                        .add(SectionExpanded(i));
                    onJumpTo?.call();
                    _scrollTo(keyFor, i);
                  },
                );
              },
            ),
          ),
          const Divider(),
          FilledButton.tonalIcon(
            key: const Key('sidebar_add_section'),
            onPressed: () => _handleAdd(context),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi sezione'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('sidebar_collapse_all'),
                  onPressed: () => context
                      .read<EditorBloc>()
                      .add(const AllSectionsCollapseSet(true)),
                  child: const Text('Comprimi tutte'),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('sidebar_expand_all'),
                  onPressed: () => context
                      .read<EditorBloc>()
                      .add(const AllSectionsCollapseSet(false)),
                  child: const Text('Espandi tutte'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _handleAdd(BuildContext context) async {
  final bloc = context.read<EditorBloc>();
  final s = bloc.state;
  if (s is! EditorReady) return;
  final choice = await showAddSectionDialog(context, document: s.document);
  if (choice == null) return;
  if (choice.customTitle != null) {
    bloc.add(SectionAdded.custom(choice.customTitle!));
  } else {
    bloc.add(SectionAdded.fixed(choice.kind));
  }
}

void _scrollTo(SectionKeyLookup keyFor, int index) {
  final ctx = keyFor(index).currentContext;
  if (ctx != null) {
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      alignment: 0.1,
    );
  }
}

// ─────────────────────────── Body / scroll unico ───────────────────────────

class _EditorBody extends StatelessWidget {
  const _EditorBody({required this.state, required this.keyFor});
  final EditorReady state;
  final SectionKeyLookup keyFor;

  @override
  Widget build(BuildContext context) {
    final doc = state.document;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: doc.sections.length + 1,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex >= doc.sections.length) return;
        if (newIndex > doc.sections.length) {
          newIndex = doc.sections.length;
        }
        context
            .read<EditorBloc>()
            .add(SectionReordered(oldIndex, newIndex));
      },
      itemBuilder: (context, i) {
        if (i == doc.sections.length) {
          return Padding(
            key: const ValueKey('editor_add_section_footer'),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: OutlinedButton.icon(
              key: const Key('editor_add_section'),
              onPressed: () => _handleAdd(context),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi sezione'),
            ),
          );
        }
        final section = doc.sections[i];
        return Container(
          key: ValueKey('section_${_sectionKey(section)}'),
          child: KeyedSubtree(
            key: keyFor(i),
            child: SectionShell(
              index: i,
              title: section.displayTitle,
              missingCount: state.missing.countForSection(i),
              collapsed: state.isCollapsed(i),
              child: _sectionBody(section, i),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionBody(CvSection s, int index) => switch (s) {
        AnagraficaSection() => AnagraficaForm(index: index, section: s),
        ContattiSection() => ContattiForm(index: index, section: s),
        SommarioSection() => const _RichTextPlaceholder(
            name: 'Sommario',
          ),
        EsperienzeSection() => EsperienzeForm(index: index, section: s),
        FormazioneSection() => FormazioneForm(index: index, section: s),
        SkillSection() => SkillForm(index: index, section: s),
        LingueSection() => LingueForm(index: index, section: s),
        CertificazioniSection() =>
          CertificazioniForm(index: index, section: s),
        CustomSection() => const _RichTextPlaceholder(name: 'Sezione custom'),
      };
}

String _sectionKey(CvSection s) => switch (s) {
      CustomSection(:final id) => 'custom_$id',
      _ => s.kind.wire,
    };

class _RichTextPlaceholder extends StatelessWidget {
  const _RichTextPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name: editor di testo ricco disponibile presto.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
