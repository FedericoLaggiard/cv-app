/// Block-renderer Markdown condiviso dai template PDF (ticket 08/24).
///
/// Sottoinsieme: **bold**, *italic*/_italic_, liste puntate/numerate,
/// `[label](url)`. Nessun heading Markdown (i field-level heading sono
/// decisi dal template, non dal contenuto). Coerente col rendering usato
/// in editor da `markdown_text_ops.dart` (stessa sintassi, uso opposto:
/// qui si legge invece di scriversi).
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renderizza Markdown in widget `pdf`.
///
/// [baseStyle] deve avere `fontNormal`/`fontBold`/`fontItalic`/
/// `fontBoldItalic` impostati esplicitamente: la selezione bold/italic
/// avviene tramite `fontWeight`/`fontStyle` (la libreria `pdf` sceglie il
/// font giusto in base a quei due campi, vedi `TextStyle.font` getter),
/// non passando un `Font` diverso a mano.
class MarkdownPdfRenderer {
  final pw.TextStyle baseStyle;
  final PdfColor linkColor;
  final double listIndent;
  final double blockSpacing;

  const MarkdownPdfRenderer({
    required this.baseStyle,
    required this.linkColor,
    this.listIndent = 14,
    this.blockSpacing = 6,
  });

  /// Renderizza [markdown] in una sequenza di blocchi (paragrafi/liste).
  List<pw.Widget> render(String markdown) {
    final blocks = _splitBlocks(markdown);
    final widgets = <pw.Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) widgets.add(pw.SizedBox(height: blockSpacing));
      widgets.add(_renderBlock(blocks[i]));
    }
    return widgets;
  }

  static final RegExp _bulletLine = RegExp(r'^- (.*)$');
  static final RegExp _orderedLine = RegExp(r'^(\d+)\. (.*)$');

  List<List<String>> _splitBlocks(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.split('\n').where((l) => l.trim().isNotEmpty).toList())
        .where((lines) => lines.isNotEmpty)
        .toList();
  }

  pw.Widget _renderBlock(List<String> lines) {
    if (lines.every((l) => _bulletLine.hasMatch(l.trim()))) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            _listItem(_bulletLine.firstMatch(l.trim())!.group(1)!),
        ],
      );
    }
    if (lines.every((l) => _orderedLine.hasMatch(l.trim()))) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            _listItem(
              _orderedLine.firstMatch(l.trim())!.group(2)!,
              marker: '${_orderedLine.firstMatch(l.trim())!.group(1)}.',
            ),
        ],
      );
    }
    // Paragrafo: le righe si uniscono con uno spazio (soft line break).
    final text = lines.map((l) => l.trim()).join(' ');
    return pw.RichText(
      text: pw.TextSpan(style: baseStyle, children: _inlineSpans(text)),
    );
  }

  pw.Widget _listItem(String content, {String marker = '•'}) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: listIndent,
          child: pw.Text(marker, style: baseStyle),
        ),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              style: baseStyle,
              children: _inlineSpans(content),
            ),
          ),
        ),
      ],
    ),
  );

  static final RegExp _inlineToken = RegExp(
    r'\*\*(.+?)\*\*'
    r'|__(.+?)__'
    r'|\[([^\]]*)\]\(([^)]*)\)'
    r'|(?<!\*)\*([^*]+?)\*(?!\*)'
    r'|(?<!_)_([^_]+?)_(?!_)',
  );

  List<pw.InlineSpan> _inlineSpans(String text) {
    final spans = <pw.InlineSpan>[];
    var last = 0;
    for (final m in _inlineToken.allMatches(text)) {
      if (m.start > last) {
        spans.add(pw.TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(pw.TextSpan(text: m.group(1), style: _styleFor(bold: true)));
      } else if (m.group(2) != null) {
        spans.add(pw.TextSpan(text: m.group(2), style: _styleFor(bold: true)));
      } else if (m.group(3) != null) {
        final label = m.group(3)!;
        final url = m.group(4)!;
        spans.add(
          pw.TextSpan(
            text: label.isEmpty ? url : label,
            style: _styleFor(link: true),
            annotation: pw.AnnotationUrl(url),
          ),
        );
      } else if (m.group(5) != null) {
        spans.add(
          pw.TextSpan(text: m.group(5), style: _styleFor(italic: true)),
        );
      } else if (m.group(6) != null) {
        spans.add(
          pw.TextSpan(text: m.group(6), style: _styleFor(italic: true)),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(pw.TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  pw.TextStyle _styleFor({
    bool bold = false,
    bool italic = false,
    bool link = false,
  }) {
    var style = baseStyle;
    if (bold) style = style.copyWith(fontWeight: pw.FontWeight.bold);
    if (italic) style = style.copyWith(fontStyle: pw.FontStyle.italic);
    if (link) {
      style = style.copyWith(
        color: linkColor,
        decoration: pw.TextDecoration.underline,
      );
    }
    return style;
  }
}
