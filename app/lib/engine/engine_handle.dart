/// UI-isolate side of the engine (#68): spawns the engine isolate, connects drift's
/// cross-isolate databases for `watch()` reads, and runs commands in the engine isolate.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:core/core.dart';

import '../platform/time_zone.dart';
import 'engine_runtime.dart';
import 'messages.dart';
import 'ui_port_host.dart';

class EngineCommandException implements Exception {
  EngineCommandException(this.message, [this.remoteStack]);
  final String message;
  final String? remoteStack;
  @override
  String toString() => 'EngineCommandException: $message';
}

class EngineHandle {
  EngineHandle._(this._isolate, this._rx, this._commands, this.appDb, this.db, this.profileId, this._host);

  final Isolate _isolate;
  final ReceivePort _rx;
  final SendPort _commands;
  final UiPortHost? _host;

  /// Read-only views (drift data classes, #71). Write only through [run] / [runtime].
  final AppDb appDb;
  final ProfileDb db;
  final String profileId;

  var _next = 0;
  final _pending = <int, Completer<Object?>>{};
  var _closed = false;

  /// Spawns the engine isolate for the active profile. [host] serves plugin-backed ports
  /// (keychain, notifications, EventKit); null in tests, where port calls fail.
  static Future<EngineHandle> start(EngineConfig config, {UiPortHost? host}) async {
    final rx = ReceivePort('ant-engine-ui');
    final ready = Completer<EngineReady>();
    EngineHandle? handle;
    rx.listen((msg) {
      switch (msg) {
        case EngineReady():
          ready.complete(msg);
        case EngineFailed():
          Log.warn('engine.start_failed');
          if (!ready.isCompleted) ready.completeError(EngineCommandException(msg.error, msg.stack));
        case CommandResult():
          handle?._onResult(msg);
        case PortCall():
          final h = handle;
          if (h == null || h._host == null) {
            msg.reply.send(PortReply(msg.id, error: h == null ? 'engine not ready' : 'no UI port host'));
          } else {
            unawaited(h._host.handle(msg, msg.reply));
          }
        case [final Object? error, final Object? stack]:
          // Uncaught error in the engine isolate (Isolate.addErrorListener format).
          Log.error('engine.uncaught', '$error', stack == null ? null : StackTrace.fromString('$stack'));
          final e = EngineCommandException('$error', '$stack');
          if (!ready.isCompleted) ready.completeError(e);
          handle?._failAll(e);
        case null:
          // onExit.
          Log.info('engine.exit');
          final e = EngineCommandException('engine isolate exited');
          if (!ready.isCompleted) ready.completeError(e);
          handle?._failAll(e);
      }
    });
    final isolate = await Isolate.spawn(
      engineMain,
      EngineBoot(rx.sendPort, config),
      debugName: 'ant-engine',
      onError: rx.sendPort,
      onExit: rx.sendPort,
    );
    final EngineReady r;
    try {
      r = await ready.future;
    } catch (_) {
      isolate.kill();
      rx.close();
      rethrow;
    }
    final appDb = AppDb(await r.appDb.connect());
    final db = ProfileDb(await r.profileDb.connect());
    host?.attach(r.commands);
    profileUtcOffset = zoneOffset(r.timeZone);
    return handle = EngineHandle._(isolate, rx, r.commands, appDb, db, r.profileId, host);
  }

  /// Runs [cmd] against the active profile's [AntEngine] in the engine isolate.
  ///
  /// The closure is copied to the engine isolate: it must capture only sendable data
  /// (strings, numbers, records, data classes) — never widgets, `Ref`s or this handle.
  /// Build closures in top-level functions (see `commands.dart`) to keep captures explicit.
  /// The result must be sendable too.
  Future<T> run<T>(Future<T> Function(AntEngine e) cmd) => runtime(_onEngine(cmd));

  static EngineCommand<T> _onEngine<T>(Future<T> Function(AntEngine e) cmd) => (rt) => cmd(rt.engine);

  /// Like [run], with the whole [EngineRuntime] (profiles, pause, sync, app DB).
  Future<T> runtime<T>(EngineCommand<T> cmd) async {
    if (_closed) throw EngineCommandException('engine is shut down');
    final id = _next++;
    final c = Completer<Object?>();
    _pending[id] = c;
    try {
      _commands.send(RunCommand(id, cmd));
    } catch (e) {
      _pending.remove(id);
      rethrow; // e.g. the closure captured something unsendable.
    }
    return await c.future as T;
  }

  void _onResult(CommandResult r) {
    final c = _pending.remove(r.id);
    if (c == null) return;
    if (r.error != null) {
      c.completeError(EngineCommandException(r.error!, r.stack));
    } else {
      c.complete(r.value);
    }
  }

  void _failAll(Object e) {
    for (final c in _pending.values) {
      c.completeError(e);
    }
    _pending.clear();
  }

  /// Stops the loops, closes the databases and ends the isolate.
  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true;
    _host?.detach();
    await db.close();
    await appDb.close();
    final done = ReceivePort();
    _commands.send(ShutdownEngine(done.sendPort));
    await done.first.timeout(const Duration(seconds: 10), onTimeout: () => _isolate.kill());
    done.close();
    _failAll(EngineCommandException('engine is shut down'));
    _rx.close();
  }
}
