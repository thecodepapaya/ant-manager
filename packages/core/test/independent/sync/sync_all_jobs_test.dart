import 'package:core/core.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness.create());
  tearDown(() => h.db.close());

  group('syncAll (claim 4)', () {
    test('covers only enabled sources with a registered kind; a failure does not stop the others', () async {
      final seen = <String>[];
      h.engine.sources.register(SourceKind.github, () => ScriptSource(SourceKind.github, (ctx) async* {
            seen.add(ctx.sourceId);
            yield obs('gh-${ctx.sourceId}');
          }));
      h.engine.sources.register(SourceKind.linear, () => ScriptSource(SourceKind.linear, (ctx) async* {
            seen.add(ctx.sourceId);
            throw StateError('linear down');
          }));
      // Inserted so the failing one is visited first by default rowid order.
      await h.addRow('bad', SourceKind.linear);
      await h.addRow('ok1', SourceKind.github);
      await h.addRow('off', SourceKind.github, enabled: false);
      await h.addRow('unreg', SourceKind.jira); // no connector registered
      await h.addRow('notes', SourceKind.manualNote);
      await h.addRow('ok2', SourceKind.github);

      final out = await h.service().syncAll();
      expect(out.map((r) => r.sourceId), unorderedEquals(['bad', 'ok1', 'ok2']));
      expect(seen, unorderedEquals(['bad', 'ok1', 'ok2']));

      final bad = out.singleWhere((r) => r.sourceId == 'bad');
      expect(bad.ok, isFalse);
      expect(bad.result, isNull);
      expect(bad.error, contains('linear down'));
      expect(bad.toString(), contains('error'));

      for (final id in ['ok1', 'ok2']) {
        final r = out.singleWhere((r) => r.sourceId == id);
        expect(r.ok, isTrue);
        expect(r.result!.created, 1);
      }
      expect(await h.externalIds('ok1'), ['gh-ok1']);
      expect((await h.status('bad'))!.lastError, contains('linear down'));
      expect(await h.status('off'), isNull);
      expect(await h.status('unreg'), isNull);
    });

    test('no sources -> empty summary', () async {
      expect(await h.service().syncAll(), isEmpty);
    });
  });

  group('jobs (claim 5)', () {
    test("'sources.sync' runs the source and its failure goes through job backoff", () async {
      var fail = true;
      h.engine.sources.register(SourceKind.github, () => ScriptSource(SourceKind.github, (ctx) async* {
            if (fail) throw StateError('rate limited');
            yield obs('a');
          }));
      await h.addRow('s', SourceKind.github);
      registerSyncJobs(h.engine);
      await h.engine.jobs.enqueue(SyncService.syncJob, args: {'source_id': 's'});

      expect(await h.engine.jobs.runOne(JobLane.io), isTrue);
      var job = (await h.jobs(SyncService.syncJob)).single;
      expect(job.state, JobState.queued);
      expect(job.attempts, 1);
      expect(job.lastError, contains('rate limited'));
      expect(job.runAfter.isAtSameMomentAs(h.clock.t.add(JobQueue.backoff.first)), isTrue);
      expect((await h.status('s'))!.lastError, contains('rate limited'));

      // Not ready before backoff elapses.
      expect(await h.engine.jobs.runOne(JobLane.io), isFalse);

      fail = false;
      h.clock.t = h.clock.t.add(const Duration(minutes: 2));
      expect(await h.engine.jobs.runOne(JobLane.io), isTrue);
      job = (await h.jobs(SyncService.syncJob)).single;
      expect(job.state, JobState.done);
      expect(await h.externalIds('s'), ['a']);
      expect((await h.status('s'))!.lastError, isNull);
    });

    test("'sources.syncAll' never throws even when every source fails", () async {
      h.engine.sources.register(SourceKind.github,
          () => ScriptSource(SourceKind.github, (ctx) => Stream.error(StateError('down'))));
      await h.addRow('a', SourceKind.github);
      await h.addRow('b', SourceKind.github);
      registerSyncJobs(h.engine);
      await h.engine.jobs.enqueue(SyncService.syncAllJob);
      expect(await h.engine.jobs.runOne(JobLane.io), isTrue);
      final job = (await h.jobs(SyncService.syncAllJob)).single;
      expect(job.state, JobState.done);
      expect(job.attempts, 0);
      expect((await h.status('a'))!.lastError, contains('down'));
      expect((await h.status('b'))!.lastError, contains('down'));
    });

    test("a 'sources.sync' job queued before the source was removed does not pull its data", () async {
      h.engine.sources.register(SourceKind.github, () => ScriptSource(SourceKind.github, (ctx) async* {
            yield obs('a');
          }));
      final svc = registerSyncJobs(h.engine);
      final id = await svc.addSource(SourceKind.github, 'GH', {});
      expect(await svc.enqueueSync(id), isTrue); // e.g. by the scheduler or a watcher
      await svc.removeSource(id);
      await h.engine.jobs.runOne(JobLane.io);
      expect(await h.externalIds(id), isEmpty);
    }, skip: 'BUG: syncSource() never checks SourceRow.enabled, so a queued sources.sync job (scheduler/watcher) '
        'still syncs a source after removeSource disabled it (sync_service.dart:49-53)');

    test('both jobs are on the IO lane', () async {
      registerSyncJobs(h.engine);
      await h.engine.jobs.enqueue(SyncService.syncAllJob);
      await h.engine.jobs.enqueue(SyncService.syncJob, args: {'source_id': 'x'});
      expect((await h.jobs()).map((j) => j.lane), everyElement(JobLane.io));
    });
  });
}
