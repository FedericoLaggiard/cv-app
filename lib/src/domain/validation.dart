/// Semantic invariants for a [CvDocument] (tickets 01, 02, 03).
///
/// Le regole sono divise in due famiglie, perché rispondono a due domande
/// diverse:
///
///  * **strutturali** — il documento è *coerente*? Titoli unici, `kind`
///    fissi non ripetuti, id presenti e univoci, `current` xor `endDate`,
///    range di date sensati, riferimenti ad asset risolvibili. Un
///    documento che viola queste regole è corrotto: nessuna quantità di
///    digitazione lo rende sensato, quindi non deve mai finire su disco.
///    Applicate da `save()`, dal caricamento e dall'import.
///  * **completezza** — i campi obbligatori sono compilati? Una bozza in
///    lavorazione li viola di continuo, per definizione (ticket 07:
///    "nessun blocco durante l'editing"). Non impediscono il salvataggio:
///    sono ciò che l'export segnala all'utente prima di produrre il PDF.
///
/// Di conseguenza:
///  * [validateStructure] → solo strutturali, usata dalla persistenza;
///  * [completenessIssues] → elenco non bloccante dei campi mancanti;
///  * [validate] → entrambe, per i punti in cui pretendiamo un CV finito.
///
/// La conoscenza di *quali* campi sono obbligatori vive in un posto solo,
/// [analyzeMissingRequired] (`missing_required.dart`): i badge ⚠
/// dell'editor e gli avvisi di export leggono la stessa fonte.
library;

import 'cv_document.dart';
import 'cv_section.dart';
import 'enums.dart';
import 'missing_required.dart';

class CvValidationException implements Exception {
  final List<String> errors;
  CvValidationException(this.errors);
  @override
  String toString() =>
      'CvValidationException:\n${errors.map((e) => '  - $e').join('\n')}';
}

/// Struttura **e** completezza. Throws [CvValidationException] elencando
/// ogni violazione. Da usare dove serve un CV finito (export), non nel
/// percorso di salvataggio.
void validate(CvDocument doc) {
  final errors = [..._structuralErrors(doc), ...completenessIssues(doc)];
  if (errors.isNotEmpty) {
    throw CvValidationException(errors);
  }
}

/// Solo invarianti strutturali. È ciò che protegge il file su disco: una
/// bozza incompleta passa, un documento incoerente no.
void validateStructure(CvDocument doc) {
  final errors = _structuralErrors(doc);
  if (errors.isNotEmpty) {
    throw CvValidationException(errors);
  }
}

/// Elenco leggibile dei campi obbligatori mancanti. Non lancia: il
/// chiamante decide se avvisare, bloccare o ignorare.
List<String> completenessIssues(CvDocument doc) {
  final missing = analyzeMissingRequired(doc);
  return [
    for (final m in missing.fields)
      m.itemId == null
          ? 'sections[${m.sectionIndex}].${m.field} is required'
          : 'sections[${m.sectionIndex}].items[${m.itemId}].${m.field} is required',
  ];
}

List<String> _structuralErrors(CvDocument doc) {
  final errors = <String>[];

  if (doc.variantName.trim().isEmpty) {
    errors.add('variantName must be non-empty');
  }
  if (doc.id.isEmpty) {
    errors.add('id must be non-empty');
  }

  // displayTitle uniqueness (case-insensitive + trim) and non-emptiness.
  final normalizedTitles = <String, int>{};
  for (var i = 0; i < doc.sections.length; i++) {
    final title = doc.sections[i].displayTitle;
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      errors.add('sections[$i].displayTitle must be non-empty');
      continue;
    }
    final key = trimmed.toLowerCase();
    final previous = normalizedTitles[key];
    if (previous != null) {
      errors.add(
        'sections[$i].displayTitle "$title" duplicates sections[$previous]',
      );
    } else {
      normalizedTitles[key] = i;
    }
  }

  // Kind uniqueness for non-custom sections, and id uniqueness for custom.
  final seenKinds = <SectionKind>{};
  final seenCustomIds = <String, int>{};
  for (var i = 0; i < doc.sections.length; i++) {
    final s = doc.sections[i];
    if (s.kind.isFixed) {
      if (!seenKinds.add(s.kind)) {
        errors.add(
          'sections[$i].kind ${s.kind.wire} is not unique (fixed sections must appear at most once)',
        );
      }
    } else if (s is CustomSection && s.id.isNotEmpty) {
      final prev = seenCustomIds[s.id];
      if (prev != null) {
        errors.add(
          'sections[$i].id "${s.id}" duplicates sections[$prev].id',
        );
      } else {
        seenCustomIds[s.id] = i;
      }
    }
  }

  // Per-section invariants.
  for (var i = 0; i < doc.sections.length; i++) {
    final s = doc.sections[i];
    final path = 'sections[$i]';
    switch (s) {
      case AnagraficaSection():
        // nome/cognome sono completezza, non struttura: vedi
        // `completenessIssues`.
        break;
      case ContattiSection():
        break; // no strict requirements
      case SommarioSection():
        break;
      case EsperienzeSection(:final items):
        _validateListIds(items.map((i) => i.id).toList(), path, errors);
        for (var j = 0; j < items.length; j++) {
          final it = items[j];
          final ip = '$path.items[$j]';
          if (it.id.isEmpty) errors.add('$ip.id required');
          if (it.current && it.endDate != null) {
            errors.add('$ip cannot have both current=true and endDate');
          }
          if (it.endDate != null && it.endDate!.compareTo(it.startDate) < 0) {
            errors.add('$ip.endDate is before startDate');
          }
        }
      case FormazioneSection(:final items):
        _validateListIds(items.map((i) => i.id).toList(), path, errors);
        for (var j = 0; j < items.length; j++) {
          final it = items[j];
          final ip = '$path.items[$j]';
          if (it.id.isEmpty) errors.add('$ip.id required');
          if (it.current && it.endDate != null) {
            errors.add('$ip cannot have both current=true and endDate');
          }
          if (it.startDate != null &&
              it.endDate != null &&
              it.endDate!.compareTo(it.startDate!) < 0) {
            errors.add('$ip.endDate is before startDate');
          }
        }
      case SkillSection():
        break;
      case LingueSection(:final items):
        _validateListIds(items.map((i) => i.id).toList(), path, errors);
        for (var j = 0; j < items.length; j++) {
          final it = items[j];
          final ip = '$path.items[$j]';
          if (it.id.isEmpty) errors.add('$ip.id required');
        }
      case CertificazioniSection(:final items):
        _validateListIds(items.map((i) => i.id).toList(), path, errors);
        for (var j = 0; j < items.length; j++) {
          final it = items[j];
          final ip = '$path.items[$j]';
          if (it.id.isEmpty) errors.add('$ip.id required');
        }
      case CustomSection():
        if (s.id.isEmpty) errors.add('$path.id required for custom section');
    }
  }

  // Referenced assets must exist in the assets store.
  final referenced = collectAssetReferences(doc);
  for (final id in referenced) {
    if (!doc.assets.containsKey(id)) {
      errors.add('asset reference `$id` has no matching entry in `assets`');
    }
  }

  return errors;
}

void _validateListIds(List<String> ids, String path, List<String> errors) {
  final seen = <String, int>{};
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    if (id.isEmpty) continue; // reported elsewhere
    final prev = seen[id];
    if (prev != null) {
      errors.add(
          '$path.items[$i].id "$id" duplicates $path.items[$prev].id');
    } else {
      seen[id] = i;
    }
  }
}

/// Collects every asset id referenced from anywhere in the document.
///
/// In the MVP the only reference site is `AnagraficaData.foto`, but the
/// helper walks all sections so adding new references later stays cheap.
Set<String> collectAssetReferences(CvDocument doc) {
  final refs = <String>{};
  for (final section in doc.sections) {
    if (section is AnagraficaSection && section.data.foto != null) {
      refs.add(section.data.foto!.assetId);
    }
  }
  return refs;
}

/// Removes assets not referenced from any section — the on-save GC pass
/// mandated by ticket 03.
CvDocument garbageCollectAssets(CvDocument doc) {
  final referenced = collectAssetReferences(doc);
  if (doc.assets.length == referenced.length &&
      doc.assets.keys.every(referenced.contains)) {
    return doc;
  }
  final trimmed = {
    for (final e in doc.assets.entries)
      if (referenced.contains(e.key)) e.key: e.value,
  };
  return doc.copyWith(assets: trimmed);
}
