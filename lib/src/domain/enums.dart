/// Canonical enums for the CV schema.
///
/// **Wire values are snake_case ASCII** (ticket 03). Dart identifiers are
/// lowerCamelCase to satisfy `camel_case_types`/`constant_identifier_names`
/// lints; the mapping between the two lives in [wire] / `fromWire`.
library;

enum SectionKind {
  anagrafica('anagrafica'),
  contatti('contatti'),
  sommario('sommario'),
  esperienze('esperienze'),
  formazione('formazione'),
  skill('skill'),
  lingue('lingue'),
  certificazioni('certificazioni'),
  custom('custom');

  const SectionKind(this.wire);
  final String wire;

  static SectionKind fromWire(String value) {
    for (final k in SectionKind.values) {
      if (k.wire == value) return k;
    }
    throw FormatException('Unknown section kind: $value');
  }

  /// True for the fixed structured sections (everything except `custom`).
  /// Fixed sections have a unique `kind` per variant; custom sections carry
  /// their own UUID identity.
  bool get isFixed => this != SectionKind.custom;
}

enum LivelloCefr {
  a1('a1'),
  a2('a2'),
  b1('b1'),
  b2('b2'),
  c1('c1'),
  c2('c2'),
  madrelingua('madrelingua');

  const LivelloCefr(this.wire);
  final String wire;

  static LivelloCefr fromWire(String value) {
    for (final v in LivelloCefr.values) {
      if (v.wire == value) return v;
    }
    throw FormatException('Unknown CEFR level: $value');
  }
}

enum Genere {
  femminile('femminile'),
  maschile('maschile'),
  altro('altro'),
  preferiscoNonSpecificare('preferisco_non_specificare');

  const Genere(this.wire);
  final String wire;

  static Genere fromWire(String value) {
    for (final v in Genere.values) {
      if (v.wire == value) return v;
    }
    throw FormatException('Unknown gender: $value');
  }
}

enum StatoCivile {
  celibeNubile('celibe_nubile'),
  coniugato('coniugato_a'),
  divorziato('divorziato_a'),
  vedovo('vedovo_a'),
  convivente('convivente');

  const StatoCivile(this.wire);
  final String wire;

  static StatoCivile fromWire(String value) {
    for (final v in StatoCivile.values) {
      if (v.wire == value) return v;
    }
    throw FormatException('Unknown civil status: $value');
  }
}

enum ModalitaLavoro {
  inSede('in_sede'),
  remoto('remoto'),
  ibrido('ibrido');

  const ModalitaLavoro(this.wire);
  final String wire;

  static ModalitaLavoro fromWire(String value) {
    for (final v in ModalitaLavoro.values) {
      if (v.wire == value) return v;
    }
    throw FormatException('Unknown work modality: $value');
  }
}

enum TipoContratto {
  fullTime('full_time'),
  partTime('part_time'),
  freelance('freelance'),
  stage('stage'),
  consulenza('consulenza');

  const TipoContratto(this.wire);
  final String wire;

  static TipoContratto fromWire(String value) {
    for (final v in TipoContratto.values) {
      if (v.wire == value) return v;
    }
    throw FormatException('Unknown contract type: $value');
  }
}
