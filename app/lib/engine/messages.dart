/// Messages between the UI isolate and the engine isolate (#68).
///
/// Both isolates are in the same isolate group (Isolate.spawn), so these plain objects,
/// closures and drift's [DriftIsolate] handles are sent as-is (no serialization).
library;

import 'dart:isolate';

import 'package:drift/isolate.dart';

import 'engine_runtime.dart';

/// Everything the engine isolate needs to boot. Must stay sendable (plain data).
final class EngineConfig {
  const EngineConfig({
    required this.dataDir,
    required this.timeZone,
    this.calendarAvailable = false,
    this.inMemory = false,
    this.startLoops = true,
    this.idlePoll = const Duration(seconds: 5),
    this.appVersion = '0.1.0',
  });

  /// `<app support>/ant_manager`: `app.sqlite`, `profiles/<id>.sqlite`, `blobs/<id>/`.
  final String dataDir;

  /// IANA name for a first-run default profile (#87).
  final String timeZone;

  /// True on macOS: the engine gets a bridged [CalendarBridge].
  final bool calendarAvailable;

  /// Tests: in-memory databases instead of files.
  final bool inMemory;

  /// Tests: don't run the job/recompute loops.
  final bool startLoops;

  final Duration idlePoll;

  /// Recorded in backup manifests.
  final String appVersion;
}

// ---------- UI → engine ----------

/// A command body executed in the engine isolate. Build these in `commands.dart`
/// (top-level functions) so the closure captures only plain data.
typedef EngineCommand<T> = Future<T> Function(EngineRuntime rt);

final class RunCommand {
  const RunCommand(this.id, this.body);
  final int id;
  final EngineCommand<Object?> body;
}

final class PortReply {
  const PortReply(this.id, {this.value, this.error});
  final int id;
  final Object? value;
  final String? error;
}

/// A platform event forwarded to the engine (e.g. `calendar.changes`).
final class PortEvent {
  const PortEvent(this.name);
  final String name;
}

final class ShutdownEngine {
  const ShutdownEngine(this.done);
  final SendPort done;
}

// ---------- engine → UI ----------

final class EngineBoot {
  const EngineBoot(this.ui, this.config);
  final SendPort ui;
  final EngineConfig config;
}

final class EngineReady {
  const EngineReady({
    required this.commands,
    required this.appDb,
    required this.profileDb,
    required this.profileId,
  });
  final SendPort commands;
  final DriftIsolate appDb;
  final DriftIsolate profileDb;
  final String profileId;
}

final class EngineFailed {
  const EngineFailed(this.error, this.stack);
  final String error;
  final String stack;
}

final class CommandResult {
  const CommandResult(this.id, {this.value, this.error, this.stack});
  final int id;
  final Object? value;
  final String? error;
  final String? stack;
}

/// The engine asks the UI isolate to run a plugin-backed port method
/// (`secrets.read`, `notifier.show`, `calendar.events`, ...).
final class PortCall {
  const PortCall(this.id, this.port, this.method, this.args);
  final int id;
  final String port;
  final String method;
  final List<Object?> args;
}
