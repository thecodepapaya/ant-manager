/// UI-isolate side of the port bridge: runs plugin-backed port calls requested by the engine.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:core/core.dart';

import 'messages.dart';

class UiPortHost {
  UiPortHost({required this.secrets, required this.notifier, this.calendar});

  final SecretStore secrets;
  final Notifier notifier;
  final CalendarBridge? calendar;

  SendPort? _engine;
  StreamSubscription<void>? _calendarSub;

  void attach(SendPort engine) => _engine = engine;

  void detach() {
    _engine = null;
    _calendarSub?.cancel();
    _calendarSub = null;
  }

  Future<void> handle(PortCall c, SendPort reply) async {
    try {
      reply.send(PortReply(c.id, value: await _dispatch(c)));
    } catch (e) {
      reply.send(PortReply(c.id, error: e.toString()));
    }
  }

  Future<Object?> _dispatch(PortCall c) async {
    final a = c.args;
    switch ((c.port, c.method)) {
      case ('secrets', 'read'):
        return secrets.read(a[0]! as String);
      case ('secrets', 'write'):
        await secrets.write(a[0]! as String, a[1]! as String);
        return null;
      case ('secrets', 'delete'):
        await secrets.delete(a[0]! as String);
        return null;
      case ('notifier', 'show'):
        await notifier.show(title: a[0]! as String, body: a[1]! as String, actionId: a[2] as String?);
        return null;
      case ('calendar', 'requestAccess'):
        return _cal.requestAccess();
      case ('calendar', 'events'):
        return _cal.events(a[0]! as DateTime, a[1]! as DateTime);
      case ('calendar', 'watch'):
        _calendarSub ??= _cal.changes().listen((_) => _engine?.send(const PortEvent('calendar.changes')));
        return null;
    }
    throw UnsupportedError('unknown port call ${c.port}.${c.method}');
  }

  CalendarBridge get _cal => calendar ?? (throw UnsupportedError('Calendar is not available on this platform'));
}
