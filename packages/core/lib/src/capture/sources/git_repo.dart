import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/enums.dart';
import '../source.dart';

/// Patches larger than this are dropped; stats are kept (#89).
const maxPatchBytes = 200 * 1024;

/// A local git repository (LLD 04 §4.3). Config: `{path}`.
///
/// Sync runs `git log --all` from the cursor (last seen committer time minus one
/// day; overlap is free because content hashes make re-syncs no-ops) and keeps
/// commits whose author or committer email is one of your identities.
class GitRepoSource implements WatchableSource {
  static const _cursorScope = '';
  static const _sep = '\x00';
  static const _rec = '\x1e';
  // sha, author name/email, committer name/email, author/committer ISO dates, source ref, raw body.
  // NUL can't be passed in argv, so the format uses git's %x escapes.
  static const _format = '%x1e%H%x00%an%x00%ae%x00%cn%x00%ce%x00%aI%x00%cI%x00%S%x00%B%x00';

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
    final cursor = await ctx.cursor(_cursorScope);
    final since = cursor == null
        ? ctx.initialImportFrom
        : DateTime.parse(cursor).subtract(const Duration(days: 1));

    final out = await ctx.git.run(repo, [
      'log',
      '--all',
      '--source',
      '--since=${since.toUtc().toIso8601String()}',
      '--format=$_format',
      '--numstat',
      '--no-color',
    ]);

    DateTime? latest;
    for (final c in parseGitLog(out)) {
      if (latest == null || c.committedAt.isAfter(latest)) latest = c.committedAt;
      if (!mine.contains(c.authorEmail.toLowerCase()) && !mine.contains(c.committerEmail.toLowerCase())) {
        continue;
      }
      final patch = await ctx.git.run(repo, ['show', '--format=', '--no-color', c.sha]);
      yield c.toObservation(utf8.encode(patch).length <= maxPatchBytes ? patch : null);
    }
    if (latest != null) ctx.setCursor(_cursorScope, latest.toUtc().toIso8601String());
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
    required this.branch,
    required this.message,
    required this.files,
  });

  final String sha, authorName, authorEmail, committerName, committerEmail, branch, message;
  final DateTime authoredAt, committedAt;
  final List<({String path, int? added, int? deleted})> files; // null counts = binary

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
        'branch': branch,
        'stats': {
          'files': [for (final f in files) {'path': f.path, 'added': f.added, 'deleted': f.deleted}],
          'added': added,
          'deleted': deleted,
        },
        'patch': patch, // null when over maxPatchBytes (#89)
      },
    );
  }
}

/// Parses output produced with [GitRepoSource]'s `--format` plus `--numstat`.
List<GitCommit> parseGitLog(String out) {
  final commits = <GitCommit>[];
  for (final record in out.split(GitRepoSource._rec)) {
    if (record.trim().isEmpty) continue;
    final f = record.split(GitRepoSource._sep);
    if (f.length < 10) continue;
    final files = <({String path, int? added, int? deleted})>[];
    for (final line in const LineSplitter().convert(f[9])) {
      final cols = line.split('\t');
      if (cols.length < 3) continue;
      files.add((path: cols.sublist(2).join('\t'), added: int.tryParse(cols[0]), deleted: int.tryParse(cols[1])));
    }
    var branch = f[7];
    for (final prefix in const ['refs/heads/', 'refs/remotes/', 'refs/']) {
      if (branch.startsWith(prefix)) {
        branch = branch.substring(prefix.length);
        break;
      }
    }
    commits.add(GitCommit(
      sha: f[0].trim(),
      authorName: f[1],
      authorEmail: f[2],
      committerName: f[3],
      committerEmail: f[4],
      authoredAt: DateTime.parse(f[5]).toUtc(),
      committedAt: DateTime.parse(f[6]).toUtc(),
      branch: branch,
      message: f[8].trimRight(),
      files: files,
    ));
  }
  return commits;
}

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

final _scpLike = RegExp(r'^(?:[^@/\s]+@)?([^:/\s]+):(?!//)(.+)$');

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
