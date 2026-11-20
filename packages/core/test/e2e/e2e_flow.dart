// End-to-end flow shared by e2e_fake_test.dart (local fake model server) and e2e_live_test.dart
// (OpenRouter). Drives the real AntEngine on temp file databases: real git, real sync jobs, the real
// DbModelRouter and OpenAI-compatible client, the narrative pipeline, reports, wins, tools and backup.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The model endpoint the flow configures in Settings → Models (AppDb rows + secret).
class E2eEndpoint {
  const E2eEndpoint({required this.kind, required this.baseUrl, required this.model, this.apiKey});
  final ProviderKind kind;
  final String baseUrl;
  final String model;
  final String? apiKey;
}

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class DirBlobStore implements BlobStore {
  DirBlobStore(this.root);
  final String root;
  var _n = 0;
  @override
  Future<String> put(Uint8List bytes, {required String extension}) async {
    final rel = 'b${++_n}.$extension';
    await File(p.join(root, rel)).create(recursive: true);
    await File(p.join(root, rel)).writeAsBytes(bytes, flush: true);
    return rel;
  }

  @override
  Future<Uint8List> get(String path) => File(p.join(root, path)).readAsBytes();
  @override
  Future<void> delete(String path) async => File(p.join(root, path)).delete();
}

class FixedClock implements Clock {
  FixedClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

class NoWatcher implements FileWatcher {
  @override
  Stream<void> watch(List<String> paths) => const Stream.empty();
}

const day1 = '2026-11-17', day2 = '2026-11-18';
const me = 'dev@example.com';
DateTime utc(String d, int h, [int m = 0]) => DateTime.parse('${d}T00:00:00Z').add(Duration(hours: h, minutes: m));

/// A 16×16 striped RGB PNG.
Uint8List tinyPng() {
  const w = 16, h = 16;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    for (var x = 0; x < w; x++) {
      raw.add(y.isEven ? [40, 200, 80] : [255, 255, 255]);
    }
  }
  Uint8List chunk(String type, List<int> data) {
    final td = [...ascii.encode(type), ...data];
    final b = BytesBuilder()
      ..add(_u32(data.length))
      ..add(td)
      ..add(_u32(_crc32(td)));
    return b.toBytes();
  }

  return (BytesBuilder()
        ..add([137, 80, 78, 71, 13, 10, 26, 10])
        ..add(chunk('IHDR', [..._u32(w), ..._u32(h), 8, 2, 0, 0, 0]))
        ..add(chunk('IDAT', ZLibCodec().encode(raw.toBytes())))
        ..add(chunk('IEND', const [])))
      .toBytes();
}

List<int> _u32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// Registers the e2e group. [endpoint] is called once in setUpAll (e.g. to start a fake server).
/// [live] prints model output for review and relaxes only workstream coverage (model may skip facts).
void defineE2eFlow(String name, {required Future<E2eEndpoint> Function() endpoint, bool live = false}) {
  group(name, () {
    late Directory tmp;
    late String repo;
    late AppDb appDb;
    late ProfileDb db;
    late AntEngine e;
    late SyncService sync;
    late ReportGenerator reports;
    late MemorySecrets secrets;
    late DirBlobStore blobs;
    late E2eEndpoint ep;
    final clock = FixedClock(utc(day2, 20));
    const profileId = 'E2EPROFILE';
    late String sourceId;
    late String noteEvidence, imageEvidence;
    late Report daily, weekly;
    late ReportSnapshot dailySnap, weeklySnap;

    Future<void> git(List<String> args, {DateTime? at, String email = me}) async {
      final env = {
        'GIT_AUTHOR_NAME': email == me ? 'Dev' : 'Bob',
        'GIT_AUTHOR_EMAIL': email,
        'GIT_COMMITTER_NAME': email == me ? 'Dev' : 'Bob',
        'GIT_COMMITTER_EMAIL': email,
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_NOSYSTEM': '1',
        if (at != null) 'GIT_AUTHOR_DATE': at.toIso8601String(),
        if (at != null) 'GIT_COMMITTER_DATE': at.toIso8601String(),
      };
      final r = await Process.run('git', ['-C', repo, '-c', 'commit.gpgsign=false', ...args],
          environment: {...env, 'PATH': Platform.environment['PATH'] ?? '/usr/bin', 'HOME': tmp.path},
          includeParentEnvironment: false); // keeps OPENROUTER_API_KEY out of child processes
      if (r.exitCode != 0) throw StateError('git ${args.join(' ')}: ${r.stderr}');
    }

    Future<void> commit(String file, String content, String msg, DateTime at, {String email = me}) async {
      await File(p.join(repo, file)).create(recursive: true);
      await File(p.join(repo, file)).writeAsString(content);
      await git(['add', file]);
      await git(['commit', '-q', '-m', msg], at: at, email: email);
    }

    /// Runs IO/LLM jobs and the recompute queue until nothing is left (the app's lane loops, inline).
    Future<void> settle() async {
      for (var i = 0; i < 100; i++) {
        var worked = await e.jobs.runOne(JobLane.io);
        worked = await e.jobs.runOne(JobLane.llm) || worked;
        worked = await e.recompute.drain() > 0 || worked;
        if (!worked) {
          final bad = (await db.select(db.jobs).get()).where((j) => j.state == JobState.failed || j.lastError != null);
          expect(bad.map((j) => '${j.kind}: ${j.lastError}'), isEmpty, reason: 'jobs failed');
          return;
        }
      }
      fail('engine did not settle');
    }

    /// Runs the sync job only (IO lane); the recompute work it enqueues is left for [settle].
    Future<void> syncRepo() async {
      expect(await sync.enqueueSync(sourceId), isTrue);
      while (await e.jobs.runOne(JobLane.io)) {}
      final jobs = await (db.select(db.jobs)..where((j) => j.kind.equals(SyncService.syncJob))).get();
      for (final j in jobs) {
        expect(j.state, JobState.done, reason: 'sync job failed: ${j.lastError}');
      }
      final status = await (db.select(db.syncCursors)
            ..where((c) => c.sourceId.equals(sourceId) & c.scope.equals('')))
          .getSingle();
      expect(status.lastError, isNull);
      final cursor = await (db.select(db.syncCursors)
            ..where((c) => c.sourceId.equals(sourceId) & c.scope.equals('')))
          .getSingle();
      final latest = (await (db.select(db.payloads)..where((x) => x.kind.equalsValue(PayloadKind.commit))).get())
          .map((pl) => DateTime.parse((jsonDecode(pl.content) as Map)['committedAt'] as String))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      expect(DateTime.parse(cursor.cursor!), latest, reason: 'cursor = latest commit time');
    }

    Future<List<Fact>> liveFacts({bool time = false}) async => (await (db.select(db.facts)
          ..where((f) => f.retired.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.periodStart)]))
        .get())
        .where((f) => (f.type == FactType.timeAllocation) == time)
        .toList();

    Future<bool> stale(ReportSnapshot s) => e.staleness.isStale((type: EntityType.reportSnapshot, id: s.id));

    Future<ReportSnapshot> generate(Report r) async {
      final done = await reports.generate(r.id).last as ReportDone;
      return done.snapshot!;
    }

    Future<ReportSnapshot> latestSnapshot(Report r) async => (await (db.select(db.reportSnapshots)
          ..where((s) => s.reportId.equals(r.id))
          ..orderBy([(s) => OrderingTerm.desc(s.version)])
          ..limit(1))
        .getSingle());

    Future<void> checkReport(ReportSnapshot s) async {
      final json = jsonDecode(s.json) as Map<String, Object?>;
      final sections = (json['sections'] as List).cast<Map<String, Object?>>();
      final items = [for (final sec in sections) ...(sec['items'] as List).cast<Map<String, Object?>>()];
      expect(items, isNotEmpty, reason: 'report has no items:\n${s.markdown}');
      final factIds = {for (final f in await db.select(db.facts).get()) if (!f.retired) f.id};
      for (final i in items) {
        final ids = (i['fact_ids'] as List).cast<String>();
        expect(ids, isNotEmpty, reason: 'uncited bullet: ${i['text']}');
        expect(factIds, containsAll(ids));
      }
      expect(s.markdown.trim(), isNotEmpty);
      for (final sec in sections) {
        expect((sec['heading'] as String).trim(), isNotEmpty);
        expect(s.markdown, contains(sec['heading'] as String));
      }
      expect(await stale(s), isFalse);
    }

    setUpAll(() async {
      ep = await endpoint();
      tmp = await Directory.systemTemp.createTemp('ant_e2e');
      repo = p.join(tmp.path, 'repo');
      await Directory(repo).create();
      await git(['init', '-q', '-b', 'main']);
      appDb = AppDb(NativeDatabase(File(p.join(tmp.path, 'app.sqlite'))));
      db = ProfileDb(NativeDatabase(File(p.join(tmp.path, 'profiles', '$profileId.sqlite'))..parent.createSync()));
      secrets = MemorySecrets();
      blobs = DirBlobStore(p.join(tmp.path, 'blobs'));
      await appDb.into(appDb.profiles).insert(ProfilesCompanion.insert(
            id: profileId,
            name: 'Work',
            timeZone: 'UTC',
            active: const Value(true),
            createdAt: clock.now(),
          ));
      e = AntEngine(
        db: db,
        profileId: profileId,
        ports: EnginePorts(
          secrets: secrets,
          blobs: blobs,
          git: ProcessGitExecutable(),
          watcher: NoWatcher(),
          clock: clock,
        ),
        router: DbModelRouter(appDb: appDb, profileDb: db, secrets: secrets),
        utcOffset: (_) => Duration.zero,
      );
      registerCodeSources(e.sources);
      registerOtherSources(e.sources);
      sync = registerSyncJobs(e);
      registerBuiltinTools(e.tools);
      registerNarrativePipeline(e);
      await TemplateService(db).seedBuiltins();
      reports = ReportGenerator(db: db, router: e.router, tools: e.tools, profileId: profileId, clock: clock);
    });

    tearDownAll(() async {
      await db.close();
      await appDb.close();
      await tmp.delete(recursive: true);
    });

    test('1. git repo + identity synced through sync jobs', () async {
      await commit('pay/retry.dart', 'retry v1', 'Add retry with backoff to payment client', utc(day1, 9));
      await commit('pay/retry_test.dart', 'test', 'Fix flaky timeout in payment retry test', utc(day1, 9, 40));
      await commit('docs/retry.md', 'docs', 'Document payment retry configuration', utc(day1, 10, 30));
      await commit('other.txt', 'x', 'Unrelated change by a colleague', utc(day1, 11), email: 'bob@example.com');
      await commit('checkout/idem.dart', 'keys', 'Implement idempotency keys for checkout API', utc(day2, 14));
      await commit('checkout/idem_test.dart', 'tests', 'Add tests for idempotency key reuse', utc(day2, 14, 50));

      await db.into(db.identities).insert(IdentitiesCompanion.insert(id: 'I1', kind: 'email', value: me));
      sourceId = await sync.addSource(SourceKind.gitRepo, 'repo', {'path': repo});
      expect((await sync.validateSource(sourceId)).ok, isTrue);
      await syncRepo();

      final payloads = await db.select(db.payloads).get();
      expect(payloads, hasLength(5), reason: "only the identity's commits");
      for (final pl in payloads) {
        expect(pl.kind, PayloadKind.commit);
        expect(pl.revision, 1);
        final c = jsonDecode(pl.content) as Map<String, Object?>;
        expect((c['author'] as Map)['email'], me);
        expect(c['patch'], isA<String>());
        expect(pl.groupKey, c['sha']);
      }
      final ev = await db.select(db.evidences).get();
      expect(ev, hasLength(5));
      expect(ev.where((x) => x.day == day1), hasLength(3));
      expect(ev.where((x) => x.day == day2), hasLength(2));
      expect(ev.map((x) => x.title), contains('Implement idempotency keys for checkout API'));
      expect(await db.select(db.payloadRevisions).get(), hasLength(5));

      // Re-sync is a no-op (content hashes).
      await syncRepo();
      expect(await db.select(db.payloadRevisions).get(), hasLength(5));
    });

    test('2. text note and image note', () async {
      noteEvidence = await e.addNote(
        text: 'Paired with Priya on the refund edge cases; she is unblocked',
        at: utc(day2, 16),
      );
      final path = await blobs.put(tinyPng(), extension: 'png');
      imageEvidence = await e.addNote(text: 'CI green after the retry fix', at: utc(day1, 12), attachmentPaths: [path]);
      final note = await (db.select(db.evidences)..where((x) => x.id.equals(noteEvidence))).getSingle();
      expect(note.day, day2);
      final img = await (db.select(db.payloads)..where((x) => x.evidenceId.equals(imageEvidence))).getSingle();
      expect(img.kind, PayloadKind.image);
      final att = await (db.select(db.attachments)..where((a) => a.payloadId.equals(img.id))).getSingle();
      expect(att.mime, 'image/png');
      expect(att.size, tinyPng().length);
    });

    test('3. provider + model configured, all routes on it, probe passes', () async {
      final ref = ep.apiKey == null ? null : 'provider:e2e';
      if (ref != null) await secrets.write(ref, ep.apiKey!);
      expect(requiresConsent(ep.baseUrl), ep.kind == ProviderKind.openrouter);
      await appDb.into(appDb.providers).insert(ProvidersCompanion.insert(
            id: 'PROV',
            kind: ep.kind,
            name: 'E2E provider',
            baseUrl: ep.baseUrl,
            protocol: ProviderProtocol.openai,
            credentialRef: Value(ref),
            consentGiven: const Value(true),
          ));
      final provider = await appDb.select(appDb.providers).getSingle();
      final listed = await createClient(provider, apiKey: ep.apiKey).listModels();
      final info = listed.firstWhere((m) => m.name == ep.model);
      await appDb.into(appDb.models).insert(ModelsCompanion.insert(
            id: 'MODEL',
            providerId: 'PROV',
            modelName: ep.model,
            vision: Value(info.vision),
            contextLength: Value(info.contextLength ?? 32000),
            inputPricePerMTok: Value(info.inputPricePerMTok),
            outputPricePerMTok: Value(info.outputPricePerMTok),
          ));
      for (final r in LlmRoute.values) {
        await db.into(db.taskRoutes).insert(TaskRoutesCompanion.insert(route: r, modelId: const Value('MODEL')));
      }
      for (final r in LlmRoute.values) {
        final m = await e.router.resolve(r);
        expect(m.modelName, ep.model);
        expect(m.info.vision, isTrue);
      }
      final resolved = await e.router.resolve(LlmRoute.defaultRoute);
      final probed = await probeModel(resolved.client, resolved.modelName, info: resolved.info);
      expect(probed.name, ep.model);
    });

    test('4. narrative pipeline: importance, enrichments, facts, time, workstreams', () async {
      expect(await db.select(db.recomputeQueue).get(), isNotEmpty);
      await settle();
      expect(await db.select(db.recomputeQueue).get().then((q) => q.where((x) => x.entityType == EntityType.day)),
          isEmpty);

      final ev = await db.select(db.evidences).get();
      for (final x in ev) {
        expect(x.importanceSetBy, ImportanceSetBy.model, reason: 'unscored ${x.title}');
        expect(x.importance, inInclusiveRange(0, 1));
      }

      final enr = await db.select(db.enrichments).get();
      for (final pl in await db.select(db.payloads).get()) {
        final n = enr.where((x) => x.targetId == pl.id).toList();
        expect(n, hasLength(1), reason: 'enrichment for ${pl.kind.name} ${pl.title}');
        expect(n.single.output.trim(), isNotEmpty);
        if (pl.kind == PayloadKind.image) expect(n.single.kind, 'image_description');
      }

      final facts = await liveFacts();
      expect(facts, isNotEmpty);
      final payloads = {for (final pl in await db.select(db.payloads).get()) pl.id: pl};
      final deps = await db.select(db.dependencies).get();
      for (final f in facts) {
        final cites = await (db.select(db.citations)..where((c) => c.factId.equals(f.id))).get();
        expect(cites, isNotEmpty, reason: 'uncited fact: ${f.statement}');
        for (final c in cites) {
          expect(c.payloadRevision, payloads[c.payloadId]!.revision);
          expect(
            deps.any((d) =>
                d.dependentType == EntityType.fact &&
                d.dependentId == f.id &&
                d.inputType == EntityType.payload &&
                d.inputId == c.payloadId &&
                d.inputRevision == c.payloadRevision),
            isTrue,
            reason: 'dependency row for ${f.id} ← ${c.payloadId}',
          );
        }
        expect(f.origin, FactOrigin.inferred);
        // A real model may leave a fact without a workstream (it isn't re-asked); the fake assigns all.
        if (!live) expect(f.workstreamId, isNotNull, reason: 'unassigned: ${f.statement}');
      }
      expect(facts.map((f) => f.periodStart).toSet(), {day1, day2});

      final time = await liveFacts(time: true);
      expect(time.map((f) => f.periodStart).toSet(), {day1, day2});
      for (final f in time) {
        final d = jsonDecode(f.details) as Map<String, Object?>;
        expect(d['basis'], 'estimated');
        expect(d['minutes'], greaterThan(0));
      }
      // day1: one session 08:30–10:30 = 120 min; day2: 13:30–14:50 = 80 min.
      final byDay = {for (final f in time) f.periodStart: (jsonDecode(f.details) as Map)['minutes']};
      expect(byDay, {day1: 120, day2: 80});

      final ws = await db.select(db.workstreams).get();
      expect(ws, isNotEmpty);
      final assigned = facts.where((f) => f.workstreamId != null).length;
      expect(assigned, greaterThanOrEqualTo((facts.length / 2).ceil()), reason: 'most facts get a workstream');
      if (live) print('workstreams assigned: $assigned/${facts.length} facts');
      for (final w in ws) {
        expect(w.title.trim(), isNotEmpty);
      }
      if (live) {
        printOnFailure('facts: ${facts.map((f) => '${f.type.name}: ${f.statement}').join('\n')}');
        print('--- live facts ---');
        for (final f in facts) {
          final w = ws.where((x) => x.id == f.workstreamId).firstOrNull?.title;
          print('${f.periodStart} ${f.type.name} (${f.importance}) win=${f.winStatus.name} ws=$w: ${f.statement}');
        }
        print('--- workstreams ---\n${ws.map((w) => '${w.title}: ${w.summary}').join('\n')}');
        print('--- enrichments ---\n${enr.map((n) => '${n.kind}: ${n.output}').join('\n')}');
      }
    });

    test('5. daily and weekly reports: snapshot, markdown, every bullet cited, fresh', () async {
      daily = await reports.ensureReport(PeriodKind.daily, day2, day2, defaultTemplateFor[PeriodKind.daily]!);
      final w = Period.containing(PeriodKind.weekly, day2);
      weekly = await reports.ensureReport(PeriodKind.weekly, w.start, w.end, defaultTemplateFor[PeriodKind.weekly]!);
      dailySnap = await generate(daily);
      weeklySnap = await generate(weekly);
      expect(dailySnap.version, 1);
      expect(dailySnap.modelId, ep.model);
      await checkReport(dailySnap);
      await checkReport(weeklySnap);
      // Weekly covers both days: its inputs include facts of day1 and day2.
      final deps = await (db.select(db.dependencies)
            ..where((d) => d.dependentType.equalsValue(EntityType.reportSnapshot) & d.dependentId.equals(weeklySnap.id)))
          .get();
      final inputFacts = await (db.select(db.facts)..where((f) => f.id.isIn(deps.map((d) => d.inputId)))).get();
      expect(inputFacts.map((f) => f.periodStart).toSet(), {day1, day2});
      if (live) print('--- daily report ---\n${dailySnap.markdown}\n--- weekly report ---\n${weeklySnap.markdown}');
    });

    test('6. new commit makes reports stale; regenerate; locked report stays unchanged but stale', () async {
      await commit('checkout/expiry.dart', 'expiry', 'Handle expired idempotency keys', utc(day2, 18, 30));
      await syncRepo();
      await settle();
      expect(await db.select(db.payloads).get(), hasLength(8));
      expect(await stale(dailySnap), isTrue);
      expect(await stale(weeklySnap), isTrue);

      dailySnap = await generate(daily);
      expect(dailySnap.version, 2);
      await checkReport(dailySnap);
      expect(await stale(weeklySnap), isTrue, reason: 'only daily regenerated');

      await e.lockReport(daily.id);
      final locked = await latestSnapshot(daily);
      expect(locked.id, dailySnap.id);
      // Change the evidence: hide one of day2's commits (re-runs the day, time facts change).
      final ev = await (db.select(db.evidences)
            ..where((x) => x.day.equals(day2) & x.title.equals('Add tests for idempotency key reuse')))
          .getSingle();
      await e.setHidden(ev.id, true);
      await settle();
      expect(await stale(locked), isTrue);
      await expectLater(reports.generate(daily.id).last, throwsA(isA<ReportLockedException>()));
      final after = await latestSnapshot(daily);
      expect(after.id, locked.id);
      expect(after.markdown, locked.markdown);
      expect(after.json, locked.json);
      final r = await (db.select(db.reports)..where((x) => x.id.equals(daily.id))).getSingle();
      expect(r.locked, isTrue);
      expect(r.lockedSnapshotId, locked.id);
    });

    test('7. star evidence → accepted win; tools return sensible data', () async {
      final noteIds = (await (db.select(db.payloads)..where((x) => x.evidenceId.equals(noteEvidence))).get())
          .map((x) => x.id);
      final noteFacts = (await (db.select(db.facts).join([
        innerJoin(db.citations, db.citations.factId.equalsExp(db.facts.id)),
      ])..where(db.citations.payloadId.isIn(noteIds) & db.facts.retired.equals(false))).get())
          .map((r) => r.readTable(db.facts).id)
          .toSet();
      final factCount = (await db.select(db.facts).get()).length;
      final factId = await WinService(NarrativeContext.of(e)).starEvidence(noteEvidence);
      if (!live) {
        // #119: the fake model returns the note's existing invisible-work fact id, so it becomes the win.
        expect(noteFacts, hasLength(1), reason: 'the fake extraction wrote one fact for the note');
        expect(factId, noteFacts.single);
        expect((await db.select(db.facts).get()).length, factCount, reason: 'no duplicate fact');
        final reused = await (db.select(db.facts)..where((f) => f.id.equals(factId))).getSingle();
        expect(
          (reused.statement, reused.origin, reused.importance),
          ('Unblocked a teammate on the refund flow.', FactOrigin.confirmed, 1.0),
        );
        final cited = (await (db.select(db.citations)..where((c) => c.factId.equals(factId))).get()).map((c) => c.payloadId);
        expect(cited, containsAll(noteIds));
      }
      await settle();
      if (!live) expect((await db.select(db.facts).get()).length, factCount, reason: 'the re-run adds no fact');
      final win = await (db.select(db.facts)..where((f) => f.id.equals(factId))).getSingle();
      expect(win.type, FactType.outcome);
      expect(win.winStatus, WinStatus.accepted);
      expect(win.retired, isFalse);
      final ev = await (db.select(db.evidences)..where((x) => x.id.equals(noteEvidence))).getSingle();
      expect(ev.starred, isTrue);
      expect(ev.importance, 1.0);

      // Starring evidence an Outcome already cites accepts that fact (no model call, no new fact).
      final outcomes = (await db.select(db.facts).get())
          .where((f) => f.type == FactType.outcome && !f.retired && f.winStatus != WinStatus.accepted && f.id != factId)
          .toList();
      final cited = outcomes.isEmpty
          ? <Citation>[]
          : await (db.select(db.citations)..where((c) => c.factId.equals(outcomes.first.id))).get();
      if (cited.isEmpty) {
        if (!live) fail('fake model always creates an outcome citing commits');
        print('no unaccepted outcome to star; existing-outcome path not exercised');
      } else {
        final target = await (db.select(db.payloads)..where((x) => x.id.equals(cited.first.payloadId))).getSingle();
        final before = (await db.select(db.facts).get()).length;
        await e.setStarred(target.evidenceId, true);
        expect((await db.select(db.facts).get()).length, before, reason: 'starring itself creates no fact');
        await settle(); // the day re-runs (curation trigger); the accepted fact is user-touched now
        final accepted = await (db.select(db.facts)..where((f) => f.id.equals(outcomes.first.id))).getSingle();
        expect(accepted.winStatus, WinStatus.accepted);
        expect(accepted.origin, FactOrigin.confirmed);
        expect(accepted.retired, isFalse);
      }

      final week = Period.containing(PeriodKind.weekly, day2);
      final range = {'start': week.start, 'end': week.end};
      final ctx = e.toolContext;
      final wins = (await e.tools['list_wins'].call(range, ctx))['wins'] as List;
      expect(wins.map((w) => (w as Map)['fact_id']), contains(factId));

      final facts = ((await e.tools['get_facts'].call(range, ctx))['facts'] as List).cast<Map<String, Object?>>();
      final dbLive = (await db.select(db.facts).get())
          .where((f) => !f.retired && f.periodStart.compareTo(week.end) <= 0 && f.periodEnd.compareTo(week.start) >= 0)
          .length;
      expect(facts, hasLength(dbLive));
      final imps = [for (final f in facts) f['importance'] as num];
      expect(imps, orderedEquals([...imps]..sort((a, b) => b.compareTo(a))), reason: 'ordered by importance');

      final found = await e.tools['search_evidence'].call({'query': 'idempotency'}, ctx);
      final hits = (found['evidence'] as List).cast<Map<String, Object?>>();
      // The hidden "Add tests for idempotency key reuse" commit is excluded.
      expect(hits.map((h) => h['title']).toSet(),
          {'Implement idempotency keys for checkout API', 'Handle expired idempotency keys'});

      final commitEv = await (db.select(db.evidences)
            ..where((x) => x.title.equals('Implement idempotency keys for checkout API')))
          .getSingle();
      final got = await e.tools['get_evidence'].call({'evidence_id': commitEv.id}, ctx);
      expect(got['found'], isNot(false));
      expect(jsonEncode(got), contains('Implement idempotency keys'));
      expect(await e.tools['get_evidence'].call({'evidence_id': 'nope'}, ctx), {'found': false});

      final time = await e.tools['time_breakdown'].call(range, ctx);
      expect(time['total_minutes'], greaterThan(0));
      final ws = (await e.tools['workstream_timeline'].call(range, ctx))['workstreams'] as List;
      expect(ws, isNotEmpty);
      expect(() => e.tools['get_facts'].call({'start': week.start, 'end': week.end, 'bogus': 1}, ctx),
          throwsA(isA<ArgumentError>()));
      if (live) {
        final notePayloads = (await (db.select(db.payloads)..where((x) => x.evidenceId.equals(noteEvidence))).get())
            .map((x) => x.id);
        final citing = await (db.select(db.facts).join([
          innerJoin(db.citations, db.citations.factId.equalsExp(db.facts.id)),
        ])..where(db.citations.payloadId.isIn(notePayloads) & db.facts.retired.equals(false))).get();
        print('--- win ---\n${win.statement} (origin=${win.origin.name})');
        print('live facts citing the starred note: ${citing.map((r) => r.readTable(db.facts).type.name).toList()}');
      }
    });

    test('8. backup and restore into a fresh DB: row counts match', () async {
      final service = BackupService(db, profileId: 'P1', profileName: 'Work', appVersion: 'e2e', blobs: blobs, clock: clock);
      final bundle = await service.createBackup(p.join(tmp.path, 'backups'));
      expect(await service.list(p.join(tmp.path, 'backups')), hasLength(1));
      final target = p.join(tmp.path, 'restored', '$profileId.sqlite');
      final restoredBlobs = p.join(tmp.path, 'restored_blobs');
      final m = await BackupService.restore(bundle.path, target,
          currentSchemaVersion: db.schemaVersion, attachmentsDir: restoredBlobs);
      expect(m.counts['attachment_files'], 1);

      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
      final restored = ProfileDb(NativeDatabase(File(target)));
      addTearDown(restored.close);
      Future<Map<String, int>> counts(ProfileDb d) async {
        final tables = await d
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
            .map((r) => r.read<String>('name'))
            .get();
        return {
          for (final t in tables) t: await d.customSelect('SELECT COUNT(*) AS c FROM "$t"').map((r) => r.read<int>('c')).getSingle(),
        };
      }

      final before = await counts(db);
      final after = await counts(restored);
      expect(after, before);
      expect(before['facts'], greaterThan(0));
      expect(before['report_snapshots'], 3);
      for (final MapEntry(:key, :value) in m.counts.entries) {
        if (before.containsKey(key)) expect(value, before[key], reason: key);
      }
      final att = await db.select(db.attachments).getSingle();
      expect(await File(p.join(restoredBlobs, att.path)).readAsBytes(), await blobs.get(att.path));
      // The restored DB is usable: staleness still computes for the locked snapshot.
      final s = await (restored.select(restored.reportSnapshots)..where((x) => x.id.equals(dailySnap.id))).getSingle();
      expect(await StalenessService(restored).isStale((type: EntityType.reportSnapshot, id: s.id)), isTrue);
    });
  });
}
