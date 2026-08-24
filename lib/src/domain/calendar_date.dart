/// Value object for a calendar date (day-precision, timezone-neutral).
///
/// Used for fields that are natively "a day on the calendar" — most notably
/// `AnagraficaData.dataNascita`. Wire format is the ISO-8601 date subset
/// `YYYY-MM-DD`; the type deliberately does NOT round-trip through
/// [DateTime] to avoid the timezone-shift bug where a bare-date parses as
/// local midnight and re-encodes as a shifted UTC instant.
library;

import 'package:meta/meta.dart';

@immutable
class CalendarDate implements Comparable<CalendarDate> {
  final int year;
  final int month;
  final int day;

  CalendarDate(this.year, this.month, this.day) {
    if (year <= 0) {
      throw ArgumentError.value(year, 'year', 'must be a positive integer');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be in 1..12');
    }
    final maxDay = _daysInMonth(year, month);
    if (day < 1 || day > maxDay) {
      throw ArgumentError.value(day, 'day', 'must be in 1..$maxDay');
    }
  }

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  factory CalendarDate.parse(String input) {
    final match = _pattern.firstMatch(input);
    if (match == null) {
      throw FormatException('Invalid CalendarDate: expected YYYY-MM-DD', input);
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year <= 0 || month < 1 || month > 12) {
      throw FormatException('Invalid CalendarDate', input);
    }
    if (day < 1 || day > _daysInMonth(year, month)) {
      throw FormatException('Invalid day for month/year', input);
    }
    return CalendarDate(year, month, day);
  }

  static CalendarDate? tryParse(String input) {
    try {
      return CalendarDate.parse(input);
    } on FormatException {
      return null;
    }
  }

  static int _daysInMonth(int year, int month) {
    const nonLeap = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) return 29;
    return nonLeap[month - 1];
  }

  static bool _isLeapYear(int y) =>
      (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);

  @override
  int compareTo(CalendarDate other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    if (byMonth != 0) return byMonth;
    return day.compareTo(other.day);
  }

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
