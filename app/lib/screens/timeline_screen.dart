import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/python_service.dart';

enum TimelineFilter { all, code, notes }

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.python});

  final PythonService python;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late Future<Map<String, dynamic>> _future;
  TimelineFilter _filter = TimelineFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    await widget.python.initDb();
    return widget.python.getTimeline(days: 7);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    switch (_filter) {
      case TimelineFilter.all:
        return true;
      case TimelineFilter.code:
        return (item['kind'] == 'event') && ((item['type'] ?? '').toString().startsWith('code.'));
      case TimelineFilter.notes:
        return item['kind'] == 'note';
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
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
        ),
      );
      return;
    }

    final eventId = (item['id'] ?? '').toString();
    if (eventId.isEmpty) return;
    final details = await widget.python.getEventDetails(eventId);
    final artifacts = (details['artifacts'] as List?)?.cast<dynamic>() ?? const [];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((item['type'] ?? 'Event').toString()),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('When: ${(item['timestamp'] ?? '').toString()}'),
                const SizedBox(height: 12),
                if (artifacts.isEmpty)
                  const Text('No artifacts.')
                else
                  for (final a in artifacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText((a['content'] ?? '').toString()),
                    ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timeline', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('Failed to load timeline.\n\n${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
        final filtered = items
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .where(_matchesFilter)
            .toList();

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History & Events',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Timeline',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                      icon: Icon(LucideIcons.refreshCw, color: Colors.grey.shade700, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Filter by:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _filter == TimelineFilter.all,
                        onSelected: () => setState(() => _filter = TimelineFilter.all),
                      ),
                      _FilterChip(
                        label: 'Code',
                        isSelected: _filter == TimelineFilter.code,
                        onSelected: () => setState(() => _filter = TimelineFilter.code),
                      ),
                      _FilterChip(
                        label: 'Notes',
                        isSelected: _filter == TimelineFilter.notes,
                        onSelected: () => setState(() => _filter = TimelineFilter.notes),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.only(bottom: 24),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final kind = (item['kind'] ?? '').toString();
                    final ts = (item['timestamp'] ?? '').toString();
                    final type = (item['type'] ?? 'Event').toString();
                    final title = kind == 'note' ? 'Manual Note' : type;
                    final subtitle = kind == 'note'
                        ? (item['content'] ?? '').toString()
                        : (item['source_id'] ?? '').toString();
                    
                    final icon = kind == 'note' 
                      ? LucideIcons.stickyNote 
                      : (type.startsWith('code.') ? LucideIcons.code : LucideIcons.calendarClock);
                    
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ts,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _openItem(item),
                        trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : Colors.grey.shade200,
      ),
      showCheckmark: false,
    );
  }
}


