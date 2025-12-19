import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Wins', style: theme.textTheme.headlineMedium)),
                  DropdownButton<String>(
                    value: _period,
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _period = v;
                        _future = _load();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
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
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          text.isEmpty ? '(empty)' : text,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
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
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text('Saved.')));
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
                    onPressed: text.trim().isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard.')),
                              );
                            }
                          },
                    child: const Text('Copy'),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    TextButton(
                      onPressed: () => setState(() {
                        _isEditing = false;
                        _controller.text = text;
                      }),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}


