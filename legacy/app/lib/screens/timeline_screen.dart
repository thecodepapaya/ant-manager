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

  Future<void> _editNote(Map<String, dynamic> note) async {
    final noteId = note['id'].toString();
    final result = await _showNoteDialog(
      initialContent: note['content'].toString(),
      initialTime: DateTime.parse(note['timestamp'].toString()),
    );
    if (result != null && (result['content'] as String).isNotEmpty) {
      await widget.python.updateNote(
        noteId,
        result['content'] as String,
        timestamp: result['timestamp'] as String,
      );
      _refresh();
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.python.deleteNote(noteId);
      _refresh();
    }
  }

  Future<Map<String, dynamic>?> _showNoteDialog({
    String initialContent = '',
    DateTime? initialTime,
  }) async {
    final controller = TextEditingController(text: initialContent);
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        DateTime selectedTime = initialTime ?? DateTime.now();
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(initialContent.isEmpty ? 'Add Note' : 'Edit Note'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter your note content...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Time: ${AppFormatters.formatDateTime(selectedTime.toIso8601String())}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedTime,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedTime),
                            );
                            if (time != null) {
                              setState(() {
                                selectedTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'content': controller.text.trim(),
                    'timestamp': selectedTime.toUtc().toIso8601String(),
                  }),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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
      await _editNote(item);
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

    // Calculate counts for filters if data is available
    int totalCount = 0;
    int codeCount = 0;
    int calendarCount = 0;
    int notesCount = 0;

    final itemsData = timelineAsync.value?['items'] as List?;
    if (itemsData != null) {
      final items = itemsData
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      totalCount = items.length;
      codeCount = items
          .where((item) => (item['type'] ?? '').toString().startsWith('code.'))
          .length;
      calendarCount = items
          .where((item) => item['type'] == 'calendar.event')
          .length;
      notesCount = items.where((item) => item['kind'] == 'note').length;
    }

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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  count: totalCount,
                  selected: _filter == TimelineFilter.all,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Code',
                  count: codeCount,
                  selected: _filter == TimelineFilter.code,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.code),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Calendar',
                  count: calendarCount,
                  selected: _filter == TimelineFilter.calendar,
                  onSelected: () =>
                      setState(() => _filter = TimelineFilter.calendar),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Notes',
                  count: notesCount,
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
                final items = (itemsRaw is List)
                    ? itemsRaw
                          .whereType<Map>()
                          .map((e) => e.cast<String, dynamic>())
                          .toList()
                    : <Map<String, dynamic>>[];

                final filtered = items.where(_matchesFilter).toList();

                if (filtered.isEmpty && items.isEmpty) {
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
                              if (kind == 'note')
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    LucideIcons.moreVertical,
                                    size: 18,
                                  ),
                                  color: Colors.white,
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editNote(item);
                                    } else if (value == 'delete') {
                                      _deleteNote(item['id'].toString());
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.pencil, size: 14),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            LucideIcons.trash2,
                                            size: 14,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else
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
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ],
      ),
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
