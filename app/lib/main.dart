import 'dart:io';
import 'dart:ui';

import 'package:core/core.dart' show Log;
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
import 'platform/rotating_log.dart';
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
  // `--dart-define=ANT_DATA_DIR=…` points a dev run at a scratch data folder.
  final dataDir = const String.fromEnvironment('ANT_DATA_DIR').isNotEmpty
      ? const String.fromEnvironment('ANT_DATA_DIR')
      : p.join(support.path, 'ant_manager');
  _setUpLogging(dataDir, info);
  final config = EngineConfig(
    dataDir: dataDir,
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

/// UI-isolate log (#126): `<dataDir>/logs/ui.log`, plus uncaught Flutter and platform errors. Chains the
/// previous handlers so the default reporting (and test bindings) still see every error.
void _setUpLogging(String dataDir, PackageInfo info) {
  Log.sink = RotatingFileLog(logsDir(dataDir), 'ui');
  Log.isolate = 'ui';
  Log.info('app.start', {
    'version': info.version,
    'build': info.buildNumber,
    'os': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'dart': Platform.version.split(' ').first,
  });
  final flutterPrevious = FlutterError.onError;
  FlutterError.onError = (details) {
    Log.error('flutter.error', details.exception, details.stack);
    flutterPrevious?.call(details);
  };
  final platformPrevious = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.error('uncaught', error, stack);
    return platformPrevious?.call(error, stack) ?? false;
  };
}
