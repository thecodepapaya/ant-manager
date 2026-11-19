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
/// On 403/429 the sync stops; the cursor stays at the last fully processed MR. An MR or project that is gone
/// (404/410) is skipped; any other error (401, 5xx) fails the sync. `updated_after` is exclusive, so the
/// query starts 1 s before the cursor to re-include an unprocessed MR sharing the last timestamp.
class GitLabSource implements Source {
  @override
  SourceKind get kind => SourceKind.gitlab;

  static const _cursorScope = '';
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
    final cursor = await ctx.cursor(_cursorScope);
    final since = cursor == null
        ? ctx.initialImportFrom.toUtc().toIso8601String()
        : DateTime.parse(cursor).subtract(const Duration(seconds: 1)).toUtc().toIso8601String();

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
    } on GitLabRateLimited {
      return; // keep the cursor at the last fully processed MR
    }
  }

  static String? _closedAt(Map mr) => (mr['merged_at'] ?? mr['closed_at']) as String?;

  static bool _isMe(Object? user, String me) => user is Map && (user['username'] as String?)?.toLowerCase() == me;

  /// `group/sub/project` from `references.full` (`group/sub/project!12`) or the web URL.
  static String _repoOf(Map mr) {
    final full = (mr['references'] as Map?)?['full'] as String?;
    if (full != null && full.contains('!')) return full.substring(0, full.lastIndexOf('!'));
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
