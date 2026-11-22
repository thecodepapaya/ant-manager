import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// Launch-at-login toggle (SPEC §10, optional). On macOS the `launch_at_startup` channel is
/// answered by `MainFlutterWindow.swift` using `SMAppService` (macOS 13+; on 12 it reports
/// disabled and ignores changes).
class LaunchAtLogin {
  LaunchAtLogin._();

  static void setup() {
    launchAtStartup.setup(
      appName: 'Ant Manager',
      appPath: Platform.resolvedExecutable,
      packageName: 'dev.thecodepapaya.antmanager',
    );
  }

  static Future<bool> isEnabled() => launchAtStartup.isEnabled();

  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
