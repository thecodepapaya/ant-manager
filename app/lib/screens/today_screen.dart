import 'package:flutter/material.dart';

import '../services/python_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.python});

  final PythonService python;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _isEditing = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    await widget.python.initDb();
    return widget.python.getDailySummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _isEditing = false;
      _future = _load();
    });
  }

  Future<void> _addNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add note'),
          content: TextField(
            controller: c,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Short, factual context (e.g., blocked on API contract)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (note == null || note.isEmpty) return;
    await widget.python.addNote(note);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          body = Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Failed to load summary.\n\n${snapshot.error}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        } else {
          final data = snapshot.data ?? const <String, dynamic>{};
          final date = (data['date'] ?? '').toString();
          final text = (data['text'] ?? '').toString();
          final narrativeId = (data['narrative_id'] ?? '').toString();
          final evidenceIds =
              (data['evidence_event_ids'] as List?)?.cast<dynamic>() ??
              const [];

          if (!_isEditing) {
            _controller.text = text;
          }

          body = Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date.isEmpty ? 'Today' : 'Today — $date',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isEditing
                      ? TextField(
                          controller: _controller,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText:
                                'Edit today’s narrative (keep it factual).',
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            text.isEmpty ? '(empty)' : text,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (evidenceIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in evidenceIds.take(12))
                        Chip(
                          label: Text(
                            'Evidence ${id.toString().substring(0, 8)}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    FilledButton(
                      onPressed: narrativeId.isEmpty
                          ? null
                          : () async {
                              if (_isEditing) {
                                await widget.python.updateNarrative(
                                  narrativeId: narrativeId,
                                  text: _controller.text,
                                );
                                setState(() => _isEditing = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Saved.')),
                                  );
                                }
                                await _refresh();
                              } else {
                                setState(() => _isEditing = true);
                              }
                            },
                      child: Text(_isEditing ? 'Save' : 'Edit'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: narrativeId.isEmpty
                          ? null
                          : () async {
                              await widget.python.lockNarrative(narrativeId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Approved (locked).'),
                                  ),
                                );
                              }
                              await _refresh();
                            },
                      child: const Text('Approve'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _addNote,
                      child: const Text('+ Add note'),
                    ),
                    const Spacer(),
                    if (_isEditing)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _controller.text = text;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        return body;
      },
    );
  }
}
