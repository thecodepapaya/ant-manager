import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'engine/messages.dart';
import 'engine/ui_port_host.dart';
import 'platform/launch_at_login.dart';
import 'platform/local_notifier_adapter.dart';
import 'platform/mac_calendar_bridge.dart';
import 'platform/secure_secret_store.dart';
import 'platform/time_zone.dart';
import 'shell/desktop_shell.dart';
import 'shell/shell_state.dart';
import 'state/providers.dart';

/// Composition root: platform adapters (UI isolate), engine isolate config, desktop shell.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final support = await getApplicationSupportDirectory();
  final info = await PackageInfo.fromPlatform();
  await LocalNotifierAdapter.setup();
  LaunchAtLogin.setup();

  late final ProviderContainer container;
  final host = UiPortHost(
    secrets: SecureSecretStore(),
    // Notification clicks open the main window (e.g. the daily nudge opens Today).
    notifier: LocalNotifierAdapter(onAction: (_) => container.read(desktopShellProvider)?.showMain()),
    calendar: MacCalendarBridge.supported ? MacCalendarBridge() : null,
  );
  final config = EngineConfig(
    // `--dart-define=ANT_DATA_DIR=…` points a dev run at a scratch data folder.
    dataDir: const String.fromEnvironment('ANT_DATA_DIR').isNotEmpty
        ? const String.fromEnvironment('ANT_DATA_DIR')
        : p.join(support.path, 'ant_manager'),
    timeZone: systemTimeZoneName(),
    calendarAvailable: MacCalendarBridge.supported,
    appVersion: info.version,
  );

  late final DesktopShell shell;
  container = ProviderContainer(overrides: [
    engineConfigProvider.overrideWithValue(config),
    uiPortHostProvider.overrideWithValue(host),
    desktopShellProvider.overrideWith((ref) => shell),
  ]);
  shell = DesktopShell(container);
  await shell.init();
  // Start the engine now so the tray works even before the window is shown.
  container.read(engineProvider);

  runApp(UncontrolledProviderScope(container: container, child: const AntApp()));
}
