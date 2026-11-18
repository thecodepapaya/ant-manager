import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'formatters.dart';
import 'date_utils.dart' as app_utils;

enum DateView { day, week, month, customRange, custom }

class DateFilterHeader extends StatelessWidget {
  const DateFilterHeader({
    super.key,
    required this.title,
    required this.view,
    required this.selectedDate,
    required this.selectedRange,
    required this.onViewChanged,
    required this.onDateChanged,
    required this.onRangeChanged,
    required this.onRefresh,
    this.extraActions,
    this.defaultSubtitle,
  });

  final String title;
  final DateView view;
  final DateTime? selectedDate;
  final DateTimeRange? selectedRange;
  final ValueChanged<DateView> onViewChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final VoidCallback onRefresh;
  final List<Widget>? extraActions;
  final String? defaultSubtitle;

  String _getViewTitle() {
    if (view == DateView.customRange && selectedRange != null) {
      final start = selectedRange!.start;
      final end = selectedRange!.end;
      final startMonth = _getMonthAbbr(start.month);
      final endMonth = _getMonthAbbr(end.month);

      if (start.year == end.year) {
        if (start.month == end.month) {
          return '$startMonth ${start.day} - ${end.day}, ${start.year}';
        } else {
          return '$startMonth ${start.day} - $endMonth ${end.day}, ${start.year}';
        }
      } else {
        return '$startMonth ${start.day}, ${start.year} - $endMonth ${end.day}, ${end.year}';
      }
    }

    if (selectedDate == null) {
      return defaultSubtitle ?? 'Select a date';
    }

    final range = app_utils.DateUtils.getDateRange(view, selectedDate!);
    final date = selectedDate!;

    if (view == DateView.day) {
      final formatted = AppFormatters.formatDateOnly(date.toIso8601String());
      final parts = formatted.split(', ');
      if (parts.length >= 2) {
        return '${parts[0]}, ${parts[1]}${parts.length > 2 ? ', ${parts[2]}' : ''}';
      }
      return formatted;
    } else if (view == DateView.week) {
      final weekStart = range.start;
      final weekEnd = range.end;
      final startMonth = _getMonthAbbr(weekStart.month);
      final endMonth = _getMonthAbbr(weekEnd.month);
      if (weekStart.year == weekEnd.year) {
        if (weekStart.month == weekEnd.month) {
          return '$startMonth ${weekStart.day} - ${weekEnd.day}, ${weekStart.year}';
        } else {
          return '$startMonth ${weekStart.day} - $endMonth ${weekEnd.day}, ${weekStart.year}';
        }
      } else {
        return '$startMonth ${weekStart.day}, ${weekStart.year} - $endMonth ${weekEnd.day}, ${weekEnd.year}';
      }
    } else if (view == DateView.month) {
      final monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${monthNames[date.month - 1]} ${date.year}';
    } else {
      return AppFormatters.formatDateOnly(date.toIso8601String());
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  bool _canNavigateNext() {
    if (selectedDate == null) return false;
    final currentDate = selectedDate!;
    DateTime nextDate;

    switch (view) {
      case DateView.day:
        nextDate = currentDate.add(const Duration(days: 1));
        break;
      case DateView.week:
        nextDate = currentDate.add(const Duration(days: 7));
        break;
      case DateView.month:
        nextDate = DateTime(
          currentDate.year,
          currentDate.month + 1,
          currentDate.day,
        );
        break;
      case DateView.customRange:
        if (selectedRange == null) return false;
        nextDate = currentDate.add(selectedRange!.duration);
        break;
      case DateView.custom:
        nextDate = currentDate.add(const Duration(days: 1));
        break;
    }

    return !nextDate.isAfter(DateTime.now());
  }

  void _navigateDate(int direction) {
    final currentDate = selectedDate ?? DateTime.now();
    DateTime newDate;

    switch (view) {
      case DateView.day:
        newDate = currentDate.add(Duration(days: direction));
        break;
      case DateView.week:
        newDate = currentDate.add(Duration(days: direction * 7));
        break;
      case DateView.month:
        if (direction > 0) {
          newDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
        } else {
          newDate = DateTime(
            currentDate.year,
            currentDate.month - 1,
            currentDate.day,
          );
        }
        break;
      case DateView.customRange:
        if (selectedRange != null) {
          final duration = selectedRange!.duration;
          newDate = currentDate.add(
            Duration(days: direction * (duration.inDays + 1)),
          );
          onRangeChanged(
            DateTimeRange(start: newDate, end: newDate.add(duration)),
          );
        } else {
          newDate = currentDate.add(Duration(days: direction));
        }
        break;
      case DateView.custom:
        newDate = currentDate.add(Duration(days: direction));
        break;
    }

    if (newDate.isAfter(DateTime.now())) return;
    onDateChanged(newDate);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final theme = Theme.of(context);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          selectedRange ??
          DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onRangeChanged(picked);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
      onViewChanged(DateView.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (selectedDate != null || selectedRange != null) ...[
                  _HeaderButton(
                    icon: LucideIcons.chevronLeft,
                    tooltip: 'Previous',
                    onPressed: () => _navigateDate(-1),
                    theme: theme,
                  ),
                  _HeaderButton(
                    icon: LucideIcons.chevronRight,
                    tooltip: 'Next',
                    onPressed: _canNavigateNext()
                        ? () => _navigateDate(1)
                        : null,
                    theme: theme,
                    enabled: _canNavigateNext(),
                  ),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SegmentedButton<DateView>(
                    segments: const [
                      ButtonSegment<DateView>(
                        value: DateView.day,
                        label: Text('Day'),
                        icon: Icon(LucideIcons.calendarDays, size: 14),
                      ),
                      ButtonSegment<DateView>(
                        value: DateView.week,
                        label: Text('Week'),
                        icon: Icon(LucideIcons.calendar, size: 14),
                      ),
                      ButtonSegment<DateView>(
                        value: DateView.month,
                        label: Text('Month'),
                        icon: Icon(LucideIcons.calendarRange, size: 14),
                      ),
                      ButtonSegment<DateView>(
                        value: DateView.customRange,
                        label: Text('Range'),
                        icon: Icon(LucideIcons.calendarSearch, size: 14),
                      ),
                    ],
                    selected: {view},
                    onSelectionChanged: (Set<DateView> newSelection) {
                      final newView = newSelection.first;
                      if (newView == DateView.customRange) {
                        _selectDateRange(context);
                      } else {
                        onViewChanged(newView);
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
                _HeaderButton(
                  icon: (selectedDate == null && selectedRange == null)
                      ? LucideIcons.calendar
                      : LucideIcons.calendarCheck,
                  tooltip: view == DateView.customRange
                      ? 'Select Date Range'
                      : 'Select Date',
                  onPressed: () => view == DateView.customRange
                      ? _selectDateRange(context)
                      : _selectDate(context),
                  theme: theme,
                  isActive: selectedDate != null || selectedRange != null,
                ),
                if (selectedDate != null || selectedRange != null)
                  _HeaderButton(
                    icon: LucideIcons.x,
                    tooltip: 'Clear Date Filter',
                    onPressed: () {
                      onDateChanged(null);
                      onRangeChanged(null);
                      onViewChanged(DateView.custom);
                    },
                    theme: theme,
                    color: Colors.red.shade400,
                  ),
                _HeaderButton(
                  icon: LucideIcons.refreshCw,
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  theme: theme,
                ),
                if (extraActions != null) ...extraActions!,
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _getViewTitle(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
    this.enabled = true,
    this.isActive = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final ThemeData theme;
  final bool enabled;
  final bool isActive;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? theme.colorScheme.primary : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          color: enabled
              ? (color ??
                    (isActive
                        ? theme.colorScheme.primary
                        : Colors.grey.shade700))
              : Colors.grey.shade300,
          size: 18,
        ),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
