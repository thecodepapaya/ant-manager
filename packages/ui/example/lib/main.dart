// Ant Manager widget gallery: every `ui` component in dark and light, with
// live accent / radius / density controls.
//
//   cd packages/ui/example && flutter run -d macos
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

void main() => runApp(const GalleryApp());

/// Accent seeds to try. These are inputs to the token system, not styling.
const _accents = <String, Color>{
  'Amber (brand)': AntTokens.defaultAccent,
  'Blue': Color(0xFF6E9BEA),
  'Green': Color(0xFF5FBF8A),
  'Violet': Color(0xFFA48BEF),
  'Coral': Color(0xFFE8806B),
};

enum _Mode { dark, light, both }

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  _Mode mode = _Mode.both;
  Color accent = AntTokens.defaultAccent;
  double radius = AntRadii.defaultBase;
  bool comfortable = false;

  AntTokens _tokens(Brightness b) {
    final density = comfortable
        ? const AntDensity.comfortable()
        : const AntDensity.compact();
    return b == Brightness.dark
        ? AntTokens.dark(accent: accent, radius: radius, density: density)
        : AntTokens.light(accent: accent, radius: radius, density: density);
  }

  @override
  Widget build(BuildContext context) {
    final dark = _tokens(Brightness.dark);
    final light = _tokens(Brightness.light);
    final chrome = mode == _Mode.light ? light : dark;
    return MaterialApp(
      title: 'Ant UI Gallery',
      debugShowCheckedModeBanner: false,
      theme: antTheme(chrome),
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Controls(
              mode: mode,
              accent: accent,
              radius: radius,
              comfortable: comfortable,
              onMode: (m) => setState(() => mode = m),
              onAccent: (c) => setState(() => accent = c),
              onRadius: (r) => setState(() => radius = r),
              onDensity: (v) => setState(() => comfortable = v),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mode != _Mode.light)
                    Expanded(child: _ThemedGallery(tokens: dark)),
                  if (mode != _Mode.dark)
                    Expanded(child: _ThemedGallery(tokens: light)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.mode,
    required this.accent,
    required this.radius,
    required this.comfortable,
    required this.onMode,
    required this.onAccent,
    required this.onRadius,
    required this.onDensity,
  });

  final _Mode mode;
  final Color accent;
  final double radius;
  final bool comfortable;
  final ValueChanged<_Mode> onMode;
  final ValueChanged<Color> onAccent;
  final ValueChanged<double> onRadius;
  final ValueChanged<bool> onDensity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xl,
        vertical: t.space.md,
      ),
      decoration: BoxDecoration(
        color: t.bgSidebar,
        border: Border(
          bottom: BorderSide(color: t.border, width: t.stroke.hairline),
        ),
      ),
      child: Wrap(
        spacing: t.space.xxxl,
        runSpacing: t.space.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Ant UI', style: t.typo.title),
          _Labeled(
            'Theme',
            AntTabs<_Mode>(
              value: mode,
              onChanged: onMode,
              tabs: const [
                AntTab(value: _Mode.dark, label: 'Dark', icon: Icons.dark_mode),
                AntTab(
                  value: _Mode.light,
                  label: 'Light',
                  icon: Icons.light_mode,
                ),
                AntTab(value: _Mode.both, label: 'Both'),
              ],
            ),
          ),
          _Labeled(
            'Accent',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in _accents.entries)
                  Padding(
                    padding: EdgeInsets.only(right: t.space.sm),
                    child: _Swatch(
                      name: e.key,
                      color: e.value,
                      selected: e.value == accent,
                      onTap: () => onAccent(e.value),
                    ),
                  ),
              ],
            ),
          ),
          _Labeled(
            'Radius',
            AntTabs<double>(
              value: radius,
              onChanged: onRadius,
              tabs: const [
                AntTab(value: 0, label: '0'),
                AntTab(value: 3, label: '3'),
                AntTab(value: AntRadii.defaultBase, label: '6'),
                AntTab(value: 10, label: '10'),
              ],
            ),
          ),
          _Labeled(
            'Density',
            AntTabs<bool>(
              value: comfortable,
              onChanged: onDensity,
              tabs: const [
                AntTab(value: false, label: 'Compact'),
                AntTab(value: true, label: 'Comfortable'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.typo.label.copyWith(color: t.muted)),
        SizedBox(width: t.space.md),
        child,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AntTooltip(
      message: name,
      excludeFromSemantics: true,
      child: AntInteractive(
        onTap: onTap,
        semanticLabel: 'Accent $name',
        selected: selected,
        builder: (context, s) => AntFocusRing(
          visible: s.focused,
          borderRadius: t.radii.brPill,
          child: Container(
            width: t.icon.lg,
            height: t.icon.lg,
            decoration: BoxDecoration(
              color: color,
              borderRadius: t.radii.brPill,
              border: Border.all(
                color: selected ? t.text : t.border,
                width: t.stroke.focus,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One full gallery rendered under [tokens].
class _ThemedGallery extends StatelessWidget {
  const _ThemedGallery({required this.tokens});
  final AntTokens tokens;

  @override
  Widget build(BuildContext context) {
    return AnimatedTheme(
      data: antTheme(tokens),
      duration: tokens.motion.slow,
      child: Builder(
        builder: (context) {
          final t = context.tokens;
          return ColoredBox(
            color: t.bg,
            child: AntToastHost(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Sidebar(),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(t.space.xxxl),
                      children: const [
                        _Buttons(),
                        _Labels(),
                        _Inputs(),
                        _Overlays(),
                        _Surfaces(),
                        _TypeScale(),
                        _Palette(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.typo.heading),
          SizedBox(height: t.space.lg),
          Wrap(
            spacing: t.space.lg,
            runSpacing: t.space.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar();

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  String selected = 'Today';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget item(String label, IconData icon, {Widget? trailing}) =>
        AntSidebarItem(
          label: label,
          icon: icon,
          selected: selected == label,
          trailing: trailing,
          onPressed: () => setState(() => selected = label),
        );
    return Container(
      width: t.density.dialogWidth / 2,
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: t.bgSidebar,
        border: Border(
          right: BorderSide(color: t.border, width: t.stroke.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          item(
            'Today',
            Icons.wb_sunny_outlined,
            trailing: const AntKbd(['G', 'T']),
          ),
          item('Timeline', Icons.view_timeline_outlined),
          item(
            'Reports',
            Icons.article_outlined,
            trailing: const AntBadge(count: 2),
          ),
          item('Wins', Icons.emoji_events_outlined),
          SizedBox(height: t.space.lg),
          const AntSectionLabel('Projects'),
          item(
            'ant-manager',
            Icons.folder_outlined,
            trailing: const AntBadge.dot(),
          ),
          item('website', Icons.folder_outlined),
          const Spacer(),
          item('Settings', Icons.settings_outlined),
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    void noop() {}
    return _Section('Buttons', [
      AntButton.primary(
        label: 'Generate report',
        icon: Icons.auto_awesome,
        onPressed: noop,
      ),
      AntButton(label: 'Secondary', onPressed: noop),
      AntButton.ghost(label: 'Ghost', onPressed: noop),
      AntButton(
        label: 'Delete',
        variant: AntButtonVariant.danger,
        icon: Icons.delete_outline,
        onPressed: noop,
      ),
      const AntButton(label: 'Disabled', onPressed: null),
      AntButton(
        label: 'With shortcut',
        trailing: const AntKbd(['⌘', 'N']),
        onPressed: noop,
      ),
      AntButton.primary(label: 'Small', size: AntSize.sm, onPressed: noop),
      AntButton.primary(label: 'Large', size: AntSize.lg, onPressed: noop),
      AntIconButton(icon: Icons.add, tooltip: 'Add note', onPressed: noop),
      AntIconButton(
        icon: Icons.filter_list,
        tooltip: 'Filter (selected)',
        selected: true,
        onPressed: noop,
      ),
      AntIconButton(
        icon: Icons.more_horiz,
        tooltip: 'More',
        size: AntSize.sm,
        onPressed: noop,
      ),
    ]);
  }
}

class _Labels extends StatelessWidget {
  const _Labels();

  @override
  Widget build(BuildContext context) {
    return _Section('Chips, badges, citations, kbd', [
      const AntChip(label: 'Neutral'),
      const AntChip(label: 'Synced', tone: AntTone.ok, icon: Icons.check),
      const AntChip(label: 'Stale', tone: AntTone.warn),
      const AntChip(label: 'Failed', tone: AntTone.err, icon: Icons.close),
      const AntChip(label: 'Info', tone: AntTone.info),
      const AntChip(label: 'New', tone: AntTone.accent),
      const AntBadge(count: 7),
      const AntBadge(count: 120, tone: AntTone.neutral),
      const AntBadge.dot(),
      const AntBadge.dot(tone: AntTone.ok),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Shipped the importer '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AntCitationChip(
                label: '1',
                tooltip: 'PR #412 · Nov 14',
                onPressed: () {},
              ),
            ),
            const TextSpan(text: ' and fixed sync '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AntCitationChip(label: 'PR #419', onPressed: () {}),
            ),
          ],
        ),
      ),
      const AntKbd(['⌘', 'K']),
      const AntKbd(['Ctrl', 'Shift', 'N']),
    ]);
  }
}

class _Inputs extends StatefulWidget {
  const _Inputs();

  @override
  State<_Inputs> createState() => _InputsState();
}

class _InputsState extends State<_Inputs> {
  bool sync = true;
  bool notify = false;
  bool drafts = true;
  String range = 'week';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = t.density.dialogWidth * 0.6;
    return _Section('Inputs', [
      SizedBox(
        width: w,
        child: const AntTextField(
          label: 'Search',
          placeholder: 'Find a project…',
          leadingIcon: Icons.search,
        ),
      ),
      SizedBox(
        width: w,
        child: const AntTextField(
          label: 'Server URL',
          placeholder: 'https://gitlab.example.com',
          mono: true,
        ),
      ),
      SizedBox(
        width: w,
        child: const AntTextField(
          placeholder: 'Invalid value',
          errorText: 'Must be a URL',
        ),
      ),
      SizedBox(
        width: w,
        child: const AntTextField(placeholder: 'Disabled', enabled: false),
      ),
      SizedBox(
        width: w,
        child: const AntTextField(
          placeholder: 'Write a note…',
          minLines: 3,
          maxLines: 5,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AntSwitch(
            value: sync,
            semanticLabel: 'Sync',
            onChanged: (v) => setState(() => sync = v),
          ),
          SizedBox(width: t.space.lg),
          AntSwitch(
            value: notify,
            semanticLabel: 'Notify',
            onChanged: (v) => setState(() => notify = v),
          ),
          SizedBox(width: t.space.lg),
          const AntSwitch(value: true, onChanged: null),
        ],
      ),
      AntCheckbox(
        value: drafts,
        label: 'Include drafts',
        onChanged: (v) => setState(() => drafts = v),
      ),
      const AntCheckbox(value: false, label: 'Disabled', onChanged: null),
      AntTabs<String>(
        value: range,
        onChanged: (v) => setState(() => range = v),
        tabs: const [
          AntTab(value: 'day', label: 'Day'),
          AntTab(value: 'week', label: 'Week'),
          AntTab(value: 'month', label: 'Month'),
        ],
      ),
    ]);
  }
}

class _Overlays extends StatelessWidget {
  const _Overlays();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Section('Menus, popovers, dialogs, toasts, tooltips', [
      AntMenu(
        items: [
          AntMenuItem(
            label: 'Add note',
            icon: Icons.edit_note,
            shortcut: const ['⌘', 'N'],
            onSelected: () {},
          ),
          AntMenuItem(
            label: 'Regenerate',
            icon: Icons.refresh,
            onSelected: () {},
          ),
          const AntMenuDivider(),
          AntMenuItem(
            label: 'Delete',
            icon: Icons.delete_outline,
            danger: true,
            onSelected: () {},
          ),
        ],
        builder: (context, c) => AntButton(
          label: 'Menu',
          icon: Icons.expand_more,
          onPressed: () => c.isOpen ? c.close() : c.open(),
        ),
      ),
      AntPopover(
        width: t.density.toastWidth,
        anchorBuilder: (context, c) =>
            AntButton(label: 'Popover', onPressed: c.toggle),
        contentBuilder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Model', style: t.typo.bodyStrong),
            SizedBox(height: t.space.xs),
            Text(
              'Use one model for everything. Overrides live under Advanced.',
              style: t.typo.small.copyWith(color: t.muted),
            ),
            SizedBox(height: t.space.md),
            Align(
              alignment: Alignment.centerRight,
              child: AntButton.primary(
                label: 'Done',
                size: AntSize.sm,
                onPressed: c.hide,
              ),
            ),
          ],
        ),
      ),
      AntButton(
        label: 'Dialog',
        onPressed: () => showAntDialog<void>(
          context,
          builder: (context) => AntDialog(
            title: 'Delete this note?',
            body: const Text('The facts it supports will be marked stale.'),
            actions: [
              AntButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
              AntButton(
                label: 'Delete',
                variant: AntButtonVariant.danger,
                autofocus: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
      Builder(
        builder: (context) => AntButton(
          label: 'Toast',
          onPressed: () =>
              AntToastHost.of(context)
                  .show('Report generated', tone: AntTone.ok),
        ),
      ),
      Builder(
        builder: (context) => AntButton(
          label: 'Error toast',
          onPressed: () =>
              AntToastHost.of(context)
                  .show('Sync failed: token expired', tone: AntTone.err),
        ),
      ),
      const AntTooltip(
        message: 'Tooltips appear after a short delay',
        child: AntChip(label: 'Hover me'),
      ),
      const AntToast(message: 'Saved 3 notes', tone: AntTone.ok),
      AntToast(
        message: 'Note deleted',
        action: AntButton.ghost(
          label: 'Undo',
          size: AntSize.sm,
          onPressed: () {},
        ),
        onDismiss: () {},
      ),
    ]);
  }
}

class _Surfaces extends StatelessWidget {
  const _Surfaces();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = t.density.dialogWidth * 0.8;
    return _Section('Cards, panels, empty states', [
      SizedBox(
        width: w,
        child: AntCard(
          title: 'This week',
          trailing: const AntChip(label: 'Fresh', tone: AntTone.ok),
          child: Text(
            'Shipped the importer and two fixes across 3 repos.',
            style: t.typo.body.copyWith(color: t.textSoft),
          ),
        ),
      ),
      SizedBox(
        width: w,
        child: AntCard(
          title: 'Clickable card',
          onPressed: () {},
          child: Text(
            'Hover and focus it.',
            style: t.typo.body.copyWith(color: t.muted),
          ),
        ),
      ),
      SizedBox(
        width: w,
        child: AntPanel(
          padding: EdgeInsets.all(t.space.lg),
          child: Text('Raised panel', style: t.typo.body),
        ),
      ),
      SizedBox(
        width: w,
        child: AntCard(
          padding: EdgeInsets.zero,
          child: AntEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing captured yet',
            message: 'Connect a repo or add a note to start your day.',
            action: AntButton.primary(
              label: 'Add a note',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ]);
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final ty = context.tokens.typo;
    final styles = <String, TextStyle>{
      'display': ty.display,
      'heading': ty.heading,
      'title': ty.title,
      'bodyStrong': ty.bodyStrong,
      'body': ty.body,
      'label': ty.label,
      'small': ty.small,
      'caption': ty.caption,
      'sectionLabel': ty.sectionLabel,
      'mono': ty.mono,
      'monoSmall': ty.monoSmall,
    };
    return _Section('Type', [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in styles.entries)
            Text('${e.key} — The quick brown ant 0123', style: e.value),
        ],
      ),
    ]);
  }
}

class _Palette extends StatelessWidget {
  const _Palette();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final roles = <String, Color>{
      'bg': t.bg,
      'bgSidebar': t.bgSidebar,
      'surface': t.surface,
      'surfaceSunken': t.surfaceSunken,
      'surface2': t.surface2,
      'raised': t.raised,
      'inputBg': t.inputBg,
      'hover': t.hover,
      'active': t.active,
      'chipBg': t.chipBg,
      'divider': t.divider,
      'border': t.border,
      'borderSubtle': t.borderSubtle,
      'borderStrong': t.borderStrong,
      'borderStronger': t.borderStronger,
      'raw': t.raw,
      'text': t.text,
      'text2': t.text2,
      'text3': t.text3,
      'textSoft': t.textSoft,
      'muted': t.muted,
      'placeholder': t.placeholder,
      'success': t.success,
      'successText': t.successText,
      'info': t.info,
      'purple': t.purple,
      'danger': t.danger,
      'dangerText': t.dangerText,
      'accent': t.accent,
      'accentHover': t.accentHover,
      'accentText': t.accentText,
      'accentTextHover': t.accentTextHover,
      'onAccent': t.onAccent,
      'accentSoft': t.accentSoft,
    };
    return _Section('Colour roles', [
      for (final e in roles.entries)
        SizedBox(
          width: t.density.menuMinWidth / 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: t.density.controlLg,
                decoration: BoxDecoration(
                  color: e.value,
                  borderRadius: t.radii.brMd,
                  border: Border.all(color: t.border, width: t.stroke.hairline),
                ),
              ),
              SizedBox(height: t.space.xs),
              Text(e.key, style: t.typo.caption.copyWith(color: t.muted)),
            ],
          ),
        ),
    ]);
  }
}
