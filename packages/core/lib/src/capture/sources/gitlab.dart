import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../source.dart';

/// GitLab.com and self-managed GitLab (LLD 04 §4.3).
/// Config: `{baseUrl (default https://gitlab.com), username}`. Token (PAT) from `ctx.secret()`.
///
/// Sync: merge requests where you're author, reviewer or assignee, updated after the
/// cursor (ascending), then each MR's commits and notes. Emits one `pullRequest`
/// payload per MR and one `review` payload per note you wrote (comments, plus the
/// "approved this merge request" system note, which carries the approval time).
/// Commits are recorded by SHA in `content.commits` only; no `groupKey` is set. Grouping is exact identity
/// per payload (#57): the MR<->commit link is made downstream by facts citing both.
///
/// Issues (separate cursor scope `issue`): candidates are `GET /issues?scope=created_by_me` updated
/// after that cursor, plus your own `GET /events` since the cursor's day: `target_type=issue&action=closed`
/// and `action=commented` on an `Issue` noteable (each issue then fetched). Issues updated before the cursor
/// are dropped; the rest, ascending by update, get your non-system notes. Emits one `issue` payload per
/// issue you opened, closed (`closed_by`) or commented on.
///
/// On 403/429 the sync stops; each cursor stays at the last fully processed item. An MR, issue or project
/// that is gone (404/410) is skipped; any other error (401, 5xx) fails the sync. `updated_after` is exclusive,
/// so the query starts 1 s before the cursor to re-include an unprocessed item sharing the last timestamp.
class GitLabSource implements Source {
  @override
  SourceKind get kind => SourceKind.gitlab;

  static const _cursorScope = '';
  static const _issueScope = 'issue';
  static const _perPage = 100;
  static const _maxPages = 10;
  static const _approved = 'approved this merge request';

  String _api(SourceContext ctx) {
    var b = (ctx.config['baseUrl'] as String?) ?? 'https://gitlab.com';
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return '$b/api/v4';
  }

  String? _username(SourceContext ctx) {
    final u = ctx.config['username'] as String?;
    if (u != null && u.isNotEmpty) return u;
    final ids = ctx.identities('gitlab_user');
    return ids.isEmpty ? null : ids.first;
  }

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    final token = await ctx.secret();
    if (token == null || token.isEmpty) return const SourceHealth.error('No GitLab token');
    try {
      final r = await _get(ctx, token, '${_api(ctx)}/user') as Map;
      final want = _username(ctx);
      final got = r['username'] as String?;
      if (want != null && got != null && got.toLowerCase() != want.toLowerCase()) {
        return SourceHealth.error('Token belongs to $got, not $want');
      }
      return const SourceHealth.ok();
    } catch (e) {
      return SourceHealth.error('$e');
    }
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final token = await ctx.secret();
    final user = _username(ctx);
    if (token == null || user == null) throw StateError('GitLab source needs a token and a username');
    final me = user.toLowerCase();
    final api = _api(ctx);
    final since = _since(ctx, await ctx.cursor(_cursorScope));

    try {
      final byId = <Object, Map>{};
      for (final role in const ['author_username', 'reviewer_username', 'assignee_username']) {
        for (var page = 1; page <= _maxPages; page++) {
          final batch = (await _get(ctx, token, '$api/merge_requests', {
            'scope': 'all',
            role: user,
            'updated_after': since,
            'order_by': 'updated_at',
            'sort': 'asc',
            'per_page': _perPage,
            'page': page,
          }) as List).cast<Map>();
          for (final mr in batch) {
            byId[mr['id'] as Object] = mr;
          }
          if (batch.length < _perPage) break;
        }
      }
      final mrs = byId.values.toList()
        ..sort((a, b) => (a['updated_at'] as String).compareTo(b['updated_at'] as String));

      for (final mr in mrs) {
        final project = mr['project_id'];
        final iid = mr['iid'];
        final repo = _repoOf(mr);
        final mrBase = '$api/projects/$project/merge_requests/$iid';
        final List<Map> commits, notes;
        try {
          commits = await _getAll(ctx, token, '$mrBase/commits');
          notes = (await _getAll(ctx, token, '$mrBase/notes', {'sort': 'asc'}))
              .where((n) => _isMe(n['author'], me))
              .where((n) => n['system'] != true || (n['body'] as String?) == _approved)
              .toList();
        } on GitLabGone {
          ctx.setCursor(_cursorScope, mr['updated_at'] as String);
          continue;
        }

        final roles = <String>[
          if (_isMe(mr['author'], me)) 'author',
          if ((mr['assignees'] as List? ?? const []).any((a) => _isMe(a, me))) 'assignee',
          if ((mr['reviewers'] as List? ?? const []).any((a) => _isMe(a, me))) 'reviewer',
          if (notes.any((n) => n['system'] == true)) 'approver',
          if (notes.any((n) => n['system'] != true)) 'commenter',
        ];
        final mrRef = {'repo': repo, 'number': iid, 'title': mr['title'], 'url': mr['web_url']};

        yield PayloadObservation(
          externalId: 'mr:$project!$iid',
          kind: PayloadKind.pullRequest,
          occurredStart: DateTime.parse(mr['created_at'] as String),
          occurredEnd: _closedAt(mr) == null ? null : DateTime.parse(_closedAt(mr)!),
          title: '${mr['title']} ($repo!$iid)',
          content: {
            ...mrRef,
            'body': mr['description'],
            'state': mr['state'],
            'draft': mr['draft'] ?? mr['work_in_progress'],
            'author': (mr['author'] as Map?)?['username'],
            'createdAt': mr['created_at'],
            'mergedAt': mr['merged_at'],
            'closedAt': mr['closed_at'],
            'baseBranch': mr['target_branch'],
            'headBranch': mr['source_branch'],
            'roles': roles,
            'commits': [for (final c in commits) c['id']],
          },
        );

        for (final n in notes) {
          final approval = n['system'] == true;
          final pos = n['position'] as Map?;
          yield PayloadObservation(
            externalId: 'note:$project!$iid:${n['id']}',
            kind: PayloadKind.review,
            occurredStart: DateTime.parse(n['created_at'] as String),
            title: '${approval ? 'Approved' : 'Commented on'} ${mr['title']} ($repo!$iid)',
            content: {
              'pullRequest': mrRef,
              'prAuthor': (mr['author'] as Map?)?['username'],
              'state': approval ? 'APPROVED' : 'COMMENTED',
              'body': approval ? null : n['body'],
              'createdAt': n['created_at'],
              'path': pos?['new_path'] ?? pos?['old_path'],
              'line': pos?['new_line'] ?? pos?['old_line'],
            },
          );
        }
        ctx.setCursor(_cursorScope, mr['updated_at'] as String);
      }
      // `await for`, not `yield*`: yield* would forward GitLabRateLimited past the catch below.
      await for (final o in _issues(ctx, token, api, user, me)) {
        yield o;
      }
    } on GitLabRateLimited {
      return; // keep the cursor at the last fully processed MR
    }
  }

  /// `updated_after` is exclusive: start 1 s before the cursor.
  static String _since(SourceContext ctx, String? cursor) => cursor == null
      ? ctx.initialImportFrom.toUtc().toIso8601String()
      : DateTime.parse(cursor).subtract(const Duration(seconds: 1)).toUtc().toIso8601String();

  /// Issues you opened, closed or commented on, updated since the `issue` cursor.
  Stream<PayloadObservation> _issues(SourceContext ctx, String token, String api, String user, String me) async* {
    final since = _since(ctx, await ctx.cursor(_issueScope));
    final sinceAt = DateTime.parse(since);
    // Events take a date and `after` is exclusive: the day before the cursor's day.
    final after = sinceAt.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final byKey = <String, Map>{};
    for (final i in await _getAll(ctx, token, '$api/issues', {
      // Not `scope=all`: GitLab.com can reject instance-wide issue listing with 400.
      'scope': 'created_by_me',
      'updated_after': since,
      'order_by': 'updated_at',
      'sort': 'asc',
    })) {
      byKey['${i['project_id']}#${i['iid']}'] = i;
    }
    final closed = await _getAll(ctx, token, '$api/events', {
      'target_type': 'issue',
      'action': 'closed',
      'after': after,
    });
    final commented = await _getAll(ctx, token, '$api/events', {'action': 'commented', 'after': after});
    final refs = <(Object?, Object?)>{
      for (final e in closed) (e['project_id'], e['target_iid']),
      for (final e in commented)
        if ((e['note'] as Map?)?['noteable_type'] == 'Issue') (e['project_id'], (e['note'] as Map)['noteable_iid']),
    };
    for (final (project, iid) in refs) {
      if (project == null || iid == null || byKey.containsKey('$project#$iid')) continue;
      try {
        byKey['$project#$iid'] = await _get(ctx, token, '$api/projects/$project/issues/$iid') as Map;
      } on GitLabGone {
        continue;
      }
    }
    final issues = byKey.values.where((i) => !DateTime.parse(i['updated_at'] as String).isBefore(sinceAt)).toList()
      ..sort((a, b) => DateTime.parse(a['updated_at'] as String).compareTo(DateTime.parse(b['updated_at'] as String)));

    for (final issue in issues) {
      final project = issue['project_id'];
      final iid = issue['iid'];
      final List<Map> notes;
      try {
        notes = (await _getAll(ctx, token, '$api/projects/$project/issues/$iid/notes', {
          'sort': 'asc',
        })).where((n) => _isMe(n['author'], me) && n['system'] != true).toList();
      } on GitLabGone {
        ctx.setCursor(_issueScope, issue['updated_at'] as String);
        continue;
      }
      final roles = <String>[
        if (_isMe(issue['author'], me)) 'author',
        if (_isMe(issue['closed_by'], me)) 'closer',
        if (notes.isNotEmpty) 'commenter',
      ];
      if (roles.isNotEmpty) {
        final repo = _repoOf(issue, '#');
        yield PayloadObservation(
          externalId: 'issue:$project#$iid',
          kind: PayloadKind.issue,
          occurredStart: DateTime.parse(issue['created_at'] as String),
          occurredEnd: issue['closed_at'] == null ? null : DateTime.parse(issue['closed_at'] as String),
          title: '${issue['title']} ($repo#$iid)',
          content: {
            'repo': repo,
            'number': iid,
            'title': issue['title'],
            'url': issue['web_url'],
            'body': issue['description'],
            'state': issue['state'],
            'author': (issue['author'] as Map?)?['username'],
            'labels': issue['labels'],
            'createdAt': issue['created_at'],
            'closedAt': issue['closed_at'],
            'closedBy': (issue['closed_by'] as Map?)?['username'],
            'roles': roles,
            'comments': [
              for (final n in notes) {'body': n['body'], 'createdAt': n['created_at']},
            ],
          },
        );
      }
      ctx.setCursor(_issueScope, issue['updated_at'] as String);
    }
  }

  static String? _closedAt(Map mr) => (mr['merged_at'] ?? mr['closed_at']) as String?;

  static bool _isMe(Object? user, String me) => user is Map && (user['username'] as String?)?.toLowerCase() == me;

  /// `group/sub/project` from `references.full` (`group/sub/project!12`, issues `…#12`) or the web URL.
  static String _repoOf(Map mr, [String sep = '!']) {
    final full = (mr['references'] as Map?)?['full'] as String?;
    if (full != null && full.contains(sep)) return full.substring(0, full.lastIndexOf(sep));
    final path = Uri.parse(mr['web_url'] as String).path;
    final i = path.indexOf('/-/');
    return (i < 0 ? path : path.substring(0, i)).replaceFirst(RegExp('^/'), '');
  }

  /// All pages of a list endpoint (until a short page).
  Future<List<Map>> _getAll(
    SourceContext ctx,
    String token,
    String url, [
    Map<String, Object?> query = const {},
  ]) async {
    final out = <Map>[];
    for (var page = 1; ; page++) {
      final batch = (await _get(ctx, token, url, {...query, 'per_page': _perPage, 'page': page}) as List).cast<Map>();
      out.addAll(batch);
      if (batch.length < _perPage) return out;
    }
  }

  Future<Object?> _get(SourceContext ctx, String token, String url, [Map<String, Object?>? query]) async {
    final r = await ctx.http.get<Object?>(
      url,
      queryParameters: query,
      options: Options(headers: {'PRIVATE-TOKEN': token}, responseType: ResponseType.json, validateStatus: (_) => true),
    );
    final s = r.statusCode ?? 0;
    if (s == 429 || (s == 403 && '${r.data}'.toLowerCase().contains('rate limit'))) throw GitLabRateLimited();
    if (s == 404 || s == 410) throw GitLabGone(url, s);
    if (s < 200 || s >= 300) throw StateError('GitLab $url → HTTP $s: ${r.data}');
    return r.data;
  }
}

/// 404/410: the MR or project no longer exists (or is no longer visible). Skipped per MR; fatal elsewhere.
class GitLabGone implements Exception {
  GitLabGone(this.url, this.status);
  final String url;
  final int status;
  @override
  String toString() => 'GitLab $url → HTTP $status';
}

class GitLabRateLimited implements Exception {
  @override
  String toString() => 'GitLab rate limit reached';
}
