/// Template PDF "Classico" (ticket 08/24) — audience ATS/formale.
///
/// Singola colonna full-width, EB Garamond, palette solo neri/grigi.
/// Foto profilo opzionale (Slice G, ticket 26): un rettangolo 28×36mm in
/// alto a destra dell'header quando presente; senza foto l'header resta
/// full-width com'era prima del ticket 26.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/cv_document.dart';
import '../domain/cv_section.dart';
import 'label_locale.dart';
import 'markdown_pdf_renderer.dart';
import 'pdf_fonts.dart';
import 'template_shared.dart';

const PdfColor _textColor = PdfColor.fromInt(0x111111);
const PdfColor _metaColor = PdfColor.fromInt(0x555555);
const PdfColor _hairlineColor = PdfColor.fromInt(0x888888);
const PdfColor _linkColor = PdfColor.fromInt(0x1a1a1a);

class ClassicoTemplate {
  ClassicoTemplate._();

  /// Renderizza [document] nel template Classico. [compress] è esposto
  /// solo per i test (`false` lascia il content stream non compresso e
  /// ispezionabile).
  static pw.Document render({
    required CvDocument document,
    required ClassicoLabels labels,
    required LabelLocale locale,
    required ClassicoFonts fonts,
    bool compress = true,
  }) {
    final doc = pw.Document(compress: compress);

    final nameStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 22,
      color: _textColor,
    );
    final headlineStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 12,
      fontStyle: pw.FontStyle.italic,
      color: _textColor,
    );
    final sectionHeaderStyle = pw.TextStyle(
      fontNormal: fonts.semiBold,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 13,
      letterSpacing: 1.2,
      color: _textColor,
    );
    final bodyStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.bold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 10.5,
      lineSpacing: 3.5,
      color: _textColor,
    );
    final metaStyle = pw.TextStyle(
      fontNormal: fonts.italic,
      fontBold: fonts.boldItalic,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 10,
      fontStyle: pw.FontStyle.italic,
      color: _metaColor,
    );
    final pageHeaderStyle = pw.TextStyle(
      fontNormal: fonts.italic,
      fontBold: fonts.boldItalic,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 9,
      fontStyle: pw.FontStyle.italic,
      color: _metaColor,
    );

    final markdown = MarkdownPdfRenderer(
      baseStyle: bodyStyle,
      linkColor: _linkColor,
    );
    final dateFormat = DateFormat.yMMMM(locale.intlLocale);

    final anagrafica = document.sections
        .whereType<AnagraficaSection>()
        .firstOrNull;
    final fullName = anagrafica == null
        ? ''
        : '${anagrafica.data.nome} ${anagrafica.data.cognome}'.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          top: 18 * PdfPageFormat.mm,
          bottom: 18 * PdfPageFormat.mm,
          left: 16 * PdfPageFormat.mm,
          right: 16 * PdfPageFormat.mm,
        ),
        header: (context) {
          if (context.pageNumber <= 1) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.topRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              '$fullName — ${labels.pagina} ${context.pageNumber}/${context.pagesCount}',
              style: pageHeaderStyle,
            ),
          );
        },
        build: (context) => _buildBody(
          document: document,
          labels: labels,
          locale: locale,
          dateFormat: dateFormat,
          nameStyle: nameStyle,
          headlineStyle: headlineStyle,
          sectionHeaderStyle: sectionHeaderStyle,
          bodyStyle: bodyStyle,
          metaStyle: metaStyle,
          markdown: markdown,
        ),
      ),
    );
    return doc;
  }

  static List<pw.Widget> _buildBody({
    required CvDocument document,
    required ClassicoLabels labels,
    required LabelLocale locale,
    required DateFormat dateFormat,
    required pw.TextStyle nameStyle,
    required pw.TextStyle headlineStyle,
    required pw.TextStyle sectionHeaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle metaStyle,
    required MarkdownPdfRenderer markdown,
  }) {
    final widgets = <pw.Widget>[];

    for (final section in document.sections) {
      switch (section) {
        case AnagraficaSection(:final data):
          widgets.add(
            _anagraficaHeader(
              data,
              photoBytesFor(document, section),
              nameStyle,
              headlineStyle,
            ),
          );
        case ContattiSection(:final data):
          final row = _contattiRow(data, bodyStyle);
          if (row != null) widgets.add(row);
          widgets.add(_hairline());
        case SommarioSection(markdown: final summaryMarkdown):
          widgets.addAll(markdown.render(summaryMarkdown));
        case EsperienzeSection(:final items):
          widgets.addAll(
            _itemsSection(
              header: labels.esperienze,
              sectionHeaderStyle: sectionHeaderStyle,
              items: items,
              rowBuilder: (it) => _esperienzaItem(
                it,
                locale,
                dateFormat,
                labels,
                bodyStyle,
                metaStyle,
                markdown,
              ),
            ),
          );
        case FormazioneSection(:final items):
          widgets.addAll(
            _itemsSection(
              header: labels.formazione,
              sectionHeaderStyle: sectionHeaderStyle,
              items: items,
              rowBuilder: (it) => _formazioneItem(
                it,
                locale,
                dateFormat,
                labels,
                bodyStyle,
                metaStyle,
                markdown,
              ),
            ),
          );
        case SkillSection(:final data):
          widgets.add(_sectionHeader(labels.skill, sectionHeaderStyle));
          widgets.addAll(_skillBlock(data, bodyStyle, markdown));
        case LingueSection(:final items):
          widgets.add(_sectionHeader(labels.lingue, sectionHeaderStyle));
          widgets.add(_lingueTable(items, locale, bodyStyle));
        case CertificazioniSection(:final items):
          widgets.addAll(
            _itemsSection(
              header: labels.certificazioni,
              sectionHeaderStyle: sectionHeaderStyle,
              items: items,
              rowBuilder: (it) => _certificazioneItem(
                it,
                locale,
                dateFormat,
                bodyStyle,
                metaStyle,
                markdown,
              ),
            ),
          );
        case CustomSection(:final displayTitle, markdown: final customMarkdown):
          widgets.add(_sectionHeader(displayTitle, sectionHeaderStyle));
          widgets.addAll(markdown.render(customMarkdown));
      }
    }
    return widgets;
  }

  static pw.Widget _anagraficaHeader(
    AnagraficaData data,
    Uint8List? photoBytes,
    pw.TextStyle nameStyle,
    pw.TextStyle headlineStyle,
  ) {
    final nameBlock = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${data.nome} ${data.cognome}'.trim(), style: nameStyle),
        if ((data.headline ?? '').trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(data.headline!.trim(), style: headlineStyle),
          ),
      ],
    );

    if (photoBytes == null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [nameBlock, pw.SizedBox(height: 8)],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: nameBlock),
            pw.SizedBox(width: 12),
            _photo(photoBytes),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _photo(Uint8List bytes) => pw.Container(
    width: 28 * PdfPageFormat.mm,
    height: 36 * PdfPageFormat.mm,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _hairlineColor, width: 0.5),
      image: pw.DecorationImage(
        image: pw.MemoryImage(bytes),
        fit: pw.BoxFit.cover,
      ),
    ),
  );

  static pw.Widget? _contattiRow(ContattiData data, pw.TextStyle bodyStyle) {
    final parts = <String>[
      if ((data.email ?? '').trim().isNotEmpty) data.email!.trim(),
      if ((data.telefono ?? '').trim().isNotEmpty) data.telefono!.trim(),
      if ((data.citta ?? '').trim().isNotEmpty) data.citta!.trim(),
      for (final l in data.link)
        if (l.label.trim().isNotEmpty) l.label.trim(),
    ];
    if (parts.isEmpty) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(parts.join(' · '), style: bodyStyle),
    );
  }

  static pw.Widget _hairline() => pw.Container(
    height: 0.5,
    margin: const pw.EdgeInsets.only(bottom: 10),
    color: _hairlineColor,
  );

  static pw.Widget _sectionHeader(String title, pw.TextStyle style) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
            child: pw.Text(title.toUpperCase(), style: style),
          ),
          pw.Container(height: 0.5, color: _hairlineColor),
          pw.SizedBox(height: 6),
        ],
      );

  static List<pw.Widget> _itemsSection<T>({
    required String header,
    required pw.TextStyle sectionHeaderStyle,
    required List<T> items,
    required pw.Widget Function(T) rowBuilder,
  }) => keepFirstItemWithHeader(
    header: _sectionHeader(header, sectionHeaderStyle),
    items: items,
    rowBuilder: rowBuilder,
  );

  static pw.Widget _esperienzaItem(
    EsperienzaItem it,
    LabelLocale locale,
    DateFormat dateFormat,
    ClassicoLabels labels,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      if ((it.luogo ?? '').trim().isNotEmpty) it.luogo!.trim(),
      if (it.modalita != null) modalitaLabel(it.modalita!, locale),
      if (it.tipoContratto != null)
        tipoContrattoLabel(it.tipoContratto!, locale),
    ].join(' · ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${it.ruolo} — ${it.azienda}',
                  style: bodyStyle.copyWith(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                formatDateRange(
                  start: it.startDate,
                  end: it.endDate,
                  current: it.current,
                  format: dateFormat,
                  labels: labels,
                ),
                style: metaStyle,
              ),
            ],
          ),
          if (meta.isNotEmpty) pw.Text(meta, style: metaStyle),
          if ((it.descrizione ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            ...markdown.render(it.descrizione!),
          ],
        ],
      ),
    );
  }

  static pw.Widget _formazioneItem(
    FormazioneItem it,
    LabelLocale locale,
    DateFormat dateFormat,
    ClassicoLabels labels,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      if ((it.istituto ?? '').trim().isNotEmpty) it.istituto!.trim(),
      if ((it.luogo ?? '').trim().isNotEmpty) it.luogo!.trim(),
      if ((it.voto ?? '').trim().isNotEmpty) it.voto!.trim(),
    ].join(' · ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  it.titolo,
                  style: bodyStyle.copyWith(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                formatDateRange(
                  start: it.startDate,
                  end: it.endDate,
                  current: it.current,
                  format: dateFormat,
                  labels: labels,
                ),
                style: metaStyle,
              ),
            ],
          ),
          if (meta.isNotEmpty) pw.Text(meta, style: metaStyle),
          if ((it.descrizione ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            ...markdown.render(it.descrizione!),
          ],
        ],
      ),
    );
  }

  static pw.Widget _certificazioneItem(
    CertificazioneItem it,
    LabelLocale locale,
    DateFormat dateFormat,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      it.ente,
      if (it.dataConseguimento != null)
        dateFormat.format(it.dataConseguimento!.toDateTime()),
      if ((it.codice ?? '').trim().isNotEmpty) it.codice!.trim(),
    ].join(' · ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            it.nome,
            style: bodyStyle.copyWith(fontWeight: pw.FontWeight.bold),
          ),
          if (meta.isNotEmpty) pw.Text(meta, style: metaStyle),
          if ((it.descrizione ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            ...markdown.render(it.descrizione!),
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _skillBlock(
    SkillData data,
    pw.TextStyle bodyStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final widgets = <pw.Widget>[];
    if ((data.markdown ?? '').trim().isNotEmpty) {
      widgets.addAll(markdown.render(data.markdown!));
      widgets.add(pw.SizedBox(height: 6));
    }
    if (data.tags.isNotEmpty) {
      widgets.add(
        pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in data.tags)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _hairlineColor, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(2),
                  ),
                ),
                child: pw.Text(tag, style: bodyStyle),
              ),
          ],
        ),
      );
    }
    return widgets;
  }

  static pw.Widget _lingueTable(
    List<LinguaItem> items,
    LabelLocale locale,
    pw.TextStyle bodyStyle,
  ) => pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)},
    children: [
      for (final it in items)
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _hairlineColor, width: 0.5),
            ),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(it.lingua, style: bodyStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                [
                  cefrLabel(it.livello, locale),
                  if ((it.certificazione ?? '').trim().isNotEmpty)
                    '(${it.certificazione!.trim()})',
                ].join(' '),
                style: bodyStyle,
              ),
            ),
          ],
        ),
    ],
  );
}
