/// Independent tests (#99) for DECISIONS #141 (and the #129 startup cleanup it relies on):
/// `EngineHandle.start` failure cleanup, the shared LLM lane (`EngineRuntime.onLlmLane`) and
/// `generateReportCmd` waiting on it. The tray's deferred rebuild needs a native tray and isn't covered.
library;

import 'dart:async';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fakes.dart';

class _Sink implements LogSink {
  final lines = <String>[];
  @override
  void write(String line) => lines.add(line);
}

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('EngineHandle.start failure (#129)', () {
    late _Sink sink;
    setUp(() {
      sink = _Sink();
      Log.sink = sink;
      Log.isolate = 'ui';
    });
    tearDown(() {
      Log.sink = null;
      Log.isolate = 'engine';
    });

    test('an unusable data dir makes the engine fail: start rethrows and the UI port is closed', () async {
      // A regular file where the data folder should be: opening the file DBs fails in the engine.
      final notADir = File(p.join(dir.path, 'data'))..writeAsStringSync('x');
      final config = EngineConfig(dataDir: notADir.path, timeZone: 'UTC', inMemory: false, startLoops: false);

      await expectLater(
        EngineHandle.start(config).timeout(const Duration(seconds: 20)),
        throwsA(isA<EngineCommandException>().having((e) => e.remoteStack, 'remoteStack', isNotNull)),
      );
      expect(sink.lines.where((l) => l.contains(' engine.start_failed')), hasLength(1),
          reason: 'the EngineFailed path was taken');

      // The isolate is gone (killed or exited); with the port closed its onExit message is dropped,
      // so no `engine.exit` line is ever written.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(sink.lines.where((l) => l.contains(' engine.exit')), isEmpty,
          reason: 'the ReceivePort was closed after the failure');
    });

    test('after a failed start, a start with a usable dir works', () async {
      final notADir = File(p.join(dir.path, 'data'))..writeAsStringSync('x');
      await expectLater(
        EngineHandle.start(EngineConfig(dataDir: notADir.path, timeZone: 'UTC', inMemory: false, startLoops: false)),
        throwsA(isA<EngineCommandException>()),
      );
      final h = await EngineHandle.start(testConfig(dir.path, inMemory: false));
      addTearDown(h.shutdown);
      expect(h.profileId, isNotEmpty);
    });
  });

  group('EngineRuntime.onLlmLane (#141)', () {
    late EngineHandle h;
    setUp(() async => h = await EngineHandle.start(testConfig(dir.path))); // no loops: the lane is free
    tearDown(() => h.shutdown());

    test('tasks run one at a time in call order', () async {
      expect(await h.runtime(_laneOrderCmd()), [
        'a:start',
        'released a',
        'a:end',
        'b:start',
        'b:end',
        'c:start',
        'c:end',
      ]);
    });

    test('a failing task does not block later ones and its error reaches its own caller', () async {
      expect(await h.runtime(_laneFailureCmd()), [
        'a:start',
        'b:start',
        'c:start',
        'a=1',
        'b error=Bad state: b-fail',
        'c=3',
      ]);
    });

    test('generateReportCmd waits for the task holding the lane', () async {
      expect(await h.runtime(_reportWaitsCmd()), [
        'report not done while lane held',
        'released',
        'report done',
      ]);
    });
  });

  group('lane loop shares the lane with report runs (#141)', () {
    test('a report run waits while the LLM lane loop is running a job', () async {
      final h = await EngineHandle.start(EngineConfig(
        dataDir: dir.path,
        timeZone: 'UTC',
        inMemory: true,
        idlePoll: const Duration(milliseconds: 50),
      ));
      addTearDown(h.shutdown);
      await h.runtime(_registerBlockingLlmJobCmd());
      expect(await h.runtime(_reportWaitsForLoopJobCmd()), [
        'job started',
        'report not done while job runs',
        'released',
        'report done',
      ]);
    });
  });
}

// Engine-isolate globals: the commands below run there.
var _jobStarted = false;
Completer<void>? _jobGate;

EngineCommand<void> _registerBlockingLlmJobCmd() => (rt) async {
      rt.engine.jobs.register('test.block', JobLane.llm, (_) async {
        _jobStarted = true;
        await (_jobGate = Completer<void>()).future;
      });
      await rt.engine.jobs.enqueue('test.block');
    };

EngineCommand<List<String>> _reportWaitsForLoopJobCmd() => (rt) async {
      final log = <String>[];
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (!_jobStarted && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      log.add(_jobStarted ? 'job started' : 'job never started');
      var settled = false;
      final report = generateReportCmd('no-such-report')(rt).then<void>((_) {}, onError: (_) {}).whenComplete(() {
        settled = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      log.add(settled ? 'report done while job runs' : 'report not done while job runs');
      log.add('released');
      _jobGate?.complete();
      await report.timeout(const Duration(seconds: 10));
      log.add(settled ? 'report done' : 'report still pending');
      return log;
    };

EngineCommand<List<String>> _laneOrderCmd() => (rt) async {
      final log = <String>[];
      final gate = Completer<void>();
      Future<int> task(String name, {Future<void>? wait}) => rt.onLlmLane(() async {
            log.add('$name:start');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            if (wait != null) await wait;
            log.add('$name:end');
            return 0;
          });
      final all = [task('a', wait: gate.future), task('b'), task('c')];
      await Future<void>.delayed(const Duration(milliseconds: 100));
      log.add('released a');
      gate.complete();
      await Future.wait(all);
      return log;
    };

EngineCommand<List<String>> _laneFailureCmd() => (rt) async {
      final log = <String>[];
      final a = rt.onLlmLane(() async {
        log.add('a:start');
        return 1;
      });
      final b = rt.onLlmLane<int>(() async {
        log.add('b:start');
        throw StateError('b-fail');
      });
      final c = rt.onLlmLane(() async {
        log.add('c:start');
        return 3;
      });
      final results = await Future.wait([
        a.then((v) => 'a=$v'),
        b.then((v) => 'b=$v', onError: (Object e) => 'b error=$e'),
        c.then((v) => 'c=$v'),
      ]);
      return [...log, ...results];
    };

/// Holds the lane with a pending task, then starts a report run (an unknown report id: it fails once it
/// actually runs). The report call must not settle until the holder finishes.
EngineCommand<List<String>> _reportWaitsCmd() => (rt) async {
      final log = <String>[];
      final gate = Completer<void>();
      final holder = rt.onLlmLane(() => gate.future);
      var settled = false;
      final report = generateReportCmd('no-such-report')(rt).then<void>((_) {}, onError: (_) {}).whenComplete(() {
        settled = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      log.add(settled ? 'report done while lane held' : 'report not done while lane held');
      log.add('released');
      gate.complete();
      await holder;
      await report.timeout(const Duration(seconds: 10));
      log.add(settled ? 'report done' : 'report still pending');
      return log;
    };
