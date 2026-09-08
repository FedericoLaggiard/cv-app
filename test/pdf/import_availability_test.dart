/// Unit test for [ImportAvailability] (ticket 28: Web graceful degrade).
///
/// `flutter test` runs on the Dart VM, not Web (`kIsWeb == false`), so only
/// the off-Web no-op path is exercisable here — the on-Web probe/cache
/// behavior needs `flutter test --platform chrome` to verify for real.
library;

import 'package:cv_app/src/pdf/import_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImportAvailability — off Web', () {
    test('isAvailable is always true without touching pdfrx', () async {
      expect(await ImportAvailability.instance.isAvailable(), isTrue);
    });

    test('cachedAvailable is always true', () {
      expect(ImportAvailability.instance.cachedAvailable, isTrue);
    });
  });
}
