/// Serialization for hand-written goldens (ticket 50).
///
/// A [Golden] describes, field by field, the [CvDocument] a fixture
/// *should* produce — written by hand looking at the original PDF. Field
/// keys use the same dotted/indexed paths [flattenDocument] produces (see
/// `conversion_scoring.dart`), e.g. `esperienze[0].ruolo`.
library;

import 'dart:convert';

import 'fixture_io.dart' show LayoutFamily;

class Golden {
  final LayoutFamily layoutFamily;
  final Map<String, String> fields;

  const Golden({required this.layoutFamily, required this.fields});

  Map<String, Object?> toJson() => {
    'layoutFamily': layoutFamily.wire,
    'fields': fields,
  };

  factory Golden.fromJson(Map<String, Object?> json) => Golden(
    layoutFamily: LayoutFamily.fromWire(json['layoutFamily'] as String),
    fields: (json['fields'] as Map).cast<String, Object?>().map(
      (k, v) => MapEntry(k, v as String),
    ),
  );

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  factory Golden.decode(String source) =>
      Golden.fromJson((jsonDecode(source) as Map).cast<String, Object?>());

  @override
  bool operator ==(Object other) =>
      other is Golden &&
      other.layoutFamily == layoutFamily &&
      _mapEq(other.fields, fields);

  @override
  int get hashCode => Object.hash(
    layoutFamily,
    Object.hashAllUnordered(
      fields.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

bool _mapEq(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k) || b[k] != a[k]) return false;
  }
  return true;
}
