/// Tray, global hotkey and window behaviour (SPEC §10, #33): the app keeps running in the
/// tray when the window is closed; ⌥⌘N (Ctrl+Alt+N elsewhere) opens quick capture.
library;

import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../engine/commands.dart';
import '../state/providers.dart';
import 'shell_state.dart';

class DesktopShell {
  DesktopShell(this._container);
  final ProviderContainer _container;

  late final Window _window;
  tray.TrayIcon? _trayIcon;
  final _subs = <ProviderSubscription<Object?>>[];
  Rect? _savedBounds;
  bool _wasVisible = true;
  bool _quitting = false;

  static const quickCaptureSize = Size(480, 300);

  static final quickCaptureHotKey = HotKey(
    key: PhysicalKeyboardKey.keyN,
    modifiers: Platform.isMacOS
        ? [HotKeyModifier.alt, HotKeyModifier.meta]
        : [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  Future<void> init() async {
    _window = WindowManager.instance.getCurrent()!;
    _window
      ..title = 'Ant Manager'
      ..minimumSize = const Size(900, 600).toNative();
    // Closing the window hides it; the engine keeps running in the tray.
    _window.addListener((event) {
      if (event is WindowCloseRequestedEvent && !_quitting) {
        event.request.cancel();
        if (_container.read(quickCaptureModeProvider)) {
          unawaited(closeQuickCapture());
        } else {
          _window.hide();
        }
      }
    });
    await _initTray();
    await _initHotKey();
  }

  // ---------- tray ----------

  Future<void> _initTray() async {
    final icon = tray.TrayIcon.create();
    if (icon == null) return; // No tray on this desktop (e.g. GNOME without AppIndicator).
    _trayIcon = icon
      ..icon = tray.ImageAsset.fromAsset('assets/tray/tray_icon.png')
      ..isIconTemplate = true
      ..setTooltip('Ant Manager')
      ..setContextMenuTrigger(tray.ContextMenuTrigger.clicked)
      ..setVisible(true);
    _rebuildMenu();
    // Rebuild when the inputs of the menu change.
    _subs
      ..add(_container.listen(profilesProvider, (_, _) => _rebuildMenu()))
      ..add(_container.listen(engineProvider, (_, _) => _rebuildMenu()))
      ..add(_container.listen(pausedProvider, (_, _) => _rebuildMenu()));
  }

  void _rebuildMenu() {
    final icon = _trayIcon;
    if (icon == null) return;
    final profiles = _container.read(profilesProvider).value ?? const <Profile>[];
    final activeId = _container.read(engineProvider).value?.profileId;
    final paused = _container.read(pausedProvider).value ?? false;

    final menu = tray.Menu.create()!;
    void item(String label, VoidCallback onClick, {bool? checked, tray.Menu? into}) {
      final mi = tray.MenuItem.createWithLabelAndType(
        label,
        checked == null ? tray.MenuItemType.normal : tray.MenuItemType.checkbox,
      )!;
      if (checked != null) mi.state = checked ? tray.MenuItemState.checked : tray.MenuItemState.unchecked;
      mi.addListener((e) {
        if (e is tray.MenuItemClickedEvent) onClick();
      });
      (into ?? menu).addItem(mi);
    }

    item('Open Ant Manager', () => unawaited(showMain()));
    item('Quick note…', () => unawaited(openQuickCapture()));
    menu.addSeparator();
    if (profiles.length > 1) {
      final sub = tray.Menu.create()!;
      for (final p in profiles) {
        item(p.name, () => unawaited(_container.read(engineProvider.notifier).switchProfile(p.id)),
            checked: p.id == activeId, into: sub);
      }
      final parent = tray.MenuItem.createWithLabelAndType('Profile', tray.MenuItemType.submenu)!..submenu = sub;
      menu.addItem(parent);
    }
    item('Sync now', () => unawaited(_syncNow()));
    item('Pause collection', () => unawaited(_setPaused(!paused)), checked: paused);
    menu.addSeparator();
    item('Settings…', () => unawaited(showMain(section: ShellSection.settings)));
    item('Quit Ant Manager', () => unawaited(quit()));
    icon.setContextMenu(menu);
  }

  Future<void> _syncNow() async {
    final h = await _container.read(engineProvider.future);
    await h.runtime(syncNowCmd());
  }

  Future<void> _setPaused(bool paused) async {
    final h = await _container.read(engineProvider.future);
    await h.runtime(setPausedCmd(paused));
  }

  // ---------- hotkey ----------

  Future<void> _initHotKey() async {
    await hotKeyManager.unregisterAll(); // leftovers after a hot restart
    try {
      await hotKeyManager.register(quickCaptureHotKey, keyDownHandler: (_) => unawaited(openQuickCapture()));
    } on PlatformException catch (e) {
      debugPrint('Quick-capture hotkey unavailable: $e');
    }
  }

  // ---------- window ----------

  Future<void> showMain({ShellSection? section}) async {
    if (_container.read(quickCaptureModeProvider)) await closeQuickCapture(restoreVisibility: false);
    if (section != null) _container.read(shellSectionProvider.notifier).select(section);
    _window
      ..show()
      ..focus();
  }

  /// The main window becomes a small always-on-top capture box (one Flutter window: the
  /// app shares one engine connection), then returns to its previous bounds/visibility.
  Future<void> openQuickCapture() async {
    if (_container.read(quickCaptureModeProvider)) {
      _window.focus();
      return;
    }
    _wasVisible = _window.isVisible;
    _savedBounds = _window.bounds.toRect();
    _container.read(quickCaptureModeProvider.notifier).set(true);
    _window
      ..minimumSize = quickCaptureSize.toNative()
      ..setSize(quickCaptureSize.toNative(), false)
      ..center()
      ..isAlwaysOnTop = true
      ..show()
      ..focus();
  }

  Future<void> closeQuickCapture({bool restoreVisibility = true}) async {
    if (!_container.read(quickCaptureModeProvider)) return;
    _window.isAlwaysOnTop = false;
    if (restoreVisibility && !_wasVisible) _window.hide();
    _container.read(quickCaptureModeProvider.notifier).set(false);
    final b = _savedBounds;
    if (b != null) _window.bounds = b.toNative();
    _window.minimumSize = const Size(900, 600).toNative();
  }

  /// Hides the window while the user drags a screenshot region.
  Future<T> withWindowHidden<T>(Future<T> Function() body) async {
    _window.hide();
    try {
      return await body();
    } finally {
      _window
        ..show()
        ..focus();
    }
  }

  Future<void> quit() async {
    _quitting = true;
    for (final s in _subs) {
      s.close();
    }
    await hotKeyManager.unregisterAll();
    _trayIcon?.dispose();
    // Stop the loops and close the databases before the process ends.
    await _container.read(engineProvider).value?.shutdown();
    _container.dispose();
    exit(0);
  }
}
