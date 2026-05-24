import 'package:intl/intl.dart';

/// Central timestamp policy for app display and database serialization.
class AppTime {
  static const Duration bangkokOffset = Duration(hours: 7);

  static DateTime parseDbTimestamp(String value) {
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
    final parsed = DateTime.parse(hasOffset ? value : '${value}Z');
    return parsed.toUtc();
  }

  static DateTime bangkokNow() => DateTime.now().toUtc().add(bangkokOffset);

  static DateTime toBangkok(DateTime value) {
    final utc = value.isUtc ? value : value.toUtc();
    return utc.add(bangkokOffset);
  }

  static DateTime bangkokWallClockToUtc({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
  }) {
    return DateTime.utc(year, month, day, hour, minute, second, millisecond)
        .subtract(bangkokOffset);
  }

  static int bangkokDateKey(DateTime value) {
    final bangkok = toBangkok(value);
    return bangkok.year * 10000 + bangkok.month * 100 + bangkok.day;
  }

  static String toDbIso(DateTime value) => value.toUtc().toIso8601String();

  static String formatBangkokDateTime(
    DateTime value, {
    String pattern = 'dd/MM/yyyy HH:mm',
    String locale = 'th_TH',
  }) {
    return DateFormat(pattern, locale).format(toBangkok(value));
  }

  static String formatBangkokDate(
    DateTime value, {
    String pattern = 'dd/MM/yyyy',
    String locale = 'th_TH',
  }) {
    return DateFormat(pattern, locale).format(toBangkok(value));
  }

  static String formatBangkokTime(
    DateTime value, {
    String pattern = 'HH:mm',
    String locale = 'th_TH',
  }) {
    return DateFormat(pattern, locale).format(toBangkok(value));
  }
}
