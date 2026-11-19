/// Shared building blocks for the feature screens: page chrome, formatting, colours, command runner.
library;

import 'package:core/core.dart' hide Provider, Notifier;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../engine/engine_handle.dart';
import '../engine/messages.dart';
import '../platform/time_zone.dart';
import '../shell/shell_state.dart';
import '../state/providers.dart';

// ---------------------------------------------------------------------------
// Days and times, in the active profile's zone (#87).
// ---------------------------------------------------------------------------

String todayDay() => profileToday();

String shiftDayBy(String day, int days) => formatDay(parseDay(day).add(Duration(days: days)));

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Wednesday, Nov 19".
String longDayLabel(String day) {
  final d = parseDay(day);
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// "Nov 19" (with the year when it isn't this year).
String shortDayLabel(String day) {
  final d = parseDay(day);
  final y = d.year == parseDay(todayDay()).year ? '' : ', ${d.year}';
  return '${_months[d.month - 1]} ${d.day}$y';
}

/// "November 2026".
String monthLabel(String day) {
  final d = parseDay(day);
  return '${_monthsLong[d.month - 1]} ${d.year}';
}

/// "Today", "Yesterday", "Tomorrow" or the weekday.
String relativeDayLabel(String day) {
  final diff = parseDay(day).difference(parseDay(todayDay())).inDays;
  return switch (diff) {
    0 => 'Today',
    -1 => 'Yesterday',
    1 => 'Tomorrow',
    _ => _weekdays[parseDay(day).weekday - 1],
  };
}

String hhmm(DateTime t) {
  final l = t.toUtc().add(profileUtcOffset(t)); // profile wall clock
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String periodLabel(Period p) => switch (p.kind) {
      PeriodKind.daily => longDayLabel(p.start),
      PeriodKind.weekly => 'Week of ${shortDayLabel(p.start)}',
      PeriodKind.monthly => monthLabel(p.start),
      PeriodKind.quarterly => p.label,
      PeriodKind.custom => '${shortDayLabel(p.start)} – ${shortDayLabel(p.end)}',
    };

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

// ---------------------------------------------------------------------------
// Colours (project colours are user data stored as '#RRGGBB').
// ---------------------------------------------------------------------------

Color colourFromHex(String hex, Color fallback) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  if (v == null || h.length != 6) return fallback;
  return Color(v).withValues(alpha: 1);
}

String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Colours offered for projects: the token hues (so they follow the theme seeds).
List<Color> projectPalette(AntTokens t) => [t.accent, t.info, t.success, t.purple, t.danger, t.raw];

Color projectColour(AntTokens t, Project? p) => p == null ? t.raw : colourFromHex(p.colour, t.accent);

// ---------------------------------------------------------------------------
// Labels for core enums.
// ---------------------------------------------------------------------------

String factTypeLabel(FactType t) => switch (t) {
      FactType.outcome => 'Outcome',
      FactType.problemSolved => 'Problem solved',
      FactType.invisibleWork => 'Invisible work',
      FactType.hiccup => 'Hiccup',
      FactType.decision => 'Decision',
      FactType.timeAllocation => 'Time',
    };

AntTone factTypeTone(FactType t) => switch (t) {
      FactType.outcome => AntTone.ok,
      FactType.problemSolved => AntTone.info,
      FactType.hiccup => AntTone.err,
      FactType.decision => AntTone.warn,
      FactType.invisibleWork || FactType.timeAllocation => AntTone.neutral,
    };

String originLabel(FactOrigin o) => switch (o) {
      FactOrigin.inferred => 'Inferred',
      FactOrigin.confirmed => 'Confirmed',
      FactOrigin.userEdited => 'Edited by you',
      FactOrigin.userCreated => 'Added by you',
    };

String periodKindLabel(PeriodKind k) => switch (k) {
      PeriodKind.daily => 'Daily',
      PeriodKind.weekly => 'Weekly',
      PeriodKind.monthly => 'Monthly',
      PeriodKind.quarterly => 'Quarterly',
      PeriodKind.custom => 'Custom',
    };

IconData kindIcon(PayloadKind k) => switch (k) {
      PayloadKind.commit => Icons.commit_rounded,
      PayloadKind.pullRequest => Icons.merge_type_rounded,
      PayloadKind.review => Icons.rate_review_outlined,
      PayloadKind.issue => Icons.task_alt_rounded,
      PayloadKind.calendarEvent => Icons.calendar_today_outlined,
      PayloadKind.note => Icons.sticky_note_2_outlined,
      PayloadKind.image => Icons.image_outlined,
      PayloadKind.transcript => Icons.record_voice_over_outlined,
    };

Color kindTint(AntTokens t, PayloadKind k) => switch (k) {
      PayloadKind.commit || PayloadKind.pullRequest || PayloadKind.review => t.purple,
      PayloadKind.issue => t.success,
      PayloadKind.calendarEvent || PayloadKind.transcript => t.info,
      PayloadKind.note || PayloadKind.image => t.accentText,
    };

String kindLabel(PayloadKind k) => switch (k) {
      PayloadKind.commit => 'Commit',
      PayloadKind.pullRequest => 'Pull request',
      PayloadKind.review => 'Review',
      PayloadKind.issue => 'Ticket',
      PayloadKind.calendarEvent => 'Meeting',
      PayloadKind.note => 'Note',
      PayloadKind.image => 'Screenshot',
      PayloadKind.transcript => 'Transcript',
    };

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

/// Runs [cmd] in the engine isolate. Shows [ok] as a toast on success and the error on failure.
/// Returns null on failure.
Future<T?> runCmd<T>(BuildContext context, WidgetRef ref, EngineCommand<T> cmd, {String? ok}) async {
  final toasts = AntToastHost.of(context);
  try {
    final h = await ref.read(engineProvider.future);
    final r = await h.runtime(cmd);
    if (ok != null) toasts.show(ok, tone: AntTone.ok);
    return r;
  } on EngineCommandException catch (e) {
    toasts.show(_short(e.message), tone: AntTone.err);
  } catch (e) {
    toasts.show(_short('$e'), tone: AntTone.err);
  }
  return null;
}

String _short(String s) {
  final m = s.replaceFirst(RegExp(r'^(Bad state|Exception|StateError): '), '');
  return m.length > 160 ? '${m.substring(0, 160)}…' : m;
}

/// Opens Today on [day], highlighting [evidenceIds] (citation chips anywhere in the app).
void openEvidenceInToday(WidgetRef ref, String day, Set<String> evidenceIds) {
  ref.read(todayFocusProvider.notifier).focus(day, evidenceIds);
  ref.read(shellSectionProvider.notifier).select(ShellSection.today);
}

/// Today's selected day and highlighted evidence.
final todayFocusProvider = NotifierProvider<TodayFocus, ({String day, Set<String> highlight})>(TodayFocus.new);

class TodayFocus extends Notifier<({String day, Set<String> highlight})> {
  @override
  ({String day, Set<String> highlight}) build() => (day: todayDay(), highlight: const {});

  void setDay(String day) => state = (day: day, highlight: const {});
  void focus(String day, Set<String> ids) => state = (day: day, highlight: ids);
  void clearHighlight() => state = (day: state.day, highlight: const {});
}

// ---------------------------------------------------------------------------
// Page chrome (mockup `.topbar`, padded bodies, section labels).
// ---------------------------------------------------------------------------

/// Page top bar: title (+ optional subtitle) then [children], wrapping on narrow windows.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.leading = const [],
    this.title,
    this.subtitle,
    this.titleWidget,
    this.middle = const [],
    this.actions = const [],
  });
  final List<Widget> leading;
  final String? title;
  final String? subtitle;

  /// Replaces [title]/[subtitle] (e.g. a clickable date).
  final Widget? titleWidget;

  /// Left-aligned after the title (tabs, filter chips).
  final List<Widget> middle;

  /// Right-aligned.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: BoxConstraints(minHeight: t.density.topbarHeight),
      padding: EdgeInsets.symmetric(horizontal: t.space.xxxl, vertical: t.space.md),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: t.stroke.hairline))),
      child: Row(
        children: [
          for (final w in leading) Padding(padding: EdgeInsets.only(right: t.space.xs), child: w),
          if (titleWidget != null) Padding(padding: EdgeInsets.only(left: t.space.sm, right: t.space.lg), child: titleWidget),
          // Title and subtitle on one line (mockup `.topbar`), so every page's bar is the same height.
          if (title != null)
            Padding(
              padding: EdgeInsets.only(right: t.space.lg),
              child: Text(title!, style: t.typo.title.copyWith(color: t.text)),
            ),
          // Bounded rather than flexible, so [middle] alone takes the free width and actions stay right.
          if (subtitle != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: t.density.columnMinWidth * 1.5),
              child: Padding(
                padding: EdgeInsets.only(right: t.space.lg),
                child: Text(subtitle!,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.small.copyWith(color: t.muted)),
              ),
            ),
          Expanded(
            child: Wrap(
              spacing: t.space.md,
              runSpacing: t.space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: middle,
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: t.space.md,
              runSpacing: t.space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
  }
}

/// Uppercase label row (mockup `.label`) with optional muted text and trailing actions.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.note, this.trailing = const [], this.tone});
  final String label;
  final String? note;
  final List<Widget> trailing;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.md),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: t.typo.sectionLabel.copyWith(color: tone ?? t.muted)),
          // The note takes the free width (a Spacer beside it would halve it and truncate early).
          if (note != null) ...[
            SizedBox(width: t.space.md),
            Expanded(
              child: Text(note!,
                  maxLines: 1, style: t.typo.small.copyWith(color: t.muted), overflow: TextOverflow.ellipsis),
            ),
          ] else
            const Spacer(),
          for (final w in trailing) Padding(padding: EdgeInsets.only(left: t.space.sm), child: w),
        ],
      ),
    );
  }
}

/// Bordered panel on `surface` (mockup `.panel`), optionally tinted with the accent.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding, this.accent = false, this.dashed = false});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool accent;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: t.radii.brXl,
        border: Border.all(
          color: accent ? antToneBorder(t, AntTone.warn) : (dashed ? t.borderStronger : t.border),
          width: t.stroke.hairline,
        ),
      ),
      child: child,
    );
  }
}

/// Hover-aware builder (rows that reveal actions on hover, mockup `.ev .acts`).
class Hover extends StatefulWidget {
  const Hover({super.key, required this.builder});
  final Widget Function(BuildContext context, bool hovered) builder;
  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  var _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: widget.builder(context, _h),
      );
}

/// The app logo (warm off-white tile), outlined so it stays visible on the light sidebar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: t.icon.xl,
      height: t.icon.xl,
      foregroundDecoration: BoxDecoration(
        borderRadius: t.radii.brMd,
        border: Border.all(color: t.borderStrong, width: t.stroke.hairline),
      ),
      child: ClipRRect(
        borderRadius: t.radii.brMd,
        child: Image.asset('assets/brand/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// A page-level empty state, top-aligned like the ones inside page lists (Timeline, Wins, Today).
class PageEmpty extends StatelessWidget {
  const PageEmpty(this.child, {super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        // AntEmptyState is a Center: a min-size Column keeps it from filling the height.
        child: Padding(
          padding: EdgeInsets.only(top: context.tokens.space.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
      );
}

/// Small text-only muted line.
class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.style, this.maxLines});
  final String text;
  final TextStyle? style;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: (style ?? t.typo.small).copyWith(color: t.muted));
  }
}

/// Loading / error wrapper for AsyncValues.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody(this.value, {super.key, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncData(:final value) => builder(value),
        AsyncError(:final error) => AntEmptyState(
            icon: Icons.error_outline_rounded, title: 'Something went wrong', message: '$error'),
        _ => const SizedBox.shrink(),
      };
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

/// Asks for one line of text. Returns null when cancelled or empty.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? placeholder,
  String action = 'Save',
  int maxLines = 1,
}) async {
  final r = await showAntDialog<String>(
    context,
    builder: (_) => _PromptDialog(
      title: title,
      initial: initial,
      placeholder: placeholder,
      action: action,
      maxLines: maxLines,
    ),
  );
  final v = r?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// Owns its controller so it lives until the route's exit animation has finished.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.placeholder,
    required this.action,
    required this.maxLines,
  });
  final String title;
  final String initial;
  final String? placeholder;
  final String action;
  final int maxLines;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AntDialog(
        title: widget.title,
        body: AntTextField(
          controller: _c,
          autofocus: true,
          placeholder: widget.placeholder,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? 3 : null,
          onSubmitted: widget.maxLines == 1 ? (v) => Navigator.pop(context, v) : null,
        ),
        actions: [
          AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.pop(context)),
          AntButton.primary(label: widget.action, onPressed: () => Navigator.pop(context, _c.text)),
        ],
      );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) async {
  final r = await showAntDialog<bool>(
    context,
    builder: (ctx) => AntDialog(
      title: title,
      body: Text(message),
      actions: [
        AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
        AntButton(
          label: action,
          variant: danger ? AntButtonVariant.danger : AntButtonVariant.primary,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Material date picker (styled by antTheme's colour scheme).
Future<String?> pickDay(BuildContext context, String initial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: parseDay(initial),
    firstDate: DateTime.utc(2000),
    lastDate: DateTime.utc(2100),
  );
  return d == null ? null : formatDay(d);
}

/// The handle, for widgets that need the profile id / blob root.
EngineHandle? engineHandleOf(WidgetRef ref) => ref.watch(engineProvider).value;
