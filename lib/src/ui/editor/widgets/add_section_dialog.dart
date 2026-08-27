/// Dialog `Aggiungi sezione` (ticket 07): radio delle sezioni fisse
/// mancanti + opzione "Sezione personalizzata" con `displayTitle` libero.
library;

import 'package:flutter/material.dart';

import '../../../domain/cv_document.dart';
import '../../../domain/enums.dart';

/// Payload restituito dal dialog: `kind` fisso oppure `custom` con titolo.
class AddSectionChoice {
  final SectionKind kind;
  final String? customTitle;
  const AddSectionChoice.fixed(this.kind) : customTitle = null;
  const AddSectionChoice.custom(String title)
      : kind = SectionKind.custom,
        customTitle = title;
}

Future<AddSectionChoice?> showAddSectionDialog(
  BuildContext context, {
  required CvDocument document,
}) {
  final presentKinds = {
    for (final s in document.sections)
      if (s.kind.isFixed) s.kind,
  };
  final missingFixed =
      SectionKind.values.where((k) => k.isFixed && !presentKinds.contains(k));

  final normalizedTitles = {
    for (final s in document.sections) s.displayTitle.trim().toLowerCase(),
  };

  return showDialog<AddSectionChoice>(
    context: context,
    builder: (_) => _AddSectionDialog(
      missingFixed: missingFixed.toList(),
      normalizedTitles: normalizedTitles,
    ),
  );
}

class _AddSectionDialog extends StatefulWidget {
  const _AddSectionDialog({
    required this.missingFixed,
    required this.normalizedTitles,
  });

  final List<SectionKind> missingFixed;
  final Set<String> normalizedTitles;

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  /// Unica sorgente di verità della scelta: `SectionKind.custom` è
  /// l'opzione "Sezione personalizzata", tutti gli altri valori sono le
  /// sezioni fisse non ancora presenti. Così i due gruppi di radio del
  /// wireframe restano un `RadioGroup` solo.
  late SectionKind _selected;
  final _titleCtrl = TextEditingController();
  String? _customError;

  bool get _custom => _selected == SectionKind.custom;

  @override
  void initState() {
    super.initState();
    _selected = widget.missingFixed.isNotEmpty
        ? widget.missingFixed.first
        : SectionKind.custom;
    _titleCtrl.addListener(_validateCustom);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _validateCustom() {
    final v = _titleCtrl.text.trim();
    setState(() {
      if (!_custom) {
        _customError = null;
      } else if (v.isEmpty) {
        _customError = 'Titolo obbligatorio';
      } else if (widget.normalizedTitles.contains(v.toLowerCase())) {
        _customError = 'Titolo già usato';
      } else {
        _customError = null;
      }
    });
  }

  bool get _canSubmit {
    if (_custom) {
      return _customError == null && _titleCtrl.text.trim().isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aggiungi sezione'),
      content: SingleChildScrollView(
        child: RadioGroup<SectionKind>(
          groupValue: _selected,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selected = v);
            _validateCustom();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.missingFixed.isNotEmpty) ...[
                Text(
                  'Sezioni standard (non presenti)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                for (final k in widget.missingFixed)
                  RadioListTile<SectionKind>(
                    key: Key('add_section_fixed_${k.wire}'),
                    dense: true,
                    title: Text(_fixedLabel(k)),
                    value: k,
                  ),
                const Divider(),
              ],
              const RadioListTile<SectionKind>(
                key: Key('add_section_custom_radio'),
                dense: true,
                title: Text('Sezione personalizzata'),
                value: SectionKind.custom,
              ),
              if (_custom)
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 8, top: 4),
                  child: TextField(
                    key: const Key('add_section_custom_title'),
                    controller: _titleCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Titolo',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: _customError,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('add_section_confirm'),
          onPressed: _canSubmit
              ? () {
                  if (_custom) {
                    Navigator.of(context)
                        .pop(AddSectionChoice.custom(_titleCtrl.text.trim()));
                  } else {
                    Navigator.of(context)
                        .pop(AddSectionChoice.fixed(_selected));
                  }
                }
              : null,
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}

String _fixedLabel(SectionKind k) => switch (k) {
      SectionKind.anagrafica => 'Anagrafica',
      SectionKind.contatti => 'Contatti',
      SectionKind.sommario => 'Sommario',
      SectionKind.esperienze => 'Esperienze',
      SectionKind.formazione => 'Formazione',
      SectionKind.skill => 'Skill',
      SectionKind.lingue => 'Lingue',
      SectionKind.certificazioni => 'Certificazioni',
      SectionKind.custom => 'Sezione personalizzata',
    };
