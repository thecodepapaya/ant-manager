
import 'package:core/core.dart' hide Provider;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../engine/commands.dart';
import '../platform/rich_clipboard.dart';
import '../platform/time_zone.dart';
import '../state/providers.dart';
import 'common.dart';

const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'};

/// Inline "Add note" (SPEC §10: notes first-class and easy to find). One line by default; focusing it
/// reveals link, project and screenshot (drop a file anywhere on it, or paste with ⌘V).
class NoteComposer extends ConsumerStatefulWidget {
  const NoteComposer({super.key, this.day, this.placeholder});

  /// The note's day; null = now.
  final String? day;
  final String? placeholder;

  @override
  ConsumerState<NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends ConsumerState<NoteComposer> {
  final _text = TextEditingController();
  final _link = TextEditingController();
  final _focus = FocusNode();
  String? _projectId;
  final _images = <(Uint8List, String)>[];
  var _expanded = false;
  var _dragging = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && !_expanded) setState(() => _expanded = true);
    });
    _focus.onKeyEvent = (node, e) {
      final paste = e is KeyDownEvent &&
          e.logicalKey == LogicalKeyboardKey.keyV &&
          (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed);
      if (paste) _pasteImage();
      return KeyEventResult.ignored; // text paste still happens
    };
  }

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pasteImage() async {
    final png = await RichClipboard.readImage();
    if (png != null && mounted) {
      setState(() {
        _images.add((png, 'png'));
        _expanded = true;
      });
    }
  }

  Future<void> _onDrop(DropDoneDetails d) async {
    setState(() => _dragging = false);
    for (final f in d.files) {
      final ext = f.name.split('.').last.toLowerCase();
      if (!_imageExts.contains(ext)) continue;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _images.add((bytes, ext == 'jpeg' ? 'jpg' : ext)));
    }
    if (mounted) setState(() => _expanded = true);
  }

  DateTime _at() {
    final day = widget.day;
    if (day == null || day == todayDay()) return DateTime.now();
    final noon = parseDay(day).add(const Duration(hours: 12)); // noon of a past/future day, profile zone
    return noon.subtract(profileUtcOffset(noon));
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    setState(() => _saving = true);
    final link = _link.text.trim();
    final id = await runCmd(
      context,
      ref,
      addNoteCmd(
        text: text.isEmpty ? 'Screenshot' : text,
        at: _at(),
        link: link.isEmpty ? null : link,
        projectId: _projectId,
        images: List.of(_images),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (id != null) {
        _text.clear();
        _link.clear();
        _images.clear();
        _expanded = false;
        _focus.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
          const SingleActivator(LogicalKeyboardKey.escape): () => setState(() {
                _expanded = false;
                _focus.unfocus();
              }),
        },
        child: AnimatedContainer(
          duration: t.motion.fast,
          decoration: BoxDecoration(
            borderRadius: t.radii.brLg,
            color: _dragging ? t.accentSoft : t.accentSoft.withValues(alpha: 0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AntTextField(
                      controller: _text,
                      focusNode: _focus,
                      size: AntSize.lg,
                      placeholder: widget.placeholder ?? 'Add a note to this day — blockers, context, offline work…',
                      maxLines: _expanded ? 4 : 1,
                      minLines: 1,
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  SizedBox(width: t.space.md),
                  AntButton(
                    label: 'Add note',
                    size: AntSize.lg,
                    trailing: const AntKbd(['⌘', '⏎']),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
              if (_expanded) ...[
                SizedBox(height: t.space.md),
                Wrap(
                  spacing: t.space.md,
                  runSpacing: t.space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: t.density.columnMinWidth,
                      child: AntTextField(
                        controller: _link,
                        placeholder: 'Link (optional)',
                        leadingIcon: Icons.link_rounded,
                        mono: true,
                      ),
                    ),
                    AntSelect<String?>(
                      value: _projectId,
                      placeholder: 'No project',
                      options: [
                        const AntOption(null, 'No project'),
                        for (final p in projects)
                          AntOption(p.id, p.name, leading: AntDot(color: projectColour(t, p), size: t.space.sm)),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                    Muted(
                      _images.isEmpty ? 'Drop or paste a screenshot to attach it' : plural(_images.length, 'screenshot'),
                      style: t.typo.caption,
                    ),
                  ],
                ),
                if (_images.isNotEmpty) ...[
                  SizedBox(height: t.space.md),
                  Wrap(
                    spacing: t.space.sm,
                    runSpacing: t.space.sm,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: t.radii.brMd,
                              child: Image.memory(_images[i].$1, height: t.space.giant * 1.5, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: AntIconButton(
                                icon: Icons.close_rounded,
                                tooltip: 'Remove',
                                size: AntSize.sm,
                                onPressed: () => setState(() => _images.removeAt(i)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
