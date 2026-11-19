// scanForRepos (capture/sources/git_repo.dart) over folders it can't read (#113): it skips them
// and still returns the repos it can see.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:core/core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  final locked = <Directory>[];

  setUp(() => root = Directory.systemTemp.createTempSync('scan_unreadable_'));
  tearDown(() {
    for (final d in locked) {
      Process.runSync('chmod', ['755', d.path]);
    }
    locked.clear();
    root.deleteSync(recursive: true);
  });

  Directory repo(String rel) {
    final d = Directory(p.join(root.path, rel))..createSync(recursive: true);
    Directory(p.join(d.path, '.git')).createSync();
    return d;
  }

  Directory lock(String rel) {
    final d = Directory(p.join(root.path, rel))..createSync(recursive: true);
    expect(Process.runSync('chmod', ['000', d.path]).exitCode, 0);
    locked.add(d);
    return d;
  }

  bool canList(Directory d) {
    try {
      d.listSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  test('an unreadable subfolder is skipped; repos beside it are still found', () async {
    final a = repo('code/a');
    final b = repo('code/nested/b');
    final l = lock('code/locked');
    if (canList(l)) return markTestSkipped('running with permissions that can read a chmod 000 folder (root?)');
    final found = await scanForRepos([root.path]);
    expect(found, [p.normalize(a.absolute.path), p.normalize(b.absolute.path)]..sort());
  });

  test('an unreadable root yields nothing and does not throw; other roots still scan', () async {
    final a = repo('ok/a');
    final l = lock('nope');
    if (canList(l)) return markTestSkipped('running with permissions that can read a chmod 000 folder (root?)');
    expect(await scanForRepos([l.path]), isEmpty);
    expect(await scanForRepos([l.path, p.join(root.path, 'ok')]), [p.normalize(a.absolute.path)]);
  });

  test('a root that does not exist is ignored', () async {
    final a = repo('a');
    expect(await scanForRepos([p.join(root.path, 'missing'), root.path]), [p.normalize(a.absolute.path)]);
  });
}
