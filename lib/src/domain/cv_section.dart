/// Section data types and the [CvSection] sealed hierarchy.
///
/// See ticket 01 for field-level schema and ticket 03 for wire format.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'asset.dart';
import 'calendar_date.dart';
import 'copy_with_sentinel.dart';
import 'enums.dart';
import 'year_month.dart';

part 'cv_section.freezed.dart';

// -------------------- Shared value types --------------------

@immutable
class Link {
  final String label;
  final String url;
  final String? icon;

  const Link({required this.label, required this.url, this.icon});

  Link copyWith({
    String? label,
    String? url,
    Object? icon = unset,
  }) => Link(
    label: label ?? this.label,
    url: url ?? this.url,
    icon: isUnset(icon) ? this.icon : icon as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Link &&
      other.label == label &&
      other.url == url &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(label, url, icon);
}

// -------------------- Section data payloads --------------------

@freezed
abstract class AnagraficaData with _$AnagraficaData {
  const factory AnagraficaData({
    required String nome,
    required String cognome,
    CalendarDate? dataNascita,
    String? luogoNascita,
    String? nazionalita,
    Genere? genere,
    StatoCivile? statoCivile,
    String? codiceFiscale,
    AssetRef? foto,
    String? headline,
  }) = _AnagraficaData;
}

@immutable
class ContattiData {
  final String? email;
  final String? telefono;
  final String? citta;
  final String? indirizzo;
  final List<Link> link;

  ContattiData({
    this.email,
    this.telefono,
    this.citta,
    this.indirizzo,
    List<Link> link = const [],
  }) : link = List.unmodifiable(link);

  ContattiData copyWith({
    Object? email = unset,
    Object? telefono = unset,
    Object? citta = unset,
    Object? indirizzo = unset,
    List<Link>? link,
  }) => ContattiData(
    email: isUnset(email) ? this.email : email as String?,
    telefono: isUnset(telefono) ? this.telefono : telefono as String?,
    citta: isUnset(citta) ? this.citta : citta as String?,
    indirizzo: isUnset(indirizzo) ? this.indirizzo : indirizzo as String?,
    link: link ?? this.link,
  );

  @override
  bool operator ==(Object other) =>
      other is ContattiData &&
      other.email == email &&
      other.telefono == telefono &&
      other.citta == citta &&
      other.indirizzo == indirizzo &&
      _listEq(other.link, link);

  @override
  int get hashCode =>
      Object.hash(email, telefono, citta, indirizzo, Object.hashAll(link));
}

@freezed
abstract class EsperienzaItem with _$EsperienzaItem {
  const factory EsperienzaItem({
    required String id,
    required String ruolo,
    required String azienda,
    String? luogo,
    ModalitaLavoro? modalita,
    TipoContratto? tipoContratto,
    required YearMonth startDate,
    YearMonth? endDate,
    @Default(false) bool current,
    String? descrizione,
  }) = _EsperienzaItem;
}

@immutable
class FormazioneItem {
  final String id;
  final String titolo;
  final String? istituto;
  final String? luogo;
  final YearMonth? startDate;
  final YearMonth? endDate;
  final bool current;
  final String? voto;
  final String? descrizione;

  const FormazioneItem({
    required this.id,
    required this.titolo,
    this.istituto,
    this.luogo,
    this.startDate,
    this.endDate,
    this.current = false,
    this.voto,
    this.descrizione,
  });

  FormazioneItem copyWith({
    String? id,
    String? titolo,
    Object? istituto = unset,
    Object? luogo = unset,
    Object? startDate = unset,
    Object? endDate = unset,
    bool? current,
    Object? voto = unset,
    Object? descrizione = unset,
  }) => FormazioneItem(
    id: id ?? this.id,
    titolo: titolo ?? this.titolo,
    istituto: isUnset(istituto) ? this.istituto : istituto as String?,
    luogo: isUnset(luogo) ? this.luogo : luogo as String?,
    startDate:
        isUnset(startDate) ? this.startDate : startDate as YearMonth?,
    endDate: isUnset(endDate) ? this.endDate : endDate as YearMonth?,
    current: current ?? this.current,
    voto: isUnset(voto) ? this.voto : voto as String?,
    descrizione:
        isUnset(descrizione) ? this.descrizione : descrizione as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is FormazioneItem &&
      other.id == id &&
      other.titolo == titolo &&
      other.istituto == istituto &&
      other.luogo == luogo &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.current == current &&
      other.voto == voto &&
      other.descrizione == descrizione;

  @override
  int get hashCode => Object.hash(
    id,
    titolo,
    istituto,
    luogo,
    startDate,
    endDate,
    current,
    voto,
    descrizione,
  );
}

@immutable
class SkillData {
  final String? markdown;
  final List<String> tags;

  SkillData({this.markdown, List<String> tags = const []})
    : tags = List.unmodifiable(tags);

  SkillData copyWith({Object? markdown = unset, List<String>? tags}) =>
      SkillData(
        markdown: isUnset(markdown) ? this.markdown : markdown as String?,
        tags: tags ?? this.tags,
      );

  @override
  bool operator ==(Object other) =>
      other is SkillData &&
      other.markdown == markdown &&
      _listEq(other.tags, tags);

  @override
  int get hashCode => Object.hash(markdown, Object.hashAll(tags));
}

@immutable
class LinguaItem {
  final String id;
  final String lingua;
  final LivelloCefr livello;
  final String? certificazione;
  final String? note;

  const LinguaItem({
    required this.id,
    required this.lingua,
    required this.livello,
    this.certificazione,
    this.note,
  });

  LinguaItem copyWith({
    String? id,
    String? lingua,
    LivelloCefr? livello,
    Object? certificazione = unset,
    Object? note = unset,
  }) => LinguaItem(
    id: id ?? this.id,
    lingua: lingua ?? this.lingua,
    livello: livello ?? this.livello,
    certificazione: isUnset(certificazione)
        ? this.certificazione
        : certificazione as String?,
    note: isUnset(note) ? this.note : note as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is LinguaItem &&
      other.id == id &&
      other.lingua == lingua &&
      other.livello == livello &&
      other.certificazione == certificazione &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, lingua, livello, certificazione, note);
}

@immutable
class CertificazioneItem {
  final String id;
  final String nome;
  final String ente;
  final YearMonth? dataConseguimento;
  final YearMonth? dataScadenza;
  final String? codice;
  final String? urlVerifica;
  final String? descrizione;

  const CertificazioneItem({
    required this.id,
    required this.nome,
    required this.ente,
    this.dataConseguimento,
    this.dataScadenza,
    this.codice,
    this.urlVerifica,
    this.descrizione,
  });

  CertificazioneItem copyWith({
    String? id,
    String? nome,
    String? ente,
    Object? dataConseguimento = unset,
    Object? dataScadenza = unset,
    Object? codice = unset,
    Object? urlVerifica = unset,
    Object? descrizione = unset,
  }) => CertificazioneItem(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    ente: ente ?? this.ente,
    dataConseguimento: isUnset(dataConseguimento)
        ? this.dataConseguimento
        : dataConseguimento as YearMonth?,
    dataScadenza: isUnset(dataScadenza)
        ? this.dataScadenza
        : dataScadenza as YearMonth?,
    codice: isUnset(codice) ? this.codice : codice as String?,
    urlVerifica:
        isUnset(urlVerifica) ? this.urlVerifica : urlVerifica as String?,
    descrizione:
        isUnset(descrizione) ? this.descrizione : descrizione as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is CertificazioneItem &&
      other.id == id &&
      other.nome == nome &&
      other.ente == ente &&
      other.dataConseguimento == dataConseguimento &&
      other.dataScadenza == dataScadenza &&
      other.codice == codice &&
      other.urlVerifica == urlVerifica &&
      other.descrizione == descrizione;

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    ente,
    dataConseguimento,
    dataScadenza,
    codice,
    urlVerifica,
    descrizione,
  );
}

// -------------------- Sealed CvSection hierarchy --------------------

/// A single ordered entry in `CvDocument.sections`.
///
/// Identity: fixed sections are identified by [kind] (unique per document);
/// custom sections carry a [customId] UUID. See ticket 02.
@immutable
sealed class CvSection {
  final SectionKind kind;
  final String displayTitle;

  const CvSection({required this.kind, required this.displayTitle});
}

class AnagraficaSection extends CvSection {
  final AnagraficaData data;
  const AnagraficaSection({required super.displayTitle, required this.data})
    : super(kind: SectionKind.anagrafica);

  AnagraficaSection copyWith({String? displayTitle, AnagraficaData? data}) =>
      AnagraficaSection(
        displayTitle: displayTitle ?? this.displayTitle,
        data: data ?? this.data,
      );

  @override
  bool operator ==(Object other) =>
      other is AnagraficaSection &&
      other.displayTitle == displayTitle &&
      other.data == data;

  @override
  int get hashCode => Object.hash(kind, displayTitle, data);
}

class ContattiSection extends CvSection {
  final ContattiData data;
  const ContattiSection({required super.displayTitle, required this.data})
    : super(kind: SectionKind.contatti);

  ContattiSection copyWith({String? displayTitle, ContattiData? data}) =>
      ContattiSection(
        displayTitle: displayTitle ?? this.displayTitle,
        data: data ?? this.data,
      );

  @override
  bool operator ==(Object other) =>
      other is ContattiSection &&
      other.displayTitle == displayTitle &&
      other.data == data;
  @override
  int get hashCode => Object.hash(kind, displayTitle, data);
}

class SommarioSection extends CvSection {
  final String markdown;
  const SommarioSection({required super.displayTitle, required this.markdown})
    : super(kind: SectionKind.sommario);

  SommarioSection copyWith({String? displayTitle, String? markdown}) =>
      SommarioSection(
        displayTitle: displayTitle ?? this.displayTitle,
        markdown: markdown ?? this.markdown,
      );

  @override
  bool operator ==(Object other) =>
      other is SommarioSection &&
      other.displayTitle == displayTitle &&
      other.markdown == markdown;
  @override
  int get hashCode => Object.hash(kind, displayTitle, markdown);
}

class EsperienzeSection extends CvSection {
  final List<EsperienzaItem> items;
  EsperienzeSection({
    required super.displayTitle,
    List<EsperienzaItem> items = const [],
  }) : items = List.unmodifiable(items),
       super(kind: SectionKind.esperienze);

  EsperienzeSection copyWith({
    String? displayTitle,
    List<EsperienzaItem>? items,
  }) => EsperienzeSection(
    displayTitle: displayTitle ?? this.displayTitle,
    items: items ?? this.items,
  );

  @override
  bool operator ==(Object other) =>
      other is EsperienzeSection &&
      other.displayTitle == displayTitle &&
      _listEq(other.items, items);
  @override
  int get hashCode =>
      Object.hash(kind, displayTitle, Object.hashAll(items));
}

class FormazioneSection extends CvSection {
  final List<FormazioneItem> items;
  FormazioneSection({
    required super.displayTitle,
    List<FormazioneItem> items = const [],
  }) : items = List.unmodifiable(items),
       super(kind: SectionKind.formazione);

  FormazioneSection copyWith({
    String? displayTitle,
    List<FormazioneItem>? items,
  }) => FormazioneSection(
    displayTitle: displayTitle ?? this.displayTitle,
    items: items ?? this.items,
  );

  @override
  bool operator ==(Object other) =>
      other is FormazioneSection &&
      other.displayTitle == displayTitle &&
      _listEq(other.items, items);
  @override
  int get hashCode =>
      Object.hash(kind, displayTitle, Object.hashAll(items));
}

class SkillSection extends CvSection {
  final SkillData data;
  const SkillSection({required super.displayTitle, required this.data})
    : super(kind: SectionKind.skill);

  SkillSection copyWith({String? displayTitle, SkillData? data}) =>
      SkillSection(
        displayTitle: displayTitle ?? this.displayTitle,
        data: data ?? this.data,
      );

  @override
  bool operator ==(Object other) =>
      other is SkillSection &&
      other.displayTitle == displayTitle &&
      other.data == data;
  @override
  int get hashCode => Object.hash(kind, displayTitle, data);
}

class LingueSection extends CvSection {
  final List<LinguaItem> items;
  LingueSection({
    required super.displayTitle,
    List<LinguaItem> items = const [],
  }) : items = List.unmodifiable(items),
       super(kind: SectionKind.lingue);

  LingueSection copyWith({String? displayTitle, List<LinguaItem>? items}) =>
      LingueSection(
        displayTitle: displayTitle ?? this.displayTitle,
        items: items ?? this.items,
      );

  @override
  bool operator ==(Object other) =>
      other is LingueSection &&
      other.displayTitle == displayTitle &&
      _listEq(other.items, items);
  @override
  int get hashCode =>
      Object.hash(kind, displayTitle, Object.hashAll(items));
}

class CertificazioniSection extends CvSection {
  final List<CertificazioneItem> items;
  CertificazioniSection({
    required super.displayTitle,
    List<CertificazioneItem> items = const [],
  }) : items = List.unmodifiable(items),
       super(kind: SectionKind.certificazioni);

  CertificazioniSection copyWith({
    String? displayTitle,
    List<CertificazioneItem>? items,
  }) => CertificazioniSection(
    displayTitle: displayTitle ?? this.displayTitle,
    items: items ?? this.items,
  );

  @override
  bool operator ==(Object other) =>
      other is CertificazioniSection &&
      other.displayTitle == displayTitle &&
      _listEq(other.items, items);
  @override
  int get hashCode =>
      Object.hash(kind, displayTitle, Object.hashAll(items));
}

class CustomSection extends CvSection {
  /// UUID v4 immutable identity (ticket 03).
  final String id;
  final String markdown;

  const CustomSection({
    required this.id,
    required super.displayTitle,
    required this.markdown,
  }) : super(kind: SectionKind.custom);

  CustomSection copyWith({String? id, String? displayTitle, String? markdown}) =>
      CustomSection(
        id: id ?? this.id,
        displayTitle: displayTitle ?? this.displayTitle,
        markdown: markdown ?? this.markdown,
      );

  @override
  bool operator ==(Object other) =>
      other is CustomSection &&
      other.id == id &&
      other.displayTitle == displayTitle &&
      other.markdown == markdown;
  @override
  int get hashCode => Object.hash(kind, id, displayTitle, markdown);
}

// -------------------- Helpers --------------------

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
