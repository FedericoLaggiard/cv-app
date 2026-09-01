/// Form per le sezioni Custom — campo rich text Markdown (Slice C).
/// Il titolo è già editabile via header (`SectionShell`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';
import 'rich_text_field.dart';

class CustomSectionForm extends StatelessWidget {
  const CustomSectionForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final CustomSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RichTextField(
        fieldKey: Key('custom_field_$index'),
        value: section.markdown,
        placeholder: 'Scrivi il contenuto della sezione…',
        onChanged: (v) => context
            .read<EditorBloc>()
            .add(SectionAtIndexReplaced(index, section.copyWith(markdown: v))),
      ),
    );
  }
}
