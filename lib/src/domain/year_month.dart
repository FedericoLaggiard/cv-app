/// Value object for a month+year (subset of ISO-8601: `YYYY-MM`).
///
/// Ordering is chronological. Instances are immutable and support value
/// equality. See ticket 03 (formato-file-cv) for the wire format decision.
library;

import 'package:meta/meta.dart';

@immutable
class YearMonth implements Comparable<YearMonth> {
  final int year;
  final int month;

  YearMonth(this.year, this.month) {
    if (year <= 0) {
      throw ArgumentError.value(year, 'year', 'must be a positive integer');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be in 1..12');
    }
  }

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})$');

  /// Parses a canonical `YYYY-MM` string. Throws [FormatException] on any
  /// deviation from the exact shape (whitespace, extra characters, etc).
  factory YearMonth.parse(String input) {
    final match = _pattern.firstMatch(input);
    if (match == null) {
      throw FormatException('Invalid YearMonth: expected YYYY-MM', input);
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) {
      throw FormatException('Invalid month in YearMonth', input);
    }
    if (year <= 0) {
      throw FormatException('Invalid year in YearMonth', input);
    }
    return YearMonth(year, month);
  }

  static YearMonth? tryParse(String input) {
    try {
      return YearMonth.parse(input);
    } on FormatException {
      return null;
    }
  }

  @override
  int compareTo(YearMonth other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    return month.compareTo(other.month);
  }

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}
