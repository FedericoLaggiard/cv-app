/// Semantic invariants for a [CvDocument] (tickets 01, 02, 03).
///
/// These checks catch integrity violations before the document is persisted:
/// they are the "soft-required" backstop for the auto-save flow described in
/// ticket 04. UI-level "obbligatori mancanti" warnings (ticket 07) run
/// separately and do not block editing.
library;

import 'cv_document.dart';
import 'cv_section.dart';
import 'enums.dart';

class CvValidationException implements Exception {
  final List<String> errors;
  CvValidationException(this.errors);
  @override
  String toString() =>
      'CvValidationException:\n${errors.map((e) => '  - $e').join('\n')}';
}

/// Throws [CvValidationException] listing every violation, or returns
/// normally if the document is valid.
void validate(CvDocument doc) {
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
      case AnagraficaSection(:final data):
        if (data.nome.trim().isEmpty) {
          errors.add('$path.data.nome is required');
        }
        if (data.cognome.trim().isEmpty) {
          errors.add('$path.data.cognome is required');
        }
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
          if (it.ruolo.trim().isEmpty) errors.add('$ip.ruolo required');
          if (it.azienda.trim().isEmpty) errors.add('$ip.azienda required');
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
          if (it.titolo.trim().isEmpty) errors.add('$ip.titolo required');
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
          if (it.lingua.trim().isEmpty) errors.add('$ip.lingua required');
        }
      case CertificazioniSection(:final items):
        _validateListIds(items.map((i) => i.id).toList(), path, errors);
        for (var j = 0; j < items.length; j++) {
          final it = items[j];
          final ip = '$path.items[$j]';
          if (it.id.isEmpty) errors.add('$ip.id required');
          if (it.nome.trim().isEmpty) errors.add('$ip.nome required');
          if (it.ente.trim().isEmpty) errors.add('$ip.ente required');
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

  if (errors.isNotEmpty) {
    throw CvValidationException(errors);
  }
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
