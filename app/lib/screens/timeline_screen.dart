import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Timeline — last 7 days', style: theme.textTheme.headlineMedium)),
                  IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == TimelineFilter.all,
                    onSelected: (_) => setState(() => _filter = TimelineFilter.all),
                  ),
                  ChoiceChip(
                    label: const Text('Code'),
                    selected: _filter == TimelineFilter.code,
                    onSelected: (_) => setState(() => _filter = TimelineFilter.code),
                  ),
                  ChoiceChip(
                    label: const Text('Notes'),
                    selected: _filter == TimelineFilter.notes,
                    onSelected: (_) => setState(() => _filter = TimelineFilter.notes),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final kind = (item['kind'] ?? '').toString();
                    final ts = (item['timestamp'] ?? '').toString();
                    final title = kind == 'note' ? 'Note' : (item['type'] ?? 'Event').toString();
                    final subtitle = kind == 'note'
                        ? (item['content'] ?? '').toString()
                        : (item['source_id'] ?? '').toString();
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('$ts\n$subtitle', maxLines: 2, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: () => _openItem(item),
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


