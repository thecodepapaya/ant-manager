import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_filter_provider.dart';
import 'python_service.dart';
import '../utils/date_filter_header.dart';
import '../utils/date_utils.dart' as app_utils;

final pythonServiceProvider = Provider((ref) => PythonService());

final dailySummaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, bool>((ref, regenerate) async {
  final filter = ref.watch(dateFilterProvider);
  final python = ref.watch(pythonServiceProvider);
  await python.initDb();

  int days = 1;
  String? startDateStr;
  String? endDateStr;
  String period = 'daily';

  if (filter.view == DateView.customRange && filter.selectedRange != null) {
    startDateStr = filter.selectedRange!.start.toIso8601String().split('T')[0];
    endDateStr = filter.selectedRange!.end.toIso8601String().split('T')[0];
    days = filter.selectedRange!.duration.inDays + 1;
    period = 'custom';
  } else if (filter.selectedDate != null) {
    final range = app_utils.DateUtils.getDateRange(filter.view, filter.selectedDate!);
    startDateStr = range.start.toIso8601String().split('T')[0];
    endDateStr = range.end.toIso8601String().split('T')[0];
    days = range.duration.inDays + 1;
    period = filter.view == DateView.week
        ? 'weekly'
        : filter.view == DateView.month
            ? 'monthly'
            : 'daily';
  }

  return python.getDailySummary(
    date: filter.selectedDate?.toIso8601String().split('T')[0],
    regenerate: regenerate,
    days: days,
    period: period,
    startDate: startDateStr,
    endDate: endDateStr,
  );
});

final timelineProvider = FutureProvider.autoDispose((ref) async {
  final filter = ref.watch(dateFilterProvider);
  final python = ref.watch(pythonServiceProvider);
  await python.initDb();

  int days = 1;
  String? startDateStr;
  String? endDateStr;

  if (filter.view == DateView.customRange && filter.selectedRange != null) {
    startDateStr = filter.selectedRange!.start.toIso8601String().split('T')[0];
    endDateStr = filter.selectedRange!.end.toIso8601String().split('T')[0];
    days = filter.selectedRange!.duration.inDays + 1;
  } else if (filter.selectedDate != null) {
    final range = app_utils.DateUtils.getDateRange(filter.view, filter.selectedDate!);
    startDateStr = range.start.toIso8601String().split('T')[0];
    endDateStr = range.end.toIso8601String().split('T')[0];
    days = range.duration.inDays + 1;
  }

  return python.getTimeline(
    days: days,
    startDate: startDateStr,
    endDate: endDateStr,
  );
});

final winsProvider = FutureProvider.autoDispose((ref) async {
  final filter = ref.watch(dateFilterProvider);
  final python = ref.watch(pythonServiceProvider);
  await python.initDb();

  String period = 'daily';
  String? dateStr;
  String? startDateStr;
  String? endDateStr;

  if (filter.view == DateView.customRange && filter.selectedRange != null) {
    startDateStr = filter.selectedRange!.start.toIso8601String().split('T')[0];
    endDateStr = filter.selectedRange!.end.toIso8601String().split('T')[0];
    period = 'custom';
  } else if (filter.selectedDate != null) {
    final range = app_utils.DateUtils.getDateRange(filter.view, filter.selectedDate!);
    startDateStr = range.start.toIso8601String().split('T')[0];
    endDateStr = range.end.toIso8601String().split('T')[0];
    period = filter.view == DateView.week
        ? 'weekly'
        : filter.view == DateView.month
            ? 'monthly'
            : 'daily';
    dateStr = filter.selectedDate?.toIso8601String().split('T')[0];
  } else {
    dateStr = DateTime.now().toIso8601String().split('T')[0];
    period = 'daily';
  }

  return python.getWins(
    period: period,
    date: dateStr,
    startDate: startDateStr,
    endDate: endDateStr,
  );
});

final notesProvider = FutureProvider.autoDispose((ref) async {
  final filter = ref.watch(dateFilterProvider);
  final python = ref.watch(pythonServiceProvider);
  await python.initDb();

  int days = 30;
  String? startDateStr;
  String? endDateStr;

  if (filter.view == DateView.customRange && filter.selectedRange != null) {
    startDateStr = filter.selectedRange!.start.toIso8601String().split('T')[0];
    endDateStr = filter.selectedRange!.end.toIso8601String().split('T')[0];
    days = filter.selectedRange!.duration.inDays + 1;
  } else if (filter.selectedDate != null) {
    final range = app_utils.DateUtils.getDateRange(filter.view, filter.selectedDate!);
    startDateStr = range.start.toIso8601String().split('T')[0];
    endDateStr = range.end.toIso8601String().split('T')[0];
    days = range.duration.inDays + 1;
  }

  return python.listNotes(
    days: days,
    date: filter.selectedDate?.toIso8601String().split('T')[0],
    startDate: startDateStr,
    endDate: endDateStr,
  );
});

