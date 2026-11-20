import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'desktop_shell.dart';

/// Sidebar sections (SPEC §7, tentative order).
enum ShellSection {
  today('Today', Icons.wb_sunny_outlined),
  timeline('Timeline', Icons.format_list_bulleted_rounded),
  narrative('Narrative', Icons.article_outlined),
  reports('Reports', Icons.fact_check_outlined),
  wins('Wins', Icons.star_outline_rounded),
  projects('Projects', Icons.folder_outlined),
  sources('Sources', Icons.power_outlined),
  settings('Settings', Icons.settings_outlined);

  const ShellSection(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Sources and Settings sit at the bottom of the sidebar.
  bool get bottom => this == sources || this == settings;
}

final shellSectionProvider = NotifierProvider<ShellSectionController, ShellSection>(ShellSectionController.new);

class ShellSectionController extends Notifier<ShellSection> {
  @override
  ShellSection build() => ShellSection.today;
  void select(ShellSection s) => state = s;
}

/// True while the window is morphed into the quick-capture box.
final quickCaptureModeProvider = NotifierProvider<QuickCaptureMode, bool>(QuickCaptureMode.new);

class QuickCaptureMode extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

/// Null in tests (no tray / window plugin).
final desktopShellProvider = Provider<DesktopShell?>((ref) => null);
