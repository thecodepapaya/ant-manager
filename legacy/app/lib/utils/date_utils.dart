import 'package:flutter/material.dart';
import 'date_filter_header.dart';

class DateUtils {
  static DateTimeRange getDateRange(
    DateView view,
    DateTime date, {
    DateTimeRange? customRange,
  }) {
    switch (view) {
      case DateView.day:
        final start = DateTime(date.year, date.month, date.day);
        final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case DateView.week:
        // Start from Monday (1)
        final weekday = date.weekday;
        final weekStart = date.subtract(Duration(days: weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final weekEnd = DateTime(
          start.year,
          start.month,
          start.day,
          23,
          59,
          59,
          999,
        ).add(const Duration(days: 6));
        return DateTimeRange(start: start, end: weekEnd);
      case DateView.month:
        final start = DateTime(date.year, date.month, 1);
        final nextMonth = date.month == 12
            ? DateTime(date.year + 1, 1, 1)
            : DateTime(date.year, date.month + 1, 1);
        final lastDay = nextMonth.subtract(const Duration(days: 1));
        final end = DateTime(
          lastDay.year,
          lastDay.month,
          lastDay.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
      case DateView.customRange:
        if (customRange != null) return customRange;
        // Default to last 7 days including today if no range
        final start = date.subtract(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(date.year, date.month, date.day, 23, 59, 59, 999),
        );
      case DateView.custom:
        // Default to last 7 days including today
        final start = date.subtract(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(date.year, date.month, date.day, 23, 59, 59, 999),
        );
    }
  }
}
