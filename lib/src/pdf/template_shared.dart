/// Helper condivisi dai tre template PDF (ticket 08/24/25).
///
/// Conversioni di dominio, label multilingua e il pattern "header di
/// sezione + keepTogether col primo item" erano duplicati identici fra
/// `ClassicoTemplate`, `ModernoTemplate` e `MinimalTemplate`: estratti qui
/// per avere una sola sorgente di verità.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/cv_document.dart';
import '../domain/cv_section.dart';
import '../domain/enums.dart';
import '../domain/year_month.dart';
import '../photo/photo_normalizer.dart' show decodePhotoBase64;
import 'label_locale.dart';

/// Decodifica i bytes della foto profilo (Slice G, ticket 26) referenziata
/// da [anagrafica]`.data.foto` nello store `assets` di [document].
/// `null` quando assente, o quando il riferimento/asset non è risolvibile
/// (asset mancante, base64 corrotto) — i template trattano questi casi
/// come "nessuna foto" invece di far fallire l'export.
Uint8List? photoBytesFor(CvDocument document, AnagraficaSection? anagrafica) {
  final ref = anagrafica?.data.foto;
  if (ref == null) return null;
  final asset = document.assets[ref.assetId];
  if (asset == null) return null;
  return decodePhotoBase64(asset.data);
}

extension YearMonthPdf on YearMonth {
  DateTime toDateTime() => DateTime(year, month);
}

extension FirstOrNullPdf<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Formatta un intervallo `[start, end]` per le voci Esperienze/Formazione,
/// con `labels.presente` al posto di [end] quando `current` è true.
String formatDateRange({
  required YearMonth? start,
  required YearMonth? end,
  required bool current,
  required DateFormat format,
  required SharedTemplateLabels labels,
}) {
  final startStr = start == null ? '' : format.format(start.toDateTime());
  final endStr = current
      ? labels.presente
      : (end == null ? '' : format.format(end.toDateTime()));
  if (startStr.isEmpty) return endStr;
  return endStr.isEmpty ? startStr : '$startStr – $endStr';
}

String modalitaLabel(ModalitaLavoro m, LabelLocale locale) {
  const it = {
    ModalitaLavoro.inSede: 'in sede',
    ModalitaLavoro.remoto: 'remoto',
    ModalitaLavoro.ibrido: 'ibrido',
  };
  const en = {
    ModalitaLavoro.inSede: 'on-site',
    ModalitaLavoro.remoto: 'remote',
    ModalitaLavoro.ibrido: 'hybrid',
  };
  return (locale == LabelLocale.it ? it : en)[m]!;
}

String tipoContrattoLabel(TipoContratto t, LabelLocale locale) {
  const it = {
    TipoContratto.fullTime: 'full-time',
    TipoContratto.partTime: 'part-time',
    TipoContratto.freelance: 'freelance',
    TipoContratto.stage: 'stage',
    TipoContratto.consulenza: 'consulenza',
  };
  const en = {
    TipoContratto.fullTime: 'full-time',
    TipoContratto.partTime: 'part-time',
    TipoContratto.freelance: 'freelance',
    TipoContratto.stage: 'internship',
    TipoContratto.consulenza: 'consulting',
  };
  return (locale == LabelLocale.it ? it : en)[t]!;
}

String cefrLabel(LivelloCefr l, LabelLocale locale) {
  if (l == LivelloCefr.madrelingua) {
    return locale == LabelLocale.it ? 'Madrelingua' : 'Native';
  }
  return l.wire.toUpperCase();
}

/// [header] + il primo item di [items] come blocco `pw.Inseparable` (mai
/// header orfano a fine pagina); gli item restanti restano widget separati,
/// ognuno libero di cadere su una nuova pagina (ticket 08, riusato da tutti
/// e tre i template).
List<pw.Widget> keepFirstItemWithHeader<T>({
  required pw.Widget header,
  required List<T> items,
  required pw.Widget Function(T item) rowBuilder,
}) {
  if (items.isEmpty) return [header];
  final widgets = <pw.Widget>[
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [header, rowBuilder(items.first)],
      ),
    ),
  ];
  widgets.addAll(items.skip(1).map(rowBuilder));
  return widgets;
}
