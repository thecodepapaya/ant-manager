/// Engine-isolate side of the port bridge: core ports whose adapters need Flutter plugins
/// (keychain, notifications, EventKit) are proxied to the UI isolate as request/response
/// messages. Pure Dart; runs in the engine isolate.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:core/core.dart';

import 'messages.dart';

class PortBridgeException implements Exception {
  PortBridgeException(this.message);
  final String message;
  @override
  String toString() => 'PortBridgeException: $message';
}

class UiBridge {
  UiBridge(this._ui);
  final SendPort _ui;
  var _next = 0;
  final _pending = <int, Completer<Object?>>{};
  final _events = StreamController<String>.broadcast();

  Future<Object?> call(String port, String method, [List<Object?> args = const []]) {
    final id = _next++;
    final c = Completer<Object?>();
    _pending[id] = c;
    _ui.send(PortCall(id, port, method, args));
    return c.future;
  }

  void onReply(PortReply r) {
    final c = _pending.remove(r.id);
    if (c == null) return;
    if (r.error != null) {
      c.completeError(PortBridgeException(r.error!));
    } else {
      c.complete(r.value);
    }
  }

  void onEvent(PortEvent e) => _events.add(e.name);

  Stream<void> events(String name) => _events.stream.where((n) => n == name);

  void close() {
    for (final c in _pending.values) {
      c.completeError(PortBridgeException('engine shutting down'));
    }
    _pending.clear();
    _events.close();
  }
}

class BridgedSecretStore implements SecretStore {
  BridgedSecretStore(this._b);
  final UiBridge _b;
  @override
  Future<String?> read(String key) async => await _b.call('secrets', 'read', [key]) as String?;
  @override
  Future<void> write(String key, String value) => _b.call('secrets', 'write', [key, value]);
  @override
  Future<void> delete(String key) => _b.call('secrets', 'delete', [key]);
}

class BridgedNotifier implements Notifier {
  BridgedNotifier(this._b);
  final UiBridge _b;
  @override
  Future<void> show({required String title, required String body, String? actionId}) =>
      _b.call('notifier', 'show', [title, body, actionId]);
}

class BridgedCalendar implements CalendarBridge {
  BridgedCalendar(this._b);
  final UiBridge _b;
  var _watching = false;

  @override
  Future<bool> requestAccess() async => await _b.call('calendar', 'requestAccess') as bool;

  @override
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to) async {
    final raw = await _b.call('calendar', 'events', [from, to]) as List;
    return raw.cast<Map<String, Object?>>();
  }

  /// The UI host subscribes to EventKit change notifications on the first listen.
  @override
  Stream<void> changes() {
    if (!_watching) {
      _watching = true;
      unawaited(_b.call('calendar', 'watch'));
    }
    return _b.events('calendar.changes');
  }
}
