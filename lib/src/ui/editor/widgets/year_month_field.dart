/// Input per un [YearMonth] (mese + anno).
///
/// Espone due dropdown affiancati: mese (1..12) e anno (drop-down con
/// range configurabile). Emette `null` quando l'utente svuota entrambi
/// i campi (es. `endDate` di un'esperienza in corso).
library;

import 'package:flutter/material.dart';

import '../../../domain/year_month.dart';

const _italianMonths = <String>[
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

class YearMonthField extends StatelessWidget {
  const YearMonthField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.required = false,
    this.hasError = false,
  });

  final String label;
  final YearMonth? value;
  final ValueChanged<YearMonth?> onChanged;
  final bool enabled;
  final bool required;
  final bool hasError;

  static const _minYear = 1950;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _italianMonths;
    final years = <int>[
      for (var y = DateTime.now().year + 1; y >= _minYear; y--) y,
    ];
    final effectiveLabel = required ? '$label *' : label;
    final errorColor = theme.colorScheme.error;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: hasError ? errorColor : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                effectiveLabel,
                style: labelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null && enabled)
              InkWell(
                onTap: () => onChanged(null),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Il pulsante "Cancella" vive accanto alla label (sopra), non in
        // questa Row: qui c'è già poco spazio per due DropdownButton
        // affiancati (colonna "Data inizio/fine" in EsperienzeForm), e un
        // terzo elemento a larghezza fissa li fa andare in overflow.
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: hasError && value == null ? '' : null,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: value?.month,
                    hint: const Text('Mese'),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text(months[m - 1])),
                    ],
                    onChanged: enabled
                        ? (m) {
                            final year =
                                value?.year ?? DateTime.now().year;
                            if (m == null) {
                              onChanged(null);
                            } else {
                              onChanged(YearMonth(year, m));
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: hasError && value == null ? '' : null,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: value?.year,
                    hint: const Text('Anno'),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: enabled
                        ? (y) {
                            final month = value?.month ?? 1;
                            if (y == null) {
                              onChanged(null);
                            } else {
                              onChanged(YearMonth(y, month));
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
