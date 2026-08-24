import 'package:cv_app/src/domain/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDate.parse', () {
    test('accepts YYYY-MM-DD', () {
      final d = CalendarDate.parse('1990-05-14');
      expect(d.year, 1990);
      expect(d.month, 5);
      expect(d.day, 14);
    });

    test('rejects bad shapes and impossible calendar dates', () {
      for (final bad in [
        '',
        '1990-05',
        '1990/05/14',
        '1990-05-14T00:00:00',
        '1990-13-01',
        '1990-02-30',
        '2023-02-29', // non-leap
      ]) {
        expect(
          () => CalendarDate.parse(bad),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
    });

    test('accepts leap-day', () {
      expect(CalendarDate.parse('2024-02-29').day, 29);
    });
  });

  test('toString is canonical zero-padded', () {
    expect(CalendarDate(2024, 3, 5).toString(), '2024-03-05');
  });

  test('compareTo orders chronologically', () {
    expect(
        CalendarDate(2024, 3, 5).compareTo(CalendarDate(2024, 3, 6)),
        lessThan(0));
    expect(
        CalendarDate(2024, 3, 5).compareTo(CalendarDate(2024, 3, 5)), 0);
  });

  test('equality is value-based', () {
    expect(CalendarDate(1, 1, 1), CalendarDate(1, 1, 1));
    expect(CalendarDate(1, 1, 1).hashCode, CalendarDate(1, 1, 1).hashCode);
  });
}
