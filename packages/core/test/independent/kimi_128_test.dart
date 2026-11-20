// Independent tests (#99) for DECISIONS #128 (Kimi review fixes, capture): GitHub PR conversation comments,
// source-sync HTTP timeouts, AI clients not following redirects, payload occurred times (schema v2) and the
// git source skipping `git show` for patches numstat proves are over the cap.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:core/src/ai/clients/http.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/capture/sources/git_repo.dart';
import 'package:core/src/capture/sources/github.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:test/test.dart';

import 'ai/stub_http.dart' as stub;
import 'fakes.dart' show MemBlobs, MemSecrets, MutableClock, NoWatcher, ScriptedLlm, ScriptedRouter;
import 'fakes.dart' as fakes show NoGit;
import 'sources/support.dart';

void main() {
  group('GitHub PR conversation comments (#128 a)', () {
    late Api api;
    final now = DateTime.utc(2026, 11, 19);
    // PR detail per number; issue-comment pages per number; plain issues for `/issues`.
    late Map<int, Map<String, Object?>> pulls;
    late Map<int, Object?> issueComments; // List → 200 body; Res → forced response
    late List<Map<String, Object?>> plainIssues;

    Map<String, Object?> user(String login) => {'login': login};

    Map<String, Object?> pr(int n, {String author = 'someone', int comments = 0, String updated = '2026-11-10T00:00:00Z'}) =>
        {
          'number': n,
          'title': 'PR $n',
          'html_url': 'https://github.com/o/r/pull/$n',
          'user': user(author),
          'state': 'open',
          'created_at': '2026-11-01T00:00:00Z',
          'closed_at': null,
          'updated_at': updated,
          'comments': comments,
          'base': {'ref': 'main'},
          'head': {'ref': 'f$n'},
        };

    setUp(() async {
      api = await Api.start();
      pulls = {};
      issueComments = {};
      plainIssues = [];
      api.handler = (h) {
        final path = h.uri.path;
        if (path == '/user') return const Res({'login': 'Me'});
        if (path == '/issues') return Res(h.uri.queryParameters['filter'] == 'created' ? plainIssues : const []);
        if (path == '/search/issues') {
          final q = h.uri.queryParameters['q']!;
          if (q.contains('reviewed-by:')) return const Res({'items': <Object?>[]});
          return Res({
            'items': [
              for (final n in pulls.keys)
                {'repository_url': '${api.url}/repos/o/r', 'number': n, 'updated_at': pulls[n]!['updated_at']},
            ],
          });
        }
        final m = RegExp(r'^/repos/o/r/(pulls|issues)/(\d+)(?:/(\w+))?$').firstMatch(path);
        if (m == null) return null;
        final n = int.parse(m[2]!);
        if (m[1] == 'pulls') {
          if (m[3] == null) return pulls[n] == null ? null : Res(pulls[n]);
          return const Res([]); // commits, reviews, review comments: none
        }
        if (m[3] == 'comments') {
          final r = issueComments[n];
          if (r is Res) return r;
          return r == null ? null : Res(r);
        }
        return null;
      };
    });
    tearDown(() => api.close());

    Ctx ctx() => Ctx(config: {'apiBaseUrl': '${api.url}/', 'login': 'Me'}, token: 'tok', now: now);

    Map<String, Object?> comment(String login, String body) => {
      'user': user(login),
      'body': body,
      'created_at': '2026-11-02T00:00:00Z',
      'html_url': 'https://github.com/o/r/pull/1#issuecomment-$body',
    };

    test('your conversation comments are kept; others are dropped; you become commenter', () async {
      pulls[1] = pr(1, author: 'me', comments: 2);
      issueComments[1] = [comment('ME', 'mine'), comment('other', 'theirs')];
      final obs = await GitHubSource().sync(ctx()).toList();
      final o = obs.singleWhere((o) => o.externalId == 'pr:o/r#1');
      final conv = o.content['conversationComments'] as List;
      expect(conv, hasLength(1));
      expect(conv.single, {
        'body': 'mine',
        'createdAt': '2026-11-02T00:00:00Z',
        'url': 'https://github.com/o/r/pull/1#issuecomment-mine',
      });
      expect(o.content['roles'], containsAll(['author', 'commenter']));
      expect(o.content['comments'], isEmpty); // conversation comments are not review comments
      expect(api.to('/repos/o/r/issues/1/comments'), hasLength(1));
    });

    test('a PR where your only contribution is a conversation comment still yields a payload', () async {
      pulls[1] = pr(1, comments: 1);
      issueComments[1] = [comment('me', 'lgtm')];
      final obs = await GitHubSource().sync(ctx()).toList();
      final o = obs.singleWhere((o) => o.externalId == 'pr:o/r#1');
      expect(o.content['roles'], ['commenter']);
      expect((o.content['conversationComments'] as List).single, containsPair('body', 'lgtm'));
    });

    test('control: someone else\'s comments only → no payload', () async {
      pulls[1] = pr(1, comments: 1);
      issueComments[1] = [comment('other', 'x')];
      final obs = await GitHubSource().sync(ctx()).toList();
      expect(obs.where((o) => o.externalId.startsWith('pr:')), isEmpty);
    });

    test('comments: 0 makes no issue-comments request', () async {
      pulls[1] = pr(1, author: 'me');
      issueComments[1] = [comment('me', 'would be found')];
      final obs = await GitHubSource().sync(ctx()).toList();
      expect(api.hits.where((h) => h.uri.path.startsWith('/repos/o/r/issues/')), isEmpty);
      final o = obs.single;
      expect(o.content['conversationComments'], isEmpty);
      expect(o.content['roles'], ['author']);
    });

    test('404 on the issue-comments route skips that PR (others continue) and advances the cursor', () async {
      pulls[1] = pr(1, author: 'me', comments: 1, updated: '2026-11-10T00:00:00Z');
      pulls[2] = pr(2, author: 'me', comments: 1, updated: '2026-11-11T00:00:00Z'); // processed last
      issueComments[1] = [comment('me', 'ok')];
      issueComments[2] = const Res({'message': 'Not Found'}, status: 404);
      final c = ctx();
      final obs = await GitHubSource().sync(c).toList();
      expect(obs.map((o) => o.externalId), ['pr:o/r#1']);
      expect(api.to('/repos/o/r/issues/2/comments'), hasLength(1));
      // Only the skipped PR can have set this: it is the last one.
      expect(c.staged[''], '2026-11-11T00:00:00Z');
    });

    test('plain-issue path unchanged: comments shape, commenter role, comments: 0 skips the request', () async {
      Map<String, Object?> issue(int n, int comments) => {
        'repository_url': '${api.url}/repos/o/r',
        'number': n,
        'title': 'Issue $n',
        'html_url': 'https://github.com/o/r/issues/$n',
        'body': 'b',
        'user': user('other'),
        'state': 'open',
        'labels': const [],
        'comments': comments,
        'created_at': '2026-11-01T00:00:00Z',
        'closed_at': null,
        'updated_at': '2026-11-1${n}T00:00:00Z',
      };
      plainIssues = [issue(5, 2), issue(6, 0)];
      issueComments[5] = [comment('me', 'issue-note'), comment('other', 'x')];
      issueComments[6] = [comment('me', 'never fetched')];
      final obs = await GitHubSource().sync(ctx()).toList();
      final o = obs.singleWhere((o) => o.externalId == 'issue:o/r#5');
      expect(o.kind, PayloadKind.issue);
      expect(o.content['roles'], ['commenter']);
      expect(o.content['comments'], [
        {'body': 'issue-note', 'createdAt': '2026-11-02T00:00:00Z', 'url': 'https://github.com/o/r/pull/1#issuecomment-issue-note'},
      ]);
      expect(o.content.containsKey('conversationComments'), isFalse);
      expect(obs.where((o) => o.externalId == 'issue:o/r#6'), isEmpty);
      expect(api.to('/repos/o/r/issues/6/comments'), isEmpty);
    });
  });

  group('engine harness', () {
    late ProfileDb db;
    AntEngine engine(ProfileDb db) => AntEngine(
      db: db,
      profileId: 'p1',
      ports: EnginePorts(
        secrets: MemSecrets(),
        blobs: MemBlobs(),
        git: fakes.NoGit(),
        watcher: NoWatcher(),
        clock: MutableClock(DateTime.utc(2026, 11, 19)),
      ),
      router: ScriptedRouter(ScriptedLlm([])),
      utcOffset: (_) => Duration.zero,
    );
    setUp(() => db = ProfileDb(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('SyncService default Dio has 60 s connect, send and receive timeouts and sources get it (#128 b)', () async {
      final e = engine(db);
      final probe = _HttpProbe();
      e.sources.register(SourceKind.ics, () => probe);
      await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.ics, name: 'cal'));
      final sync = SyncService(e);
      final o = sync.http.options;
      const s60 = Duration(seconds: 60);
      expect(o.connectTimeout, s60);
      expect(o.sendTimeout, s60);
      expect(o.receiveTimeout, s60);
      await sync.syncSource('s1');
      expect(identical(probe.seen, sync.http), isTrue);
    });
  });

  group('AI client does not follow redirects (#128 c)', () {
    late stub.StubHttp origin, elsewhere;
    setUp(() async {
      origin = await stub.StubHttp.start();
      elsewhere = await stub.StubHttp.start();
      elsewhere.on['/models'] = stub.json({'data': <Object?>[]});
      elsewhere.on['/chat'] = stub.json({});
    });
    tearDown(() async {
      await origin.close();
      await elsewhere.close();
    });

    stub.Reply redirect(int status, String to) => (req) async {
      req.response
        ..statusCode = status
        ..headers.set('location', to);
      await req.response.close();
    };

    test('302 on GET /models: not followed, LlmFailure 302 naming the Location', () async {
      final target = '${elsewhere.url}/models';
      origin.on['/models'] = redirect(302, target);
      final client = OpenAiCompatibleClient(baseUrl: origin.url, apiKey: 'sk-secret') /* default Dio */;
      await expectLater(
        client.listModels(),
        throwsA(
          isA<LlmFailure>()
              .having((f) => f.statusCode, 'statusCode', 302)
              .having((f) => f.message, 'message', contains(target)),
        ),
      );
      expect(origin.seen, hasLength(1));
      expect(elsewhere.seen, isEmpty);
    });

    for (final status in [303, 307]) {
      test('POST getting $status fails and is not followed', () async {
        final target = '${elsewhere.url}/chat';
        origin.on['/chat'] = redirect(status, target);
        await expectLater(
          postLines(newDio(), '${origin.url}/chat', {'x': 1}).toList(),
          throwsA(
            isA<LlmFailure>()
                .having((f) => f.statusCode, 'statusCode', status)
                .having((f) => f.message, 'message', contains(target)),
          ),
        );
        expect(elsewhere.seen, isEmpty);
      });
    }

    test('control: 4xx still reports the error status', () async {
      origin.on['/models'] = stub.json({'error': 'nope'}, status: 401);
      await expectLater(
        getJson(newDio(), '${origin.url}/models'),
        throwsA(isA<LlmFailure>().having((f) => f.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('Ingestor: payload occurred times (#128 d)', () {
    late ProfileDb db;
    late Ingestor ing;
    // +5 h: a UTC-day computation would give a different day for t2.
    Duration offset(DateTime _) => const Duration(hours: 5);
    final t1 = DateTime.utc(2026, 11, 1, 10);
    final t1End = DateTime.utc(2026, 11, 1, 11);
    final t2 = DateTime.utc(2026, 11, 3, 20); // local 2026-11-04 01:00
    final t2End = DateTime.utc(2026, 11, 3, 21);

    PayloadObservation obs(
      String id,
      DateTime start, {
      DateTime? end,
      String? title,
      bool tombstone = false,
      Map<String, Object?>? content,
    }) => PayloadObservation(
      externalId: id,
      kind: PayloadKind.calendarEvent,
      content: content ?? {'id': id},
      occurredStart: start,
      occurredEnd: end,
      title: title ?? 'title $id',
      groupKey: 'g',
      tombstone: tombstone,
    );

    setUp(() async {
      db = ProfileDb(NativeDatabase.memory());
      await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.ics, name: 'cal'));
      ing = Ingestor(db, utcOffset: offset);
    });
    tearDown(() => db.close());

    Future<Evidence> evidence() async => (await db.select(db.evidences).get()).single;
    Future<Payload> payload(String ext) async =>
        (await (db.select(db.payloads)..where((p) => p.externalId.equals(ext))).get()).single;

    test('new payloads store their own occurred start/end', () async {
      await ing.ingest('s1', [obs('a', t1, end: t1End), obs('b', t2)]);
      final a = await payload('a'), b = await payload('b');
      expect(a.occurredStart!.toUtc(), t1);
      expect(a.occurredEnd!.toUtc(), t1End);
      expect(b.occurredStart!.toUtc(), t2);
      expect(b.occurredEnd, isNull);
    });

    test('tombstoning the earliest payload re-times evidence from the next live one', () async {
      await ing.ingest('s1', [obs('a', t1, end: t1End), obs('b', t2, end: t2End)]);
      var e = await evidence();
      expect((e.occurredStart.toUtc(), e.day, e.title), (t1, '2026-11-01', 'title a'));
      await ing.ingest('s1', [obs('a', t1, end: t1End, tombstone: true)]);
      e = await evidence();
      expect(e.title, 'title b');
      expect(e.occurredStart.toUtc(), t2);
      expect(e.occurredEnd!.toUtc(), t2End);
      expect(e.day, '2026-11-04');
    });

    test('next payload with a null end clears the evidence end', () async {
      await ing.ingest('s1', [obs('a', t1, end: t1End), obs('b', t2)]);
      await ing.ingest('s1', [obs('a', t1, tombstone: true)]);
      final e = await evidence();
      expect(e.occurredStart.toUtc(), t2);
      expect(e.occurredEnd, isNull);
    });

    test('a payload row with null times (schema v1) promotes the title only', () async {
      await ing.ingest('s1', [obs('a', t1, end: t1End)]);
      final before = await evidence();
      // A v1-era row: later id, no stored times.
      await db
          .into(db.payloads)
          .insert(
            PayloadsCompanion.insert(
              id: newId(t2),
              evidenceId: before.id,
              sourceId: 's1',
              kind: PayloadKind.calendarEvent,
              externalId: 'old',
              content: '{}',
              contentHash: 'h',
              title: const Value('v1 title'),
            ),
          );
      await ing.ingest('s1', [obs('a', t1, tombstone: true)]);
      final e = await evidence();
      expect(e.title, 'v1 title');
      expect(e.occurredStart.toUtc(), t1);
      expect(e.occurredEnd!.toUtc(), t1End);
      expect(e.day, '2026-11-01');
    });

    test('updates persist new times on the payload row, used later when promoted', () async {
      await ing.ingest('s1', [obs('a', t1, end: t1End), obs('b', t2, end: t2End)]);
      // b is rescheduled; it is not the first payload, so evidence keeps a's times for now.
      final t3 = DateTime.utc(2026, 11, 7, 23), t3End = DateTime.utc(2026, 11, 8, 1);
      final r = await ing.ingest('s1', [obs('b', t3, end: t3End, content: {'id': 'b', 'v': 2})]);
      expect(r.updated, 1);
      final b = await payload('b');
      expect(b.occurredStart!.toUtc(), t3);
      expect(b.occurredEnd!.toUtc(), t3End);
      expect((await evidence()).occurredStart.toUtc(), t1);
      await ing.ingest('s1', [obs('a', t1, tombstone: true)]);
      final e = await evidence();
      expect(e.occurredStart.toUtc(), t3);
      expect(e.occurredEnd!.toUtc(), t3End);
      expect(e.day, '2026-11-08'); // 23:00Z + 5 h
    });

    test('updating the first payload also writes its times to the row', () async {
      await ing.ingest('s1', [obs('a', t1, end: t1End)]);
      await ing.ingest('s1', [obs('a', t2, end: t2End, content: {'id': 'a', 'v': 2})]);
      final a = await payload('a');
      expect(a.occurredStart!.toUtc(), t2);
      expect(a.occurredEnd!.toUtc(), t2End);
      final e = await evidence();
      expect((e.occurredStart.toUtc(), e.occurredEnd!.toUtc(), e.day), (t2, t2End, '2026-11-04'));
    });
  });

  group('Migration v1 → v2 (#128 d)', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('kimi128_mig'));
    tearDown(() => tmp.delete(recursive: true));

    /// A schema-v1 profile DB: the current schema minus the two payload columns, `user_version = 1`,
    /// with one source, evidence and payload.
    Future<String> v1Db() async {
      final path = p.join(tmp.path, 'v1.sqlite');
      final db = ProfileDb(NativeDatabase(File(path)));
      await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.ics, name: 'cal'));
      final at = DateTime.utc(2026, 11, 1, 10);
      await db
          .into(db.evidences)
          .insert(
            EvidencesCompanion.insert(
              id: 'e1',
              occurredStart: at,
              day: '2026-11-01',
              title: 'old',
              createdAt: at,
              updatedAt: at,
            ),
          );
      await db
          .into(db.payloads)
          .insert(
            PayloadsCompanion.insert(
              id: 'p1',
              evidenceId: 'e1',
              sourceId: 's1',
              kind: PayloadKind.calendarEvent,
              externalId: 'x',
              content: '{"a":1}',
              contentHash: 'h',
              title: const Value('old'),
              occurredStart: Value(at),
            ),
          );
      await db.close();
      final raw = sqlite3.open(path);
      try {
        raw.execute('ALTER TABLE payloads DROP COLUMN occurred_start');
        raw.execute('ALTER TABLE payloads DROP COLUMN occurred_end');
        raw.execute('PRAGMA user_version = 1');
        raw.execute('PRAGMA journal_mode = DELETE');
        final cols = raw.select('PRAGMA table_info(payloads)').map((r) => r['name']).toSet();
        expect(cols, isNot(contains('occurred_start'))); // the fixture really is v1
      } finally {
        raw.close();
      }
      return path;
    }

    Future<void> expectMigrated(String path) async {
      final db = ProfileDb(NativeDatabase(File(path)));
      try {
        final cols = (await db.customSelect('PRAGMA table_info(payloads)').get()).map((r) => r.read<String>('name'));
        expect(cols, containsAll(['occurred_start', 'occurred_end']));
        final row = (await db.select(db.payloads).get()).single;
        expect(row.id, 'p1');
        expect(row.occurredStart, isNull);
        expect(row.occurredEnd, isNull);
        expect(row.title, 'old');
        final v = await db.customSelect('PRAGMA user_version').map((r) => r.read<int>('user_version')).getSingle();
        expect(v, 2);
        // The migrated DB accepts new rows with times.
        final at = DateTime.utc(2026, 11, 2, 10);
        await Ingestor(db, utcOffset: (_) => Duration.zero).ingest('s1', [
          PayloadObservation(
            externalId: 'y',
            kind: PayloadKind.calendarEvent,
            content: const {'b': 2},
            occurredStart: at,
            title: 'new',
          ),
        ]);
        final y = await (db.select(db.payloads)..where((p) => p.externalId.equals('y'))).getSingle();
        expect(y.occurredStart!.toUtc(), at);
      } finally {
        await db.close();
      }
    }

    test('opening a v1 DB adds both columns; old rows read null', () async {
      await expectMigrated(await v1Db());
    });

    test('a v1 backup restores into v2', () async {
      final bytes = await File(await v1Db()).readAsBytes();
      final manifest = BackupManifest(
        format: BackupManifest.currentFormat,
        appVersion: '0.0.1',
        schemaVersion: 1,
        profile: 'Work',
        createdAt: DateTime.utc(2026, 11, 1),
        firstDay: '2026-11-01',
        lastDay: '2026-11-01',
        counts: const {},
        dbSha256: sha256.convert(bytes).toString(),
      );
      final archive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())))
        ..addFile(ArchiveFile.bytes('db.sqlite', bytes));
      final bundle = p.join(tmp.path, 'v1.antbackup');
      await File(bundle).writeAsBytes(ZipEncoder().encodeBytes(archive));
      expect((await BackupService.inspect(bundle)).schemaVersion, 1);
      final target = p.join(tmp.path, 'restored', 'profile.sqlite');
      await BackupService.restore(bundle, target, currentSchemaVersion: 2);
      await expectMigrated(target);
    });
  });

  group('Git source skips git show for oversized commits (#128 e)', () {
    late Directory tmp;
    late String repo, argvLog;
    late ProcessGitExecutable g;
    final now = DateTime.utc(2026, 11, 19, 12);

    Future<String> git(List<String> args) async {
      final date = now.subtract(const Duration(days: 2)).toIso8601String();
      final r = await Process.run('git', ['-C', repo, ...args], environment: {
        'GIT_AUTHOR_NAME': 'Me',
        'GIT_AUTHOR_EMAIL': 'me@x.dev',
        'GIT_COMMITTER_NAME': 'Me',
        'GIT_COMMITTER_EMAIL': 'me@x.dev',
        'GIT_AUTHOR_DATE': date,
        'GIT_COMMITTER_DATE': date,
      });
      if (r.exitCode != 0) fail('git $args: ${r.stderr}');
      return (r.stdout as String).trim();
    }

    Future<String> commit(String file, String text) async {
      File(p.join(repo, file)).writeAsStringSync(text);
      await git(['add', file]);
      await git(['commit', '-q', '-m', 'add $file']);
      return git(['rev-parse', 'HEAD']);
    }

    List<List<String>> calls() => [
      for (final line in File(argvLog).readAsLinesSync())
        if (line.isNotEmpty) line.split('\x1f')..removeLast(),
    ];
    List<List<String>> shows() => calls().where((a) => a.length > 4 && a[4] == 'show').toList();

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('kimi128_git');
      repo = p.join(tmp.path, 'repo');
      Directory(repo).createSync();
      await git(['init', '-q', '-b', 'main']);
      await git(['config', 'commit.gpgsign', 'false']);
      // A `git` wrapper that records argv (unit-separated, one call per line) and runs the real git.
      final realGit = GitDetector().detect()!;
      final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
      argvLog = p.join(tmp.path, 'argv');
      File(argvLog).writeAsStringSync('');
      final wrapper = p.join(bin.path, 'git');
      File(wrapper).writeAsStringSync(
        '#!/bin/sh\nfor a in "\$@"; do printf "%s\\037" "\$a" >> "$argvLog"; done\necho >> "$argvLog"\n'
        'exec "$realGit" "\$@"\n',
      );
      await Process.run('chmod', ['+x', wrapper]);
      g = ProcessGitExecutable(detector: GitDetector(os: 'linux', env: {'PATH': bin.path}));
    });
    tearDown(() => tmp.delete(recursive: true));

    Future<List<PayloadObservation>> sync() =>
        GitRepoSource().sync(Ctx(config: {'path': repo}, ids: {'email': ['me@x.dev']}, git: g, now: now)).toList();

    String lines(int n) => '${List.filled(n, 'x').join('\n')}\n';

    test('numstat lines × 2 over the cap: patch null, no git show', () async {
      final sha = await commit('big.txt', lines(maxPatchBytes ~/ 2 + 1)); // 102401 lines → 204802 > 204800
      final o = (await sync()).single;
      expect(o.externalId, sha);
      expect(o.content['patch'], isNull);
      expect(((o.content['stats'] as Map)['added']), maxPatchBytes ~/ 2 + 1);
      expect(calls().where((a) => a.length > 4 && a[4] == 'log'), hasLength(1));
      expect(shows(), isEmpty);
    });

    test('exactly at the line bound still runs git show (then the byte check drops it)', () async {
      final sha = await commit('edge.txt', lines(maxPatchBytes ~/ 2)); // 204800, not > cap
      final o = (await sync()).single;
      expect(shows().single.last, sha);
      expect(o.content['patch'], isNull); // headers push the real patch over 200 KB
    });

    test('small commit calls git show with the safe flags and keeps the patch', () async {
      final sha = await commit('a.txt', 'hello\n');
      final o = (await sync()).single;
      final show = shows().single;
      expect(show.sublist(0, 4), ['-C', repo, '-c', 'log.showSignature=false']);
      expect(show, containsAll(['--no-textconv', '--no-ext-diff']));
      expect(show.last, sha);
      expect(o.content['patch'], allOf(isA<String>(), contains('+hello')));
    });

    test('few long lines: git show runs, the byte check still nulls the patch', () async {
      final sha = await commit('wide.txt', '${List.filled(10, 'y' * 30000).join('\n')}\n'); // 10 lines, ~300 KB
      final o = (await sync()).single;
      expect(shows().single.last, sha);
      expect(o.content['patch'], isNull);
      expect((o.content['stats'] as Map)['added'], 10);
    });
  }, skip: Platform.isWindows
      ? 'argv wrapper is a POSIX shell script'
      : GitDetector().detect() == null
      ? 'git not installed'
      : false);
}

/// Records the `ctx.http` a source is handed.
class _HttpProbe implements Source {
  Object? seen;
  @override
  SourceKind get kind => SourceKind.ics;
  @override
  Future<SourceHealth> validate(SourceContext ctx) async => const SourceHealth.ok();
  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    seen = ctx.http;
  }
}
