// PortCall replies go to the PortCall's own reply port (so a call made before EngineReady can be
// answered), and BridgedCalendar.changes() reports host errors as stream errors.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/port_bridge.dart';
import 'package:ant_manager/engine/ui_port_host.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Counts `calendar.watch` calls the host receives.
class CountingHost extends UiPortHost {
  CountingHost({super.calendar}) : super(secrets: FakeSecrets(), notifier: FakeNotifier());
  var watchCalls = 0;
  @override
  Future<void> handle(PortCall c, SendPort reply) {
    if (c.port == 'calendar' && c.method == 'watch') watchCalls++;
    return super.handle(c, reply);
  }
}

/// Emits a change every 50 ms while subscribed; counts subscriptions.
class TickingCalendar implements CalendarBridge {
  var listens = 0;
  Timer? _timer;
  late final StreamController<void> _c = StreamController<void>.broadcast(
    onListen: () {
      listens++;
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _c.add(null));
    },
    onCancel: () => _timer?.cancel(),
  );
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to) async => const [];
  @override
  Stream<void> changes() => _c.stream;
}

// ---------- engine commands (top-level: plain captures only) ----------

/// Listens to one changes() stream; returns what it saw: 'event', `error:<e>`, 'done'.
EngineCommand<List<String>> _changesLogCmd() => (rt) async {
      final log = <String>[];
      final done = Completer<void>();
      final sub = rt.engine.ports.calendar!.changes().listen(
            (_) => log.add('event'),
            onError: (Object e) => log.add('error:$e'),
            onDone: () {
              log.add('done');
              done.complete();
            },
          );
      await done.future.timeout(const Duration(seconds: 5), onTimeout: sub.cancel);
      return log;
    };

/// Two changes() streams, listened one after the other; each must see an event.
EngineCommand<List<int>> _twoStreamsCmd() => (rt) async {
      final cal = rt.engine.ports.calendar!;
      final a = await cal.changes().take(2).length.timeout(const Duration(seconds: 5));
      final b = await cal.changes().take(2).length.timeout(const Duration(seconds: 5));
      return [a, b];
    };

/// Two changes() streams listened concurrently.
EngineCommand<List<int>> _concurrentStreamsCmd() => (rt) async {
      final cal = rt.engine.ports.calendar!;
      return Future.wait([
        cal.changes().take(2).length.timeout(const Duration(seconds: 5)),
        cal.changes().take(2).length.timeout(const Duration(seconds: 5)),
      ]);
    };

/// An Apple Calendar source being watched on a host without a calendar.
EngineCommand<void> _watchAppleCalendarCmd() => (rt) async {
      await rt.sync.addSource(SourceKind.appleCalendar, 'Calendar', const {});
      await rt.sync.startWatching();
    };

EngineCommand<int> _pingCmd() => (rt) async => 42;

void main() {
  group('UiBridge reply port', () {
    late ReceivePort ui, engine;
    late UiBridge bridge;
    final calls = <PortCall>[];
    setUp(() {
      calls.clear();
      ui = ReceivePort();
      engine = ReceivePort();
      bridge = UiBridge(ui.sendPort, engine.sendPort);
      engine.listen((m) => bridge.onReply(m as PortReply));
    });
    tearDown(() {
      ui.close();
      engine.close();
    });

    test('a PortCall carries the engine reply port; an "engine not ready" reply throws, not hangs', () async {
      // The UI side before the handle exists: answer every call on msg.reply with the error.
      ui.listen((m) {
        final c = m as PortCall;
        calls.add(c);
        c.reply.send(PortReply(c.id, error: 'engine not ready'));
      });
      await expectLater(
        bridge.call('secrets', 'read', ['k']).timeout(const Duration(seconds: 2)),
        throwsA(isA<PortBridgeException>().having((e) => e.message, 'message', 'engine not ready')),
      );
      expect(calls.single.reply, engine.sendPort);
      expect((calls.single.port, calls.single.method), ('secrets', 'read'));
      expect(calls.single.args, ['k']);
    });

    test('replies are matched by id, values round-trip', () async {
      ui.listen((m) {
        final c = m as PortCall;
        c.reply.send(PortReply(c.id, value: '${c.method}-${c.id}'));
      });
      final r = await Future.wait([bridge.call('secrets', 'read'), bridge.call('secrets', 'write')]);
      expect(r, ['read-0', 'write-1']);
    });
  });

  group('EngineHandle port replies', () {
    late Directory dir;
    setUp(() => dir = tempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('host null → PortBridgeException("no UI port host") inside the engine', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      addTearDown(h.shutdown);
      await expectLater(
        h.runtime(readSecretCmd('k')).timeout(const Duration(seconds: 5)),
        throwsA(isA<EngineCommandException>()
            .having((e) => e.message, 'message', contains('PortBridgeException: no UI port host'))),
      );
      expect(await h.runtime(_pingCmd()), 42, reason: 'engine still usable');
    });

    test('with a host, calls still round-trip', () async {
      final secrets = FakeSecrets()..values['k'] = 'v';
      final h = await EngineHandle.start(testConfig(dir.path), host: fakeHost(secrets: secrets));
      addTearDown(h.shutdown);
      expect(await h.runtime(readSecretCmd('k')).timeout(const Duration(seconds: 5)), 'v');
      await h.runtime(writeSecretCmd('k2', 'v2'));
      expect(secrets.values['k2'], 'v2');
    });
  });

  group('BridgedCalendar.changes()', () {
    late Directory dir;
    setUp(() => dir = tempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('host without a calendar → one stream error, then the stream closes', () async {
      final h = await EngineHandle.start(testConfig(dir.path, calendar: true), host: CountingHost());
      addTearDown(h.shutdown);
      final log = await h.runtime(_changesLogCmd());
      expect(log, hasLength(2));
      expect(log.first, allOf(startsWith('error:PortBridgeException'), contains('not available')));
      expect(log.last, 'done');
      expect(await h.runtime(_pingCmd()), 42);
    });

    test('watching an Apple Calendar source without a host calendar does not kill the engine', () async {
      final host = CountingHost();
      final h = await EngineHandle.start(testConfig(dir.path, calendar: true), host: host);
      addTearDown(h.shutdown);
      await h.runtime(_watchAppleCalendarCmd());
      final end = DateTime.now().add(const Duration(seconds: 5));
      while (host.watchCalls == 0 && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(host.watchCalls, 1, reason: 'the source subscribed and the host answered with an error');
      // Give the error reply time to land in the engine; a fatal uncaught error would kill it.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await h.runtime(_pingCmd()).timeout(const Duration(seconds: 5)), 42);
    });

    test('repeated changes() calls all get events; watch sent each time, host subscribes once', () async {
      final cal = TickingCalendar();
      final host = CountingHost(calendar: cal);
      final h = await EngineHandle.start(testConfig(dir.path, calendar: true), host: host);
      addTearDown(h.shutdown);
      expect(await h.runtime(_twoStreamsCmd()), [2, 2]);
      expect(await h.runtime(_concurrentStreamsCmd()), [2, 2]);
      expect(host.watchCalls, 4);
      expect(cal.listens, 1);
    });
  });
}
