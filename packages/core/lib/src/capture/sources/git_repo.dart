import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/enums.dart';
import '../source.dart';

/// Patches larger than this are dropped; stats are kept (#89).
const maxPatchBytes = 200 * 1024;

/// A local git repository (LLD 04 §4.3). Config: `{path}`.
///
/// Sync runs `git log --all` (minus stash and notes refs) from the cursor (last seen committer time minus
/// one day; overlap is free because content hashes make re-syncs no-ops) and keeps commits whose author or
/// committer email is one of your identities. Branch names are not stored: which ref reaches a commit
/// changes without the commit changing, and would create spurious revisions.
class GitRepoSource implements WatchableSource {
  static const _cursorScope = '';
  // Each record: NUL, then sha, author name/email, committer name/email, author/committer ISO dates and raw
  // body, each NUL-terminated, then the numstat lines. No field can contain NUL, so splitting on NUL gives
  // exactly 1 + 9 × records tokens whatever the message contains. NUL can't be passed in argv, hence `%x00`.
  // The repo's own config / .gitattributes must not make our reads run its commands (textconv, external diff, #118).
  static const _noRepoCommands = ['--no-textconv', '--no-ext-diff'];
  static const _format = '%x00%H%x00%an%x00%ae%x00%cn%x00%ce%x00%aI%x00%cI%x00%B%x00';

  /// Records of the last [sync] that could not be parsed (and were skipped).
  int skippedRecords = 0;

  @override
  SourceKind get kind => SourceKind.gitRepo;

  String _path(SourceContext ctx) {
    final path = ctx.config['path'];
    if (path is! String || path.isEmpty) throw StateError('git repo source has no path');
    return path;
  }

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    if (await ctx.git.locate() == null) return const SourceHealth.error('git is not installed');
    if (ctx.identities('email').isEmpty) {
      return const SourceHealth.error('Add your git email in Settings → Identities to capture commits');
    }
    try {
      await ctx.git.run(_path(ctx), ['rev-parse', '--git-dir']);
      return const SourceHealth.ok();
    } catch (e) {
      return SourceHealth.error('Not a git repository: $e');
    }
  }

  @override
  Stream<void> changes(SourceContext ctx) {
    final repo = _path(ctx);
    return ctx.watcher.watch([p.join(repo, '.git', 'refs'), p.join(repo, '.git', 'logs', 'HEAD')]);
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final repo = _path(ctx);
    final mine = ctx.identities('email').map((e) => e.toLowerCase()).toSet();
    // Fail rather than advance the cursor past commits nobody could be matched to.
    if (mine.isEmpty) throw StateError('No email identities: add your git email to capture commits');
    final cursor = await ctx.cursor(_cursorScope);
    final since = cursor == null ? ctx.initialImportFrom : DateTime.parse(cursor).subtract(const Duration(days: 1));

    final out = await ctx.git.run(repo, [
      'log',
      '--exclude=refs/stash',
      '--exclude=refs/notes/*',
      '--all',
      '--diff-merges=first-parent', // a merge's stats/patch = what it brought into the branch
      '--since=${since.toUtc().toIso8601String()}',
      '--format=$_format',
      '--numstat',
      '--no-color',
      ..._noRepoCommands,
    ]);

    DateTime? latest;
    final log = parseGitLog(out);
    skippedRecords = log.skipped;
    for (final c in log.commits) {
      if (latest == null || c.committedAt.isAfter(latest)) latest = c.committedAt;
      if (!mine.contains(c.authorEmail.toLowerCase()) && !mine.contains(c.committerEmail.toLowerCase())) {
        continue;
      }
      // Each changed line is at least 2 patch bytes ("+\n"), so skip `git show` when numstat already proves
      // the patch is over the cap (#128); a few very long lines can still load before the byte check.
      if (c.changedLines * 2 > maxPatchBytes) {
        yield c.toObservation(null);
        continue;
      }
      final patch = await ctx.git.run(repo, ['show', '--format=', '--no-color', ..._noRepoCommands, '--diff-merges=first-parent', c.sha]);
      yield c.toObservation(utf8.encode(patch).length <= maxPatchBytes ? patch : null);
    }
    if (latest != null) {
      // Someone's clock in the future must not push the cursor past commits made before it.
      final now = ctx.clock.now().toUtc();
      ctx.setCursor(_cursorScope, (latest.isAfter(now) ? now : latest).toUtc().toIso8601String());
    }
  }
}

/// One commit parsed from `git log` output.
class GitCommit {
  GitCommit({
    required this.sha,
    required this.authorName,
    required this.authorEmail,
    required this.committerName,
    required this.committerEmail,
    required this.authoredAt,
    required this.committedAt,
    required this.message,
    required this.files,
  });

  final String sha, authorName, authorEmail, committerName, committerEmail, message;
  final DateTime authoredAt, committedAt;
  final List<({String path, int? added, int? deleted})> files; // null counts = binary

  /// Added + deleted lines (binary files count 0).
  int get changedLines => files.fold(0, (n, f) => n + (f.added ?? 0) + (f.deleted ?? 0));

  PayloadObservation toObservation(String? patch) {
    var added = 0, deleted = 0;
    for (final f in files) {
      added += f.added ?? 0;
      deleted += f.deleted ?? 0;
    }
    return PayloadObservation(
      externalId: sha,
      kind: PayloadKind.commit,
      groupKey: sha,
      occurredStart: authoredAt,
      title: message.split('\n').first,
      content: {
        'sha': sha,
        'message': message,
        'author': {'name': authorName, 'email': authorEmail},
        'committer': {'name': committerName, 'email': committerEmail},
        'authoredAt': authoredAt.toUtc().toIso8601String(),
        'committedAt': committedAt.toUtc().toIso8601String(),
        'stats': {
          'files': [
            for (final f in files) {'path': f.path, 'added': f.added, 'deleted': f.deleted},
          ],
          'added': added,
          'deleted': deleted,
        },
        'patch': patch, // null when over maxPatchBytes (#89)
      },
    );
  }
}

/// Parses output produced with [GitRepoSource]'s `--format` plus `--numstat`. Records whose sha or dates
/// don't parse are counted in `skipped`.
({List<GitCommit> commits, int skipped}) parseGitLog(String out) {
  final commits = <GitCommit>[];
  var skipped = 0;
  final t = out.split('\x00');
  // t[0] is whatever precedes the first record (empty); then 9 tokens per record.
  if ((t.length - 1) % 9 != 0) skipped++; // trailing partial record
  for (var i = 1; i + 9 <= t.length; i += 9) {
    final sha = t[i].trim();
    final authoredAt = DateTime.tryParse(t[i + 5]);
    final committedAt = DateTime.tryParse(t[i + 6]);
    if (!_sha.hasMatch(sha) || authoredAt == null || committedAt == null) {
      skipped++;
      continue;
    }
    final files = <({String path, int? added, int? deleted})>[];
    for (final line in const LineSplitter().convert(t[i + 8])) {
      final cols = line.split('\t');
      if (cols.length < 3) continue;
      files.add((path: cols.sublist(2).join('\t'), added: int.tryParse(cols[0]), deleted: int.tryParse(cols[1])));
    }
    commits.add(
      GitCommit(
        sha: sha,
        authorName: t[i + 1],
        authorEmail: t[i + 2],
        committerName: t[i + 3],
        committerEmail: t[i + 4],
        authoredAt: authoredAt.toUtc(),
        committedAt: committedAt.toUtc(),
        message: t[i + 7].trimRight(),
        files: files,
      ),
    );
  }
  return (commits: commits, skipped: skipped);
}

final _sha = RegExp(r'^[0-9a-f]{40}([0-9a-f]{24})?$');

/// Finds git repositories under [roots] (a directory containing `.git`), at most
/// [maxDepth] levels down. Hidden directories are skipped; repos aren't descended into.
Future<List<String>> scanForRepos(List<String> roots, {int maxDepth = 4}) async {
  final found = <String>{};
  Future<void> walk(Directory dir, int depth) async {
    if (await FileSystemEntity.type(p.join(dir.path, '.git')) != FileSystemEntityType.notFound) {
      found.add(p.normalize(dir.absolute.path));
      return;
    }
    if (depth >= maxDepth) return;
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is Directory && !p.basename(e.path).startsWith('.')) await walk(e, depth + 1);
      }
    } on FileSystemException {
      // unreadable directory: skip
    }
  }

  for (final r in roots) {
    final d = Directory(r);
    if (await d.exists()) await walk(d, 0);
  }
  return found.toList()..sort();
}

/// A parsed remote URL. [owner] may contain slashes (GitLab subgroups).
class GitRemote {
  const GitRemote(this.host, this.owner, this.repo);
  final String host, owner, repo;

  @override
  bool operator ==(Object other) =>
      other is GitRemote && other.host == host && other.owner == owner && other.repo == repo;
  @override
  int get hashCode => Object.hash(host, owner, repo);
  @override
  String toString() => '$host/$owner/$repo';
}

final _scpLike = RegExp(r'^(?:[^@/\s]+@)?([^:/\s]{2,}):(?!//)(.+)$'); // 1-letter host = drive letter
final _windowsPath = RegExp(r'^[A-Za-z]:[\\/]');

/// Parses ssh (`git@host:owner/repo.git`, `ssh://git@host:22/owner/repo`) and
/// http(s) remotes into (host, owner, repo). Returns null for anything else.
GitRemote? parseRemote(String url) {
  url = url.trim();
  String host;
  String path;
  if (url.contains('://')) {
    final u = Uri.tryParse(url);
    if (u == null || !const {'ssh', 'git+ssh', 'http', 'https', 'git'}.contains(u.scheme) || u.host.isEmpty) {
      return null;
    }
    host = u.host.toLowerCase();
    path = u.path;
  } else {
    if (_windowsPath.hasMatch(url)) return null; // local path such as C:/repos/api
    final m = _scpLike.firstMatch(url);
    if (m == null) return null;
    host = m.group(1)!.toLowerCase();
    path = m.group(2)!;
  }
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.length < 2) return null;
  var repo = segs.last;
  if (repo.endsWith('.git')) repo = repo.substring(0, repo.length - 4);
  if (repo.isEmpty) return null;
  return GitRemote(host, segs.sublist(0, segs.length - 1).join('/'), repo);
}
