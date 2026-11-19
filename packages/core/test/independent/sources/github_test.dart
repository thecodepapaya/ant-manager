import 'package:core/core.dart';
import 'package:core/src/capture/sources/github.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A tiny GitHub fake: search results per query role, and per-PR detail/commits/reviews/comments.
class Gh {
  Gh(this.api);
  final Api api;
  final reviewedBy = <Map<String, Object?>>[];
  final involves = <Map<String, Object?>>[];
  final pulls = <String, Map<String, Object?>>{}; // 'o/r#1' → pr
  final commits = <String, List<List<Map>>>{}; // pages
  final reviews = <String, List<List<Map>>>{};
  final comments = <String, List<List<Map>>>{};
  final fail = <String, Res>{}; // path → forced response

  void install() {
    api.handler = (h) {
      final path = h.uri.path;
      if (fail[path] != null) return fail[path];
      if (path == '/user') return const Res({'login': 'Me'});
      if (path == '/search/issues') {
        final q = h.uri.queryParameters['q']!;
        return Res({'items': q.contains('reviewed-by:') ? reviewedBy : involves});
      }
      final m = RegExp(r'^/repos/(.+)/pulls/(\d+)(?:/(commits|reviews|comments))?$').firstMatch(path);
      if (m == null) return null;
      final key = '${m[1]}#${m[2]}';
      if (m[3] == null) return pulls[key] == null ? null : Res(pulls[key]);
      final pages =
          switch (m[3]) {
            'commits' => commits[key],
            'reviews' => reviews[key],
            _ => comments[key],
          } ??
          [[]];
      final page = int.tryParse(h.uri.queryParameters['page'] ?? '1')!;
      final headers = page < pages.length
          ? {
              'link':
                  '<${api.url}$path?per_page=100&page=${page + 1}>; rel="next", <${api.url}$path?page=${pages.length}>; rel="last"',
            }
          : const <String, String>{};
      return Res(pages[page - 1], headers: headers);
    };
  }

  Map<String, Object?> item(String repo, int n, String updated) => {
    'repository_url': '${api.url}/repos/$repo',
    'number': n,
    'updated_at': updated,
  };

  void pr(String repo, int n, {String author = 'me', String updated = '2026-11-10T00:00:00Z'}) {
    pulls['$repo#$n'] = {
      'number': n,
      'title': 'PR $n',
      'html_url': 'https://github.com/$repo/pull/$n',
      'user': {'login': author},
      'state': 'open',
      'created_at': '2026-11-01T00:00:00Z',
      'closed_at': null,
      'updated_at': updated,
      'base': {'ref': 'main'},
      'head': {'ref': 'f$n'},
    };
  }
}

void main() {
  late Api api;
  late Gh gh;
  final now = DateTime.utc(2026, 11, 19);
  setUp(() async {
    api = await Api.start();
    gh = Gh(api)..install();
  });
  tearDown(() => api.close());

  Ctx ctx() => Ctx(config: {'apiBaseUrl': '${api.url}/', 'login': 'Me'}, token: 'tok', now: now);
  Future<List<PayloadObservation>> sync(Ctx c) => GitHubSource().sync(c).toList();

  test('searches reviewed-by and involves; sends auth headers; cursor in query', () async {
    final c = ctx()..cursors[''] = '2026-11-05T00:00:00Z';
    await sync(c);
    final qs = api.to('/search/issues').map((h) => h.uri.queryParameters['q']!).toList();
    expect(qs, containsAll([contains('reviewed-by:Me'), contains('involves:Me')]));
    expect(qs, everyElement(allOf(contains('is:pr'), contains('updated:>=2026-11-05T00:00:00Z'))));
    final h = api.hits.first.headers;
    expect(h.value('authorization'), 'Bearer tok');
    expect(h.value('accept'), 'application/vnd.github+json');
  });

  test('results de-duplicated by repo#number and processed in updated order', () async {
    gh.pr('o/a', 1);
    gh.pr('o/b', 2);
    gh.pr('o/a', 3);
    gh.reviewedBy.addAll([gh.item('o/a', 3, '2026-11-12T00:00:00Z'), gh.item('o/a', 1, '2026-11-11T00:00:00Z')]);
    gh.involves.addAll([gh.item('o/b', 2, '2026-11-10T00:00:00Z'), gh.item('o/a', 1, '2026-11-11T00:00:00Z')]);
    final c = ctx();
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['pr:o/b#2', 'pr:o/a#1', 'pr:o/a#3']);
    expect(api.to('/repos/o/a/pulls/1'), hasLength(1));
    expect(c.staged[''], '2026-11-12T00:00:00Z');
  });

  test('Link rel=next pagination for commits, reviews and comments', () async {
    gh.pr('o/r', 1, author: 'someone');
    gh.involves.add(gh.item('o/r', 1, '2026-11-10T00:00:00Z'));
    gh.commits['o/r#1'] = [
      [
        {'sha': 'c1'},
      ],
      [
        {'sha': 'c2'},
      ],
      [
        {'sha': 'c3'},
      ],
    ];
    gh.reviews['o/r#1'] = [
      [
        {
          'id': 1,
          'user': {'login': 'other'},
          'submitted_at': '2026-11-02T00:00:00Z',
          'state': 'APPROVED',
        },
      ],
      [
        {
          'id': 2,
          'user': {'login': 'me'},
          'submitted_at': '2026-11-03T00:00:00Z',
          'state': 'APPROVED',
        },
        {
          'id': 3,
          'user': {'login': 'me'},
          'submitted_at': null,
          'state': 'PENDING',
        },
      ],
    ];
    gh.comments['o/r#1'] = [
      [
        {
          'id': 10,
          'user': {'login': 'me'},
          'pull_request_review_id': 2,
          'body': 'in review',
          'path': 'a',
        },
      ],
      [
        {
          'id': 11,
          'user': {'login': 'ME'},
          'pull_request_review_id': 99,
          'body': 'single',
          'path': 'b',
        },
        {
          'id': 12,
          'user': {'login': 'other'},
          'pull_request_review_id': 98,
          'body': 'theirs',
        },
      ],
    ];
    final obs = await sync(ctx());
    final pr = obs.singleWhere((o) => o.kind == PayloadKind.pullRequest);
    expect(pr.content['commits'], ['c1', 'c2', 'c3']);
    expect(pr.content['roles'], containsAll(['reviewer', 'commenter']));
    expect((pr.content['comments'] as List).map((c) => (c as Map)['body']), ['single']);
    final reviews = obs.where((o) => o.kind == PayloadKind.review).toList();
    expect(reviews.map((r) => r.externalId), ['review:o/r#1:2']);
    expect(((reviews.single.content['comments'] as List).single as Map)['body'], 'in review');
  });

  test('404/410 per item: skipped, cursor advances, later items emitted', () async {
    gh.pr('o/r', 2);
    gh.pr('o/r', 3);
    gh.involves.addAll([
      gh.item('o/r', 1, '2026-11-10T00:00:00Z'), // detail 404 (no pull registered)
      gh.item('o/r', 2, '2026-11-11T00:00:00Z'), // comments 410
      gh.item('o/r', 3, '2026-11-12T00:00:00Z'),
    ]);
    gh.fail['/repos/o/r/pulls/2/comments'] = const Res({'message': 'Gone'}, status: 410);
    final c = ctx();
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['pr:o/r#3']);
    expect(c.staged[''], '2026-11-12T00:00:00Z');
  });

  test('cursor advances past a skipped last item', () async {
    gh.involves.add(gh.item('o/r', 1, '2026-11-10T00:00:00Z'));
    final c = ctx();
    expect(await sync(c), isEmpty);
    expect(c.staged[''], '2026-11-10T00:00:00Z');
  });

  test('401 and 5xx fail the sync', () async {
    gh.pr('o/r', 1);
    gh.involves.add(gh.item('o/r', 1, '2026-11-10T00:00:00Z'));
    for (final status in [401, 500, 502]) {
      gh.fail['/repos/o/r/pulls/1'] = Res({'message': 'x'}, status: status);
      await expectLater(sync(ctx()), throwsA(anything), reason: '$status');
    }
    gh.fail.clear();
    gh.fail['/search/issues'] = const Res({'message': 'Bad credentials'}, status: 401);
    await expectLater(sync(ctx()), throwsA(anything));
  });

  test('a repo named `repos` maps correctly', () async {
    gh.pr('acme/repos', 7);
    gh.pr('repos/x', 8);
    gh.involves.addAll([
      gh.item('acme/repos', 7, '2026-11-10T00:00:00Z'),
      gh.item('repos/x', 8, '2026-11-11T00:00:00Z'),
    ]);
    final obs = await sync(ctx());
    expect(obs.map((o) => o.externalId), ['pr:acme/repos#7', 'pr:repos/x#8']);
    expect(obs.first.content['repo'], 'acme/repos');
    expect(api.to('/repos/acme/repos/pulls/7'), hasLength(1));
  });

  test('403 with x-ratelimit-remaining 0 stops and keeps the cursor', () async {
    gh.pr('o/r', 1);
    gh.pr('o/r', 2);
    gh.pr('o/r', 3);
    gh.involves.addAll([
      gh.item('o/r', 1, '2026-11-10T00:00:00Z'),
      gh.item('o/r', 2, '2026-11-11T00:00:00Z'),
      gh.item('o/r', 3, '2026-11-12T00:00:00Z'),
    ]);
    gh.fail['/repos/o/r/pulls/2/reviews'] = const Res(
      {'message': 'API rate limit exceeded'},
      status: 403,
      headers: {'x-ratelimit-remaining': '0'},
    );
    final c = ctx();
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['pr:o/r#1']);
    expect(c.staged[''], '2026-11-10T00:00:00Z');
    expect(api.to('/repos/o/r/pulls/3'), isEmpty);
  });

  test('403 rate limit during search stops without advancing the cursor', () async {
    gh.fail['/search/issues'] = const Res({'message': 'x'}, status: 403, headers: {'x-ratelimit-remaining': '0'});
    final c = ctx()..cursors[''] = '2026-11-01T00:00:00Z';
    expect(await sync(c), isEmpty);
    expect(c.staged, isEmpty);
  });

  test('PR with no role of mine is not emitted', () async {
    gh.pr('o/r', 1, author: 'someone'); // mentioned only
    gh.involves.add(gh.item('o/r', 1, '2026-11-10T00:00:00Z'));
    expect(await sync(ctx()), isEmpty);
  });

  test('validate rejects a token for another login', () async {
    api.handler = (h) => const Res({'login': 'someone'});
    expect((await GitHubSource().validate(ctx())).ok, false);
    gh.install();
    expect((await GitHubSource().validate(ctx())).ok, true);
  });
}
