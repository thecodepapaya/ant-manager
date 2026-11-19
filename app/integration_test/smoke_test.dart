// App smoke test: launches the real app (engine isolate, tray, window) on a seeded data folder
// and visits every sidebar section, failing on any exception.
//
//   dart run packages/core/tool/seed_demo.dart <dir>
//   cd app && flutter test integration_test -d macos --dart-define=ANT_DATA_DIR=<dir>
import 'package:ant_manager/main.dart' as app;
import 'package:ant_manager/shell/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ui/ui.dart';

const dataDir = String.fromEnvironment('ANT_DATA_DIR');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder tile(ShellSection s) => find.widgetWithText(AntSidebarItem, s.label);

  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'launches on seeded data and visits every sidebar section without errors',
    (tester) async {
      await app.main();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (tile(ShellSection.today).evaluate().isEmpty || find.text('Work').evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).take(40).join(' | ');
          fail('app did not reach the sidebar; on screen: $texts');
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      for (final s in ShellSection.values) {
        await tester.tap(tile(s));
        await pumpFor(tester, const Duration(seconds: 2));
        expect(tester.takeException(), isNull, reason: s.label);
        expect(tester.widget<AntSidebarItem>(tile(s)).selected, isTrue, reason: s.label);
        expect(find.text('The engine failed to start'), findsNothing);
      }
    },
    skip: dataDir.isEmpty, // needs a seeded folder; never touch the real data dir
  );
}
