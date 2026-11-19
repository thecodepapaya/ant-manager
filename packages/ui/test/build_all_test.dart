import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

/// Every public component, enabled and disabled where that applies.
List<Widget> _all() => [
  for (final v in AntButtonVariant.values) ...[
    AntButton(label: v.name, variant: v, onPressed: () {}, icon: Icons.add),
    AntButton(label: '${v.name} off', variant: v, onPressed: null),
  ],
  for (final s in AntSize.values)
    AntButton(
      label: 'size ${s.name}',
      size: s,
      onPressed: () {},
      trailing: const AntKbd(['⌘', 'K']),
    ),
  const AntButton(label: 'expand', onPressed: null, expand: true),
  AntIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () {}),
  const AntIconButton(icon: Icons.add, tooltip: 'Add off', onPressed: null),
  AntIconButton(
    icon: Icons.star,
    tooltip: 'Star',
    selected: true,
    size: AntSize.lg,
    onPressed: () {},
  ),
  const AntTextField(placeholder: 'Search', leadingIcon: Icons.search),
  const AntTextField(label: 'Name', errorText: 'Required'),
  const AntTextField(label: 'Off', enabled: false),
  const AntTextField(mono: true, maxLines: 4, minLines: 2),
  const AntTextField(obscureText: true, size: AntSize.lg),
  AntSwitch(value: true, onChanged: (_) {}),
  AntSwitch(value: false, onChanged: (_) {}),
  const AntSwitch(value: true, onChanged: null),
  AntCheckbox(value: true, onChanged: (_) {}, label: 'On'),
  AntCheckbox(value: false, onChanged: (_) {}),
  const AntCheckbox(value: false, onChanged: null, label: 'Off'),
  for (final t in AntTone.values) ...[
    AntChip(label: t.name, tone: t, icon: Icons.circle),
    AntBadge(count: 5, tone: t),
    AntBadge.dot(tone: t),
  ],
  const AntBadge(count: 1000),
  const AntKbd(['⌘', '⇧', 'P']),
  AntCitationChip(label: '[3]', onPressed: () {}, tooltip: 'PR #412'),
  const AntCitationChip(label: 'PR #1'),
  const AntSectionLabel('Projects', trailing: AntBadge(count: 2)),
  AntTabs<int>(
    value: 1,
    onChanged: (_) {},
    tabs: const [
      AntTab(value: 0, label: 'Day', icon: Icons.today),
      AntTab(value: 1, label: 'Week'),
    ],
  ),
  AntTabs<int>(
    value: 0,
    onChanged: null,
    size: AntSize.md,
    tabs: const [AntTab(value: 0, label: 'Only')],
  ),
  SizedBox(
    width: 220,
    child: AntSidebarItem(
      label: 'Today',
      icon: Icons.today,
      selected: true,
      trailing: const AntBadge(count: 3),
      onPressed: () {},
    ),
  ),
  const SizedBox(
    width: 220,
    child: AntSidebarItem(label: 'Off', onPressed: null),
  ),
  AntCard(
    title: 'Card',
    trailing: const AntChip(label: 'ok'),
    onPressed: () {},
    child: const Text('body'),
  ),
  const AntCard(child: Text('plain card')),
  const AntPanel(child: Text('panel')),
  const AntEmptyState(
    title: 'Nothing yet',
    message: 'Add a source to begin.',
    icon: Icons.inbox,
    action: AntButton.primary(label: 'Add', onPressed: null),
  ),
  const AntTooltip(message: 'tip', child: Text('tooltip')),
  for (final t in AntTone.values)
    AntToast(message: 'toast ${t.name}', tone: t, onDismiss: () {}),
  AntToast(
    message: 'with action',
    action: AntButton.ghost(label: 'Undo', onPressed: () {}),
  ),
  const AntDialog(
    title: 'Dialog',
    body: Text('body'),
    actions: [AntButton(label: 'OK', onPressed: null)],
  ),
  AntMenu(
    items: [
      AntMenuItem(label: 'One', onSelected: () {}, icon: Icons.edit),
      const AntMenuDivider(),
      const AntMenuItem(label: 'Off', onSelected: null, danger: true),
    ],
    builder: (context, c) => AntButton(label: 'Menu', onPressed: c.open),
  ),
  AntPopover(
    anchorBuilder: (context, c) =>
        AntButton(label: 'Popover', onPressed: c.toggle),
    contentBuilder: (context, c) => const Text('content'),
  ),
];

void main() {
  final themes = <String, AntTokens>{
    'dark': AntTokens.dark(),
    'light': AntTokens.light(),
    'dark square comfortable': AntTokens.dark(
      radius: 0,
      density: const AntDensity.comfortable(),
    ),
    'light round blue': AntTokens.light(
      radius: 10,
      accent: const Color(0xFF6E9BEA),
    ),
  };

  for (final e in themes.entries) {
    testWidgets('every component builds in ${e.key}', (tester) async {
      tester.view.physicalSize = const Size(1200, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: antTheme(e.value),
          home: Scaffold(
            body: AntToastHost(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in _all())
                      Padding(padding: const EdgeInsets.all(4), child: w),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Open the overlays too.
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Popover'));
      await tester.pumpAndSettle();
      expect(find.text('content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('theme animates between dark and light (${e.key})', (
      tester,
    ) async {
      Widget app(AntTokens t) => MaterialApp(
        theme: antTheme(t),
        home: const Scaffold(
          body: Center(child: AntChip(label: 'x')),
        ),
      );
      await tester.pumpWidget(app(AntTokens.dark()));
      await tester.pumpWidget(app(e.value));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
