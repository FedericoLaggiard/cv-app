import 'package:cv_app/src/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YearMonth.parse', () {
    test('parses valid YYYY-MM', () {
      final ym = YearMonth.parse('2023-05');
      expect(ym.year, 2023);
      expect(ym.month, 5);
    });

    test('parses boundary months', () {
      expect(YearMonth.parse('2000-01').month, 1);
      expect(YearMonth.parse('2000-12').month, 12);
    });

    test('rejects non YYYY-MM shapes', () {
      for (final bad in [
        '',
        '2023',
        '2023-5',
        '2023-05-01',
        '23-05',
        '2023/05',
        'abcd-ef',
        '2023-13',
        '2023-00',
        ' 2023-05',
        '2023-05 ',
      ]) {
        expect(
          () => YearMonth.parse(bad),
          throwsA(isA<FormatException>()),
          reason: 'should reject "$bad"',
        );
      }
    });
  });

  group('YearMonth.tryParse', () {
    test('returns null for invalid input', () {
      expect(YearMonth.tryParse('nope'), isNull);
    });

    test('returns instance for valid input', () {
      expect(YearMonth.tryParse('2024-07'), YearMonth(2024, 7));
    });
  });

  group('YearMonth formatting & value semantics', () {
    test('toString is canonical YYYY-MM zero-padded', () {
      expect(YearMonth(2024, 1).toString(), '2024-01');
      expect(YearMonth(2024, 12).toString(), '2024-12');
      expect(YearMonth(9, 3).toString(), '0009-03');
    });

    test('equality is value-based', () {
      expect(YearMonth(2024, 5), YearMonth(2024, 5));
      expect(YearMonth(2024, 5).hashCode, YearMonth(2024, 5).hashCode);
      expect(YearMonth(2024, 5) == YearMonth(2024, 6), isFalse);
    });

    test('compareTo orders chronologically', () {
      final a = YearMonth(2023, 5);
      final b = YearMonth(2023, 6);
      final c = YearMonth(2024, 1);
      expect(a.compareTo(b), lessThan(0));
      expect(c.compareTo(a), greaterThan(0));
      expect(a.compareTo(YearMonth(2023, 5)), 0);
    });
  });

  group('YearMonth constructor validation', () {
    test('rejects out-of-range month', () {
      expect(() => YearMonth(2024, 0), throwsA(isA<ArgumentError>()));
      expect(() => YearMonth(2024, 13), throwsA(isA<ArgumentError>()));
    });

    test('rejects non-positive year', () {
      expect(() => YearMonth(0, 5), throwsA(isA<ArgumentError>()));
      expect(() => YearMonth(-1, 5), throwsA(isA<ArgumentError>()));
    });
  });
}
