/// Form Formazione — lista voci.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';
import 'editable_text_field.dart';
import 'year_month_field.dart';

class FormazioneForm extends StatelessWidget {
  const FormazioneForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final FormazioneSection section;

  void _replace(BuildContext ctx, List<FormazioneItem> items) {
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
          _FormazioneItemForm(
            key: ValueKey('form_${items[i].id}'),
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('formazione_add_$index'),
            onPressed: () => _replace(context, [
              ...items,
              FormazioneItem(id: const Uuid().v4(), titolo: ''),
            ]),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi titolo di studio'),
          ),
        ),
      ],
    );
  }
}

class _FormazioneItemForm extends StatelessWidget {
  const _FormazioneItemForm({
    super.key,
    required this.item,
    required this.missing,
    required this.onChanged,
    required this.onRemove,
  });

  final FormazioneItem item;
  final Set<String> missing;
  final ValueChanged<FormazioneItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                item.titolo.isEmpty ? 'Nuovo titolo di studio' : item.titolo,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (missing.isNotEmpty)
              Icon(Icons.warning_amber_rounded,
                  color: theme.colorScheme.error, size: 20),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ]),
          EditableTextField(
            label: 'Titolo',
            required: true,
            hasError: missing.contains('titolo'),
            initialText: item.titolo,
            onChanged: (v) => onChanged(item.copyWith(titolo: v)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: EditableTextField(
                label: 'Istituto',
                initialText: item.istituto ?? '',
                onChanged: (v) =>
                    onChanged(item.copyWith(istituto: v.isEmpty ? null : v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditableTextField(
                label: 'Luogo',
                initialText: item.luogo ?? '',
                onChanged: (v) =>
                    onChanged(item.copyWith(luogo: v.isEmpty ? null : v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditableTextField(
                label: 'Voto',
                initialText: item.voto ?? '',
                onChanged: (v) =>
                    onChanged(item.copyWith(voto: v.isEmpty ? null : v)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: YearMonthField(
                  label: 'Data inizio',
                  value: item.startDate,
                  onChanged: (v) => onChanged(item.copyWith(startDate: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: YearMonthField(
                  label: 'Data fine',
                  value: item.endDate,
                  enabled: !item.current,
                  onChanged: (v) => onChanged(item.copyWith(endDate: v)),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: FilterChip(
                  label: const Text('In corso'),
                  selected: item.current,
                  onSelected: (v) => onChanged(item.copyWith(
                      current: v, endDate: v ? null : item.endDate)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EditableTextField(
            label: 'Descrizione (Markdown non ancora disponibile)',
            initialText: item.descrizione ?? '',
            maxLines: 3,
            onChanged: (v) =>
                onChanged(item.copyWith(descrizione: v.isEmpty ? null : v)),
          ),
        ],
      ),
    );
  }
}
