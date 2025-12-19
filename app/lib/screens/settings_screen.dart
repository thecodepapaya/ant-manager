import 'package:flutter/material.dart';

import '../services/python_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.python});

  final PythonService python;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>> _future;
  final TextEditingController _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    await widget.python.initDb();
    return widget.python.getConfig();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _addRepo() async {
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add Git repository'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: '/path/to/repo'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Add')),
          ],
        );
      },
    );
    if (path == null || path.isEmpty) return;
    await widget.python.addRepo(path);
    await _refresh();
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
                Text('Settings', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('Failed to load settings.\n\n${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final repos = (data['repo_paths'] as List?)?.cast<dynamic>() ?? const [];
        final llmModel = (data['llm_model'] ?? 'llama3.1:8b').toString();
        _modelController.text = llmModel;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Settings', style: theme.textTheme.headlineMedium)),
                  IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Data Sources', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Git repositories', style: theme.textTheme.titleMedium)),
                  FilledButton(onPressed: _addRepo, child: const Text('+ Add')),
                ],
              ),
              const SizedBox(height: 8),
              if (repos.isEmpty)
                const Text('No repositories configured yet.')
              else
                ...repos.map((r) {
                  final repoPath = r.toString();
                  return ListTile(
                    dense: true,
                    title: Text(repoPath),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await widget.python.removeRepo(repoPath);
                        await _refresh();
                      },
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Text('LLM', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Ollama model',
                        hintText: 'llama3.1:8b',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      final model = _modelController.text.trim();
                      if (model.isEmpty) return;
                      await widget.python.setModel(model);
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Model saved.')));
                      }
                      await _refresh();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Privacy', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const CheckboxListTile(
                value: false,
                onChanged: null,
                title: Text('Encrypt local database (planned)'),
                subtitle: Text('V0 stores everything locally. Encryption is a planned hardening step.'),
              ),
              const CheckboxListTile(
                value: false,
                onChanged: null,
                title: Text('Hide previews (planned)'),
                subtitle: Text('Will reduce accidental exposure via app switcher / screenshots.'),
              ),
              const SizedBox(height: 16),
              Text('About', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('AntManager is local-first: no cloud sync, no tracking.'),
              const SizedBox(height: 8),
              const Text('LLM calls go only to your local Ollama runtime (if running).'),
            ],
          ),
        );
      },
    );
  }
}


