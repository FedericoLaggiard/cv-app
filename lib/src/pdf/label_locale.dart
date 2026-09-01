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

/// Label statiche del template Classico (ticket 08), localizzate.
class ClassicoLabels {
  final String esperienze;
  final String formazione;
  final String skill;
  final String lingue;
  final String certificazioni;
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

const Map<LabelLocale, ClassicoLabels> classicoLabelsByLocale = {
  LabelLocale.it: ClassicoLabels(
    esperienze: 'Esperienze',
    formazione: 'Formazione',
    skill: 'Skill',
    lingue: 'Lingue',
    certificazioni: 'Certificazioni',
    presente: 'in corso',
    pagina: 'pag.',
  ),
  LabelLocale.en: ClassicoLabels(
    esperienze: 'Experience',
    formazione: 'Education',
    skill: 'Skills',
    lingue: 'Languages',
    certificazioni: 'Certifications',
    presente: 'present',
    pagina: 'page',
  ),
};

/// Label per [SectionKind] fissi + Classico, usata anche per sezioni con
/// header generico (es. displayTitle custom).
ClassicoLabels labelsFor(LabelLocale locale) => classicoLabelsByLocale[locale]!;
