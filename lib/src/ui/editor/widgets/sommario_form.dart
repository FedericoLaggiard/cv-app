/// Form Sommario — campo rich text Markdown (Slice C).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';
import 'rich_text_field.dart';

class SommarioForm extends StatelessWidget {
  const SommarioForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final SommarioSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RichTextField(
        fieldKey: Key('sommario_field_$index'),
        value: section.markdown,
        placeholder: 'Scrivi un breve sommario…',
        onChanged: (v) => context
            .read<EditorBloc>()
            .add(SectionAtIndexReplaced(index, section.copyWith(markdown: v))),
      ),
    );
  }
}
