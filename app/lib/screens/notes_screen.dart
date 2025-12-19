import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Notes — last 30 days', style: theme.textTheme.headlineMedium)),
                  IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
                  const SizedBox(width: 4),
                  FilledButton(onPressed: _addNote, child: const Text('+ New note')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: typed.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final n = typed[idx];
                    final ts = (n['timestamp'] ?? '').toString();
                    final content = (n['content'] ?? '').toString();
                    return ListTile(
                      title: Text(content, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(ts),
                      onTap: () => _openNote(n),
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


