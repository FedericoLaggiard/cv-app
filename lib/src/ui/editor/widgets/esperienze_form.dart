/// Form Esperienze — lista di voci con drag reorder + add/remove.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/cv_section.dart';
import '../../../domain/enums.dart';
import '../../../domain/year_month.dart';
import '../editor_bloc.dart';
import 'editable_text_field.dart';
import 'year_month_field.dart';

class EsperienzeForm extends StatelessWidget {
  const EsperienzeForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final EsperienzeSection section;

  void _replace(BuildContext ctx, List<EsperienzaItem> items) {
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
          _EsperienzaItemForm(
            key: ValueKey('esp_${items[i].id}'),
            item: items[i],
            missing: missingByItem[items[i].id] ?? const {},
            onChanged: (updated) {
              final list = [...items];
              list[i] = updated;
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
            key: Key('esperienze_add_$index'),
            onPressed: () {
              final list = [
                ...items,
                EsperienzaItem(
                  id: const Uuid().v4(),
                  ruolo: '',
                  azienda: '',
                  startDate: YearMonth(DateTime.now().year, 1),
                ),
              ];
              _replace(context, list);
            },
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi esperienza'),
          ),
        ),
      ],
    );
  }
}

class _EsperienzaItemForm extends StatelessWidget {
  const _EsperienzaItemForm({
    super.key,
    required this.item,
    required this.missing,
    required this.onChanged,
    required this.onRemove,
  });

  final EsperienzaItem item;
  final Set<String> missing;
  final ValueChanged<EsperienzaItem> onChanged;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _summary(item),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (missing.isNotEmpty)
                Tooltip(
                  message: '${missing.length} campi mancanti',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ),
              IconButton(
                tooltip: 'Rimuovi voce',
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              ),
            ],
          ),
          Row(children: [
            Expanded(
              child: EditableTextField(
                label: 'Ruolo',
                required: true,
                hasError: missing.contains('ruolo'),
                initialText: item.ruolo,
                onChanged: (v) => onChanged(item.copyWith(ruolo: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditableTextField(
                label: 'Azienda',
                required: true,
                hasError: missing.contains('azienda'),
                initialText: item.azienda,
                onChanged: (v) => onChanged(item.copyWith(azienda: v)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
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
              child: _ModalitaDropdown(
                value: item.modalita,
                onChanged: (m) => onChanged(item.copyWith(modalita: m)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipoContrattoDropdown(
                value: item.tipoContratto,
                onChanged: (t) => onChanged(item.copyWith(tipoContratto: t)),
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
                  required: true,
                  value: item.startDate,
                  onChanged: (v) {
                    if (v == null) return; // startDate obbligatoria
                    onChanged(item.copyWith(startDate: v));
                  },
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
                  onSelected: (v) => onChanged(
                    item.copyWith(current: v, endDate: v ? null : item.endDate),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EditableTextField(
            label: 'Descrizione (Markdown non ancora disponibile)',
            initialText: item.descrizione ?? '',
            maxLines: 4,
            onChanged: (v) =>
                onChanged(item.copyWith(descrizione: v.isEmpty ? null : v)),
          ),
        ],
      ),
    );
  }
}

String _summary(EsperienzaItem it) {
  final parts = <String>[];
  if (it.ruolo.isNotEmpty) parts.add(it.ruolo);
  if (it.azienda.isNotEmpty) parts.add(it.azienda);
  final range = _dateRange(it.startDate, it.endDate, it.current);
  if (range != null) parts.add(range);
  return parts.isEmpty ? 'Nuova esperienza' : parts.join(' · ');
}

String? _dateRange(YearMonth start, YearMonth? end, bool current) {
  final s = '${start.month.toString().padLeft(2, '0')}/${start.year}';
  if (current) return '$s – oggi';
  if (end == null) return s;
  final e = '${end.month.toString().padLeft(2, '0')}/${end.year}';
  return '$s – $e';
}

class _ModalitaDropdown extends StatelessWidget {
  const _ModalitaDropdown({required this.value, required this.onChanged});
  final ModalitaLavoro? value;
  final ValueChanged<ModalitaLavoro?> onChanged;
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Modalità',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ModalitaLavoro?>(
            isExpanded: true,
            value: value,
            items: const [
              DropdownMenuItem<Never>(value: null, child: Text('—')),
              DropdownMenuItem(value: ModalitaLavoro.inSede, child: Text('In sede')),
              DropdownMenuItem(value: ModalitaLavoro.remoto, child: Text('Remoto')),
              DropdownMenuItem(value: ModalitaLavoro.ibrido, child: Text('Ibrido')),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}

class _TipoContrattoDropdown extends StatelessWidget {
  const _TipoContrattoDropdown({required this.value, required this.onChanged});
  final TipoContratto? value;
  final ValueChanged<TipoContratto?> onChanged;
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Contratto',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<TipoContratto?>(
            isExpanded: true,
            value: value,
            items: const [
              DropdownMenuItem<Never>(value: null, child: Text('—')),
              DropdownMenuItem(value: TipoContratto.fullTime, child: Text('Full-time')),
              DropdownMenuItem(value: TipoContratto.partTime, child: Text('Part-time')),
              DropdownMenuItem(value: TipoContratto.freelance, child: Text('Freelance')),
              DropdownMenuItem(value: TipoContratto.stage, child: Text('Stage')),
              DropdownMenuItem(value: TipoContratto.consulenza, child: Text('Consulenza')),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}
