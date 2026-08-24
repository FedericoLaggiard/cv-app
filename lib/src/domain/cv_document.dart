/// A single CV variant serialized to a `.cvapp` file (ticket 03).
library;

import 'package:meta/meta.dart';

import 'asset.dart';
import 'cv_section.dart';

/// Latest schema version this code writes/understands.
///
/// Bump this + register a migration in `migrations.dart` whenever the wire
/// format changes.
const int currentSchemaVersion = 1;

@immutable
class CvDocument {
  final int schemaVersion;
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String variantName;
  final List<CvSection> sections;
  final Map<String, Asset> assets;

  CvDocument({
    this.schemaVersion = currentSchemaVersion,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.variantName,
    List<CvSection> sections = const [],
    Map<String, Asset> assets = const {},
  }) : sections = List.unmodifiable(sections),
       assets = Map.unmodifiable(assets);

  CvDocument copyWith({
    int? schemaVersion,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? variantName,
    List<CvSection>? sections,
    Map<String, Asset>? assets,
  }) => CvDocument(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    variantName: variantName ?? this.variantName,
    sections: sections ?? this.sections,
    assets: assets ?? this.assets,
  );

  @override
  bool operator ==(Object other) =>
      other is CvDocument &&
      other.schemaVersion == schemaVersion &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.variantName == variantName &&
      _listEq(other.sections, sections) &&
      _mapEq(other.assets, assets);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    id,
    createdAt,
    updatedAt,
    variantName,
    Object.hashAll(sections),
    Object.hashAllUnordered(assets.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k) || b[k] != a[k]) return false;
  }
  return true;
}
