import 'package:intl/intl.dart';

enum ReportRangeType { day, week, month, year, custom }

class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  const DateRange({required this.start, required this.end, required this.label});
}

final DateFormat dbDateFormat = DateFormat('yyyy-MM-dd');
final DateFormat displayDateFormat = DateFormat('d MMM yyyy');
final DateFormat displayDayFormat = DateFormat('EEE, d MMM');

String formatDbDate(DateTime date) => dbDateFormat.format(date);

String formatDisplayDate(DateTime date) => displayDateFormat.format(date);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime todayDateOnly() => dateOnly(DateTime.now());

String todayDbDate() => formatDbDate(todayDateOnly());

String yesterdayDbDate() => formatDbDate(todayDateOnly().subtract(const Duration(days: 1)));

/// Builds the inclusive [start, end] date range (both date-only) for a report filter.
DateRange buildRange(ReportRangeType type, {DateTime? customStart, DateTime? customEnd}) {
  final today = todayDateOnly();
  switch (type) {
    case ReportRangeType.day:
      return DateRange(start: today, end: today, label: displayDateFormat.format(today));
    case ReportRangeType.week:
      final weekday = today.weekday; // Monday = 1 ... Sunday = 7
      final start = today.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 6));
      return DateRange(
        start: start,
        end: end,
        label: '${displayDateFormat.format(start)} - ${displayDateFormat.format(end)}',
      );
    case ReportRangeType.month:
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return DateRange(start: start, end: end, label: DateFormat('MMMM yyyy').format(today));
    case ReportRangeType.year:
      final start = DateTime(today.year, 1, 1);
      final end = DateTime(today.year, 12, 31);
      return DateRange(start: start, end: end, label: DateFormat('yyyy').format(today));
    case ReportRangeType.custom:
      final start = dateOnly(customStart ?? today);
      final end = dateOnly(customEnd ?? today);
      return DateRange(
        start: start,
        end: end,
        label: '${displayDateFormat.format(start)} - ${displayDateFormat.format(end)}',
      );
  }
}

/// Every yyyy-MM-dd string from [start] to [end] inclusive.
List<String> dbDatesInRange(DateTime start, DateTime end) {
  final dates = <String>[];
  var cursor = dateOnly(start);
  final last = dateOnly(end);
  while (!cursor.isAfter(last)) {
    dates.add(formatDbDate(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return dates;
}
