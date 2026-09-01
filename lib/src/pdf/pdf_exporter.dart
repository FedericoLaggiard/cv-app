/// Seam unico di export PDF per tutti i template presenti/futuri (ticket 24).
library;

import 'dart:typed_data';

import 'package:intl/date_symbol_data_local.dart';

import '../domain/cv_document.dart';
import 'classico_template.dart';
import 'label_locale.dart';
import 'pdf_fonts.dart';

/// Template PDF disponibili. In questa slice solo [classico] è renderizzato;
/// gli altri due (ticket 08) arriveranno con la Slice F.
enum TemplateId {
  classico('classico', 'Classico');

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
    }
  }
}
