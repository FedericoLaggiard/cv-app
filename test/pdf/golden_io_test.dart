/// Round-trip tests for the golden JSON serializer (ticket 50).
library;

import 'package:flutter_test/flutter_test.dart';

import 'fixture_io.dart' show LayoutFamily;
import 'golden_io.dart';

void main() {
  test('encode -> decode preserves layoutFamily and fields', () {
    final golden = Golden(
      layoutFamily: LayoutFamily.singleColumn,
      fields: const {
        'contatti.email': 'anna.bianchi83@example-mail.com',
        'esperienze[0].ruolo': 'Sviluppatrice Backend',
      },
    );

    final decoded = Golden.decode(golden.encode());

    expect(decoded, golden);
    expect(decoded.fields['contatti.email'], 'anna.bianchi83@example-mail.com');
  });

  test('empty fields map round-trips', () {
    final golden = Golden(
      layoutFamily: LayoutFamily.multiColumn,
      fields: const {},
    );
    expect(Golden.decode(golden.encode()).fields, isEmpty);
  });
}
