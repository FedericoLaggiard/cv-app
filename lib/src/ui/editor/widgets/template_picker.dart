/// Selettore a griglia di thumbnail per il template PDF (ticket 25),
/// sostituisce il `DropdownButtonFormField<TemplateId>` della Slice E.
///
/// Le thumbnail sono PNG statici pre-renderizzati e committati in
/// `assets/template_thumbnails/` (generati da
/// `tool/generate_thumbnails.dart`) — non un rendering live del PDF, vedi
/// Implementation Decisions del ticket 25.
library;

import 'package:flutter/material.dart';

import '../../../pdf/pdf_exporter.dart';

/// Percorso dell'asset thumbnail per [template].
String templateThumbnailAsset(TemplateId template) =>
    'assets/template_thumbnails/${template.wire}.png';

class TemplatePicker extends StatelessWidget {
  const TemplatePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TemplateId selected;
  final ValueChanged<TemplateId> onChanged;

  /// Sotto i 600px la griglia cade a lista verticale con thumbnail più
  /// piccole a sinistra (ticket 25, Implementation Decisions).
  static const double _compactBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        return compact ? _compactList(context) : _grid(context);
      },
    );
  }

  Widget _grid(BuildContext context) => Row(
    key: const Key('template_picker_grid'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final template in TemplateId.values) ...[
        Expanded(child: _Thumbnail(template: template, selected: template == selected, onChanged: onChanged, compact: false)),
        if (template != TemplateId.values.last) const SizedBox(width: 12),
      ],
    ],
  );

  Widget _compactList(BuildContext context) => Column(
    key: const Key('template_picker_list'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final template in TemplateId.values) ...[
        _Thumbnail(template: template, selected: template == selected, onChanged: onChanged, compact: true),
        if (template != TemplateId.values.last) const SizedBox(height: 8),
      ],
    ],
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.template,
    required this.selected,
    required this.onChanged,
    required this.compact,
  });

  final TemplateId template;
  final bool selected;
  final ValueChanged<TemplateId> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final image = AspectRatio(
      aspectRatio: 210 / 297,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(templateThumbnailAsset(template), fit: BoxFit.cover),
            if (selected)
              Positioned(
                right: 4,
                top: 4,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: color,
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );

    final label = Text(
      template.displayName,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );

    final content = compact
        ? Row(
            children: [
              SizedBox(width: 64, child: image),
              const SizedBox(width: 12),
              label,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              image,
              const SizedBox(height: 4),
              label,
            ],
          );

    return InkWell(
      key: Key('template_picker_option_${template.wire}'),
      onTap: () => onChanged(template),
      child: content,
    );
  }
}
