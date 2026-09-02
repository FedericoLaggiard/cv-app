/// Template PDF "Minimal" (ticket 08/25) — audience senior/consulenza/
/// creativi, tono editoriale.
///
/// Singola colonna stretta (~72 caratteri di misura), zero colori: solo
/// nero/grigio. Miscela tipografica intenzionale: Inter uppercase per le
/// label (header di sezione, tracking largo), EB Garamond per il corpo.
/// **Ignora sempre la foto per design** (ticket 08), anche se presente in
/// `AnagraficaData.foto` — non è una degradazione, è la scelta stilistica
/// del template. Se una foto è presente, viene emesso solo un warning in
/// `debugMode` (nessun blocco, nessun rendering).
library;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/cv_document.dart';
import '../domain/cv_section.dart';
import 'label_locale.dart';
import 'markdown_pdf_renderer.dart';
import 'pdf_fonts.dart';
import 'template_shared.dart';

const PdfColor _bodyColor = PdfColor.fromInt(0x000000);
const PdfColor _nameColor = PdfColor.fromInt(0x333333);
const PdfColor _metaColor = PdfColor.fromInt(0x666666);

class MinimalTemplate {
  MinimalTemplate._();

  /// Renderizza [document] nel template Minimal. [labelFont] è Inter
  /// (label uppercase), [bodyFonts] è EB Garamond (corpo/meta) — riusa lo
  /// stesso font già embeddato da Classico (ticket 08/24), coerente col
  /// vincolo "solo font già in bundle" quando la famiglia è la stessa.
  /// [compress] è esposto solo per i test.
  static pw.Document render({
    required CvDocument document,
    required MinimalLabels labels,
    required LabelLocale locale,
    required InterFonts labelFont,
    required ClassicoFonts bodyFonts,
    bool compress = true,
  }) {
    final doc = pw.Document(compress: compress);
    final dateFormat = DateFormat.yMMMM(locale.intlLocale);

    final anagrafica = document.sections
        .whereType<AnagraficaSection>()
        .firstOrNull;
    if (kDebugMode && anagrafica?.data.foto != null) {
      debugPrint(
        'MinimalTemplate: foto profilo presente ma ignorata by design '
        '(ticket 08, "il Minimal ignora sempre la foto").',
      );
    }

    final nameStyle = pw.TextStyle(
      fontNormal: labelFont.regular,
      fontBold: labelFont.semiBold,
      fontItalic: labelFont.italic,
      fontBoldItalic: labelFont.boldItalic,
      fontSize: 16,
      letterSpacing: 0.4,
      color: _nameColor,
    );
    final contattiStyle = pw.TextStyle(
      fontNormal: labelFont.regular,
      fontBold: labelFont.semiBold,
      fontItalic: labelFont.italic,
      fontBoldItalic: labelFont.boldItalic,
      fontSize: 9,
      color: _metaColor,
    );
    final headlineStyle = pw.TextStyle(
      fontNormal: bodyFonts.regular,
      fontBold: bodyFonts.bold,
      fontItalic: bodyFonts.italic,
      fontBoldItalic: bodyFonts.boldItalic,
      fontSize: 10.5,
      color: _metaColor,
    );
    final sectionHeaderStyle = pw.TextStyle(
      fontNormal: labelFont.regular,
      fontBold: labelFont.semiBold,
      fontItalic: labelFont.italic,
      fontBoldItalic: labelFont.boldItalic,
      fontSize: 9.5,
      letterSpacing: 1.6,
      color: _metaColor,
    );
    final bodyStyle = pw.TextStyle(
      fontNormal: bodyFonts.regular,
      fontBold: bodyFonts.bold,
      fontItalic: bodyFonts.italic,
      fontBoldItalic: bodyFonts.boldItalic,
      fontSize: 10.5,
      lineSpacing: 4.5,
      color: _bodyColor,
    );
    final metaStyle = pw.TextStyle(
      fontNormal: bodyFonts.italic,
      fontBold: bodyFonts.boldItalic,
      fontItalic: bodyFonts.italic,
      fontBoldItalic: bodyFonts.boldItalic,
      fontSize: 10,
      fontStyle: pw.FontStyle.italic,
      color: _metaColor,
    );
    final pageNumberStyle = pw.TextStyle(
      fontNormal: labelFont.regular,
      fontBold: labelFont.semiBold,
      fontItalic: labelFont.italic,
      fontBoldItalic: labelFont.boldItalic,
      fontSize: 8.5,
      color: _metaColor,
    );

    final markdown = MarkdownPdfRenderer(
      baseStyle: bodyStyle,
      linkColor: _bodyColor,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          top: 22 * PdfPageFormat.mm,
          bottom: 22 * PdfPageFormat.mm,
          left: 28 * PdfPageFormat.mm,
          right: 28 * PdfPageFormat.mm,
        ),
        footer: (context) {
          if (context.pageNumber <= 1) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.bottomRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('— ${context.pageNumber} —', style: pageNumberStyle),
          );
        },
        build: (context) => _buildBody(
          document: document,
          labels: labels,
          locale: locale,
          dateFormat: dateFormat,
          nameStyle: nameStyle,
          contattiStyle: contattiStyle,
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
    required MinimalLabels labels,
    required LabelLocale locale,
    required DateFormat dateFormat,
    required pw.TextStyle nameStyle,
    required pw.TextStyle contattiStyle,
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
          widgets.add(_anagraficaHeader(data, nameStyle, headlineStyle));
        case ContattiSection(:final data):
          final row = _contattiRow(data, contattiStyle);
          if (row != null) widgets.add(row);
          widgets.add(pw.SizedBox(height: 24));
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
          widgets.add(_lingueColumn(items, locale, bodyStyle));
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
    pw.TextStyle nameStyle,
    pw.TextStyle headlineStyle,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('${data.nome} ${data.cognome}'.trim(), style: nameStyle),
      if ((data.headline ?? '').trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(data.headline!.trim(), style: headlineStyle),
        ),
    ],
  );

  static pw.Widget? _contattiRow(ContattiData data, pw.TextStyle style) {
    final parts = <String>[
      if ((data.email ?? '').trim().isNotEmpty) data.email!.trim(),
      if ((data.telefono ?? '').trim().isNotEmpty) data.telefono!.trim(),
      if ((data.citta ?? '').trim().isNotEmpty) data.citta!.trim(),
      for (final l in data.link)
        if (l.label.trim().isNotEmpty) l.label.trim(),
    ];
    if (parts.isEmpty) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text(parts.join('   ·   '), style: style),
    );
  }

  static pw.Widget _sectionHeader(String title, pw.TextStyle style) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
        child: pw.Text(title.toUpperCase(), style: style),
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
    MinimalLabels labels,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      if ((it.luogo ?? '').trim().isNotEmpty) it.luogo!.trim(),
      if (it.modalita != null) modalitaLabel(it.modalita!, locale),
    ].join(' · ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
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
    MinimalLabels labels,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      if ((it.istituto ?? '').trim().isNotEmpty) it.istituto!.trim(),
      if ((it.luogo ?? '').trim().isNotEmpty) it.luogo!.trim(),
    ].join(' · ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
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
      padding: const pw.EdgeInsets.only(bottom: 12),
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
      widgets.add(pw.Text(data.tags.join(' · '), style: bodyStyle));
    }
    return widgets;
  }

  static pw.Widget _lingueColumn(
    List<LinguaItem> items,
    LabelLocale locale,
    pw.TextStyle bodyStyle,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final it in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            [
              '${it.lingua} — ${cefrLabel(it.livello, locale)}',
              if ((it.certificazione ?? '').trim().isNotEmpty)
                '(${it.certificazione!.trim()})',
            ].join(' '),
            style: bodyStyle,
          ),
        ),
    ],
  );
}
