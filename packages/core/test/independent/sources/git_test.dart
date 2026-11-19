import 'dart:io';

import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/capture/sources/git_repo.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Directory tmp;
  late String repo;
  final now = DateTime.utc(2026, 11, 19, 12);
  final twoDaysAgo = now.subtract(const Duration(days: 2));

  Future<String> git(List<String> args, {String email = 'me@x.dev', String? committer, DateTime? at}) async {
    final date = (at ?? twoDaysAgo).toIso8601String();
    final r = await Process.run(
      'git',
      ['-C', repo, ...args],
      environment: {
        'GIT_AUTHOR_NAME': 'Me',
        'GIT_AUTHOR_EMAIL': email,
        'GIT_COMMITTER_NAME': 'Me',
        'GIT_COMMITTER_EMAIL': committer ?? email,
        'GIT_AUTHOR_DATE': date,
        'GIT_COMMITTER_DATE': date,
      },
    );
    if (r.exitCode != 0) fail('git $args: ${r.stderr}');
    return (r.stdout as String).trim();
  }

  Future<String> commit(
    String file,
    String text, {
    String email = 'me@x.dev',
    String? committer,
    DateTime? at,
    String? msg,
  }) async {
    File(p.join(repo, file)).writeAsStringSync(text);
    await git(['add', file]);
    await git(['commit', '-q', '-m', msg ?? 'add $file'], email: email, committer: committer, at: at);
    return git(['rev-parse', 'HEAD']);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ind_git_');
    repo = tmp.path;
    await git(['init', '-q', '-b', 'main']);
    await git(['config', 'commit.gpgsign', 'false']);
    await git(['config', 'user.name', 'Me']);
    await git(['config', 'user.email', 'me@x.dev']);
  });
  tearDown(() => tmp.delete(recursive: true));

  Ctx ctx({List<String> emails = const ['me@x.dev']}) =>
      Ctx(config: {'path': repo}, ids: {'email': emails}, git: ProcessGitExecutable(), now: now);
  Future<List<PayloadObservation>> sync(Ctx c) => GitRepoSource().sync(c).toList();

  test('stash and notes commits are excluded', () async {
    final sha = await commit('a.txt', 'one\n');
    File(p.join(repo, 'a.txt')).writeAsStringSync('dirty\n');
    await git(['stash', 'push', '-q', '-m', 'wip'], at: now.subtract(const Duration(hours: 1)));
    await git(['notes', 'add', '-m', 'a note', sha], at: now.subtract(const Duration(hours: 1)));
    final obs = await sync(ctx());
    expect(obs.map((o) => o.externalId), [sha]);
  });

  test('no branch in content; creating a branch makes no new revision', () async {
    await commit('a.txt', 'one\n');
    final db = ProfileDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.gitRepo, name: 'r'));
    final ing = Ingestor(db, utcOffset: (_) => Duration.zero);
    final c = ctx();
    final first = await sync(c);
    expect(first.single.content.keys.where((k) => k.toLowerCase().contains('branch')), isEmpty);
    await ing.ingest('s1', first);
    c.commit();
    await git(['branch', 'feature']);
    final r = await ing.ingest('s1', await sync(c));
    expect(r.created + r.updated, 0);
    expect(r.unchanged, 1);
    expect(await db.select(db.payloadRevisions).get(), hasLength(1));
  });

  test('merge commits use first-parent stats with a non-empty patch', () async {
    await commit('base.txt', 'base\n');
    await git(['checkout', '-q', '-b', 'feature']);
    await commit('f.txt', 'one\ntwo\nthree\n');
    await git(['checkout', '-q', 'main']);
    await commit('m.txt', 'main\n');
    await git(['merge', '-q', '--no-ff', '-m', 'Merge feature', 'feature']);
    final mergeSha = await git(['rev-parse', 'HEAD']);
    final merge = (await sync(ctx())).singleWhere((o) => o.externalId == mergeSha);
    final stats = merge.content['stats'] as Map;
    expect((stats['files'] as List).map((f) => (f as Map)['path']), ['f.txt']);
    expect(stats['added'], 3);
    expect(merge.content['patch'], allOf(isA<String>(), contains('f.txt'), contains('+three')));
  });

  test('a future-dated commit clamps the cursor to now', () async {
    await commit('a.txt', 'x\n', at: now.add(const Duration(days: 10)));
    final c = ctx();
    expect(await sync(c), hasLength(1));
    expect(DateTime.parse(c.staged['']!), now);
  });

  test('cursor = latest committer time; next sync starts one day earlier', () async {
    final at = now.subtract(const Duration(hours: 5));
    await commit('a.txt', 'x\n', at: at);
    final c = ctx();
    await sync(c);
    expect(DateTime.parse(c.staged['']!), at);
  });

  test('a message containing 0x1e (and other control chars) parses', () async {
    final msgFile = File(p.join(tmp.path, '..', 'msg_${DateTime.now().microsecondsSinceEpoch}.txt'))
      ..writeAsStringSync('subject \x1e rs\n\nbody \x1f us \t tab\n');
    addTearDown(msgFile.delete);
    File(p.join(repo, 'a.txt')).writeAsStringSync('a\n');
    await git(['add', 'a.txt']);
    await git(['commit', '-q', '-F', msgFile.path]);
    final o = (await sync(ctx())).single;
    expect(o.content['message'], contains('\x1e'));
    expect(o.title, 'subject \x1e rs');
    expect((o.content['stats'] as Map)['added'], 1);
  });

  test('renames are kept as one file entry', () async {
    await commit('old.txt', List.generate(20, (i) => 'line $i').join('\n'));
    await git(['mv', 'old.txt', 'new.txt']);
    await git(['commit', '-q', '-m', 'rename']);
    final o = (await sync(ctx())).firstWhere((o) => o.title == 'rename');
    final files = ((o.content['stats'] as Map)['files'] as List).cast<Map>();
    expect(files, hasLength(1));
    expect(files.single['path'], allOf(contains('old.txt'), contains('new.txt')));
    expect(o.content['patch'], contains('rename'));
  });

  test('parseGitLog counts bad records as skipped', () {
    final good = 'a' * 40;
    String rec(String sha, String date) =>
        '\x00$sha\x00Me\x00me@x.dev\x00Me\x00me@x.dev\x00$date\x00$date\x00msg\n\x00\n1\t2\tf.txt\n';
    final out =
        rec(good, '2026-11-01T10:00:00+00:00') +
        rec('nothex', '2026-11-01T10:00:00+00:00') +
        rec('b' * 40, 'not-a-date') +
        rec('c' * 40, '2026-11-02T10:00:00+00:00');
    final log = parseGitLog(out);
    expect(log.commits.map((c) => c.sha), [good, 'c' * 40]);
    expect(log.skipped, 2);
    expect(log.commits.first.files.single, (path: 'f.txt', added: 1, deleted: 2));
    // A truncated trailing record counts too.
    final truncated = parseGitLog('${rec(good, '2026-11-01T10:00:00+00:00')}\x00${'d' * 40}\x00Me');
    expect(truncated.commits, hasLength(1));
    expect(truncated.skipped, 1);
  });

  test('binary files have null counts', () {
    final out =
        '\x00${'a' * 40}\x00Me\x00m@x\x00Me\x00m@x\x002026-11-01T10:00:00Z\x002026-11-01T10:00:00Z\x00m\x00\n-\t-\timg.png\n';
    expect(parseGitLog(out).commits.single.files.single, (path: 'img.png', added: null, deleted: null));
  });

  test('validate errors and sync throws with no email identities', () async {
    await commit('a.txt', 'x\n');
    final c = ctx(emails: const []);
    final h = await GitRepoSource().validate(c);
    expect(h.ok, false);
    expect(h.message, isNotNull);
    await expectLater(sync(c), throwsA(anything));
    expect(c.staged, isEmpty);
  });

  test('validate ok for a repo, error for a non-repo', () async {
    expect((await GitRepoSource().validate(ctx())).ok, true);
    final notRepo = await Directory.systemTemp.createTemp('ind_norepo_');
    addTearDown(() => notRepo.delete(recursive: true));
    final c = Ctx(
      config: {'path': notRepo.path},
      ids: {
        'email': ['me@x.dev'],
      },
      git: ProcessGitExecutable(),
      now: now,
    );
    expect((await GitRepoSource().validate(c)).ok, false);
  });

  test('patch is null over 200 KB; stats kept', () async {
    final big = List.generate(5000, (i) => 'line number $i padded with some text to grow the patch').join('\n');
    expect(big.length, greaterThan(200 * 1024));
    await commit('big.txt', big, msg: 'big');
    await commit('small.txt', 'small\n', msg: 'small');
    final obs = await sync(ctx());
    final bigO = obs.firstWhere((o) => o.title == 'big');
    expect(bigO.content['patch'], isNull);
    expect((bigO.content['stats'] as Map)['added'], 5000);
    expect(obs.firstWhere((o) => o.title == 'small').content['patch'], contains('+small'));
  });

  test('identity match is case-insensitive, on author or committer', () async {
    await commit('a.txt', 'a\n', email: 'Me@X.Dev', msg: 'author match');
    await commit('b.txt', 'b\n', email: 'other@y.dev', committer: 'ME@x.dev', msg: 'committer match');
    await commit('c.txt', 'c\n', email: 'other@y.dev', msg: 'not mine');
    final obs = await sync(ctx(emails: ['mE@x.DEV']));
    expect(obs.map((o) => o.title).toSet(), {'author match', 'committer match'});
  });

  test('first sync imports 30 days; older commits skipped', () async {
    await commit('old.txt', 'o\n', at: now.subtract(const Duration(days: 45)), msg: 'old');
    await commit('new.txt', 'n\n', msg: 'new');
    expect((await sync(ctx())).map((o) => o.title), ['new']);
  });

  test('re-sync through the Ingestor is idempotent', () async {
    await commit('a.txt', 'a\n');
    await commit('b.txt', 'b\n');
    await git(['checkout', '-q', '-b', 'side']);
    await commit('c.txt', 'c\n');
    final db = ProfileDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.gitRepo, name: 'r'));
    final ing = Ingestor(db, utcOffset: (_) => Duration.zero);
    final c = ctx();
    expect((await ing.ingest('s1', await sync(c))).created, 3);
    c.commit();
    for (var i = 0; i < 2; i++) {
      final r = await ing.ingest('s1', await sync(c));
      c.commit();
      expect((r.created, r.updated, r.unchanged), (0, 0, 3));
    }
    expect(await db.select(db.payloadRevisions).get(), hasLength(3));
  });

  group('parseRemote', () {
    test('ssh, https and scp-like forms', () {
      expect(parseRemote('git@github.com:acme/api.git'), const GitRemote('github.com', 'acme', 'api'));
      expect(parseRemote('github.com:acme/api'), const GitRemote('github.com', 'acme', 'api'));
      expect(parseRemote('ssh://git@github.com:22/acme/api.git'), const GitRemote('github.com', 'acme', 'api'));
      expect(parseRemote('git+ssh://git@GitHub.com/acme/api'), const GitRemote('github.com', 'acme', 'api'));
      expect(parseRemote('https://github.com/acme/api.git'), const GitRemote('github.com', 'acme', 'api'));
      expect(parseRemote('https://user:tok@ghe.corp.com/acme/api/'), const GitRemote('ghe.corp.com', 'acme', 'api'));
      expect(
        parseRemote('  https://gitlab.com/group/sub/proj.git\n'),
        const GitRemote('gitlab.com', 'group/sub', 'proj'),
      );
      expect(
        parseRemote('git@gitlab.example.org:group/sub/proj.git'),
        const GitRemote('gitlab.example.org', 'group/sub', 'proj'),
      );
    });

    test('rejects Windows drive paths, one-letter hosts, local paths and incomplete urls', () {
      for (final u in [
        r'C:\repos\api',
        'C:/repos/api',
        'c:repos/api',
        'x:owner/repo',
        '/home/me/repos/api',
        '../api',
        'file:///home/me/api',
        'https://github.com/onlyowner',
        'git@github.com:api',
        'ftp://host/a/b',
        '',
      ]) {
        expect(parseRemote(u), isNull, reason: u);
      }
    });
  });
}
