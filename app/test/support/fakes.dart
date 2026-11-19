import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/ui_port_host.dart';
import 'package:core/core.dart';

/// Engine config for tests: in-memory DBs (unless [inMemory] is false), no loops, UTC.
EngineConfig testConfig(String dataDir, {bool inMemory = true, bool calendar = false}) => EngineConfig(
      dataDir: dataDir,
      timeZone: 'UTC',
      inMemory: inMemory,
      startLoops: false,
      calendarAvailable: calendar,
    );

Directory tempDir() => Directory.systemTemp.createTempSync('ant_app_test_');

class FakeSecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class FakeNotifier implements Notifier {
  final shown = <(String, String, String?)>[];
  @override
  Future<void> show({required String title, required String body, String? actionId}) async =>
      shown.add((title, body, actionId));
}

class FakeCalendar implements CalendarBridge {
  final eventCalls = <(DateTime, DateTime)>[];
  late final StreamController<void> _changes = StreamController<void>.broadcast(
    // Emit one change as soon as the UI host subscribes.
    onListen: () => Timer(const Duration(milliseconds: 50), () => _changes.add(null)),
  );

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to) async {
    eventCalls.add((from, to));
    return [
      {'id': 'e1', 'title': 'Standup', 'start': from.toUtc().toIso8601String()},
    ];
  }

  @override
  Stream<void> changes() => _changes.stream;
}

UiPortHost fakeHost({FakeSecrets? secrets, FakeNotifier? notifier, FakeCalendar? calendar}) => UiPortHost(
      secrets: secrets ?? FakeSecrets(),
      notifier: notifier ?? FakeNotifier(),
      calendar: calendar,
    );

// ---------- engine commands (top-level so closures capture only plain data) ----------

EngineCommand<void> writeSecretCmd(String k, String v) => (rt) => rt.engine.ports.secrets.write(k, v);
EngineCommand<String?> readSecretCmd(String k) => (rt) => rt.engine.ports.secrets.read(k);
EngineCommand<void> notifyCmd(String title) => (rt) => rt.engine.ports.notifier!.show(title: title, body: 'b');
EngineCommand<int> calendarEventsCmd(DateTime from, DateTime to) =>
    (rt) async => (await rt.engine.ports.calendar!.events(from, to)).length;
EngineCommand<bool> calendarChangeCmd() => (rt) async {
      await rt.engine.ports.calendar!.changes().first.timeout(const Duration(seconds: 5));
      return true;
    };
EngineCommand<bool> pausedFlagCmd() => (rt) async => rt.paused;
EngineCommand<List<String>> tickCmd(DateTime at) => (rt) => rt.scheduler.tick(at);
EngineCommand<Isolate> currentIsolateCmd() => (rt) async => Isolate.current;
EngineCommand<void> throwingCmd(String msg) => (rt) async => throw StateError(msg);
