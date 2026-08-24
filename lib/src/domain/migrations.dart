/// Forward-only schema migrations for `.cvapp` files (ticket 03).
///
/// Add a new migration by appending to [_migrations]:
///
/// ```dart
/// int _migrate_1_to_2(Map<String, dynamic> raw) { ... return 2; }
/// static const _migrations = { 1: _migrate_1_to_2, ... };
/// ```
///
/// Migrations mutate the raw map in place and return the new schemaVersion.
library;

import 'json_codec.dart';
import 'cv_document.dart';

typedef _Migration = int Function(Map<String, dynamic> raw);

class CvMigrations {
  const CvMigrations._();

  /// Ordered map from `from-version -> migration-to-next`. Empty at v1: the
  /// schema is unchanged. Every entry must bump the value exactly by one and
  /// return the resulting version.
  static const Map<int, _Migration> _migrations = <int, _Migration>{};

  /// Applies any needed forward migrations in place and returns the same map.
  static Map<String, dynamic> apply(Map<String, dynamic> raw) {
    final rawVersion = raw['schemaVersion'];
    if (rawVersion is! int) {
      // Let the codec surface a precise error later.
      return raw;
    }
    var version = rawVersion;
    while (version < currentSchemaVersion) {
      final migrate = _migrations[version];
      if (migrate == null) {
        throw CvSchemaException(
          'no migration registered from schemaVersion $version',
          path: r'$.schemaVersion',
        );
      }
      final next = migrate(raw);
      if (next != version + 1) {
        throw StateError('migration from $version must return ${version + 1}');
      }
      version = next;
      raw['schemaVersion'] = version;
    }
    return raw;
  }
}
