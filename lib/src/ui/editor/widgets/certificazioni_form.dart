/// Form Certificazioni — lista voci.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';
import 'editable_text_field.dart';
import 'year_month_field.dart';

class CertificazioniForm extends StatelessWidget {
  const CertificazioniForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final CertificazioniSection section;

  void _replace(BuildContext ctx, List<CertificazioneItem> items) {
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
          _CertRow(
            key: ValueKey('cert_${items[i].id}'),
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
            key: Key('cert_add_$index'),
            onPressed: () => _replace(context, [
              ...items,
              CertificazioneItem(
                id: const Uuid().v4(),
                nome: '',
                ente: '',
              ),
            ]),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi certificazione'),
          ),
        ),
      ],
    );
  }
}

class _CertRow extends StatelessWidget {
  const _CertRow({
    super.key,
    required this.item,
    required this.missing,
    required this.onChanged,
    required this.onRemove,
  });

  final CertificazioneItem item;
  final Set<String> missing;
  final ValueChanged<CertificazioneItem> onChanged;
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
                item.nome.isEmpty ? 'Nuova certificazione' : item.nome,
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
          Row(children: [
            Expanded(
              child: EditableTextField(
                label: 'Nome',
                required: true,
                hasError: missing.contains('nome'),
                initialText: item.nome,
                onChanged: (v) => onChanged(item.copyWith(nome: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditableTextField(
                label: 'Ente',
                required: true,
                hasError: missing.contains('ente'),
                initialText: item.ente,
                onChanged: (v) => onChanged(item.copyWith(ente: v)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: YearMonthField(
                label: 'Conseguimento',
                value: item.dataConseguimento,
                onChanged: (v) =>
                    onChanged(item.copyWith(dataConseguimento: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: YearMonthField(
                label: 'Scadenza',
                value: item.dataScadenza,
                onChanged: (v) => onChanged(item.copyWith(dataScadenza: v)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: EditableTextField(
                label: 'Codice',
                initialText: item.codice ?? '',
                onChanged: (v) =>
                    onChanged(item.copyWith(codice: v.isEmpty ? null : v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: EditableTextField(
                label: 'URL di verifica',
                initialText: item.urlVerifica ?? '',
                onChanged: (v) => onChanged(
                    item.copyWith(urlVerifica: v.isEmpty ? null : v)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
