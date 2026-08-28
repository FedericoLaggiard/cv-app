/// Analisi dei campi obbligatori mancanti (badge ⚠ del ticket 07).
///
/// È la fonte **unica** su quali campi sono obbligatori: i badge
/// dell'editor la leggono per sezione e per voce, e
/// `validation.dart` ci costruisce sopra `completenessIssues`, che è
/// ciò che l'export mostra all'utente prima di produrre il PDF.
///
/// Volutamente separata dalle invarianti strutturali: mancare un campo
/// obbligatorio è lo stato normale di una bozza in lavorazione e non
/// impedisce il salvataggio (ticket 07, "nessun blocco durante
/// l'editing"). Vedi `validateStructure` per ciò che invece rifiuta un
/// documento.
library;

import 'cv_document.dart';
import 'cv_section.dart';

/// Riferimento a un campo obbligatorio mancante.
///
/// `sectionIndex` è l'indice della sezione dentro `document.sections`.
/// `itemId` è il UUID di una voce dentro una sezione-lista (nullo per
/// campi diretti come `AnagraficaData.nome`). `field` è il nome logico
/// del campo (`nome`, `ruolo`, `azienda`, `startDate`, …).
class MissingField {
  final int sectionIndex;
  final String? itemId;
  final String field;

  const MissingField({
    required this.sectionIndex,
    this.itemId,
    required this.field,
  });

  @override
  bool operator ==(Object other) =>
      other is MissingField &&
      other.sectionIndex == sectionIndex &&
      other.itemId == itemId &&
      other.field == field;

  @override
  int get hashCode => Object.hash(sectionIndex, itemId, field);

  @override
  String toString() =>
      'MissingField(section=$sectionIndex, item=$itemId, field=$field)';
}

/// Aggregato dei campi obbligatori mancanti in un [CvDocument].
class MissingRequired {
  final Set<MissingField> fields;

  /// Conteggio per sezione (indice → numero campi mancanti,
  /// somma su tutte le voci della sezione).
  final Map<int, int> perSection;

  /// Conteggio per voce (`itemId` → numero campi mancanti).
  final Map<String, int> perItem;

  const MissingRequired({
    required this.fields,
    required this.perSection,
    required this.perItem,
  });

  static const empty = MissingRequired(
    fields: <MissingField>{},
    perSection: <int, int>{},
    perItem: <String, int>{},
  );

  int countForSection(int index) => perSection[index] ?? 0;
  int countForItem(String itemId) => perItem[itemId] ?? 0;
  bool hasFieldMissing(int sectionIndex,
          {String? itemId, required String field}) =>
      fields.contains(MissingField(
        sectionIndex: sectionIndex,
        itemId: itemId,
        field: field,
      ));
}

MissingRequired analyzeMissingRequired(CvDocument doc) {
  final missing = <MissingField>{};
  void add(int i, {String? itemId, required String field}) {
    missing.add(MissingField(sectionIndex: i, itemId: itemId, field: field));
  }

  for (var i = 0; i < doc.sections.length; i++) {
    final s = doc.sections[i];
    switch (s) {
      case AnagraficaSection(:final data):
        if (data.nome.trim().isEmpty) add(i, field: 'nome');
        if (data.cognome.trim().isEmpty) add(i, field: 'cognome');
      case ContattiSection():
        break;
      case SommarioSection():
        break;
      case EsperienzeSection(:final items):
        for (final it in items) {
          if (it.ruolo.trim().isEmpty) add(i, itemId: it.id, field: 'ruolo');
          if (it.azienda.trim().isEmpty) {
            add(i, itemId: it.id, field: 'azienda');
          }
        }
      case FormazioneSection(:final items):
        for (final it in items) {
          if (it.titolo.trim().isEmpty) {
            add(i, itemId: it.id, field: 'titolo');
          }
        }
      case SkillSection():
        break;
      case LingueSection(:final items):
        for (final it in items) {
          if (it.lingua.trim().isEmpty) {
            add(i, itemId: it.id, field: 'lingua');
          }
        }
      case CertificazioniSection(:final items):
        for (final it in items) {
          if (it.nome.trim().isEmpty) add(i, itemId: it.id, field: 'nome');
          if (it.ente.trim().isEmpty) add(i, itemId: it.id, field: 'ente');
        }
      case CustomSection():
        break;
    }
  }

  final perSection = <int, int>{};
  final perItem = <String, int>{};
  for (final m in missing) {
    perSection.update(m.sectionIndex, (v) => v + 1, ifAbsent: () => 1);
    final id = m.itemId;
    if (id != null) {
      perItem.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  return MissingRequired(
    fields: missing,
    perSection: perSection,
    perItem: perItem,
  );
}
