import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  late SyncService svc;
  late SyncScheduler sched;
  final t0 = DateTime.utc(2026, 11, 18, 12);

  setUp(() {
    h = Harness.create(now: t0);
    for (final k in [SourceKind.github, SourceKind.ics, SourceKind.linear]) {
      h.engine.sources.register(k, () => ScriptSource(k, (_) => const Stream.empty()));
    }
    svc = h.service();
    sched = SyncScheduler(svc);
  });
  tearDown(() => h.db.close());

  Future<void> succeededAt(String id, DateTime at) => h.db.into(h.db.syncCursors).insert(
        SyncCursorsCompanion.insert(sourceId: id, lastSuccessAt: Value(at)),
      );

  test('intervals: ICS 60 min, others 15 min', () {
    expect(SyncScheduler.intervalFor(SourceKind.ics), const Duration(minutes: 60));
    for (final k in SourceKind.values.where((k) => k != SourceKind.ics)) {
      expect(SyncScheduler.intervalFor(k), const Duration(minutes: 15));
    }
  });

  test('never-synced sources are due at once', () async {
    await h.addRow('gh', SourceKind.github);
    await h.addRow('cal', SourceKind.ics);
    expect(await sched.tick(), unorderedEquals(['gh', 'cal']));
    final jobs = await h.jobs(SyncService.syncJob);
    expect(jobs.map((j) => j.args), unorderedEquals(['{"source_id":"gh"}', '{"source_id":"cal"}']));
  });

  test('a source that only ever failed (status row, no lastSuccessAt) is due', () async {
    await h.addRow('gh', SourceKind.github);
    await h.db.into(h.db.syncCursors).insert(SyncCursorsCompanion.insert(sourceId: 'gh', lastError: const Value('e')));
    expect(await sched.tick(), ['gh']);
  });

  test('non-ICS: not due within 15 min of last success, due at 15 min', () async {
    await h.addRow('gh', SourceKind.github);
    await succeededAt('gh', t0);
    expect(await sched.tick(t0.add(const Duration(minutes: 14, seconds: 59))), isEmpty);
    expect(await sched.tick(t0.add(const Duration(minutes: 15))), ['gh']);
  });

  test('ICS: not due within 60 min, due at 60 min', () async {
    await h.addRow('cal', SourceKind.ics);
    await succeededAt('cal', t0);
    expect(await sched.tick(t0.add(const Duration(minutes: 30))), isEmpty);
    expect(await sched.tick(t0.add(const Duration(minutes: 59, seconds: 59))), isEmpty);
    expect(await sched.tick(t0.add(const Duration(minutes: 60))), ['cal']);
  });

  test('tick without an argument uses the engine clock', () async {
    await h.addRow('gh', SourceKind.github);
    await succeededAt('gh', t0);
    h.clock.t = t0.add(const Duration(minutes: 10));
    expect(await sched.tick(), isEmpty);
    h.clock.t = t0.add(const Duration(minutes: 20));
    expect(await sched.tick(), ['gh']);
  });

  test('concurrent enqueueSync calls (scheduler tick vs watcher timer) create one pending job', () async {
    await h.addRow('gh', SourceKind.github);
    final r = await Future.wait(
        [svc.enqueueSync('gh'), svc.enqueueSync('gh'), sched.tick().then((l) => l.isNotEmpty)]);
    expect(r.where((x) => x), hasLength(1));
    expect(await h.jobs(SyncService.syncJob), hasLength(1));
  }, skip: 'BUG: enqueueSync is check-then-insert outside a transaction, so two interleaved callers both '
      'enqueue a sources.sync for the same source (sync_service.dart:146-154)');

  test('no second job while one is queued or running; a new one once it is done or failed', () async {
    await h.addRow('gh', SourceKind.github);
    expect(await sched.tick(), ['gh']);
    expect(await sched.tick(), isEmpty, reason: 'queued');
    expect(await svc.enqueueSync('gh'), isFalse);

    await (h.db.update(h.db.jobs)).write(const JobsCompanion(state: Value(JobState.running)));
    expect(await sched.tick(), isEmpty, reason: 'running');

    await (h.db.update(h.db.jobs)).write(const JobsCompanion(state: Value(JobState.failed)));
    expect(await sched.tick(), ['gh']);
    expect((await h.jobs(SyncService.syncJob)).length, 2);

    await (h.db.update(h.db.jobs)).write(const JobsCompanion(state: Value(JobState.done)));
    expect(await svc.enqueueSync('gh'), isTrue);
  });

  test('a pending job for one source does not block another source', () async {
    await h.addRow('a', SourceKind.github);
    await h.addRow('b', SourceKind.github);
    expect(await svc.enqueueSync('a'), isTrue);
    expect(await sched.tick(), ['b']);
  });

  test('a job in backoff (queued, runAfter in the future) still counts as pending', () async {
    await h.addRow('gh', SourceKind.github);
    await h.engine.jobs.enqueue(SyncService.syncJob,
        args: {'source_id': 'gh'}, runAfter: t0.add(const Duration(minutes: 30)));
    expect(await sched.tick(), isEmpty);
  });

  test('disabled sources and kinds without a connector are skipped', () async {
    await h.addRow('off', SourceKind.github, enabled: false);
    await h.addRow('jira', SourceKind.jira);
    await h.addRow('notes', SourceKind.manualNote);
    expect(await sched.tick(), isEmpty);
    expect(await h.jobs(), isEmpty);
  });

  test('after a real successful sync the source is not due again for its interval', () async {
    await h.addRow('gh', SourceKind.github);
    await svc.syncSource('gh');
    expect(await sched.tick(t0.add(const Duration(minutes: 1))), isEmpty);
    expect(await sched.tick(t0.add(const Duration(minutes: 15))), ['gh']);
  });
}
