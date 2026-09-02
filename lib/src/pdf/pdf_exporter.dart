/// Seam unico di export PDF per tutti i template presenti/futuri (ticket 24).
library;

import 'dart:typed_data';

import 'package:intl/date_symbol_data_local.dart';

import '../domain/cv_document.dart';
import 'classico_template.dart';
import 'label_locale.dart';
import 'minimal_template.dart';
import 'moderno_template.dart';
import 'pdf_fonts.dart';

/// Template PDF disponibili (ticket 08, completati dalla Slice F/ticket 25).
enum TemplateId {
  classico('classico', 'Classico'),
  moderno('moderno', 'Moderno'),
  minimal('minimal', 'Minimal');

  const TemplateId(this.wire, this.displayName);
  final String wire;
  final String displayName;
}

abstract class PdfExporter {
  Future<Uint8List> render({
    required CvDocument document,
    required TemplateId template,
    required LabelLocale labelLocale,
  });
}

class DefaultPdfExporter implements PdfExporter {
  const DefaultPdfExporter();

  @override
  Future<Uint8List> render({
    required CvDocument document,
    required TemplateId template,
    required LabelLocale labelLocale,
  }) async {
    switch (template) {
      case TemplateId.classico:
        await initializeDateFormatting(labelLocale.intlLocale);
        final fonts = await ClassicoFonts.load();
        final doc = ClassicoTemplate.render(
          document: document,
          labels: labelsFor(labelLocale),
          locale: labelLocale,
          fonts: fonts,
        );
        return doc.save();
      case TemplateId.moderno:
        await initializeDateFormatting(labelLocale.intlLocale);
        final fonts = await InterFonts.load();
        final doc = ModernoTemplate.render(
          document: document,
          labels: modernoLabelsFor(labelLocale),
          locale: labelLocale,
          fonts: fonts,
        );
        return doc.save();
      case TemplateId.minimal:
        await initializeDateFormatting(labelLocale.intlLocale);
        final labelFont = await InterFonts.load();
        final bodyFonts = await ClassicoFonts.load();
        final doc = MinimalTemplate.render(
          document: document,
          labels: minimalLabelsFor(labelLocale),
          locale: labelLocale,
          labelFont: labelFont,
          bodyFonts: bodyFonts,
        );
        return doc.save();
    }
  }
}
