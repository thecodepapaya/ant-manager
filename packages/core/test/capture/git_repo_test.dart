import 'dart:io';

import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/capture/sources/git_detect.dart';
import 'package:core/src/capture/sources/git_repo.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_context.dart';

void main() {
  late Directory tmp;
  late String repo;
  final now = DateTime.now().toUtc();

  Future<void> git(List<String> args, {String? email, DateTime? at}) async {
    final date = (at ?? now.subtract(const Duration(days: 2))).toIso8601String();
    final r = await Process.run('git', ['-C', repo, ...args], environment: {
      'GIT_AUTHOR_NAME': 'A',
      'GIT_AUTHOR_EMAIL': email ?? 'me@x.dev',
      'GIT_COMMITTER_NAME': 'A',
      'GIT_COMMITTER_EMAIL': email ?? 'me@x.dev',
      'GIT_AUTHOR_DATE': date,
      'GIT_COMMITTER_DATE': date,
    });
    if (r.exitCode != 0) fail('git $args: ${r.stderr}');
  }

  Future<void> commitFile(String name, String text, {String? email, DateTime? at, String? msg}) async {
    File(p.join(repo, name)).writeAsStringSync(text);
    await git(['add', name]);
    await git(['commit', '-q', '-m', msg ?? 'add $name'], email: email, at: at);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ant_git_');
    repo = tmp.path;
    await git(['init', '-q', '-b', 'main']);
    await git(['config', 'commit.gpgsign', 'false']);
  });
  tearDown(() => tmp.delete(recursive: true));

  FakeContext ctx() => FakeContext(
        config: {'path': repo},
        ids: {
          'email': ['ME@x.dev'],
        },
        git: ProcessGitExecutable(),
        now: now,
      );

  Future<List<PayloadObservation>> sync(FakeContext c) => GitRepoSource().sync(c).toList();

  test('captures my commits with stats, patch and branch; skips others', () async {
    await commitFile('old.txt', 'old\n', at: now.subtract(const Duration(days: 60)));
    await commitFile('a.txt', 'one\ntwo\n', msg: 'feat: first\n\nbody line');
    await commitFile('b.txt', 'other\n', email: 'someone@else.dev');
    await git(['checkout', '-q', '-b', 'feature']);
    await commitFile('c.txt', 'c\n');

    final c = ctx();
    final obs = await sync(c);
    expect(obs, hasLength(2));
    final first = obs.firstWhere((o) => o.title == 'feat: first');
    expect(first.kind, PayloadKind.commit);
    expect(first.groupKey, first.externalId);
    expect(first.content['message'], 'feat: first\n\nbody line');
    expect(first.content['stats'], {
      'files': [
        {'path': 'a.txt', 'added': 2, 'deleted': 0},
      ],
      'added': 2,
      'deleted': 0,
    });
    expect(first.content['patch'], contains('+one'));
    expect(obs.firstWhere((o) => o.title == 'add c.txt').content['branch'], 'feature');
    expect(c.staged[''], isNotNull);
  });

  test('re-sync through the Ingestor is idempotent', () async {
    await commitFile('a.txt', 'one\n');
    await commitFile('b.txt', 'two\n');
    final db = ProfileDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.gitRepo, name: 'r'));
    final ingestor = Ingestor(db, utcOffset: (_) => Duration.zero);
    final c = ctx();

    final r1 = await ingestor.ingest('s1', await sync(c));
    c.commit();
    expect(r1.created, 2);
    final cursor = c.cursors['']!;

    final r2 = await ingestor.ingest('s1', await sync(c));
    c.commit();
    expect(r2.created, 0);
    expect(r2.unchanged, 2);
    expect(c.cursors[''], cursor);
    expect((await db.select(db.payloads).get()), hasLength(2));
    expect((await db.select(db.payloadRevisions).get()), hasLength(2));

    await commitFile('c.txt', 'three\n', at: now.subtract(const Duration(days: 1)));
    final r3 = await ingestor.ingest('s1', await sync(c));
    expect(r3.created, 1);
  });

  test('patches over 200 KB keep stats only', () async {
    await commitFile('big.txt', List.filled(5000, 'x' * 60).join('\n'));
    final obs = await sync(ctx());
    expect(obs.single.content['patch'], isNull);
    expect((obs.single.content['stats'] as Map)['added'], 5000);
  });

  test('validate and changes', () async {
    final c = ctx();
    expect((await GitRepoSource().validate(c)).ok, isTrue);
    await GitRepoSource().changes(c).drain<void>();
    expect(c.watcher.watched.single, [p.join(repo, '.git', 'refs'), p.join(repo, '.git', 'logs', 'HEAD')]);
    final bad = FakeContext(config: {'path': tmp.parent.path}, git: ProcessGitExecutable());
    expect((await GitRepoSource().validate(bad)).ok, isFalse);
  });

  test('scanForRepos finds repos within depth and skips hidden dirs', () async {
    final root = await Directory.systemTemp.createTemp('ant_scan_');
    addTearDown(() => root.delete(recursive: true));
    for (final d in ['a/.git', 'b/c/.git', 'b/c/nested/.git', '.hidden/x/.git', 'd/e/f/g/h/.git']) {
      Directory(p.join(root.path, d)).createSync(recursive: true);
    }
    final found = await scanForRepos([root.path]);
    final rel = found.map((f) => p.relative(f, from: root.absolute.path)).toList();
    expect(rel, ['a', p.join('b', 'c')]);
  });

  group('parseRemote', () {
    final cases = {
      'git@github.com:acme/api.git': const GitRemote('github.com', 'acme', 'api'),
      'git@github.com:acme/api': const GitRemote('github.com', 'acme', 'api'),
      'https://github.com/acme/api.git': const GitRemote('github.com', 'acme', 'api'),
      'https://user:tok@GHE.corp.com/acme/api': const GitRemote('ghe.corp.com', 'acme', 'api'),
      'ssh://git@gitlab.corp.com:2222/group/sub/proj.git': const GitRemote('gitlab.corp.com', 'group/sub', 'proj'),
      'https://gitlab.com/group/sub/proj': const GitRemote('gitlab.com', 'group/sub', 'proj'),
      'github.com:acme/api.git': const GitRemote('github.com', 'acme', 'api'),
    };
    cases.forEach((url, want) => test(url, () => expect(parseRemote(url), want)));
    for (final bad in ['', '/local/path/repo', 'file:///x/y', 'https://github.com/onlyowner', 'not a url']) {
      test('rejects "$bad"', () => expect(parseRemote(bad), isNull));
    }
  });

  group('GitDetector', () {
    GitDetector mac({required Set<String> files, Set<String> dirs = const {}, String? xcode}) => GitDetector(
          os: 'macos',
          env: {'PATH': '/usr/bin:/bin'},
          fileExists: files.contains,
          dirExists: dirs.contains,
          xcodeSelectPath: () => xcode,
        );

    test('skips the /usr/bin/git stub when no CLT or Xcode', () {
      expect(mac(files: {'/usr/bin/git'}).detect(), isNull);
      expect(mac(files: {'/usr/bin/git', '/opt/homebrew/bin/git'}).detect(), '/opt/homebrew/bin/git');
    });

    test('accepts /usr/bin/git with CLT or Xcode', () {
      expect(mac(files: {'/usr/bin/git'}, dirs: {GitDetector.macCltDir}).detect(), '/usr/bin/git');
      const xcode = '/Applications/Xcode.app/Contents/Developer';
      expect(mac(files: {'/usr/bin/git'}, dirs: {xcode}, xcode: xcode).detect(), '/usr/bin/git');
    });

    test('windows candidates include Git for Windows defaults', () {
      final d = GitDetector(
        os: 'windows',
        env: {'Path': r'C:\Windows', 'LOCALAPPDATA': r'C:\Users\me\AppData\Local'},
        fileExists: (_) => false,
        dirExists: (_) => false,
        xcodeSelectPath: () => null,
      );
      expect(d.candidates(), containsAll([r'C:\Windows\git.exe', r'C:\Program Files\Git\cmd\git.exe',
        r'C:\Users\me\AppData\Local\Programs\Git\cmd\git.exe']));
    });
  });
}
