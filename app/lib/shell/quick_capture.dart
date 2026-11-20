import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../engine/commands.dart';
import '../platform/screen_capture.dart';
import '../state/providers.dart';
import '../widgets/common.dart' show colourFromHex, hhmm;
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
      final path = shell == null
          ? await _capture.captureRegion()
          : await shell.withWindowHidden(_capture.captureRegion);
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
      await h.runtime(
        addQuickNoteCmd(
          text: text.isEmpty ? 'Screenshot' : text,
          link: link.isEmpty ? null : link,
          projectId: _projectId,
          screenshotPath: _screenshot,
        ),
      );
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
    final profile = ref.watch(activeProfileProvider)?.name;
    final divider = BorderSide(color: t.divider, width: t.stroke.hairline);
    // Mockup "Quick capture": header, a borderless note area, then a footer with project, link,
    // screenshot and Save. The window itself is the panel.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Material(
        color: t.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.lg),
              decoration: BoxDecoration(border: Border(bottom: divider)),
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: t.icon.sm, color: t.accent),
                  SizedBox(width: t.space.md),
                  Text('Quick note', style: t.typo.bodyStrong.copyWith(color: t.text)),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: Text(
                      [?profile, 'today ${hhmm(DateTime.now())}'].map((s) => '· $s').join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typo.body.copyWith(color: t.muted),
                    ),
                  ),
                  const AntKbd(['esc']),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.lg),
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: t.typo.prose.copyWith(color: t.text),
                  cursorColor: t.accent,
                  decoration: InputDecoration.collapsed(
                    hintText: 'What just happened? Blocker, decision, offline work…',
                    hintStyle: t.typo.prose.copyWith(color: t.placeholder),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.fromLTRB(t.space.xl, 0, t.space.xl, t.space.sm),
                child: Text(_error!, maxLines: 2, style: t.typo.small.copyWith(color: t.dangerText)),
              ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.md + t.space.xxs),
              decoration: BoxDecoration(border: Border(top: divider)),
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: t.density.menuMinWidth),
                    child: AntSelect<String?>(
                      value: _projectId,
                      options: [
                        const AntOption(null, 'No project'),
                        for (final p in projects)
                          AntOption(
                            p.id,
                            p.name,
                            leading: AntDot(color: colourFromHex(p.colour, t.accent), size: t.space.sm),
                          ),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: AntTextField(
                      controller: _link,
                      size: AntSize.sm,
                      placeholder: 'Link (optional)',
                      leadingIcon: Icons.link_rounded,
                    ),
                  ),
                  if (_capture.supported) ...[
                    SizedBox(width: t.space.xs),
                    AntIconButton(
                      icon: _screenshot == null ? Icons.crop_rounded : Icons.check_rounded,
                      tooltip: _screenshot == null ? 'Capture a screen region' : 'Screenshot attached',
                      selected: _screenshot != null,
                      onPressed: _saving ? null : _captureRegion,
                    ),
                  ],
                  SizedBox(width: t.space.md),
                  AntButton.primary(
                    label: 'Save',
                    trailing: AntKbd([Theme.of(context).platform == TargetPlatform.macOS ? '⌘' : 'Ctrl', '⏎']),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
