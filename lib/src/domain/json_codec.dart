/// Strict JSON codec for [CvDocument] (ticket 03).
///
/// Rules:
/// * Unknown fields anywhere in the tree throw [CvSchemaException].
/// * `schemaVersion > currentSchemaVersion` throws [CvSchemaTooNewException].
/// * Older `schemaVersion` runs the forward-only migration chain from
///   `migrations.dart` before decoding.
/// * Output is JSON minified (no whitespace).
library;

import 'dart:convert';

import 'asset.dart';
import 'calendar_date.dart';
import 'cv_document.dart';
import 'cv_section.dart';
import 'enums.dart';
import 'migrations.dart';
import 'year_month.dart';

class CvSchemaException implements Exception {
  final String message;
  final String? path;
  CvSchemaException(this.message, {this.path});
  @override
  String toString() =>
      path == null ? 'CvSchemaException: $message' : 'CvSchemaException at $path: $message';
}

class CvSchemaTooNewException extends CvSchemaException {
  final int fileVersion;
  final int supported;
  CvSchemaTooNewException(this.fileVersion, this.supported)
    : super(
        'schemaVersion $fileVersion is newer than supported $supported',
        path: r'$.schemaVersion',
      );
}

class CvDocumentCodec {
  const CvDocumentCodec._();

  // ---------- Public API ----------

  static CvDocument fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw CvSchemaException('root must be a JSON object');
    }
    return fromJsonMap(decoded);
  }

  static CvDocument fromJsonMap(Map<String, dynamic> raw) {
    final migrated = CvMigrations.apply(raw);
    return _decodeDocument(migrated);
  }

  static String toJsonString(CvDocument doc) =>
      jsonEncode(toJsonMap(doc));

  static Map<String, dynamic> toJsonMap(CvDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'id': doc.id,
      'createdAt': doc.createdAt.toUtc().toIso8601String(),
      'updatedAt': doc.updatedAt.toUtc().toIso8601String(),
      'variantName': doc.variantName,
      'sections': doc.sections.map(_encodeSection).toList(),
      'assets': doc.assets.map((k, v) => MapEntry(k, {
            'mimeType': v.mimeType,
            'data': v.data,
          })),
    };
  }

  // ---------- Root decode ----------

  static const _rootKeys = {
    'schemaVersion',
    'id',
    'createdAt',
    'updatedAt',
    'variantName',
    'sections',
    'assets',
  };

  static CvDocument _decodeDocument(Map<String, dynamic> raw) {
    _requireOnlyKeys(raw, _rootKeys, r'$');
    final version = _requireInt(raw, 'schemaVersion', r'$');
    if (version > currentSchemaVersion) {
      throw CvSchemaTooNewException(version, currentSchemaVersion);
    }
    if (version < 1) {
      throw CvSchemaException('schemaVersion must be >= 1', path: r'$.schemaVersion');
    }

    final sectionsRaw = raw['sections'];
    if (sectionsRaw is! List) {
      throw CvSchemaException('missing or non-list `sections`',
          path: r'$.sections');
    }
    final sections = <CvSection>[];
    for (var i = 0; i < sectionsRaw.length; i++) {
      final entry = sectionsRaw[i];
      if (entry is! Map<String, dynamic>) {
        throw CvSchemaException('section must be an object', path: r'$.sections[' '$i]');
      }
      sections.add(_decodeSection(entry, i));
    }

    final assetsRaw = raw['assets'];
    final assets = <String, Asset>{};
    if (assetsRaw != null) {
      if (assetsRaw is! Map<String, dynamic>) {
        throw CvSchemaException('assets must be an object', path: r'$.assets');
      }
      assetsRaw.forEach((k, v) {
        if (v is! Map<String, dynamic>) {
          throw CvSchemaException('asset must be object', path: r'$.assets.' '$k');
        }
        _requireOnlyKeys(v, {'mimeType', 'data'}, r'$.assets.' '$k');
        assets[k] = Asset(
          mimeType: _requireString(v, 'mimeType', r'$.assets.' '$k'),
          data: _requireString(v, 'data', r'$.assets.' '$k'),
        );
      });
    }

    return CvDocument(
      schemaVersion: version,
      id: _requireString(raw, 'id', r'$'),
      createdAt: _requireDateTime(raw, 'createdAt', r'$'),
      updatedAt: _requireDateTime(raw, 'updatedAt', r'$'),
      variantName: _requireString(raw, 'variantName', r'$'),
      sections: sections,
      assets: assets,
    );
  }

  // ---------- Section decode ----------

  static const _sectionWrapperKeys = {'kind', 'displayTitle', 'data', 'id'};

  static CvSection _decodeSection(Map<String, dynamic> raw, int index) {
    _requireOnlyKeys(raw, _sectionWrapperKeys, r'$.sections[' '$index]');
    final kindStr = _requireString(raw, 'kind', r'$.sections[' '$index]');
    final SectionKind kind;
    try {
      kind = SectionKind.fromWire(kindStr);
    } on FormatException catch (e) {
      throw CvSchemaException(e.message, path: r'$.sections[' '$index].kind');
    }
    final displayTitle =
        _requireString(raw, 'displayTitle', r'$.sections[' '$index]');
    final data = raw['data'];
    final path = r'$.sections[' '$index]';

    // `id` is allowed only on custom sections.
    if (kind != SectionKind.custom && raw.containsKey('id')) {
      throw CvSchemaException(
        '`id` is only allowed on custom sections',
        path: '$path.id',
      );
    }
    if (kind == SectionKind.custom && !raw.containsKey('id')) {
      throw CvSchemaException(
        '`id` is required on custom sections',
        path: '$path.id',
      );
    }

    switch (kind) {
      case SectionKind.anagrafica:
        return AnagraficaSection(
          displayTitle: displayTitle,
          data: _decodeAnagrafica(_asObject(data, '$path.data'), '$path.data'),
        );
      case SectionKind.contatti:
        return ContattiSection(
          displayTitle: displayTitle,
          data: _decodeContatti(_asObject(data, '$path.data'), '$path.data'),
        );
      case SectionKind.sommario:
        return SommarioSection(
          displayTitle: displayTitle,
          markdown: _asString(data, '$path.data'),
        );
      case SectionKind.esperienze:
        return EsperienzeSection(
          displayTitle: displayTitle,
          items: _decodeItemList(
            data,
            '$path.data',
            _decodeEsperienzaItem,
          ),
        );
      case SectionKind.formazione:
        return FormazioneSection(
          displayTitle: displayTitle,
          items: _decodeItemList(
            data,
            '$path.data',
            _decodeFormazioneItem,
          ),
        );
      case SectionKind.skill:
        return SkillSection(
          displayTitle: displayTitle,
          data: _decodeSkill(_asObject(data, '$path.data'), '$path.data'),
        );
      case SectionKind.lingue:
        return LingueSection(
          displayTitle: displayTitle,
          items: _decodeItemList(
            data,
            '$path.data',
            _decodeLinguaItem,
          ),
        );
      case SectionKind.certificazioni:
        return CertificazioniSection(
          displayTitle: displayTitle,
          items: _decodeItemList(
            data,
            '$path.data',
            _decodeCertificazioneItem,
          ),
        );
      case SectionKind.custom:
        return CustomSection(
          id: _requireString(raw, 'id', path),
          displayTitle: displayTitle,
          markdown: _asString(data, '$path.data'),
        );
    }
  }

  // ---------- Payload decoders ----------

  static const _anagraficaKeys = {
    'nome',
    'cognome',
    'dataNascita',
    'luogoNascita',
    'nazionalita',
    'genere',
    'statoCivile',
    'codiceFiscale',
    'foto',
    'headline',
  };

  static AnagraficaData _decodeAnagrafica(Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _anagraficaKeys, path);
    return AnagraficaData(
      nome: _requireString(raw, 'nome', path),
      cognome: _requireString(raw, 'cognome', path),
      dataNascita: _optCalendarDate(raw, 'dataNascita', path),
      luogoNascita: _optString(raw, 'luogoNascita', path),
      nazionalita: _optString(raw, 'nazionalita', path),
      genere: _optEnum(raw, 'genere', path, Genere.fromWire),
      statoCivile: _optEnum(raw, 'statoCivile', path, StatoCivile.fromWire),
      codiceFiscale: _optString(raw, 'codiceFiscale', path),
      foto: _decodeAssetRef(raw['foto'], '$path.foto'),
      headline: _optString(raw, 'headline', path),
    );
  }

  static AssetRef? _decodeAssetRef(Object? raw, String path) {
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw CvSchemaException('must be an object', path: path);
    }
    _requireOnlyKeys(raw, {'assetId'}, path);
    final id = raw['assetId'];
    if (id is! String) {
      throw CvSchemaException('assetId must be string', path: '$path.assetId');
    }
    return AssetRef(id);
  }

  static const _contattiKeys = {
    'email',
    'telefono',
    'citta',
    'indirizzo',
    'link',
  };
  static ContattiData _decodeContatti(Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _contattiKeys, path);
    final links = <Link>[];
    final linkRaw = raw['link'];
    if (linkRaw != null) {
      if (linkRaw is! List) {
        throw CvSchemaException('link must be a list', path: '$path.link');
      }
      for (var i = 0; i < linkRaw.length; i++) {
        final e = linkRaw[i];
        if (e is! Map<String, dynamic>) {
          throw CvSchemaException('link entry must be object',
              path: '$path.link[$i]');
        }
        _requireOnlyKeys(e, {'label', 'url', 'icon'}, '$path.link[$i]');
        links.add(Link(
          label: _requireString(e, 'label', '$path.link[$i]'),
          url: _requireString(e, 'url', '$path.link[$i]'),
          icon: _optString(e, 'icon', '$path.link[$i]'),
        ));
      }
    }
    return ContattiData(
      email: _optString(raw, 'email', path),
      telefono: _optString(raw, 'telefono', path),
      citta: _optString(raw, 'citta', path),
      indirizzo: _optString(raw, 'indirizzo', path),
      link: links,
    );
  }

  static const _esperienzaKeys = {
    'id',
    'ruolo',
    'azienda',
    'luogo',
    'modalita',
    'tipoContratto',
    'startDate',
    'endDate',
    'current',
    'descrizione',
  };
  static EsperienzaItem _decodeEsperienzaItem(
      Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _esperienzaKeys, path);
    return EsperienzaItem(
      id: _requireString(raw, 'id', path),
      ruolo: _requireString(raw, 'ruolo', path),
      azienda: _requireString(raw, 'azienda', path),
      luogo: _optString(raw, 'luogo', path),
      modalita: _optEnum(raw, 'modalita', path, ModalitaLavoro.fromWire),
      tipoContratto:
          _optEnum(raw, 'tipoContratto', path, TipoContratto.fromWire),
      startDate: _requireYearMonth(raw, 'startDate', path),
      endDate: _optYearMonth(raw, 'endDate', path),
      current: _optBool(raw, 'current', path) ?? false,
      descrizione: _optString(raw, 'descrizione', path),
    );
  }

  static const _formazioneKeys = {
    'id',
    'titolo',
    'istituto',
    'luogo',
    'startDate',
    'endDate',
    'current',
    'voto',
    'descrizione',
  };
  static FormazioneItem _decodeFormazioneItem(
      Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _formazioneKeys, path);
    return FormazioneItem(
      id: _requireString(raw, 'id', path),
      titolo: _requireString(raw, 'titolo', path),
      istituto: _optString(raw, 'istituto', path),
      luogo: _optString(raw, 'luogo', path),
      startDate: _optYearMonth(raw, 'startDate', path),
      endDate: _optYearMonth(raw, 'endDate', path),
      current: _optBool(raw, 'current', path) ?? false,
      voto: _optString(raw, 'voto', path),
      descrizione: _optString(raw, 'descrizione', path),
    );
  }

  static const _skillKeys = {'markdown', 'tags'};
  static SkillData _decodeSkill(Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _skillKeys, path);
    final tagsRaw = raw['tags'];
    final tags = <String>[];
    if (tagsRaw != null) {
      if (tagsRaw is! List) {
        throw CvSchemaException('tags must be list', path: '$path.tags');
      }
      for (var i = 0; i < tagsRaw.length; i++) {
        final v = tagsRaw[i];
        if (v is! String) {
          throw CvSchemaException('tag must be string',
              path: '$path.tags[$i]');
        }
        tags.add(v);
      }
    }
    return SkillData(
      markdown: _optString(raw, 'markdown', path),
      tags: tags,
    );
  }

  static const _linguaKeys = {
    'id',
    'lingua',
    'livello',
    'certificazione',
    'note',
  };
  static LinguaItem _decodeLinguaItem(Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _linguaKeys, path);
    final livelloStr = _requireString(raw, 'livello', path);
    final LivelloCefr livello;
    try {
      livello = LivelloCefr.fromWire(livelloStr);
    } on FormatException catch (e) {
      throw CvSchemaException(e.message, path: '$path.livello');
    }
    return LinguaItem(
      id: _requireString(raw, 'id', path),
      lingua: _requireString(raw, 'lingua', path),
      livello: livello,
      certificazione: _optString(raw, 'certificazione', path),
      note: _optString(raw, 'note', path),
    );
  }

  static const _certificazioneKeys = {
    'id',
    'nome',
    'ente',
    'dataConseguimento',
    'dataScadenza',
    'codice',
    'urlVerifica',
    'descrizione',
  };
  static CertificazioneItem _decodeCertificazioneItem(
      Map<String, dynamic> raw, String path) {
    _requireOnlyKeys(raw, _certificazioneKeys, path);
    return CertificazioneItem(
      id: _requireString(raw, 'id', path),
      nome: _requireString(raw, 'nome', path),
      ente: _requireString(raw, 'ente', path),
      dataConseguimento: _optYearMonth(raw, 'dataConseguimento', path),
      dataScadenza: _optYearMonth(raw, 'dataScadenza', path),
      codice: _optString(raw, 'codice', path),
      urlVerifica: _optString(raw, 'urlVerifica', path),
      descrizione: _optString(raw, 'descrizione', path),
    );
  }

  // ---------- Encoders ----------

  static Map<String, dynamic> _encodeSection(CvSection s) {
    final base = <String, dynamic>{
      'kind': s.kind.wire,
      'displayTitle': s.displayTitle,
    };
    switch (s) {
      case AnagraficaSection(:final data):
        base['data'] = _encodeAnagrafica(data);
      case ContattiSection(:final data):
        base['data'] = _encodeContatti(data);
      case SommarioSection(:final markdown):
        base['data'] = markdown;
      case EsperienzeSection(:final items):
        base['data'] = items.map(_encodeEsperienza).toList();
      case FormazioneSection(:final items):
        base['data'] = items.map(_encodeFormazione).toList();
      case SkillSection(:final data):
        base['data'] = _encodeSkill(data);
      case LingueSection(:final items):
        base['data'] = items.map(_encodeLingua).toList();
      case CertificazioniSection(:final items):
        base['data'] = items.map(_encodeCertificazione).toList();
      case CustomSection(:final id, :final markdown):
        base['id'] = id;
        base['data'] = markdown;
    }
    return base;
  }

  static Map<String, dynamic> _encodeAnagrafica(AnagraficaData d) {
    final m = <String, dynamic>{
      'nome': d.nome,
      'cognome': d.cognome,
    };
    if (d.dataNascita != null) {
      m['dataNascita'] = d.dataNascita.toString();
    }
    if (d.luogoNascita != null) m['luogoNascita'] = d.luogoNascita;
    if (d.nazionalita != null) m['nazionalita'] = d.nazionalita;
    if (d.genere != null) m['genere'] = d.genere!.wire;
    if (d.statoCivile != null) m['statoCivile'] = d.statoCivile!.wire;
    if (d.codiceFiscale != null) m['codiceFiscale'] = d.codiceFiscale;
    if (d.foto != null) m['foto'] = {'assetId': d.foto!.assetId};
    if (d.headline != null) m['headline'] = d.headline;
    return m;
  }

  static Map<String, dynamic> _encodeContatti(ContattiData d) {
    final m = <String, dynamic>{};
    if (d.email != null) m['email'] = d.email;
    if (d.telefono != null) m['telefono'] = d.telefono;
    if (d.citta != null) m['citta'] = d.citta;
    if (d.indirizzo != null) m['indirizzo'] = d.indirizzo;
    if (d.link.isNotEmpty) {
      m['link'] = d.link.map((l) {
        final e = <String, dynamic>{'label': l.label, 'url': l.url};
        if (l.icon != null) e['icon'] = l.icon;
        return e;
      }).toList();
    }
    return m;
  }

  static Map<String, dynamic> _encodeEsperienza(EsperienzaItem i) {
    final m = <String, dynamic>{
      'id': i.id,
      'ruolo': i.ruolo,
      'azienda': i.azienda,
      'startDate': i.startDate.toString(),
    };
    if (i.luogo != null) m['luogo'] = i.luogo;
    if (i.modalita != null) m['modalita'] = i.modalita!.wire;
    if (i.tipoContratto != null) m['tipoContratto'] = i.tipoContratto!.wire;
    if (i.endDate != null) m['endDate'] = i.endDate.toString();
    if (i.current) m['current'] = true;
    if (i.descrizione != null) m['descrizione'] = i.descrizione;
    return m;
  }

  static Map<String, dynamic> _encodeFormazione(FormazioneItem i) {
    final m = <String, dynamic>{'id': i.id, 'titolo': i.titolo};
    if (i.istituto != null) m['istituto'] = i.istituto;
    if (i.luogo != null) m['luogo'] = i.luogo;
    if (i.startDate != null) m['startDate'] = i.startDate.toString();
    if (i.endDate != null) m['endDate'] = i.endDate.toString();
    if (i.current) m['current'] = true;
    if (i.voto != null) m['voto'] = i.voto;
    if (i.descrizione != null) m['descrizione'] = i.descrizione;
    return m;
  }

  static Map<String, dynamic> _encodeSkill(SkillData d) {
    final m = <String, dynamic>{};
    if (d.markdown != null) m['markdown'] = d.markdown;
    if (d.tags.isNotEmpty) m['tags'] = List<String>.from(d.tags);
    return m;
  }

  static Map<String, dynamic> _encodeLingua(LinguaItem i) {
    final m = <String, dynamic>{
      'id': i.id,
      'lingua': i.lingua,
      'livello': i.livello.wire,
    };
    if (i.certificazione != null) m['certificazione'] = i.certificazione;
    if (i.note != null) m['note'] = i.note;
    return m;
  }

  static Map<String, dynamic> _encodeCertificazione(CertificazioneItem i) {
    final m = <String, dynamic>{
      'id': i.id,
      'nome': i.nome,
      'ente': i.ente,
    };
    if (i.dataConseguimento != null) {
      m['dataConseguimento'] = i.dataConseguimento.toString();
    }
    if (i.dataScadenza != null) m['dataScadenza'] = i.dataScadenza.toString();
    if (i.codice != null) m['codice'] = i.codice;
    if (i.urlVerifica != null) m['urlVerifica'] = i.urlVerifica;
    if (i.descrizione != null) m['descrizione'] = i.descrizione;
    return m;
  }

  // ---------- Generic helpers ----------

  static List<T> _decodeItemList<T>(
    Object? raw,
    String path,
    T Function(Map<String, dynamic>, String) decode,
  ) {
    if (raw is! List) {
      throw CvSchemaException('must be a list', path: path);
    }
    final out = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map<String, dynamic>) {
        throw CvSchemaException('item must be object', path: '$path[$i]');
      }
      out.add(decode(entry, '$path[$i]'));
    }
    return out;
  }

  static void _requireOnlyKeys(
      Map<String, dynamic> raw, Set<String> allowed, String path) {
    for (final k in raw.keys) {
      if (!allowed.contains(k)) {
        throw CvSchemaException('unknown field `$k`', path: path);
      }
    }
  }

  static String _requireString(Map<String, dynamic> raw, String k, String path) {
    final v = raw[k];
    if (v is! String) {
      throw CvSchemaException('missing or non-string `$k`', path: '$path.$k');
    }
    return v;
  }

  static String? _optString(Map<String, dynamic> raw, String k, String path) {
    if (!raw.containsKey(k) || raw[k] == null) return null;
    final v = raw[k];
    if (v is! String) {
      throw CvSchemaException('`$k` must be string', path: '$path.$k');
    }
    return v;
  }

  static int _requireInt(Map<String, dynamic> raw, String k, String path) {
    final v = raw[k];
    if (v is! int) {
      throw CvSchemaException('missing or non-int `$k`', path: '$path.$k');
    }
    return v;
  }

  static bool? _optBool(Map<String, dynamic> raw, String k, String path) {
    if (!raw.containsKey(k) || raw[k] == null) return null;
    final v = raw[k];
    if (v is! bool) {
      throw CvSchemaException('`$k` must be bool', path: '$path.$k');
    }
    return v;
  }

  static DateTime _requireDateTime(
      Map<String, dynamic> raw, String k, String path) {
    final v = _requireString(raw, k, path);
    return _parseUtcInstant(v, '$path.$k');
  }

  /// Parses an ISO-8601 instant and enforces that it is expressed in UTC
  /// (i.e. carries a `Z` or explicit `+00:00` suffix). Spec 03 §41.
  static DateTime _parseUtcInstant(String v, String path) {
    final endsZ = v.endsWith('Z');
    final endsPlus = v.endsWith('+00:00') || v.endsWith('+0000');
    if (!endsZ && !endsPlus) {
      throw CvSchemaException(
        'ISO-8601 datetime must be expressed in UTC (Z or +00:00 suffix)',
        path: path,
      );
    }
    try {
      return DateTime.parse(v).toUtc();
    } on FormatException {
      throw CvSchemaException('malformed ISO-8601 datetime', path: path);
    }
  }

  static CalendarDate? _optCalendarDate(
      Map<String, dynamic> raw, String k, String path) {
    final v = _optString(raw, k, path);
    if (v == null) return null;
    try {
      return CalendarDate.parse(v);
    } on FormatException {
      throw CvSchemaException('`$k` must be YYYY-MM-DD', path: '$path.$k');
    }
  }

  static YearMonth _requireYearMonth(
      Map<String, dynamic> raw, String k, String path) {
    final v = _requireString(raw, k, path);
    try {
      return YearMonth.parse(v);
    } on FormatException {
      throw CvSchemaException('`$k` must be YYYY-MM', path: '$path.$k');
    }
  }

  static YearMonth? _optYearMonth(
      Map<String, dynamic> raw, String k, String path) {
    final v = _optString(raw, k, path);
    if (v == null) return null;
    try {
      return YearMonth.parse(v);
    } on FormatException {
      throw CvSchemaException('`$k` must be YYYY-MM', path: '$path.$k');
    }
  }

  static T? _optEnum<T>(
    Map<String, dynamic> raw,
    String k,
    String path,
    T Function(String) fromWire,
  ) {
    final v = _optString(raw, k, path);
    if (v == null) return null;
    try {
      return fromWire(v);
    } on FormatException catch (e) {
      throw CvSchemaException(e.message, path: '$path.$k');
    }
  }

  static Map<String, dynamic> _asObject(Object? raw, String path) {
    if (raw is! Map<String, dynamic>) {
      throw CvSchemaException('must be an object', path: path);
    }
    return raw;
  }

  static String _asString(Object? raw, String path) {
    if (raw is! String) {
      throw CvSchemaException('must be a string', path: path);
    }
    return raw;
  }
}
