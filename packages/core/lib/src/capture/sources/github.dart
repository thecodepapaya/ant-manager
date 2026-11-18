import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../source.dart';

/// GitHub and GitHub Enterprise Server (LLD 04 §4.3).
/// Config: `{apiBaseUrl (default https://api.github.com; GHES https://host/api/v3), login}`.
/// Token from `ctx.secret()`.
///
/// Sync: search PRs that involve you or that you reviewed (`involves:` omits reviewers), updated since the
/// cursor (ascending), then each PR's details, commits, and your reviews + review comments (all pages).
/// Emits one `pullRequest` payload per PR you authored / were assigned / reviewed / commented on, and one
/// `review` payload per review you submitted. Your review comments outside any review are kept on the PR
/// payload (`comments`).
///
/// Commits are recorded by SHA in `content.commits` only; no `groupKey` is set. Grouping is exact identity
/// per payload (#57), so a PR never groups with its commits: the PR<->commit link is made downstream by facts
/// citing both (the SHAs in the content let the model connect them).
///
/// On 403/429 the sync stops; the cursor stays at the last fully processed PR. A PR that is gone (404/410,
/// e.g. deleted or transferred) is skipped; any other error (401, 5xx) fails the sync.
class GitHubSource implements Source {
  GitHubSource({this.kind = SourceKind.github});

  @override
  final SourceKind kind; // github or githubEnterprise

  static const _cursorScope = '';
  static const _perPage = 100;
  static const _maxSearchPages = 10; // the search API caps results at 1000

  String _base(SourceContext ctx) {
    final b = (ctx.config['apiBaseUrl'] as String?) ?? 'https://api.github.com';
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  String? _login(SourceContext ctx) {
    final l = ctx.config['login'] as String?;
    if (l != null && l.isNotEmpty) return l;
    final ids = ctx.identities('github_login');
    return ids.isEmpty ? null : ids.first;
  }

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    final token = await ctx.secret();
    if (token == null || token.isEmpty) return const SourceHealth.error('No GitHub token');
    try {
      final r = await _get(ctx, token, '${_base(ctx)}/user');
      final login = (r as Map)['login'] as String?;
      final want = _login(ctx);
      if (want != null && login != null && login.toLowerCase() != want.toLowerCase()) {
        return SourceHealth.error('Token belongs to $login, not $want');
      }
      return const SourceHealth.ok();
    } catch (e) {
      return SourceHealth.error('$e');
    }
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final token = await ctx.secret();
    final login = _login(ctx);
    if (token == null || login == null) throw StateError('GitHub source needs a token and a login');
    final me = login.toLowerCase();
    final base = _base(ctx);
    final cursor = await ctx.cursor(_cursorScope);
    final since = cursor ?? _iso(ctx.initialImportFrom);

    try {
      final byPr = <String, Map>{};
      for (final who in ['reviewed-by:$login', 'involves:$login']) {
        for (var page = 1; page <= _maxSearchPages; page++) {
          final r = await _get(ctx, token, '$base/search/issues', {
            'q': 'is:pr $who updated:>=$since',
            'sort': 'updated',
            'order': 'asc',
            'per_page': _perPage,
            'page': page,
          }) as Map;
          final batch = (r['items'] as List).cast<Map>();
          for (final item in batch) {
            byPr['${item['repository_url']}#${item['number']}'] = item;
          }
          if (batch.length < _perPage) break;
        }
      }
      final items = byPr.values.toList()
        ..sort((a, b) => (a['updated_at'] as String).compareTo(b['updated_at'] as String));

      for (final item in items) {
        final repo = _repoOf(item['repository_url'] as String);
        final number = item['number'] as int;
        final prBase = '$base/repos/$repo/pulls/$number';
        final Map pr;
        final List<Map> commits, reviews, comments;
        try {
          pr = await _get(ctx, token, prBase) as Map;
          commits = await _getAll(ctx, token, '$prBase/commits');
          reviews = (await _getAll(
            ctx,
            token,
            '$prBase/reviews',
          )).where((rv) => _isMe(rv['user'], me) && rv['submitted_at'] != null).toList();
          comments = (await _getAll(ctx, token, '$prBase/comments')).where((c) => _isMe(c['user'], me)).toList();
        } on GitHubGone {
          ctx.setCursor(_cursorScope, item['updated_at'] as String);
          continue;
        }
        final reviewIds = {for (final rv in reviews) rv['id']};

        final roles = <String>[
          if (_isMe(pr['user'], me)) 'author',
          if ((pr['assignees'] as List? ?? const []).any((a) => _isMe(a, me))) 'assignee',
          if (reviews.isNotEmpty) 'reviewer',
          if (comments.isNotEmpty) 'commenter',
        ];
        final prRef = {'repo': repo, 'number': number, 'title': pr['title'], 'url': pr['html_url']};

        if (roles.isNotEmpty) {
          yield PayloadObservation(
            externalId: 'pr:$repo#$number',
            kind: PayloadKind.pullRequest,
            occurredStart: DateTime.parse(pr['created_at'] as String),
            occurredEnd: pr['closed_at'] == null ? null : DateTime.parse(pr['closed_at'] as String),
            title: '${pr['title']} ($repo#$number)',
            content: {
              ...prRef,
              'body': pr['body'],
              'state': pr['state'],
              'draft': pr['draft'],
              'author': (pr['user'] as Map?)?['login'],
              'createdAt': pr['created_at'],
              'mergedAt': pr['merged_at'],
              'closedAt': pr['closed_at'],
              'baseBranch': (pr['base'] as Map?)?['ref'],
              'headBranch': (pr['head'] as Map?)?['ref'],
              'additions': pr['additions'],
              'deletions': pr['deletions'],
              'changedFiles': pr['changed_files'],
              'roles': roles,
              'commits': [for (final c in commits) c['sha']],
              // Your review comments not attached to one of your submitted reviews ("single comments").
              'comments': [
                for (final c in comments)
                  if (!reviewIds.contains(c['pull_request_review_id'])) _comment(c),
              ],
            },
          );
        }

        for (final rv in reviews) {
          final id = rv['id'];
          yield PayloadObservation(
            externalId: 'review:$repo#$number:$id',
            kind: PayloadKind.review,
            occurredStart: DateTime.parse(rv['submitted_at'] as String),
            title: 'Reviewed ${pr['title']} ($repo#$number)',
            content: {
              'pullRequest': prRef,
              'prAuthor': (pr['user'] as Map?)?['login'],
              'state': rv['state'],
              'body': rv['body'],
              'submittedAt': rv['submitted_at'],
              'url': rv['html_url'],
              'comments': [
                for (final c in comments)
                  if (c['pull_request_review_id'] == id) _comment(c),
              ],
            },
          );
        }
        ctx.setCursor(_cursorScope, item['updated_at'] as String);
      }
    } on GitHubRateLimited {
      return; // keep the cursor at the last fully processed PR; next poll resumes
    }
  }

  static Map<String, Object?> _comment(Map c) => {
    'path': c['path'],
    'line': c['line'] ?? c['original_line'],
    'body': c['body'],
    'createdAt': c['created_at'],
    'url': c['html_url'],
    'inReplyTo': c['in_reply_to_id'],
  };

  static bool _isMe(Object? user, String me) => user is Map && (user['login'] as String?)?.toLowerCase() == me;

  static String _repoOf(String repositoryUrl) {
    final segs = Uri.parse(repositoryUrl).pathSegments;
    final i = segs.indexOf('repos'); // first: a repo may itself be named `repos`
    return segs.sublist(i + 1).join('/');
  }

  static String _iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

  Future<Object?> _get(SourceContext ctx, String token, String url, [Map<String, Object?>? query]) async =>
      (await _request(ctx, token, url, query)).data;

  /// All pages of a list endpoint, following `Link: <...>; rel="next"`.
  Future<List<Map>> _getAll(SourceContext ctx, String token, String url) async {
    final out = <Map>[];
    String? next = url;
    Map<String, Object?>? query = {'per_page': _perPage};
    while (next != null) {
      final r = await _request(ctx, token, next, query);
      out.addAll((r.data as List).cast<Map>());
      next = _nextLink(r.headers.value('link'));
      query = null; // the next link carries the query
    }
    return out;
  }

  static final _next = RegExp(r'<([^>]+)>\s*;\s*rel="next"');

  static String? _nextLink(String? link) => link == null ? null : _next.firstMatch(link)?.group(1);

  Future<Response<Object?>> _request(SourceContext ctx, String token, String url, Map<String, Object?>? query) async {
    final r = await ctx.http.get<Object?>(
      url,
      queryParameters: query,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );
    final s = r.statusCode ?? 0;
    if (s == 429 ||
        (s == 403 && r.headers.value('x-ratelimit-remaining') == '0') ||
        (s == 403 && '${r.data}'.toLowerCase().contains('rate limit'))) {
      throw GitHubRateLimited();
    }
    if (s == 404 || s == 410) throw GitHubGone(url, s);
    if (s < 200 || s >= 300) throw StateError('GitHub $url → HTTP $s: ${r.data}');
    return r;
  }
}

/// 404/410: the item no longer exists (or is no longer visible). Skipped per PR; fatal elsewhere.
class GitHubGone implements Exception {
  GitHubGone(this.url, this.status);
  final String url;
  final int status;
  @override
  String toString() => 'GitHub $url → HTTP $status';
}

class GitHubRateLimited implements Exception {
  @override
  String toString() => 'GitHub rate limit reached';
}
