/// Form Skill — chip input per i tag + blob Markdown (Slice C).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/cv_section.dart';
import '../editor_bloc.dart';
import 'rich_text_field.dart';

class SkillForm extends StatefulWidget {
  const SkillForm({
    super.key,
    required this.index,
    required this.section,
  });

  final int index;
  final SkillSection section;

  @override
  State<SkillForm> createState() => _SkillFormState();
}

class _SkillFormState extends State<SkillForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replaceTags(List<String> tags) {
    final section =
        widget.section.copyWith(data: widget.section.data.copyWith(tags: tags));
    context
        .read<EditorBloc>()
        .add(SectionAtIndexReplaced(widget.index, section));
  }

  void _updateMarkdown(String markdown) {
    final section =
        widget.section.copyWith(data: widget.section.data.copyWith(markdown: markdown));
    context
        .read<EditorBloc>()
        .add(SectionAtIndexReplaced(widget.index, section));
  }

  void _addFromController() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    final existing = widget.section.data.tags;
    if (existing.any((t) => t.toLowerCase() == v.toLowerCase())) {
      _controller.clear();
      return;
    }
    _replaceTags([...existing, v]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.section.data.tags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tags)
                InputChip(
                  key: Key('skill_tag_$t'),
                  label: Text(t),
                  onDeleted: () => _replaceTags(
                    tags.where((x) => x != t).toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              key: Key('skill_tag_input_${widget.index}'),
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Aggiungi tag',
                hintText: 'es. Flutter, Dart, Kubernetes',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addFromController(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _addFromController,
            child: const Text('Aggiungi'),
          ),
        ]),
        const SizedBox(height: 12),
        RichTextField(
          fieldKey: Key('skill_markdown_${widget.index}'),
          value: widget.section.data.markdown ?? '',
          placeholder: 'Descrizione libera delle competenze…',
          onChanged: _updateMarkdown,
        ),
      ],
    );
  }
}
