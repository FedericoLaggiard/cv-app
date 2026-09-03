/// Template PDF "Moderno" (ticket 08/25) — audience tech/product/design.
///
/// Due colonne asimmetriche: banda laterale sinistra `#1f2d3d` (foto,
/// contatti, skill, lingue) **solo sulla prima pagina** + colonna
/// principale (Sommario, Esperienze, Formazione, Certificazioni, Custom).
/// Dalla pagina 2 in poi la colonna principale si espande a piena
/// larghezza (niente banda ripetuta, niente spreco di superficie).
///
/// Nota implementativa: la libreria `pdf` (package:pdf) non supporta lo
/// spanning multi-pagina di un `Row`/`Stack` (solo i `Column` verticali
/// possono spezzarsi fra pagine, vedi `Flex.canSpan`). Per questo la
/// prima pagina è composta come un unico `pw.Stack` posizionato in modo
/// assoluto (banda + *solo* la prima sezione "colonna principale" —
/// tipicamente il Sommario, per costruzione breve) in un `pw.MultiPage`
/// dedicato a una pagina; il resto delle sezioni "colonna principale"
/// (Esperienze, Formazione, Certificazioni, Custom) fluisce in un
/// secondo `pw.MultiPage` a piena larghezza, che può spezzarsi su
/// quante pagine servono. Le sezioni banda (Anagrafica/Contatti/Skill/
/// Lingue) mantengono sempre il loro ordine interno fisso da wireframe
/// (ticket 08); le sezioni "colonna principale" rispettano l'ordine
/// relativo con cui compaiono in `document.sections` (ticket 25, user
/// story 6).
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/cv_document.dart';
import '../domain/cv_section.dart';
import '../domain/enums.dart';
import 'label_locale.dart';
import 'markdown_pdf_renderer.dart';
import 'pdf_fonts.dart';
import 'template_shared.dart';

/// Palette + costanti di layout del template Moderno (ticket 25).
class ModernoTheme {
  ModernoTheme._();

  static const PdfColor accent = PdfColor.fromInt(0x2b6cb0);
  static const PdfColor bandBackground = PdfColor.fromInt(0x1f2d3d);
  static const PdfColor bandText = PdfColor.fromInt(0xe6ecf1);
  static const PdfColor bandHeadline = PdfColor.fromInt(0xe6e6e6);
  static const PdfColor bandHeader = PdfColor.fromInt(0xc9d4de);
  static const PdfColor bandMeta = PdfColor.fromInt(0xa4b1bd);
  static const PdfColor bandHairline = PdfColor.fromInt(0x3a4a5c);
  static const PdfColor mainText = PdfColor.fromInt(0x1f2933);
  static const PdfColor mainMeta = PdfColor.fromInt(0x5c6b7a);
  static const PdfColor mainHairline = PdfColor.fromInt(0xe2e8f0);
  static const PdfColor white = PdfColor.fromInt(0xffffff);

  static const double bandWidth = 62 * PdfPageFormat.mm;
  static const double photoSize = 40 * PdfPageFormat.mm;
}

class ModernoTemplate {
  ModernoTemplate._();

  /// Renderizza [document] nel template Moderno. [compress] è esposto solo
  /// per i test (`false` lascia il content stream ispezionabile).
  static pw.Document render({
    required CvDocument document,
    required ModernoLabels labels,
    required LabelLocale locale,
    required InterFonts fonts,
    bool compress = true,
  }) {
    final doc = pw.Document(compress: compress);
    final dateFormat = DateFormat.yMMMM(locale.intlLocale);

    final nameStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 20,
      color: ModernoTheme.white,
    );
    final headlineStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 10,
      color: ModernoTheme.bandHeadline,
    );
    final bandHeaderStyle = pw.TextStyle(
      fontNormal: fonts.semiBold,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 9,
      letterSpacing: 1.4,
      color: ModernoTheme.bandHeader,
    );
    final bandBodyStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.bold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 9,
      lineSpacing: 3,
      color: ModernoTheme.bandText,
    );
    final mainHeaderStyle = pw.TextStyle(
      fontNormal: fonts.semiBold,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 12,
      color: ModernoTheme.accent,
    );
    final bodyStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.bold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 10,
      lineSpacing: 4,
      color: ModernoTheme.mainText,
    );
    final metaStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 9,
      color: ModernoTheme.mainMeta,
    );
    final pageHeaderStyle = pw.TextStyle(
      fontNormal: fonts.regular,
      fontBold: fonts.semiBold,
      fontItalic: fonts.italic,
      fontBoldItalic: fonts.boldItalic,
      fontSize: 9,
      color: ModernoTheme.mainMeta,
    );

    final mainMarkdown = MarkdownPdfRenderer(
      baseStyle: bodyStyle,
      linkColor: ModernoTheme.accent,
    );
    final bandMarkdown = MarkdownPdfRenderer(
      baseStyle: bandBodyStyle,
      linkColor: ModernoTheme.white,
    );

    final anagrafica = document.sections
        .whereType<AnagraficaSection>()
        .firstOrNull;
    final contatti = document.sections.whereType<ContattiSection>().firstOrNull;
    final skill = document.sections.whereType<SkillSection>().firstOrNull;
    final lingue = document.sections.whereType<LingueSection>().firstOrNull;
    final fullName = anagrafica == null
        ? ''
        : '${anagrafica.data.nome} ${anagrafica.data.cognome}'.trim();

    const bandKinds = {
      SectionKind.anagrafica,
      SectionKind.contatti,
      SectionKind.skill,
      SectionKind.lingue,
    };
    final mainSections = document.sections
        .where((s) => !bandKinds.contains(s.kind))
        .toList();
    final page1Lead = mainSections.isEmpty ? null : mainSections.first;
    final restSections = mainSections.isEmpty
        ? const <CvSection>[]
        : mainSections.sublist(1);

    final photoBytes = photoBytesFor(document, anagrafica);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          pw.SizedBox(
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
            child: pw.Stack(
              children: [
                pw.Positioned(
                  left: 0,
                  top: 0,
                  child: pw.Container(
                    width: ModernoTheme.bandWidth,
                    height: PdfPageFormat.a4.height,
                    color: ModernoTheme.bandBackground,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8 * PdfPageFormat.mm,
                      vertical: 18 * PdfPageFormat.mm,
                    ),
                    child: _band(
                      photoBytes: photoBytes,
                      anagrafica: anagrafica,
                      contatti: contatti,
                      skill: skill,
                      lingue: lingue,
                      labels: labels,
                      locale: locale,
                      nameStyle: nameStyle,
                      headlineStyle: headlineStyle,
                      bandHeaderStyle: bandHeaderStyle,
                      bandBodyStyle: bandBodyStyle,
                      bandMarkdown: bandMarkdown,
                    ),
                  ),
                ),
                pw.Positioned(
                  left: ModernoTheme.bandWidth,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(
                      10 * PdfPageFormat.mm,
                      16 * PdfPageFormat.mm,
                      14 * PdfPageFormat.mm,
                      16 * PdfPageFormat.mm,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: page1Lead == null
                          ? []
                          : _mainSectionWidgets(
                              section: page1Lead,
                              labels: labels,
                              locale: locale,
                              dateFormat: dateFormat,
                              mainHeaderStyle: mainHeaderStyle,
                              bodyStyle: bodyStyle,
                              metaStyle: metaStyle,
                              markdown: mainMarkdown,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (restSections.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.only(
            top: 16 * PdfPageFormat.mm,
            bottom: 16 * PdfPageFormat.mm,
            left: 16 * PdfPageFormat.mm,
            right: 16 * PdfPageFormat.mm,
          ),
          header: (context) => pw.Container(
            alignment: pw.Alignment.topRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              '$fullName — ${labels.pagina} ${context.pageNumber}/${context.pagesCount}',
              style: pageHeaderStyle,
            ),
          ),
          build: (context) => [
            for (final section in restSections)
              ..._mainSectionWidgets(
                section: section,
                labels: labels,
                locale: locale,
                dateFormat: dateFormat,
                mainHeaderStyle: mainHeaderStyle,
                bodyStyle: bodyStyle,
                metaStyle: metaStyle,
                markdown: mainMarkdown,
              ),
          ],
        ),
      );
    }

    return doc;
  }

  static pw.Widget _band({
    required Uint8List? photoBytes,
    required AnagraficaSection? anagrafica,
    required ContattiSection? contatti,
    required SkillSection? skill,
    required LingueSection? lingue,
    required ModernoLabels labels,
    required LabelLocale locale,
    required pw.TextStyle nameStyle,
    required pw.TextStyle headlineStyle,
    required pw.TextStyle bandHeaderStyle,
    required pw.TextStyle bandBodyStyle,
    required MarkdownPdfRenderer bandMarkdown,
  }) {
    final nameBlock = anagrafica == null
        ? null
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${anagrafica.data.nome} ${anagrafica.data.cognome}'.trim(),
                style: nameStyle,
              ),
              if ((anagrafica.data.headline ?? '').trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    anagrafica.data.headline!.trim(),
                    style: headlineStyle,
                  ),
                ),
            ],
          );

    final contattiBlock = contatti == null
        ? null
        : _bandSection(
            title: labels.contatti,
            headerStyle: bandHeaderStyle,
            child: _contattiColumn(contatti.data, bandBodyStyle),
          );

    final skillBlock = skill == null
        ? null
        : _bandSection(
            title: labels.skill,
            headerStyle: bandHeaderStyle,
            child: _bandSkill(skill.data, bandBodyStyle, bandMarkdown),
          );

    final lingueBlock = lingue == null
        ? null
        : _bandSection(
            title: labels.lingue,
            headerStyle: bandHeaderStyle,
            child: _bandLingue(lingue.items, locale, bandBodyStyle),
          );

    // User story 5 (ticket 25): senza foto la banda non lascia un buco al
    // posto del ritratto — i contatti salgono in cima, seguiti da
    // nome/headline. Con foto: foto → nome/headline → contatti.
    final blocks = <pw.Widget>[];
    if (photoBytes != null) {
      blocks.add(_photo(photoBytes));
      blocks.add(pw.SizedBox(height: 12));
      if (nameBlock != null) blocks.add(nameBlock);
      if (contattiBlock != null) blocks.add(contattiBlock);
    } else {
      if (contattiBlock != null) blocks.add(contattiBlock);
      if (nameBlock != null) blocks.add(nameBlock);
    }
    if (skillBlock != null) blocks.add(skillBlock);
    if (lingueBlock != null) blocks.add(lingueBlock);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 14),
          blocks[i],
        ],
      ],
    );
  }

  static pw.Widget _photo(Uint8List bytes) => pw.Container(
    width: ModernoTheme.photoSize,
    height: ModernoTheme.photoSize,
    decoration: pw.BoxDecoration(
      shape: pw.BoxShape.circle,
      border: pw.Border.all(color: ModernoTheme.bandHairline, width: 1.5),
      image: pw.DecorationImage(
        image: pw.MemoryImage(bytes),
        fit: pw.BoxFit.cover,
      ),
    ),
  );

  static pw.Widget _bandSection({
    required String title,
    required pw.TextStyle headerStyle,
    required pw.Widget child,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title.toUpperCase(), style: headerStyle),
      pw.SizedBox(height: 6),
      child,
    ],
  );

  static pw.Widget _contattiColumn(ContattiData data, pw.TextStyle style) {
    final lines = <String>[
      if ((data.email ?? '').trim().isNotEmpty) data.email!.trim(),
      if ((data.telefono ?? '').trim().isNotEmpty) data.telefono!.trim(),
      if ((data.citta ?? '').trim().isNotEmpty) data.citta!.trim(),
      for (final l in data.link)
        if (l.label.trim().isNotEmpty) l.label.trim(),
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(line, style: style),
          ),
      ],
    );
  }

  static pw.Widget _bandSkill(
    SkillData data,
    pw.TextStyle style,
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
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final tag in data.tags)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: ModernoTheme.accent,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Text(
                  tag,
                  style: style.copyWith(color: ModernoTheme.white),
                ),
              ),
          ],
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static pw.Widget _bandLingue(
    List<LinguaItem> items,
    LabelLocale locale,
    pw.TextStyle style,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final it in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${it.lingua} — ${cefrLabel(it.livello, locale)}',
                style: style,
              ),
              pw.SizedBox(height: 2),
              pw.Stack(
                children: [
                  pw.Container(
                    width: double.infinity,
                    height: 4,
                    color: ModernoTheme.bandHairline,
                  ),
                  pw.Container(
                    width: 46 * (_cefrFraction(it.livello)),
                    height: 4,
                    color: ModernoTheme.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );

  static double _cefrFraction(LivelloCefr l) {
    const order = [
      LivelloCefr.a1,
      LivelloCefr.a2,
      LivelloCefr.b1,
      LivelloCefr.b2,
      LivelloCefr.c1,
      LivelloCefr.c2,
      LivelloCefr.madrelingua,
    ];
    final idx = order.indexOf(l);
    return (idx + 1) / order.length;
  }

  /// Header di sezione + [keepTogether] col primo item come blocco unico,
  /// stesso pattern di `ClassicoTemplate._itemsSection` (ticket 08/24).
  static List<pw.Widget> _mainSectionWidgets({
    required CvSection section,
    required ModernoLabels labels,
    required LabelLocale locale,
    required DateFormat dateFormat,
    required pw.TextStyle mainHeaderStyle,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle metaStyle,
    required MarkdownPdfRenderer markdown,
  }) {
    switch (section) {
      case SommarioSection(markdown: final summaryMarkdown):
        return markdown.render(summaryMarkdown);
      case EsperienzeSection(:final items):
        return _itemsSection(
          header: labels.esperienze,
          headerStyle: mainHeaderStyle,
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
        );
      case FormazioneSection(:final items):
        return _itemsSection(
          header: labels.formazione,
          headerStyle: mainHeaderStyle,
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
        );
      case CertificazioniSection(:final items):
        return _itemsSection(
          header: labels.certificazioni,
          headerStyle: mainHeaderStyle,
          items: items,
          rowBuilder: (it) => _certificazioneItem(
            it,
            locale,
            dateFormat,
            bodyStyle,
            metaStyle,
            markdown,
          ),
        );
      case CustomSection(:final displayTitle, markdown: final customMarkdown):
        return [
          _mainSectionHeader(displayTitle, mainHeaderStyle),
          ...markdown.render(customMarkdown),
        ];
      case AnagraficaSection():
      case ContattiSection():
      case SkillSection():
      case LingueSection():
        return const [];
    }
  }

  static pw.Widget _mainSectionHeader(String title, pw.TextStyle style) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 3, height: 13, color: ModernoTheme.accent),
            pw.SizedBox(width: 8),
            pw.Text(title.toUpperCase(), style: style),
          ],
        ),
      );

  static List<pw.Widget> _itemsSection<T>({
    required String header,
    required pw.TextStyle headerStyle,
    required List<T> items,
    required pw.Widget Function(T) rowBuilder,
  }) => keepFirstItemWithHeader(
    header: _mainSectionHeader(header, headerStyle),
    items: items,
    rowBuilder: rowBuilder,
  );

  static pw.Widget _esperienzaItem(
    EsperienzaItem it,
    LabelLocale locale,
    DateFormat dateFormat,
    ModernoLabels labels,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      formatDateRange(
        start: it.startDate,
        end: it.endDate,
        current: it.current,
        format: dateFormat,
        labels: labels,
      ),
      if ((it.luogo ?? '').trim().isNotEmpty) it.luogo!.trim(),
      if (it.modalita != null) modalitaLabel(it.modalita!, locale),
    ].join(' · ');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ModernoTheme.mainHairline, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: it.ruolo,
                  style: bodyStyle.copyWith(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.TextSpan(
                  text: ' — ${it.azienda}',
                  style: bodyStyle.copyWith(fontSize: 11),
                ),
              ],
            ),
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
    ModernoLabels labels,
    pw.TextStyle bodyStyle,
    pw.TextStyle metaStyle,
    MarkdownPdfRenderer markdown,
  ) {
    final meta = [
      formatDateRange(
        start: it.startDate,
        end: it.endDate,
        current: it.current,
        format: dateFormat,
        labels: labels,
      ),
      if ((it.istituto ?? '').trim().isNotEmpty) it.istituto!.trim(),
      if ((it.luogo ?? '').trim().isNotEmpty) it.luogo!.trim(),
    ].join(' · ');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ModernoTheme.mainHairline, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            it.titolo,
            style: bodyStyle.copyWith(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
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
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ModernoTheme.mainHairline, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            it.nome,
            style: bodyStyle.copyWith(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
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
}
