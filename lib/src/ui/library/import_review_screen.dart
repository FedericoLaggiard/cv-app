/// Import review step (ticket 52): the "cambio di rotta" screen shown after
/// a PDF import instead of opening the editor directly. Summarizes what the
/// heuristics understood, highlights the fields the [ImportProposalReport]
/// marks uncertain, lets the user correct them inline, and lets them assign
/// unattributed "Da rivedere" lines to a field — all without leaving this
/// screen. Confirming saves the (possibly edited) [CvDocument] as a new
/// variant and discards the report (ADR 0002); cancelling creates nothing.
library;

import 'package:flutter/material.dart';

import '../../domain/cv_document.dart';
import '../../domain/cv_section.dart';
import '../../domain/year_month.dart';
import '../../pdf/import_proposal_report.dart';
import '../../pdf/pdf_import_heuristics.dart' show tryParseFreeTextYearMonth;

/// Pushed by `pdf_import_flow.dart` after a [FilledOutcome]. Returns the
/// (possibly edited) [CvDocument] via `Navigator.pop` on confirm, or `null`
/// on cancel.
class ImportReviewScreen extends StatefulWidget {
  const ImportReviewScreen({
    super.key,
    required this.doc,
    required this.report,
  });

  final CvDocument doc;
  final ImportProposalReport report;

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  late CvDocument _doc;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewLines = _daRivedereLines(_doc);

    return Scaffold(
      appBar: AppBar(title: const Text('Rivedi import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            _summary(_doc),
            key: const Key('import_review_summary'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ..._buildSectionCards(context),
          if (reviewLines.isNotEmpty) ...[
            const Divider(height: 32),
            Text('Da rivedere', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in reviewLines)
              _ReviewLineTile(
                key: ValueKey('review_line_${line.index}_${line.text}'),
                text: line.text,
                targets: _availableTargets(context),
                onAssign: (target) => _assignLine(line, target),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('import_review_cancel'),
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  key: const Key('import_review_confirm'),
                  onPressed: () => Navigator.of(context).pop(_doc),
                  child: const Text('Conferma'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── summary ────────────────────────────────────────────────────────────

  String _summary(CvDocument doc) {
    final parts = <String>[];
    void addCount(int n, String singular, String plural) {
      if (n == 0) return;
      parts.add('$n ${n == 1 ? singular : plural}');
    }

    for (final section in doc.sections) {
      switch (section) {
        case EsperienzeSection(:final items):
          addCount(items.length, 'esperienza', 'esperienze');
        case FormazioneSection(:final items):
          addCount(items.length, 'formazione', 'formazione');
        case LingueSection(:final items):
          addCount(items.length, 'lingua', 'lingue');
        case CertificazioniSection(:final items):
          addCount(items.length, 'certificazione', 'certificazioni');
        case SkillSection(:final data):
          addCount(data.tags.length, 'skill', 'skill');
        case AnagraficaSection():
        case ContattiSection():
        case SommarioSection():
        case CustomSection():
          break;
      }
    }
    if (parts.isEmpty) {
      return 'Nessun campo strutturato riconosciuto: guarda "Da rivedere" qui sotto.';
    }
    return 'Ho capito: ${parts.join(', ')}.';
  }

  // ── section cards ──────────────────────────────────────────────────────

  List<Widget> _buildSectionCards(BuildContext context) {
    final cards = <Widget>[];
    for (final section in _doc.sections) {
      switch (section) {
        case ContattiSection(:final data):
          cards.add(
            _FieldCard(
              title: 'Contatti',
              children: [
                _uncertainField(
                  field: 'contatti.email',
                  label: 'Email',
                  value: data.email ?? '',
                  onChanged: (v) => _updateContatti(data.copyWith(email: v)),
                ),
                _uncertainField(
                  field: 'contatti.telefono',
                  label: 'Telefono',
                  value: data.telefono ?? '',
                  onChanged: (v) => _updateContatti(data.copyWith(telefono: v)),
                ),
              ],
            ),
          );
        case EsperienzeSection(:final items):
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            cards.add(
              _FieldCard(
                title: 'Esperienza ${i + 1}',
                children: [
                  _DateRangeEditor(
                    key: ValueKey('field_esperienze[$i].dateRange'),
                    field: 'esperienze[$i].dateRange',
                    start: item.startDate,
                    end: item.endDate,
                    current: item.current,
                    uncertain: widget.report.isUncertain(
                      'esperienze[$i].dateRange',
                    ),
                    onChanged: (start, end, current) => _updateEsperienza(
                      i,
                      item.copyWith(
                        startDate: start ?? item.startDate,
                        endDate: end,
                        current: current,
                      ),
                    ),
                  ),
                  _uncertainField(
                    field: 'esperienze[$i].descrizione',
                    label: 'Descrizione',
                    value: item.descrizione ?? '',
                    maxLines: 4,
                    onChanged: (v) => _updateEsperienza(
                      i,
                      item.copyWith(descrizione: v.isEmpty ? null : v),
                    ),
                  ),
                ],
              ),
            );
          }
        case FormazioneSection(:final items):
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            cards.add(
              _FieldCard(
                title: 'Formazione ${i + 1}',
                children: [
                  _DateRangeEditor(
                    key: ValueKey('field_formazione[$i].dateRange'),
                    field: 'formazione[$i].dateRange',
                    start: item.startDate,
                    end: item.endDate,
                    current: item.current,
                    uncertain: widget.report.isUncertain(
                      'formazione[$i].dateRange',
                    ),
                    onChanged: (start, end, current) => _updateFormazione(
                      i,
                      item.copyWith(
                        startDate: start,
                        endDate: end,
                        current: current,
                      ),
                    ),
                  ),
                  _uncertainField(
                    field: 'formazione[$i].descrizione',
                    label: 'Descrizione',
                    value: item.descrizione ?? '',
                    maxLines: 4,
                    onChanged: (v) => _updateFormazione(
                      i,
                      item.copyWith(descrizione: v.isEmpty ? null : v),
                    ),
                  ),
                ],
              ),
            );
          }
        case CertificazioniSection(:final items):
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            cards.add(
              _FieldCard(
                title: 'Certificazione',
                children: [
                  _uncertainField(
                    field: 'certificazioni[$i].nome',
                    label: 'Nome',
                    value: item.nome,
                    onChanged: (v) =>
                        _updateCertificazione(i, item.copyWith(nome: v)),
                  ),
                ],
              ),
            );
          }
        case SkillSection(:final data):
          cards.add(
            _FieldCard(
              title: 'Skill',
              children: [
                _uncertainField(
                  field: 'skill.markdown',
                  label: 'Skill',
                  value: data.markdown ?? '',
                  maxLines: 4,
                  onChanged: (v) => _updateSkill(
                    data.copyWith(markdown: v.isEmpty ? null : v),
                  ),
                ),
              ],
            ),
          );
        case LingueSection(:final items):
          cards.add(
            _FieldCard(
              title: 'Lingue',
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${item.lingua} — ${item.livello.name}'),
                  ),
              ],
            ),
          );
        case AnagraficaSection():
        case SommarioSection():
        case CustomSection():
          break;
      }
    }
    return cards;
  }

  Widget _uncertainField({
    required String field,
    required String label,
    required String value,
    required void Function(String) onChanged,
    int maxLines = 1,
  }) {
    final uncertain = widget.report.isUncertain(field);
    return _UncertainField(
      key: ValueKey('field_$field'),
      field: field,
      label: label,
      value: value,
      uncertain: uncertain,
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }

  // ── mutations ──────────────────────────────────────────────────────────

  void _updateContatti(ContattiData data) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is ContattiSection) s.copyWith(data: data) else s,
        ],
      );
    });
  }

  void _updateEsperienza(int index, EsperienzaItem item) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is EsperienzeSection)
              s.copyWith(items: _replaceAt(s.items, index, item))
            else
              s,
        ],
      );
    });
  }

  void _updateFormazione(int index, FormazioneItem item) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is FormazioneSection)
              s.copyWith(items: _replaceAt(s.items, index, item))
            else
              s,
        ],
      );
    });
  }

  void _updateCertificazione(int index, CertificazioneItem item) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is CertificazioniSection)
              s.copyWith(items: _replaceAt(s.items, index, item))
            else
              s,
        ],
      );
    });
  }

  List<T> _replaceAt<T>(List<T> items, int index, T value) => [
    for (var i = 0; i < items.length; i++) i == index ? value : items[i],
  ];

  void _updateSkill(SkillData data) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is SkillSection) s.copyWith(data: data) else s,
        ],
      );
    });
  }

  // ── "Da rivedere" assignment ──────────────────────────────────────────

  List<_ReviewLine> _daRivedereLines(CvDocument doc) {
    final section = _daRivedereSection(doc);
    if (section == null) return [];
    final lines = section.markdown.split('\n');
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty) _ReviewLine(i, lines[i].trim()),
    ];
  }

  CustomSection? _daRivedereSection(CvDocument doc) {
    for (final s in doc.sections) {
      if (s is CustomSection && s.displayTitle == 'Da rivedere') return s;
    }
    return null;
  }

  List<_AssignTarget> _availableTargets(BuildContext context) {
    final targets = <_AssignTarget>[];
    for (final section in _doc.sections) {
      switch (section) {
        case SommarioSection(:final markdown):
          targets.add(
            _AssignTarget(
              'Sommario',
              (line) => _appendToSommario(line, markdown),
            ),
          );
        case SkillSection(:final data):
          targets.add(
            _AssignTarget('Skill', (line) => _appendToSkill(line, data)),
          );
        case EsperienzeSection(:final items):
          for (var i = 0; i < items.length; i++) {
            targets.add(
              _AssignTarget(
                'Esperienza ${i + 1}',
                (line) => _appendToEsperienza(i, line, items[i]),
              ),
            );
          }
        case FormazioneSection(:final items):
          for (var i = 0; i < items.length; i++) {
            targets.add(
              _AssignTarget(
                'Formazione ${i + 1}',
                (line) => _appendToFormazione(i, line, items[i]),
              ),
            );
          }
        case AnagraficaSection():
        case ContattiSection():
        case LingueSection():
        case CertificazioniSection():
        case CustomSection():
          break;
      }
    }
    if (!_doc.sections.whereType<SommarioSection>().any((_) => true)) {
      targets.add(
        _AssignTarget('Sommario (nuovo)', (line) => _createSommario(line)),
      );
    }
    return targets;
  }

  String _appendLine(String? existing, String line) =>
      (existing == null || existing.isEmpty) ? line : '$existing\n$line';

  void _appendToSommario(String line, String existing) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is SommarioSection)
              s.copyWith(markdown: _appendLine(existing, line))
            else
              s,
        ],
      );
    });
  }

  void _createSommario(String line) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          ..._doc.sections,
          SommarioSection(displayTitle: 'Sommario', markdown: line),
        ],
      );
    });
  }

  void _appendToSkill(String line, SkillData existing) {
    setState(() {
      _doc = _doc.copyWith(
        sections: [
          for (final s in _doc.sections)
            if (s is SkillSection)
              s.copyWith(
                data: existing.copyWith(
                  markdown: _appendLine(existing.markdown, line),
                ),
              )
            else
              s,
        ],
      );
    });
  }

  void _appendToEsperienza(int index, String line, EsperienzaItem item) {
    _updateEsperienza(
      index,
      item.copyWith(descrizione: _appendLine(item.descrizione, line)),
    );
  }

  void _appendToFormazione(int index, String line, FormazioneItem item) {
    _updateFormazione(
      index,
      item.copyWith(descrizione: _appendLine(item.descrizione, line)),
    );
  }

  void _assignLine(_ReviewLine line, _AssignTarget target) {
    final section = _daRivedereSection(_doc);
    if (section == null) return;
    final lines = section.markdown.split('\n');
    final remaining = [
      for (var i = 0; i < lines.length; i++)
        if (i != line.index) lines[i],
    ].join('\n').trim();

    target.apply(line.text);

    setState(() {
      _doc = _doc.copyWith(
        sections: remaining.isEmpty
            ? [
                for (final s in _doc.sections)
                  if (!(s is CustomSection && s.displayTitle == 'Da rivedere'))
                    s,
              ]
            : [
                for (final s in _doc.sections)
                  if (s is CustomSection && s.displayTitle == 'Da rivedere')
                    s.copyWith(markdown: remaining)
                  else
                    s,
              ],
      );
    });
  }
}

// ── small private widgets/helpers ──────────────────────────────────────

class _ReviewLine {
  final int index;
  final String text;
  const _ReviewLine(this.index, this.text);
}

class _AssignTarget {
  final String label;
  final void Function(String line) apply;
  const _AssignTarget(this.label, this.apply);
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Editable month/year date range, highlighted when the
/// [ImportProposalReport] marks [field] uncertain (ticket 52). Each side is
/// free text in `MM/YYYY` form, reparsed on change via
/// [tryParseFreeTextYearMonth] — an unparseable edit is kept on screen but
/// not propagated until it resolves to a valid month/year.
class _DateRangeEditor extends StatefulWidget {
  const _DateRangeEditor({
    super.key,
    required this.field,
    required this.start,
    required this.end,
    required this.current,
    required this.uncertain,
    required this.onChanged,
  });

  final String field;
  final YearMonth? start;
  final YearMonth? end;
  final bool current;
  final bool uncertain;
  final void Function(YearMonth? start, YearMonth? end, bool current) onChanged;

  @override
  State<_DateRangeEditor> createState() => _DateRangeEditorState();
}

class _DateRangeEditorState extends State<_DateRangeEditor> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late bool _current;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: _fmt(widget.start));
    _endController = TextEditingController(text: _fmt(widget.end));
    _current = widget.current;
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  String _fmt(YearMonth? ym) =>
      ym == null ? '' : '${ym.month.toString().padLeft(2, '0')}/${ym.year}';

  void _propagate() {
    widget.onChanged(
      tryParseFreeTextYearMonth(_startController.text),
      _current ? null : tryParseFreeTextYearMonth(_endController.text),
      _current,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('field_${widget.field}_start'),
              controller: _startController,
              onChanged: (_) => _propagate(),
              decoration: InputDecoration(
                labelText: 'Inizio (MM/AAAA)',
                isDense: true,
                suffixIcon: widget.uncertain
                    ? Icon(
                        Icons.warning_amber_rounded,
                        key: Key('uncertain_marker_${widget.field}'),
                        color: theme.colorScheme.error,
                      )
                    : null,
                filled: widget.uncertain,
                fillColor: widget.uncertain
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _current
                ? const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('In corso'),
                  )
                : TextField(
                    key: ValueKey('field_${widget.field}_end'),
                    controller: _endController,
                    onChanged: (_) => _propagate(),
                    decoration: const InputDecoration(
                      labelText: 'Fine (MM/AAAA)',
                      isDense: true,
                    ),
                  ),
          ),
          Checkbox(
            key: ValueKey('field_${widget.field}_current'),
            value: _current,
            onChanged: (value) {
              setState(() => _current = value ?? false);
              _propagate();
            },
          ),
        ],
      ),
    );
  }
}

/// A single editable field, highlighted when the [ImportProposalReport]
/// marks it uncertain (ticket 52).
class _UncertainField extends StatefulWidget {
  const _UncertainField({
    super.key,
    required this.field,
    required this.label,
    required this.value,
    required this.uncertain,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String field;
  final String label;
  final String value;
  final bool uncertain;
  final int maxLines;
  final void Function(String) onChanged;

  @override
  State<_UncertainField> createState() => _UncertainFieldState();
}

class _UncertainFieldState extends State<_UncertainField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _controller,
        maxLines: widget.maxLines,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          suffixIcon: widget.uncertain
              ? Icon(
                  Icons.warning_amber_rounded,
                  key: Key('uncertain_marker_${widget.field}'),
                  color: theme.colorScheme.error,
                )
              : null,
          filled: widget.uncertain,
          fillColor: widget.uncertain
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
              : null,
        ),
      ),
    );
  }
}

class _ReviewLineTile extends StatelessWidget {
  const _ReviewLineTile({
    super.key,
    required this.text,
    required this.targets,
    required this.onAssign,
  });

  final String text;
  final List<_AssignTarget> targets;
  final void Function(_AssignTarget) onAssign;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(text),
        trailing: targets.isEmpty
            ? null
            : PopupMenuButton<_AssignTarget>(
                key: const Key('review_line_assign'),
                tooltip: 'Assegna a un campo',
                icon: const Icon(Icons.drive_file_move_outline),
                onSelected: onAssign,
                itemBuilder: (context) => [
                  for (final target in targets)
                    PopupMenuItem(value: target, child: Text(target.label)),
                ],
              ),
      ),
    );
  }
}
