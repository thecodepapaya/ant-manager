import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/python_service.dart';

class WinsScreen extends StatefulWidget {
  const WinsScreen({super.key, required this.python});

  final PythonService python;

  @override
  State<WinsScreen> createState() => _WinsScreenState();
}

class _WinsScreenState extends State<WinsScreen> {
  String _period = 'weekly';
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
    return widget.python.getWins(period: _period);
  }

  Future<void> _refresh() async {
    setState(() {
      _isEditing = false;
      _future = _load();
    });
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
                Text('Wins', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('Failed to load wins.\n\n${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final text = (data['text'] ?? '').toString();
        final narrativeId = (data['narrative_id'] ?? '').toString();

        if (!_isEditing) {
          _controller.text = text;
        }

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
                          'Achievements & Milestones',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Wins',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _period,
                        icon: const Icon(LucideIcons.chevronDown, size: 18),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(
                              value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _period = v;
                            _future = _load();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            Icon(LucideIcons.trophy,
                                size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Highlights',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
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
                                    hintText: 'Describe your wins...',
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: SelectableText(
                                    text.isEmpty ? 'No wins recorded for this period.' : text,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 16,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                        ),
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
                                  const SnackBar(content: Text('Wins updated')),
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
                      label: const Text('Edit Wins'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: text.trim().isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: text));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Copied to clipboard')),
                                );
                              }
                            },
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: const Text('Copy to Clipboard'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}


