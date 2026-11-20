// Independent tests (#99) for DECISIONS #131 (e): the recompute drain runs on the LLM lane loop,
// so it never runs beside an LLM-lane job, isn't blocked by IO-lane work, and keeps running while
// collection is paused. Drives the real EngineRuntime lane loops in this isolate (no engine isolate).
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ant_manager/engine/engine_runtime.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/port_bridge.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late Directory dir;
  late EngineRuntime rt;
  late ReceivePort ui, reply;

  /// Number of recompute rows our handler processed; [llmBusy]/[ioBusy] are true while a test job runs.
  var drained = 0;
  var llmBusy = false, ioBusy = false;
  bool? llmBusyAtDrain;
  late Completer<void> llmGate, ioGate, llmStarted, ioStarted;

  setUp(() async {
    dir = tempDir();
    ui = ReceivePort();
    reply = ReceivePort();
    drained = 0;
    llmBusy = ioBusy = false;
    llmBusyAtDrain = null;
    llmGate = Completer();
    ioGate = Completer();
    llmStarted = Completer();
    ioStarted = Completer();
    rt = await EngineRuntime.open(
      EngineConfig(
        dataDir: dir.path,
        timeZone: 'UTC',
        inMemory: true,
        startLoops: false,
        idlePoll: const Duration(milliseconds: 10),
      ),
      UiBridge(ui.sendPort, reply.sendPort),
    );
    // Our handlers replace the narrative pipeline's for `day`, so no model is called.
    rt.engine.recompute.on(EntityType.day, (_) async {
      llmBusyAtDrain = llmBusy;
      drained++;
    });
    rt.engine.jobs.register('test.llm', JobLane.llm, (_) async {
      llmBusy = true;
      llmStarted.complete();
      await llmGate.future;
      llmBusy = false;
    });
    rt.engine.jobs.register('test.io', JobLane.io, (_) async {
      ioBusy = true;
      ioStarted.complete();
      await ioGate.future;
      ioBusy = false;
    });
  });

  tearDown(() async {
    if (!llmGate.isCompleted) llmGate.complete();
    if (!ioGate.isCompleted) ioGate.complete();
    await rt.stop();
    ui.close();
    reply.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> queueDay() => rt.db
      .into(rt.db.recomputeQueue)
      .insert(
        RecomputeQueueCompanion.insert(
          entityType: EntityType.day,
          entityId: '2026-11-17',
          reason: 'test',
          enqueuedAt: DateTime.now().toUtc(),
        ),
      );

  Future<int> queued() async =>
      (await rt.db.select(rt.db.recomputeQueue).get()).where((r) => r.entityType == EntityType.day).length;

  Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 5)}) async {
    final end = DateTime.now().add(timeout);
    while (!ok()) {
      if (DateTime.now().isAfter(end)) fail('condition not met within $timeout');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('never overlaps a running LLM-lane job: drains only after it finishes', () async {
    await rt.engine.jobs.enqueue('test.llm');
    rt.startLoops();
    await llmStarted.future.timeout(const Duration(seconds: 5));
    await queueDay();
    rt.kick();
    await Future<void>.delayed(const Duration(milliseconds: 200)); // many idle polls of the IO loop
    expect(drained, 0, reason: 'the IO loop must not drain while the LLM lane is busy');
    expect(await queued(), 1);

    llmGate.complete();
    await until(() => drained == 1);
    expect(llmBusyAtDrain, isFalse);
    expect(await queued(), 0);
  });

  test('drains on the LLM lane: a blocked IO-lane job does not hold it up', () async {
    await rt.engine.jobs.enqueue('test.io');
    rt.startLoops();
    await ioStarted.future.timeout(const Duration(seconds: 5));
    await queueDay();
    rt.kick();
    await until(() => drained == 1);
    expect(ioBusy, isTrue, reason: 'drained while the IO lane was still busy');
    expect(await queued(), 0);
  });

  // Regression guard: pausing never blocked the drain before #131 either; the lane tests are above.
  test('keeps draining while collection is paused (IO jobs wait)', () async {
    rt.paused = true;
    await rt.engine.jobs.enqueue('test.io');
    await queueDay();
    rt.startLoops();
    await until(() => drained == 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(ioStarted.isCompleted, isFalse, reason: 'paused: the IO lane runs no jobs');
    expect(await queued(), 0);
  });
}
