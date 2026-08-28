/// Form Contatti — email, telefono, città, indirizzo + lista Link.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';
import 'editable_text_field.dart';

class ContattiForm extends StatelessWidget {
  const ContattiForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final ContattiSection section;

  void _update(BuildContext ctx, ContattiData Function(ContattiData) f) {
    final data = f(section.data);
    ctx
        .read<EditorBloc>()
        .add(SectionAtIndexReplaced(index, section.copyWith(data: data)));
  }

  @override
  Widget build(BuildContext context) {
    final data = section.data;
    final emailErr = data.email != null &&
        data.email!.isNotEmpty &&
        !_looksLikeEmail(data.email!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            Expanded(
              child: EditableTextField(
                key: Key('contatti_email_$index'),
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                initialText: data.email ?? '',
                onChanged: (v) => _update(context,
                    (d) => d.copyWith(email: v.isEmpty ? null : v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditableTextField(
                label: 'Telefono',
                keyboardType: TextInputType.phone,
                initialText: data.telefono ?? '',
                onChanged: (v) => _update(context,
                    (d) => d.copyWith(telefono: v.isEmpty ? null : v)),
              ),
            ),
          ]),
        ),
        if (emailErr)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Email non valida',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            Expanded(
              child: EditableTextField(
                label: 'Città',
                initialText: data.citta ?? '',
                onChanged: (v) => _update(context,
                    (d) => d.copyWith(citta: v.isEmpty ? null : v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: EditableTextField(
                label: 'Indirizzo',
                initialText: data.indirizzo ?? '',
                onChanged: (v) => _update(context,
                    (d) => d.copyWith(indirizzo: v.isEmpty ? null : v)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Link', style: Theme.of(context).textTheme.titleSmall),
        for (var i = 0; i < data.link.length; i++)
          _LinkRow(
            key: ValueKey('contatti_link_${index}_$i'),
            link: data.link[i],
            onChanged: (l) => _update(context, (d) {
              final list = [...d.link];
              list[i] = l;
              return d.copyWith(link: list);
            }),
            onRemove: () => _update(context, (d) {
              final list = [...d.link]..removeAt(i);
              return d.copyWith(link: list);
            }),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('contatti_add_link_$index'),
            onPressed: () => _update(context, (d) {
              return d.copyWith(
                link: [...d.link, const Link(label: '', url: '')],
              );
            }),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi link'),
          ),
        ),
      ],
    );
  }
}

bool _looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.link,
    required this.onChanged,
    required this.onRemove,
  });

  final Link link;
  final ValueChanged<Link> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: EditableTextField(
              label: 'Etichetta',
              initialText: link.label,
              onChanged: (v) => onChanged(link.copyWith(label: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: EditableTextField(
              label: 'URL',
              initialText: link.url,
              onChanged: (v) => onChanged(link.copyWith(url: v)),
            ),
          ),
          IconButton(
            tooltip: 'Rimuovi',
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
