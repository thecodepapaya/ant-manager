import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
                            'Daily Narrative',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date.isEmpty ? 'Today' : date,
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
                const SizedBox(height: 32),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.text,
                                  size: 18, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                'Summary',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (narrativeId.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'AI Generated',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: _isEditing
                                ? TextField(
                                    controller: _controller,
                                    expands: true,
                                    maxLines: null,
                                    minLines: null,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Edit today’s narrative (keep it factual).',
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: SelectableText(
                                      text.isEmpty ? 'No narrative generated yet.' : text,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 16,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                          ),
                          if (evidenceIds.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'Sources & Evidence',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final id in evidenceIds.take(12))
                                  Tooltip(
                                    message: id.toString(),
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        '#${id.toString().substring(0, 6)}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_isEditing) ...[
                      FilledButton.icon(
                        onPressed: narrativeId.isEmpty
                            ? null
                            : () async {
                                await widget.python.updateNarrative(
                                  narrativeId: narrativeId,
                                  text: _controller.text,
                                );
                                setState(() => _isEditing = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Changes saved')),
                                  );
                                }
                                await _refresh();
                              },
                        icon: const Icon(LucideIcons.check, size: 18),
                        label: const Text('Save Changes'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _controller.text = text;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ] else ...[
                      FilledButton.icon(
                        onPressed: narrativeId.isEmpty
                            ? null
                            : () => setState(() => _isEditing = true),
                        icon: const Icon(LucideIcons.pencil, size: 18),
                        label: const Text('Edit Narrative'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: narrativeId.isEmpty
                            ? null
                            : () async {
                                await widget.python.lockNarrative(narrativeId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Narrative approved & locked'),
                                    ),
                                  );
                                }
                                await _refresh();
                              },
                        icon: const Icon(LucideIcons.lock, size: 18),
                        label: const Text('Approve & Lock'),
                      ),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addNote,
                      icon: const Icon(LucideIcons.messageSquarePlus, size: 18),
                      label: const Text('Add Observation'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
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
