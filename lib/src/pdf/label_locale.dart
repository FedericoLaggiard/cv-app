/// Lingua etichette per l'export PDF (ticket 15, amendment al ticket 08).
///
/// Indipendente dalla lingua UI dell'app: scelta esplicita nel dialog di
/// export (ticket 24). Le label statiche dei template sono duplicate
/// IT/EN e chiavate su questo enum.
library;

enum LabelLocale {
  it('it', 'Italiano'),
  en('en', 'English');

  const LabelLocale(this.wire, this.displayName);

  final String wire;
  final String displayName;

  /// Locale usato per `intl.DateFormat` nel rendering delle date.
  String get intlLocale => switch (this) {
    LabelLocale.it => 'it_IT',
    LabelLocale.en => 'en_US',
  };
}

/// Stringhe condivise dai tre template (ticket 08, amendment ticket 25):
/// nomi delle sezioni fisse + "presente" per le date correnti. Ogni
/// `*Labels` per-template implementa questo mixin e aggiunge le proprie
/// stringhe specifiche (es. `pagina` per l'header di multipagina).
mixin SharedTemplateLabels {
  String get esperienze;
  String get formazione;
  String get skill;
  String get lingue;
  String get certificazioni;
  String get presente;
}

/// Label statiche del template Classico (ticket 08), localizzate.
class ClassicoLabels with SharedTemplateLabels {
  @override
  final String esperienze;
  @override
  final String formazione;
  @override
  final String skill;
  @override
  final String lingue;
  @override
  final String certificazioni;
  @override
  final String presente;
  final String pagina;

  const ClassicoLabels({
    required this.esperienze,
    required this.formazione,
    required this.skill,
    required this.lingue,
    required this.certificazioni,
    required this.presente,
    required this.pagina,
  });
}

/// Label statiche del template Moderno (ticket 08/25), localizzate.
class ModernoLabels with SharedTemplateLabels {
  @override
  final String esperienze;
  @override
  final String formazione;
  @override
  final String skill;
  @override
  final String lingue;
  @override
  final String certificazioni;
  @override
  final String presente;
  final String pagina;
  final String contatti;

  const ModernoLabels({
    required this.esperienze,
    required this.formazione,
    required this.skill,
    required this.lingue,
    required this.certificazioni,
    required this.presente,
    required this.pagina,
    required this.contatti,
  });
}

/// Label statiche del template Minimal (ticket 08/25), localizzate.
///
/// Niente `pagina`: il footer multipagina di Minimal è solo `— N —`
/// (numero, senza parola "pagina"), vedi wireframe ticket 08.
class MinimalLabels with SharedTemplateLabels {
  @override
  final String esperienze;
  @override
  final String formazione;
  @override
  final String skill;
  @override
  final String lingue;
  @override
  final String certificazioni;
  @override
  final String presente;

  const MinimalLabels({
    required this.esperienze,
    required this.formazione,
    required this.skill,
    required this.lingue,
    required this.certificazioni,
    required this.presente,
  });
}

/// Sorgente unica delle 6 stringhe condivise da [SharedTemplateLabels],
/// una per locale — i tre `*LabelsByLocale` sotto vi attingono invece di
/// ripetere i valori, per evitare che IT/EN divergano fra template per
/// errore di copia.
const Map<
  LabelLocale,
  ({
    String esperienze,
    String formazione,
    String skill,
    String lingue,
    String certificazioni,
    String presente,
  })
>
_sharedLabelValues = {
  LabelLocale.it: (
    esperienze: 'Esperienze',
    formazione: 'Formazione',
    skill: 'Skill',
    lingue: 'Lingue',
    certificazioni: 'Certificazioni',
    presente: 'in corso',
  ),
  LabelLocale.en: (
    esperienze: 'Experience',
    formazione: 'Education',
    skill: 'Skills',
    lingue: 'Languages',
    certificazioni: 'Certifications',
    presente: 'present',
  ),
};

final Map<LabelLocale, ClassicoLabels> classicoLabelsByLocale = {
  for (final entry in _sharedLabelValues.entries)
    entry.key: ClassicoLabels(
      esperienze: entry.value.esperienze,
      formazione: entry.value.formazione,
      skill: entry.value.skill,
      lingue: entry.value.lingue,
      certificazioni: entry.value.certificazioni,
      presente: entry.value.presente,
      pagina: entry.key == LabelLocale.it ? 'pag.' : 'page',
    ),
};

/// Label per [SectionKind] fissi + Classico, usata anche per sezioni con
/// header generico (es. displayTitle custom).
ClassicoLabels labelsFor(LabelLocale locale) => classicoLabelsByLocale[locale]!;

final Map<LabelLocale, ModernoLabels> modernoLabelsByLocale = {
  for (final entry in _sharedLabelValues.entries)
    entry.key: ModernoLabels(
      esperienze: entry.value.esperienze,
      formazione: entry.value.formazione,
      skill: entry.value.skill,
      lingue: entry.value.lingue,
      certificazioni: entry.value.certificazioni,
      presente: entry.value.presente,
      pagina: entry.key == LabelLocale.it ? 'pag.' : 'page',
      contatti: entry.key == LabelLocale.it ? 'Contatti' : 'Contact',
    ),
};

ModernoLabels modernoLabelsFor(LabelLocale locale) =>
    modernoLabelsByLocale[locale]!;

final Map<LabelLocale, MinimalLabels> minimalLabelsByLocale = {
  for (final entry in _sharedLabelValues.entries)
    entry.key: MinimalLabels(
      esperienze: entry.value.esperienze,
      formazione: entry.value.formazione,
      skill: entry.value.skill,
      lingue: entry.value.lingue,
      certificazioni: entry.value.certificazioni,
      presente: entry.value.presente,
    ),
};

MinimalLabels minimalLabelsFor(LabelLocale locale) =>
    minimalLabelsByLocale[locale]!;
