import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/staleness/staleness.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

class FakeClock implements Clock {
  FakeClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

class NoRouter implements ModelRouter {
  @override
  Future<ResolvedModel> resolve(LlmRoute route) => throw UnimplementedError();
}

class Unused implements SecretStore, BlobStore, GitExecutable, FileWatcher {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

PayloadObservation obs(String id, {String title = 't', Map<String, Object?>? content, String? group, bool tomb = false}) =>
    PayloadObservation(
      externalId: id,
      kind: PayloadKind.calendarEvent,
      content: content ?? {'id': id},
      occurredStart: DateTime.utc(2026, 11, 17, 10),
      title: title,
      groupKey: group,
      tombstone: tomb,
    );

void main() {
  late ProfileDb db;
  late Ingestor ing;
  late FakeClock clock;
  late AntEngine engine;

  setUp(() async {
    db = ProfileDb(NativeDatabase.memory());
    ing = Ingestor(db, utcOffset: (_) => Duration.zero);
    clock = FakeClock(DateTime.utc(2026, 11, 18, 12));
    final u = Unused();
    engine = AntEngine(
      db: db,
      profileId: 'p',
      ports: EnginePorts(secrets: u, blobs: u, git: u, watcher: u, clock: clock),
      router: NoRouter(),
      utcOffset: (_) => Duration.zero,
    );
    for (final s in ['s1', 's2']) {
      await db.into(db.sources).insert(SourcesCompanion.insert(id: s, kind: SourceKind.googleCalendar, name: s));
    }
  });
  tearDown(() => db.close());

  Future<List<(EntityType, String)>> queue() async =>
      (await db.select(db.recomputeQueue).get()).map((q) => (q.entityType, q.entityId)).toList();

  Future<Fact> fact({FactOrigin origin = FactOrigin.inferred, WinStatus win = WinStatus.none}) async {
    final now = clock.now();
    await db.into(db.facts).insert(FactsCompanion.insert(
      id: 'f1', type: FactType.outcome, statement: 's', periodStart: '2026-11-17', periodEnd: '2026-11-17',
      origin: origin, createdAt: now, updatedAt: now, winStatus: Value(win),
    ));
    return (db.select(db.facts)..where((f) => f.id.equals('f1'))).getSingle();
  }

  group('ingest', () {
    test('tombstoning the first payload re-titles the evidence from the next live one', () async {
      await ing.ingest('s1', [obs('a', title: 'Standup', group: 'uid')]);
      await ing.ingest('s2', [obs('b', title: 'Design review', group: 'uid')]);
      await ing.ingest('s1', [obs('a', title: 'Standup', group: 'uid', tomb: true)]);
      expect((await db.select(db.evidences).getSingle()).title, 'Design review');
    });

    test('a tombstoned peer is not used for grouping', () async {
      await ing.ingest('s1', [obs('a', group: 'uid')]);
      await ing.ingest('s1', [obs('a', group: 'uid', tomb: true)]);
      await ing.ingest('s2', [obs('b', group: 'uid')]);
      expect((await db.select(db.evidences).get()).length, 2);
    });

    test('same external id from two sources makes two payloads', () async {
      await ing.ingest('s1', [obs('x')]);
      await ing.ingest('s2', [obs('x')]);
      expect((await db.select(db.payloads).get()).length, 2);
    });

    test('a later sync can add the group key', () async {
      await ing.ingest('s1', [obs('a')]);
      await ing.ingest('s1', [obs('a', group: 'sha')]);
      expect((await db.select(db.payloads).getSingle()).groupKey, 'sha');
    });

    test('tombstoned payloads leave the FTS index', () async {
      await ing.ingest('s1', [obs('a', content: {'t': 'zebra'})]);
      await ing.ingest('s1', [obs('a', content: {'t': 'zebra'}, tomb: true)]);
      final rows = await db.customSelect("SELECT 1 FROM fts_payloads WHERE fts_payloads MATCH 'zebra'").get();
      expect(rows, isEmpty);
    });
  });

  group('triggers', () {
    test('no-op curation does not enqueue; real change does', () async {
      await ing.ingest('s1', [obs('a')]);
      final e = await db.select(db.evidences).getSingle();
      await db.delete(db.recomputeQueue).go();
      await engine.setHidden(e.id, false);
      expect(await queue(), isEmpty);
      await engine.setStarred(e.id, true);
      expect(await queue(), [(EntityType.day, '2026-11-17')]);
    });

    test('fact revision bump enqueues dependent reports', () async {
      final f = await fact();
      await DependencyRecorder(db).record((type: EntityType.report, id: 'r1'), 1, [(type: EntityType.fact, id: f.id, revision: 1)]);
      await engine.editFact(f.id, 'better');
      expect(await queue(), contains((EntityType.report, 'r1')));
    });

    test('enrichment revision bump enqueues dependent facts', () async {
      await db.into(db.enrichments).insert(EnrichmentsCompanion.insert(
          id: 'n1', targetType: EntityType.payload, targetId: 'p', kind: 'summary', output: 'o', modelId: 'm', createdAt: clock.now()));
      await DependencyRecorder(db).record((type: EntityType.fact, id: 'f9'), 1, [(type: EntityType.enrichment, id: 'n1', revision: 1)]);
      await (db.update(db.enrichments)..where((n) => n.id.equals('n1'))).write(const EnrichmentsCompanion(revision: Value(2)));
      expect(await queue(), contains((EntityType.fact, 'f9')));
    });

    test('unrevisioned dependency inputs are rejected', () {
      expect(() => DependencyRecorder(db).record((type: EntityType.report, id: 'r'), 1, [(type: EntityType.evidence, id: 'e', revision: 1)]),
          throwsArgumentError);
    });
  });

  group('curation & user-touched facts', () {
    test('star and hide combine instead of clobbering', () async {
      await ing.ingest('s1', [obs('a')]);
      final id = (await db.select(db.evidences).getSingle()).id;
      await engine.setStarred(id, true);
      await engine.setHidden(id, true);
      await engine.setHidden(id, false);
      final e = await db.select(db.evidences).getSingle();
      expect((e.starred, e.importance, e.importanceSetBy), (true, 1.0, ImportanceSetBy.user));
    });

    test('setWinStatus is a user correction: revision bump, history, user-touched', () async {
      final f = await fact();
      await engine.setWinStatus(f.id, WinStatus.accepted);
      final g = await db.select(db.facts).getSingle();
      expect((g.revision, g.winStatus, g.origin.isUserTouched), (2, WinStatus.accepted, true));
      expect((await db.select(db.factRevisions).get()).length, 1);
    });

    test('rejecting a fact removes it from Wins', () async {
      final f = await fact(win: WinStatus.accepted);
      await engine.rejectFact(f.id);
      final g = await db.select(db.facts).getSingle();
      expect((g.retired, g.winStatus), (true, WinStatus.rejected));
    });

    test('a user edit clears a pending review proposal', () async {
      await fact(origin: FactOrigin.confirmed);
      await (db.update(db.facts)).write(const FactsCompanion(
          reviewState: Value(ReviewState.needsReview), reviewProposal: Value('{"statement":"model"}')));
      await engine.editFact('f1', 'mine');
      final g = await db.select(db.facts).getSingle();
      expect((g.statement, g.reviewState, g.reviewProposal), ('mine', ReviewState.ok, null));
    });
  });

  group('recompute worker', () {
    test('rows for types without a handler stay queued', () async {
      await db.into(db.recomputeQueue).insert(RecomputeQueueCompanion.insert(
          entityType: EntityType.report, entityId: 'r1', reason: 'x', enqueuedAt: clock.now()));
      final w = RecomputeWorker(db)..on(EntityType.day, (_) async {});
      expect(await w.drain(), 0);
      expect(await queue(), [(EntityType.report, 'r1')]);
    });

    test('work enqueued during a handler is processed on the next pass', () async {
      await db.into(db.recomputeQueue).insert(RecomputeQueueCompanion.insert(
          entityType: EntityType.day, entityId: 'd', reason: 'x', enqueuedAt: clock.now()));
      var runs = 0;
      final w = RecomputeWorker(db)
        ..on(EntityType.day, (id) async {
          runs++;
          if (runs == 1) {
            await db.into(db.recomputeQueue).insert(RecomputeQueueCompanion.insert(
                entityType: EntityType.day, entityId: 'd', reason: 'again', enqueuedAt: clock.now()));
          }
        });
      await w.drain();
      expect(runs, 2);
      expect(await queue(), isEmpty);
    });
  });

  group('job queue', () {
    test('backoff ladder from failure time, then failed', () async {
      final q = JobQueue(db, clock: clock);
      q.register('boom', JobLane.io, (_) async {
        clock.t = clock.t.add(const Duration(minutes: 20)); // long-running job
        throw StateError('x');
      });
      await q.enqueue('boom');
      for (final d in JobQueue.backoff) {
        expect(await q.runOne(JobLane.io), isTrue);
        final j = await db.select(db.jobs).getSingle();
        expect(j.state, JobState.queued);
        expect(j.runAfter.isAtSameMomentAs(clock.t.add(d)), isTrue); // measured from failure, not lease
        clock.t = j.runAfter;
      }
      await q.runOne(JobLane.io);
      final j = await db.select(db.jobs).getSingle();
      expect((j.state, j.attempts), (JobState.failed, 4));
    });

    test('an expired lease is re-leased without consuming an attempt', () async {
      final q = JobQueue(db, clock: clock);
      var ran = 0;
      q.register('ok', JobLane.io, (_) async => ran++);
      await q.enqueue('ok');
      await (db.update(db.jobs)).write(JobsCompanion(
          state: const Value(JobState.running), leaseUntil: Value(clock.now().subtract(const Duration(minutes: 1)))));
      expect(await q.runOne(JobLane.io), isTrue);
      final j = await db.select(db.jobs).getSingle();
      expect((ran, j.state, j.attempts), (1, JobState.done, 0));
    });
  });

  test('addNote with an attachment writes Attachment rows', () async {
    final blobs = _Blobs();
    final e2 = AntEngine(
      db: db, profileId: 'p', router: NoRouter(), utcOffset: (_) => Duration.zero,
      ports: EnginePorts(secrets: Unused(), blobs: blobs, git: Unused(), watcher: Unused(), clock: clock),
    );
    await e2.addNote(text: 'kudos', at: clock.now(), attachmentPaths: ['a.png']);
    final a = await db.select(db.attachments).getSingle();
    expect((a.path, a.size, a.mime), ('a.png', 3, 'image/png'));
  });
}

class _Blobs implements BlobStore {
  @override
  Future<Uint8List> get(String path) async => Uint8List.fromList([1, 2, 3]);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}
