/// Independent tests (#99) for the injectable log clock (DECISIONS #141): line timestamps and the repeat
/// window come from [Log.clock].
library;

import 'package:core/core.dart';
import 'package:test/test.dart';

class _Sink implements LogSink {
  final lines = <String>[];
  @override
  void write(String line) => lines.add(line);
}

class _Clock implements Clock {
  _Clock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

var _n = 0;

/// Unique per test: `Log._recent` is static and survives between tests.
String _event(String base) => '$base.c141x${++_n}x${DateTime.now().microsecondsSinceEpoch}';

void main() {
  late _Sink sink;
  late _Clock clock;
  final t0 = DateTime.utc(2031, 3, 4, 5, 6, 7, 890);

  setUp(() {
    sink = _Sink();
    clock = _Clock(t0);
    Log.sink = sink;
    Log.clock = clock;
    Log.isolate = 'engine';
  });
  tearDown(() {
    Log.sink = null;
    Log.clock = const SystemClock();
    Log.isolate = 'engine';
  });

  test('line timestamps come from Log.clock', () {
    final e = _event('ts');
    Log.info(e);
    expect(sink.lines.single, startsWith('2031-03-04T05:06:07.890Z INFO  engine $e'));
  });

  test('a non-UTC clock time is written in UTC', () {
    clock.t = DateTime.fromMillisecondsSinceEpoch(t0.millisecondsSinceEpoch); // local
    final e = _event('tsLocal');
    Log.info(e);
    expect(sink.lines.single, startsWith('2031-03-04T05:06:07.890Z '));
  });

  test('a repeated warning inside the window is suppressed; after it the next carries repeated=<n>', () {
    final e = _event('warn');
    Log.warn(e, {'k': 1});
    clock.t = t0.add(const Duration(minutes: 3));
    Log.warn(e, {'k': 1});
    clock.t = t0.add(Log.repeatWindow - const Duration(milliseconds: 1));
    Log.warn(e, {'k': 1});
    expect(sink.lines, hasLength(1));
    expect(sink.lines.single, isNot(contains('repeated')));

    final later = t0.add(Log.repeatWindow);
    clock.t = later;
    Log.warn(e, {'k': 1});
    expect(sink.lines, hasLength(2));
    expect(sink.lines.last, startsWith('2031-03-04T05:16:07.890Z WARN  engine $e'));
    expect(sink.lines.last, contains('k=1'));
    expect(sink.lines.last, endsWith('repeated=2'));
  });

  test('the window restarts from the line written after it', () {
    final e = _event('warnAgain');
    Log.warn(e);
    clock.t = t0.add(Log.repeatWindow);
    Log.warn(e); // written (nothing suppressed, so no repeated=)
    expect(sink.lines, hasLength(2));
    expect(sink.lines.last, isNot(contains('repeated')));
    clock.t = t0.add(Log.repeatWindow + const Duration(minutes: 5));
    Log.warn(e); // inside the new window
    expect(sink.lines, hasLength(2));
    clock.t = t0.add(Log.repeatWindow * 2);
    Log.warn(e);
    expect(sink.lines, hasLength(3));
    expect(sink.lines.last, endsWith('repeated=1'));
  });

  test('a repeated error is suppressed by the clock window and then reports the count', () {
    final e = _event('err');
    for (var i = 0; i < 4; i++) {
      clock.t = t0.add(Duration(minutes: i));
      Log.error(e, StateError('down'), StackTrace.current, {'ms': i});
    }
    expect(sink.lines, hasLength(1));
    clock.t = t0.add(const Duration(minutes: 11));
    Log.error(e, StateError('down'));
    expect(sink.lines, hasLength(2));
    expect(sink.lines.last, startsWith('2031-03-04T05:17:07.890Z ERROR engine $e'));
    expect(sink.lines.last, contains('repeated=3'));
  });

  test('info lines are never suppressed, even at the same instant', () {
    final e = _event('info');
    for (var i = 0; i < 5; i++) {
      Log.info(e, {'k': 1});
    }
    expect(sink.lines, hasLength(5));
    expect(sink.lines.any((l) => l.contains('repeated')), isFalse);
  });
}
