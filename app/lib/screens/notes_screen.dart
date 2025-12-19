import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/python_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.python});

  final PythonService python;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    await widget.python.initDb();
    return widget.python.listNotes(days: 30);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _addNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('New note'),
          content: TextField(
            controller: c,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Short, factual note'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Add')),
          ],
        );
      },
    );
    if (note == null || note.isEmpty) return;
    await widget.python.addNote(note);
    await _refresh();
  }

  Future<void> _openNote(Map<String, dynamic> note) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note'),
        content: SelectableText((note['content'] ?? '').toString()),
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
                Text('Notes', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('Failed to load notes.\n\n${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final notes = (data['notes'] as List?)?.cast<dynamic>() ?? const [];
        final typed = notes
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
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
                          'Personal Context & Logs',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Notes',
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
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _addNote,
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('New Note'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: typed.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.stickyNote,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No notes yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _addNote,
                              child: const Text('Add your first note'),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 160,
                        ),
                        itemCount: typed.length,
                        itemBuilder: (context, idx) {
                          final n = typed[idx];
                          final ts = (n['timestamp'] ?? '').toString();
                          final content = (n['content'] ?? '').toString();
                          return Card(
                            child: InkWell(
                              onTap: () => _openNote(n),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ts,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Text(
                                        content,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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


