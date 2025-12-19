import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final TextEditingController _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _userController.dispose();
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
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Git Repository',
    );

    if (selectedDirectory != null) {
      await widget.python.addRepo(selectedDirectory);

      // Frictionless Identity Setup
      final currentUserName = _userController.text.trim();
      if (currentUserName.isEmpty) {
        final detectedName = await widget.python.detectGitUser(selectedDirectory);
        if (mounted) {
          final confirmedName = await showDialog<String>(
            context: context,
            builder: (ctx) {
              final c = TextEditingController(text: detectedName);
              return AlertDialog(
                title: const Text('Setup Identity'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detectedName != null
                          ? 'We detected your Git name. Is this you? We use this to filter only your commits.'
                          : 'We couldn\'t detect your Git name automatically. Please enter it here so we can filter your commits.',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: c,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Git Author Name',
                        hintText: 'e.g., Jane Doe',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                    child: const Text('Confirm'),
                  ),
                ],
              );
            },
          );

          if (confirmedName != null && confirmedName.isNotEmpty) {
            await widget.python.setUserName(confirmedName);
          }
        }
      }

      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added repository: $selectedDirectory')),
        );
      }
    }
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
            padding: const EdgeInsets.all(32),
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
        final userName = (data['user_name'] ?? '').toString();
        _modelController.text = llmModel;
        _userController.text = userName;

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
                          'Configuration & Sources',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Settings',
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
                child: ListView(
                  children: [
                    _SettingsSection(
                      title: 'Data Sources',
                      icon: LucideIcons.database,
                      children: [
                        Row(
                          children: [
                            Text('Git Repositories', style: theme.textTheme.titleMedium),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _addRepo,
                              icon: const Icon(LucideIcons.folderPlus, size: 18),
                              label: const Text('Select Directory'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (repos.isEmpty)
                          Text(
                            'No repositories configured yet.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                          )
                        else
                          Card(
                            margin: EdgeInsets.zero,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: repos.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final repoPath = repos[idx].toString();
                                return ListTile(
                                  dense: true,
                                  title: Text(repoPath, style: const TextStyle(fontSize: 13)),
                                  trailing: IconButton(
                                    tooltip: 'Remove',
                                    icon: Icon(LucideIcons.trash2, color: Colors.red.shade400, size: 18),
                                    onPressed: () async {
                                      await widget.python.removeRepo(repoPath);
                                      await _refresh();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _SettingsSection(
                      title: 'Identity',
                      icon: LucideIcons.user,
                      children: [
                        Text('Your Git Name', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _userController,
                                decoration: const InputDecoration(
                                  labelText: 'Git Author Name',
                                  hintText: 'e.g., Jane Doe',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () async {
                                final name = _userController.text.trim();
                                await widget.python.setUserName(name);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Identity updated')),
                                  );
                                }
                                await _refresh();
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This name will be used to filter commits in your repositories.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _SettingsSection(
                      title: 'Artificial Intelligence',
                      icon: LucideIcons.brainCircuit,
                      children: [
                        Text('Local LLM (via Ollama)', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _modelController,
                                decoration: const InputDecoration(
                                  labelText: 'Model Name',
                                  hintText: 'e.g., llama3.1:8b',
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('AI model updated')),
                                  );
                                }
                                await _refresh();
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _SettingsSection(
                      title: 'Security & Privacy',
                      icon: LucideIcons.shieldCheck,
                      children: [
                        CheckboxListTile(
                          value: false,
                          onChanged: null,
                          title: const Text('Encrypt local database'),
                          subtitle: const Text('Store your data using AES-256 (Planned)'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: false,
                          onChanged: null,
                          title: const Text('Hide previews'),
                          subtitle: const Text('Blur content in app switcher (Planned)'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _SettingsSection(
                      title: 'About',
                      icon: LucideIcons.info,
                      children: [
                        Text(
                          'AntManager is designed to be 100% local-first. No cloud sync, no tracking, no telemetry. Your work data stays on your disk.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Privacy Note: AI summaries are processed entirely on your machine using your local Ollama runtime.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}


