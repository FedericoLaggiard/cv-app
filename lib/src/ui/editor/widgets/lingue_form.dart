/// Form Lingue — lista voci con dropdown CEFR.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/cv_section.dart';
import '../../../domain/enums.dart';
import '../editor_bloc.dart';
import 'editable_text_field.dart';

class LingueForm extends StatelessWidget {
  const LingueForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final LingueSection section;

  void _replace(BuildContext ctx, List<LinguaItem> items) {
    ctx
        .read<EditorBloc>()
        .add(SectionAtIndexReplaced(index, section.copyWith(items: items)));
  }

  @override
  Widget build(BuildContext context) {
    final items = section.items;
    final missingByItem = context.select<EditorBloc, Map<String, Set<String>>>((b) {
      final s = b.state;
      if (s is! EditorReady) return const {};
      final out = <String, Set<String>>{};
      for (final m in s.missing.fields) {
        if (m.sectionIndex != index || m.itemId == null) continue;
        out.putIfAbsent(m.itemId!, () => <String>{}).add(m.field);
      }
      return out;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            key: ValueKey('lingua_${items[i].id}'),
            padding: const EdgeInsets.only(top: 12),
            child: _LinguaRow(
              item: items[i],
              missing: missingByItem[items[i].id] ?? const {},
              onChanged: (u) {
                final list = [...items];
                list[i] = u;
                _replace(context, list);
              },
              onRemove: () {
                final list = [...items]..removeAt(i);
                _replace(context, list);
              },
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('lingue_add_$index'),
            onPressed: () => _replace(context, [
              ...items,
              LinguaItem(
                id: const Uuid().v4(),
                lingua: '',
                livello: LivelloCefr.b1,
              ),
            ]),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi lingua'),
          ),
        ),
      ],
    );
  }
}

class _LinguaRow extends StatelessWidget {
  const _LinguaRow({
    required this.item,
    required this.missing,
    required this.onChanged,
    required this.onRemove,
  });

  final LinguaItem item;
  final Set<String> missing;
  final ValueChanged<LinguaItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: EditableTextField(
            label: 'Lingua',
            required: true,
            hasError: missing.contains('lingua'),
            initialText: item.lingua,
            onChanged: (v) => onChanged(item.copyWith(lingua: v)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Livello',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LivelloCefr>(
                isExpanded: true,
                value: item.livello,
                items: [
                  for (final l in LivelloCefr.values)
                    DropdownMenuItem(value: l, child: Text(_cefrLabel(l))),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(item.copyWith(livello: v));
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: EditableTextField(
            label: 'Certificazione (opz.)',
            initialText: item.certificazione ?? '',
            onChanged: (v) => onChanged(
                item.copyWith(certificazione: v.isEmpty ? null : v)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

String _cefrLabel(LivelloCefr l) => switch (l) {
      LivelloCefr.a1 => 'A1',
      LivelloCefr.a2 => 'A2',
      LivelloCefr.b1 => 'B1',
      LivelloCefr.b2 => 'B2',
      LivelloCefr.c1 => 'C1',
      LivelloCefr.c2 => 'C2',
      LivelloCefr.madrelingua => 'Madrelingua',
    };
