/// Form Anagrafica — campi tipizzati non-Markdown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/cv_section.dart';
import '../../../domain/enums.dart';
import '../editor_bloc.dart';
import 'editable_text_field.dart';

class AnagraficaForm extends StatelessWidget {
  const AnagraficaForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final AnagraficaSection section;

  void _update(BuildContext ctx, AnagraficaData Function(AnagraficaData) f) {
    final data = f(section.data);
    ctx
        .read<EditorBloc>()
        .add(SectionAtIndexReplaced(index, section.copyWith(data: data)));
  }

  @override
  Widget build(BuildContext context) {
    final data = section.data;
    final missing = context.select<EditorBloc, Set<String>>((b) {
      final s = b.state;
      if (s is! EditorReady) return const <String>{};
      return {
        for (final m in s.missing.fields)
          if (m.sectionIndex == index && m.itemId == null) m.field,
      };
    });

    Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row([
          EditableTextField(
            key: Key('anagrafica_nome_$index'),
            label: 'Nome',
            required: true,
            hasError: missing.contains('nome'),
            initialText: data.nome,
            onChanged: (v) => _update(context, (d) => d.copyWith(nome: v)),
          ),
          EditableTextField(
            key: Key('anagrafica_cognome_$index'),
            label: 'Cognome',
            required: true,
            hasError: missing.contains('cognome'),
            initialText: data.cognome,
            onChanged: (v) => _update(context, (d) => d.copyWith(cognome: v)),
          ),
        ]),
        row([
          EditableTextField(
            key: Key('anagrafica_headline_$index'),
            label: 'Headline (breve descrizione)',
            initialText: data.headline ?? '',
            onChanged: (v) => _update(
                context, (d) => d.copyWith(headline: v.isEmpty ? null : v)),
          ),
        ]),
        row([
          EditableTextField(
            label: 'Luogo di nascita',
            initialText: data.luogoNascita ?? '',
            onChanged: (v) => _update(context,
                (d) => d.copyWith(luogoNascita: v.isEmpty ? null : v)),
          ),
          EditableTextField(
            label: 'Nazionalità',
            initialText: data.nazionalita ?? '',
            onChanged: (v) => _update(context,
                (d) => d.copyWith(nazionalita: v.isEmpty ? null : v)),
          ),
        ]),
        row([
          _EnumDropdown<Genere>(
            label: 'Genere',
            value: data.genere,
            values: Genere.values,
            labelOf: _genereLabel,
            onChanged: (g) => _update(context, (d) => d.copyWith(genere: g)),
          ),
          _EnumDropdown<StatoCivile>(
            label: 'Stato civile',
            value: data.statoCivile,
            values: StatoCivile.values,
            labelOf: _statoCivileLabel,
            onChanged: (s) =>
                _update(context, (d) => d.copyWith(statoCivile: s)),
          ),
        ]),
        row([
          EditableTextField(
            label: 'Codice fiscale',
            initialText: data.codiceFiscale ?? '',
            onChanged: (v) => _update(context,
                (d) => d.copyWith(codiceFiscale: v.isEmpty ? null : v)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Foto profilo: disponibile presto.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          isExpanded: true,
          value: value,
          items: [
            const DropdownMenuItem<Never>(value: null, child: Text('—')),
            for (final v in values)
              DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

String _genereLabel(Genere g) => switch (g) {
      Genere.femminile => 'Femminile',
      Genere.maschile => 'Maschile',
      Genere.altro => 'Altro',
      Genere.preferiscoNonSpecificare => 'Preferisco non specificare',
    };

String _statoCivileLabel(StatoCivile s) => switch (s) {
      StatoCivile.celibeNubile => 'Celibe/Nubile',
      StatoCivile.coniugato => 'Coniugato/a',
      StatoCivile.divorziato => 'Divorziato/a',
      StatoCivile.vedovo => 'Vedovo/a',
      StatoCivile.convivente => 'Convivente',
    };
