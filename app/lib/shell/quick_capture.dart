import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/commands.dart';
import '../platform/screen_capture.dart';
import '../state/providers.dart';
import 'shell_state.dart';

/// Floating note box (SPEC §7 quick capture, #83, #84): note, optional link, project,
/// optional screenshot region. Saves through `AntEngine.addNote`.
class QuickCaptureView extends ConsumerStatefulWidget {
  const QuickCaptureView({super.key});
  @override
  ConsumerState<QuickCaptureView> createState() => _QuickCaptureViewState();
}

class _QuickCaptureViewState extends ConsumerState<QuickCaptureView> {
  final _text = TextEditingController();
  final _link = TextEditingController();
  String? _projectId;
  String? _screenshot;
  bool _saving = false;
  String? _error;

  static const _capture = ScreenCapture();

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final shell = ref.read(desktopShellProvider);
    if (shell != null) {
      await shell.closeQuickCapture();
    } else {
      ref.read(quickCaptureModeProvider.notifier).set(false);
    }
  }

  Future<void> _captureRegion() async {
    try {
      final shell = ref.read(desktopShellProvider);
      final path = shell == null ? await _capture.captureRegion() : await shell.withWindowHidden(_capture.captureRegion);
      if (path != null) setState(() => _screenshot = path);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty && _screenshot == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final h = await ref.read(engineProvider.future);
      final link = _link.text.trim();
      await h.runtime(addQuickNoteCmd(
        text: text.isEmpty ? 'Screenshot' : text,
        link: link.isEmpty ? null : link,
        projectId: _projectId,
        screenshotPath: _screenshot,
      ));
      _text.clear();
      _link.clear();
      _screenshot = null;
      await _close();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).value ?? const [];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(hintText: 'What happened?', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _link,
                      decoration: const InputDecoration(hintText: 'Link (optional)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _projectId,
                    hint: const Text('Project'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No project')),
                      for (final p in projects) DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() => _projectId = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_capture.supported)
                    TextButton.icon(
                      onPressed: _saving ? null : _captureRegion,
                      icon: Icon(_screenshot == null ? Icons.crop : Icons.check),
                      label: Text(_screenshot == null ? 'Capture screenshot region' : 'Screenshot attached'),
                    ),
                  const Spacer(),
                  TextButton(onPressed: _close, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
                ],
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}
