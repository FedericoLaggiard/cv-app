/// Storage abstraction for CV variants (ticket 04).
///
/// The repository is a single seam between the app and any concrete storage
/// backend: `path_provider` on desktop/mobile, `idb_shim` on web, or the
/// in-memory `InMemoryCvRepository` used for tests / previews.
///
/// Regole (dal ticket 04):
///  - `Uint8List` è l'unico contratto verso il mondo esterno.
///  - Nessun `rename`: cambiare `variantName` passa da `save()`.
///  - `ImportConflict` segnala UUID già presente in libreria.
///  - `ImportCorrupt` segnala JSON malformato / schemaVersion futura / campi
///    sconosciuti.
library;

import 'dart:typed_data';

import '../domain/cv_document.dart';

abstract class CvRepository {
  Stream<List<VariantSummary>> watchAll();
  Stream<CvDocument> watch(String id);

  Future<CvDocument> create({String? initialVariantName});
  Future<CvDocument> duplicate(String id);
  Future<void> save(CvDocument doc);
  Future<void> delete(String id);

  Future<ImportResult> importFromBytes(Uint8List bytes);
  Future<Uint8List> exportToBytes(String id);
}

class VariantSummary {
  final String id;
  final String variantName;
  final DateTime updatedAt;
  final bool corrupt;

  const VariantSummary({
    required this.id,
    required this.variantName,
    required this.updatedAt,
    this.corrupt = false,
  });
}

sealed class ImportResult {
  const ImportResult();
}

class ImportSuccess extends ImportResult {
  final CvDocument doc;
  const ImportSuccess(this.doc);
}

class ImportConflict extends ImportResult {
  final String existingId;
  final CvDocument incoming;
  const ImportConflict({required this.existingId, required this.incoming});
}

class ImportCorrupt extends ImportResult {
  final String reason;
  const ImportCorrupt(this.reason);
}

class CvRepositoryNotFound implements Exception {
  final String id;
  CvRepositoryNotFound(this.id);
  @override
  String toString() => 'CvRepositoryNotFound: no variant with id $id';
}

/// Thrown by [CvRepository.create] / [CvRepository.save] when a variantName
/// (trimmed, case-insensitive) is already in use by another variant.
///
/// Enforces the "univocità hard" rule from ticket 14.
class DuplicateVariantNameException implements Exception {
  final String variantName;
  const DuplicateVariantNameException(this.variantName);
  @override
  String toString() =>
      'DuplicateVariantNameException: variantName "$variantName" already in use';
}
