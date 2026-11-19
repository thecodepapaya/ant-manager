import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

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
    final t = context.tokens;
    final projects = ref.watch(projectsProvider).value ?? const [];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Material(
        color: t.bg,
        child: Padding(
          padding: EdgeInsets.all(t.space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AntTextField(
                  controller: _text,
                  autofocus: true,
                  maxLines: null,
                  minLines: 4,
                  placeholder: 'What happened? Blockers, context, offline work…',
                ),
              ),
              SizedBox(height: t.space.md),
              Row(
                children: [
                  Expanded(
                    child: AntTextField(controller: _link, placeholder: 'Link (optional)', leadingIcon: Icons.link_rounded),
                  ),
                  SizedBox(width: t.space.md),
                  AntSelect<String?>(
                    value: _projectId,
                    options: [
                      const AntOption(null, 'No project'),
                      for (final p in projects) AntOption(p.id, p.name),
                    ],
                    onChanged: (v) => setState(() => _projectId = v),
                  ),
                ],
              ),
              SizedBox(height: t.space.md),
              Row(
                children: [
                  if (_capture.supported)
                    AntButton.ghost(
                      onPressed: _saving ? null : _captureRegion,
                      icon: _screenshot == null ? Icons.crop_rounded : Icons.check_rounded,
                      label: _screenshot == null ? 'Capture screenshot region' : 'Screenshot attached',
                    ),
                  const Spacer(),
                  AntButton.ghost(label: 'Cancel', onPressed: _close),
                  SizedBox(width: t.space.sm),
                  AntButton.primary(label: 'Save', trailing: const AntKbd(['⌘', '⏎']), onPressed: _saving ? null : _save),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.only(top: t.space.sm),
                  child: Text(_error!, maxLines: 2, style: t.typo.small.copyWith(color: t.dangerText)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
