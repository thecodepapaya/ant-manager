import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/date_filter_header.dart';
import '../utils/formatters.dart';
import '../utils/event_details_dialog.dart';
import '../services/python_service.dart';
import '../services/date_filter_provider.dart';
import '../services/data_providers.dart';

enum TimelineFilter { all, code, calendar, notes }

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key, required this.python});

  final PythonService python;

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  TimelineFilter _filter = TimelineFilter.all;

  Future<void> _refresh() async {
    ref.invalidate(timelineProvider);
  }

  Color _getIconColor(String type, ThemeData theme) {
    if (type == 'calendar.event') {
      return Colors.blue;
    } else if (type.startsWith('code.')) {
      return Colors.green;
    } else {
      return theme.colorScheme.primary;
    }
  }

  IconData _getSubtitleIcon(String type) {
    if (type == 'calendar.event') {
      return LucideIcons.clock;
    } else if (type.startsWith('code.')) {
      return LucideIcons.gitBranch;
    } else {
      return LucideIcons.info;
    }
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    if (_filter == TimelineFilter.all) {
      return true;
    }

    final kind = (item['kind'] ?? '').toString().trim().toLowerCase();
    final type = (item['type'] ?? '').toString().trim().toLowerCase();

    switch (_filter) {
      case TimelineFilter.all:
        return true;
      case TimelineFilter.code:
        return kind == 'event' && type.startsWith('code.');
      case TimelineFilter.calendar:
        return kind == 'event' && type == 'calendar.event';
      case TimelineFilter.notes:
        return kind == 'note';
    }
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final kind = (item['kind'] ?? '').toString();
    if (kind == 'note') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Note'),
          content: SelectableText((item['content'] ?? '').toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final eventId = (item['id'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final source = (item['source'] ?? '').toString();
    final timestamp = (item['timestamp'] ?? '').toString();
    final isCalendarEvent = type == 'calendar.event';

    if (eventId.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => EventDetailsDialog(
        eventId: eventId,
        item: item,
        source: source,
        timestamp: timestamp,
        isCalendarEvent: isCalendarEvent,
        python: widget.python,
        onRefresh: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(dateFilterProvider);
    final timelineAsync = ref.watch(timelineProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateFilterHeader(
            title: 'Timeline',
            view: filter.view,
            selectedDate: filter.selectedDate,
            selectedRange: filter.selectedRange,
            onViewChanged: (newView) {
              ref.read(dateFilterProvider.notifier).updateView(newView);
            },
            onDateChanged: (newDate) {
              if (newDate == null) {
                ref.read(dateFilterProvider.notifier).clearFilters();
              } else {
                ref.read(dateFilterProvider.notifier).updateDate(newDate);
              }
            },
            onRangeChanged: (newRange) {
              ref.read(dateFilterProvider.notifier).updateRange(newRange);
            },
            onRefresh: _refresh,
            defaultSubtitle: 'Last 7 days',
          ),
          const SizedBox(height: 16),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == TimelineFilter.all,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Code',
                  selected: _filter == TimelineFilter.code,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.code),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Calendar',
                  selected: _filter == TimelineFilter.calendar,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.calendar),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Notes',
                  selected: _filter == TimelineFilter.notes,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.notes),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: timelineAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading timeline data...'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load timeline',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final itemsRaw = data['items'];
                final items = (itemsRaw is List) ? itemsRaw : const [];

                final filtered = items
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .where(_matchesFilter)
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filter == TimelineFilter.code
                              ? LucideIcons.gitCommit
                              : _filter == TimelineFilter.calendar
                              ? LucideIcons.calendar
                              : _filter == TimelineFilter.notes
                              ? LucideIcons.stickyNote
                              : LucideIcons.inbox,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == TimelineFilter.all
                              ? 'No items found'
                              : 'No ${_filter.name} items found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (_filter != TimelineFilter.all) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                setState(() => _filter = TimelineFilter.all),
                            child: const Text('Show all items'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.only(bottom: 24),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final kind = (item['kind'] ?? '').toString();
                    final ts = (item['timestamp'] ?? '').toString();
                    final type = (item['type'] ?? 'Event').toString();
                    final title = kind == 'note'
                        ? 'Manual Note'
                        : (item['title'] ??
                                  (type == 'calendar.event' ? 'Meeting' : type))
                              .toString();
                    final subtitle = kind == 'note'
                        ? (item['content'] ?? '').toString()
                        : (type == 'calendar.event'
                              ? '${item['duration']} mins'
                              : (item['source_id'] ?? '').toString());

                    final icon = kind == 'note'
                        ? LucideIcons.stickyNote
                        : (type.startsWith('code.')
                              ? LucideIcons.code
                              : (type == 'calendar.event'
                                    ? LucideIcons.calendar
                                    : LucideIcons.calendarClock));

                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => _openItem(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getIconColor(
                                    type,
                                    theme,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  color: _getIconColor(type, theme),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          LucideIcons.clock,
                                          size: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          AppFormatters.formatDateTime(ts),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                        ),
                                        if (subtitle.isNotEmpty) ...[
                                          const SizedBox(width: 12),
                                          Icon(
                                            _getSubtitleIcon(type),
                                            size: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              subtitle,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                LucideIcons.chevronRight,
                                size: 18,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected ? theme.colorScheme.primary : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      selectedColor: theme.colorScheme.primary.withOpacity(0.15),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
        width: selected ? 1.5 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
