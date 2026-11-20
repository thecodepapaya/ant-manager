// Independent tests for GitHub / GitLab issue capture (LLD 04 §4.3 issue rows, DECISIONS #106).
import 'package:core/core.dart';
import 'package:core/src/capture/sources/github.dart';
import 'package:core/src/capture/sources/gitlab.dart';
import 'package:test/test.dart';

import 'support.dart';

final now = DateTime.utc(2026, 11, 19);

/// Link-paginated reply: [pages] are served by `page` query param; `rel="next"` until the last.
Res linkPaged(Api api, Hit h, List<List<Map<String, Object?>>> pages, {Map<String, String> keep = const {}}) {
  final page = int.tryParse(h.uri.queryParameters['page'] ?? '1')!;
  final next = Uri.parse('${api.url}${h.uri.path}').replace(queryParameters: {...keep, 'page': '${page + 1}'});
  return Res(
    page <= pages.length ? pages[page - 1] : const <Object?>[],
    headers: page < pages.length ? {'link': '<$next>; rel="next"'} : const {},
  );
}

// ---------------------------------------------------------------------------------------------------------------
// GitHub

class GhIssues {
  GhIssues(this.api);
  final Api api;
  final created = <List<Map<String, Object?>>>[[]]; // pages of /issues?filter=created
  final subscribed = <List<Map<String, Object?>>>[[]];
  final details = <String, Map<String, Object?>>{}; // 'o/r#1' → full issue
  final comments = <String, List<List<Map<String, Object?>>>>{}; // pages
  final fail = <String, Res>{};

  void install() {
    api.handler = (h) {
      final path = h.uri.path;
      if (fail[path] != null) return fail[path];
      if (path == '/user') return const Res({'login': 'Me'});
      if (path == '/search/issues') return const Res({'items': <Object?>[]});
      if (path == '/issues') {
        final f = h.uri.queryParameters['filter'];
        return linkPaged(api, h, f == 'created' ? created : subscribed, keep: {'filter': f!});
      }
      final m = RegExp(r'^/repos/(.+)/issues/(\d+)(/comments)?$').firstMatch(path);
      if (m == null) return null;
      final key = '${m[1]}#${m[2]}';
      if (m[3] == null) return details[key] == null ? null : Res(details[key]);
      return linkPaged(api, h, comments[key] ?? [[]]);
    };
  }

  Map<String, Object?> issue(
    String repo,
    int n, {
    String updated = '2026-11-10T00:00:00Z',
    String author = 'me',
    String state = 'open',
    int comments = 0,
    String? closedAt,
    String? closedBy,
    bool pr = false,
  }) => {
    'repository_url': '${api.url}/repos/$repo',
    'number': n,
    'title': 'Issue $n',
    'html_url': 'https://github.com/$repo/issues/$n',
    'body': 'body $n',
    'user': {'login': author},
    'state': state,
    'state_reason': state == 'closed' ? 'completed' : null,
    'labels': [
      {'name': 'bug'},
    ],
    'comments': comments,
    'created_at': '2026-11-01T00:00:00Z',
    'closed_at': closedAt,
    'updated_at': updated,
    'closed_by': closedBy == null ? null : {'login': closedBy},
    if (pr) 'pull_request': {'url': 'x'},
  };

  /// Registers a closed issue's detail (with `closed_by`) and returns the list entry (no `closed_by`).
  Map<String, Object?> closed(String repo, int n, {String closer = 'me', String author = 'me', String? updated}) {
    final full = issue(
      repo,
      n,
      author: author,
      state: 'closed',
      closedAt: '2026-11-05T00:00:00Z',
      closedBy: closer,
      updated: updated ?? '2026-11-10T00:00:00Z',
    );
    details['$repo#$n'] = full;
    return {...full}..remove('closed_by');
  }
}

Map<String, Object?> ghComment(String login, String body) => {
  'user': {'login': login},
  'body': body,
  'created_at': '2026-11-03T00:00:00Z',
  'html_url': 'https://github.com/c/$body',
};

void githubTests() {
  late Api api;
  late GhIssues gh;
  setUp(() async {
    api = await Api.start();
    gh = GhIssues(api)..install();
  });
  tearDown(() => api.close());

  Ctx ctx() => Ctx(config: {'apiBaseUrl': api.url, 'login': 'Me'}, token: 'tok', now: now);
  Future<List<PayloadObservation>> sync(Ctx c) => GitHubSource().sync(c).toList();
  Iterable<Map<String, String>> issueQueries() => api.to('/issues').map((h) => h.uri.queryParameters);

  test('GET /issues twice (created, subscribed) with state/since/sort/direction/per_page', () async {
    await sync(ctx());
    final qs = issueQueries().toList();
    expect(qs.map((q) => q['filter']), ['created', 'subscribed']);
    for (final q in qs) {
      expect(q, {
        'filter': q['filter'],
        'state': 'all',
        'since': '2026-10-20T00:00:00Z', // initial import: now − 30 days
        'sort': 'updated',
        'direction': 'asc',
        'per_page': '100',
      });
    }
    expect(api.to('/issues').first.headers.value('authorization'), 'Bearer tok');
  });

  test('since = the issue cursor (independent of the PR cursor)', () async {
    final c = ctx()
      ..cursors['issue'] = '2026-11-15T01:02:03Z'
      ..cursors[''] = '2026-11-01T00:00:00Z';
    await sync(c);
    expect(issueQueries().map((q) => q['since']), ['2026-11-15T01:02:03Z', '2026-11-15T01:02:03Z']);
    expect(api.to('/search/issues').first.uri.queryParameters['q'], contains('updated:>=2026-11-01T00:00:00Z'));
  });

  test('follows Link rel=next pagination on /issues', () async {
    gh.created
      ..clear()
      ..addAll([
        [gh.issue('o/r', 1, updated: '2026-11-10T00:00:00Z')],
        [gh.issue('o/r', 2, updated: '2026-11-11T00:00:00Z')],
      ]);
    final obs = await sync(ctx());
    expect(obs.map((o) => o.externalId), ['issue:o/r#1', 'issue:o/r#2']);
    expect(
      api
          .to('/issues')
          .where((h) => h.uri.queryParameters['filter'] == 'created')
          .map((h) => h.uri.queryParameters['page']),
      [null, '2'],
    );
  });

  test('pull_request entries dropped; dedupe by repo#number; ascending updated_at', () async {
    gh.created[0] = [
      gh.issue('o/r', 3, updated: '2026-11-12T00:00:00Z'),
      gh.issue('o/r', 9, updated: '2026-11-09T00:00:00Z', pr: true),
      gh.issue('o/r', 1, updated: '2026-11-10T00:00:00Z'),
    ];
    gh.subscribed[0] = [
      gh.issue('o/r', 1, updated: '2026-11-10T00:00:00Z'), // duplicate of created
      gh.issue('x/y', 1, updated: '2026-11-11T00:00:00Z'), // same number, other repo
      gh.issue('o/r', 8, updated: '2026-11-08T00:00:00Z', pr: true, author: 'bob', comments: 2),
    ];
    final c = ctx();
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['issue:o/r#1', 'issue:x/y#1', 'issue:o/r#3']);
    expect(obs.every((o) => o.kind == PayloadKind.issue), isTrue);
    expect(api.hits.where((h) => h.uri.path.contains('/issues/8') || h.uri.path.contains('/issues/9')), isEmpty);
    expect(c.staged['issue'], '2026-11-12T00:00:00Z');
  });

  test('closed issue re-fetched for closed_by → closer; open issue not re-fetched', () async {
    gh.created[0] = [gh.issue('o/r', 1)];
    gh.subscribed[0] = [gh.closed('o/r', 2, author: 'bob', closer: 'ME', updated: '2026-11-11T00:00:00Z')];
    final obs = await sync(ctx());
    expect(obs.map((o) => o.externalId), ['issue:o/r#1', 'issue:o/r#2']);
    expect(api.to('/repos/o/r/issues/1'), isEmpty);
    expect(api.to('/repos/o/r/issues/2'), hasLength(1));
    final closed = obs[1];
    expect(closed.content['roles'], ['closer']);
    expect(closed.content['closedBy'], 'ME');
    expect(closed.content['state'], 'closed');
    expect(closed.content['stateReason'], 'completed');
    expect(closed.occurredStart, DateTime.utc(2026, 11, 1));
    expect(closed.occurredEnd, DateTime.utc(2026, 11, 5));
    expect(obs[0].occurredEnd, isNull);
  });

  test('closed by someone else and not authored → no role, not emitted, cursor advances', () async {
    gh.subscribed[0] = [gh.closed('o/r', 2, author: 'bob', closer: 'bob')];
    final c = ctx();
    expect(await sync(c), isEmpty);
    expect(c.staged['issue'], '2026-11-10T00:00:00Z');
  });

  test('comments fetched (all pages) only when comments > 0; only my comments kept', () async {
    gh.subscribed[0] = [
      gh.issue('o/r', 1, author: 'bob', comments: 3),
      gh.issue('o/r', 2, author: 'bob', comments: 0, updated: '2026-11-11T00:00:00Z'),
      gh.issue('o/r', 3, author: 'bob', comments: 1, updated: '2026-11-12T00:00:00Z'),
    ];
    gh.comments['o/r#1'] = [
      [ghComment('bob', 'b1'), ghComment('me', 'm1')],
      [ghComment('mE', 'm2')],
    ];
    gh.comments['o/r#2'] = [
      [ghComment('me', 'never-fetched')],
    ];
    gh.comments['o/r#3'] = [
      [ghComment('bob', 'b3')],
    ];
    final c = ctx();
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['issue:o/r#1']);
    expect(obs.single.content['roles'], ['commenter']);
    expect(obs.single.content['comments'], [
      {'body': 'm1', 'createdAt': '2026-11-03T00:00:00Z', 'url': 'https://github.com/c/m1'},
      {'body': 'm2', 'createdAt': '2026-11-03T00:00:00Z', 'url': 'https://github.com/c/m2'},
    ]);
    expect(api.to('/repos/o/r/issues/1/comments').map((h) => h.uri.queryParameters['page']), [null, '2']);
    expect(api.to('/repos/o/r/issues/2/comments'), isEmpty);
    expect(c.staged['issue'], '2026-11-12T00:00:00Z');
  });

  test('roles in order author, closer, commenter; payload shape', () async {
    gh.created[0] = [
      {...gh.closed('o/r', 4), 'comments': 1},
    ];
    gh.comments['o/r#4'] = [
      [ghComment('me', 'done')],
    ];
    final o = (await sync(ctx())).single;
    expect(o.externalId, 'issue:o/r#4');
    expect(o.kind, PayloadKind.issue);
    expect(o.title, 'Issue 4 (o/r#4)');
    expect(o.content, {
      'repo': 'o/r',
      'number': 4,
      'title': 'Issue 4',
      'url': 'https://github.com/o/r/issues/4',
      'body': 'body 4',
      'state': 'closed',
      'stateReason': 'completed',
      'author': 'me',
      'labels': ['bug'],
      'createdAt': '2026-11-01T00:00:00Z',
      'closedAt': '2026-11-05T00:00:00Z',
      'closedBy': 'me',
      'roles': ['author', 'closer', 'commenter'],
      'comments': [
        {'body': 'done', 'createdAt': '2026-11-03T00:00:00Z', 'url': 'https://github.com/c/done'},
      ],
    });
  });

  test('404 detail / 410 comments: skipped, cursor advances, later issues emitted', () async {
    gh.subscribed[0] = [
      gh.issue('o/r', 1, state: 'closed', updated: '2026-11-10T00:00:00Z'), // no detail registered → 404
      gh.issue('o/r', 2, comments: 1, updated: '2026-11-11T00:00:00Z'),
      gh.issue('o/r', 3, updated: '2026-11-12T00:00:00Z'),
    ];
    gh.fail['/repos/o/r/issues/2/comments'] = const Res({'message': 'Gone'}, status: 410);
    final c = ctx();
    expect((await sync(c)).map((o) => o.externalId), ['issue:o/r#3']);
    expect(c.staged['issue'], '2026-11-12T00:00:00Z');
  });

  test('cursor advances past a skipped (404) last issue', () async {
    gh.created[0] = [gh.issue('o/r', 1, state: 'closed', updated: '2026-11-14T00:00:00Z')];
    final c = ctx();
    expect(await sync(c), isEmpty);
    expect(c.staged['issue'], '2026-11-14T00:00:00Z');
  });

  for (final (name, res) in [
    ('403 x-ratelimit-remaining 0', const Res({'message': 'x'}, status: 403, headers: {'x-ratelimit-remaining': '0'})),
    ('403 rate limit message', const Res({'message': 'API rate limit exceeded'}, status: 403)),
    ('429', const Res({'message': 'slow down'}, status: 429)),
  ]) {
    test('$name mid-issues stops the sync; cursor stays at the last finished issue', () async {
      gh.created[0] = [
        gh.issue('o/r', 1, updated: '2026-11-10T00:00:00Z'),
        gh.issue('o/r', 2, comments: 1, updated: '2026-11-11T00:00:00Z'),
        gh.issue('o/r', 3, updated: '2026-11-12T00:00:00Z'),
      ];
      gh.fail['/repos/o/r/issues/2/comments'] = res;
      final c = ctx();
      final obs = await sync(c);
      expect(obs.map((o) => o.externalId), ['issue:o/r#1']);
      expect(c.staged['issue'], '2026-11-10T00:00:00Z');
    });
  }

  test('rate limit on the /issues list stops without staging an issue cursor', () async {
    gh.fail['/issues'] = const Res({'message': 'x'}, status: 429);
    final c = ctx()..cursors['issue'] = '2026-11-01T00:00:00Z';
    expect(await sync(c), isEmpty);
    expect(c.staged.containsKey('issue'), isFalse);
  });

  test('rate limit in the PR phase skips issues entirely', () async {
    gh.fail['/search/issues'] = const Res({'message': 'x'}, status: 429);
    gh.created[0] = [gh.issue('o/r', 1)];
    expect(await sync(ctx()), isEmpty);
    expect(api.to('/issues'), isEmpty);
  });

  test('401 / 5xx on an issue detail fails the sync', () async {
    gh.created[0] = [gh.issue('o/r', 1, state: 'closed')];
    for (final s in [401, 500]) {
      gh.fail['/repos/o/r/issues/1'] = Res({'message': 'x'}, status: s);
      await expectLater(sync(ctx()), throwsA(anything), reason: '$s');
    }
  });

  test('re-sync from the committed cursor re-emits identical payloads', () async {
    gh.created[0] = [gh.issue('o/r', 1, updated: '2026-11-10T00:00:00Z')];
    final c = ctx();
    final first = await sync(c);
    c.commit();
    api.hits.clear();
    final second = await sync(c);
    expect(issueQueries().map((q) => q['since']).toSet(), {'2026-11-10T00:00:00Z'});
    expect(second.single.content, first.single.content);
  });
}

// ---------------------------------------------------------------------------------------------------------------
// GitLab

Map<String, Object?> glIssue(
  int project,
  int iid, {
  String updated = '2026-11-10T00:00:00.000Z',
  String author = 'me',
  String state = 'opened',
  String? closedBy,
  bool refs = true,
}) => {
  'id': project * 1000 + iid,
  'iid': iid,
  'project_id': project,
  'title': 'Issue $iid',
  'description': 'desc $iid',
  'web_url': 'https://gl/g/sub/p$project/-/issues/$iid',
  if (refs) 'references': {'full': 'g/sub/p$project#$iid'},
  'author': {'username': author},
  'state': state,
  'labels': ['bug'],
  'created_at': '2026-11-01T00:00:00.000Z',
  'closed_at': state == 'closed' ? '2026-11-05T00:00:00.000Z' : null,
  'closed_by': closedBy == null ? null : {'username': closedBy},
  'updated_at': updated,
};

Map<String, Object?> glNote(String author, String body, {bool system = false}) => {
  'author': {'username': author},
  'body': body,
  'system': system,
  'created_at': '2026-11-03T00:00:00.000Z',
};

void gitlabTests() {
  late Api api;
  late List<Map<String, Object?>> created; // /issues?scope=created_by_me
  late List<Map<String, Object?>> closedEvents, commentedEvents;
  late Map<String, Map<String, Object?>> byRef; // '5#1' → issue (project issue endpoint)
  late Map<String, List<Map<String, Object?>>> notes; // '5#1' → notes
  late Map<String, Res> fail;

  List<Object?> page(List<Object?> all, Hit h) {
    final per = int.parse(h.uri.queryParameters['per_page']!);
    final p = int.parse(h.uri.queryParameters['page']!);
    return all.skip((p - 1) * per).take(per).toList();
  }

  setUp(() async {
    api = await Api.start();
    created = [];
    closedEvents = [];
    commentedEvents = [];
    byRef = {};
    notes = {};
    fail = {};
    api.handler = (h) {
      final path = h.uri.path;
      if (fail[path] != null) return fail[path];
      if (path == '/api/v4/user') return const Res({'username': 'Me'});
      if (path == '/api/v4/merge_requests') return const Res(<Object?>[]);
      if (path == '/api/v4/issues') return Res(page(created, h));
      if (path == '/api/v4/events') {
        return Res(page(h.uri.queryParameters['action'] == 'closed' ? closedEvents : commentedEvents, h));
      }
      final m = RegExp(r'^/api/v4/projects/(\d+)/issues/(\d+)(/notes)?$').firstMatch(path);
      if (m == null) return null;
      final key = '${m[1]}#${m[2]}';
      if (m[3] == null) return byRef[key] == null ? null : Res(byRef[key]);
      return Res(page(notes[key] ?? const [], h));
    };
  });
  tearDown(() => api.close());

  Ctx ctx() => Ctx(config: {'baseUrl': api.url, 'username': 'Me'}, token: 'pat', now: now);
  Future<List<PayloadObservation>> sync(Ctx c) => GitLabSource().sync(c).toList();
  Map<String, Object?> closedEv(int p, int iid) => {'project_id': p, 'target_iid': iid, 'target_type': 'Issue'};
  Map<String, Object?> noteEv(int p, int iid, {String type = 'Issue'}) => {
    'project_id': p,
    'note': {'noteable_type': type, 'noteable_iid': iid},
  };

  test('/issues query: scope=created_by_me, updated_after = cursor − 1 s, order/sort, paged', () async {
    final c = ctx()..cursors['issue'] = '2026-11-10T12:00:00.000Z';
    await sync(c);
    final q = api.to('/api/v4/issues').single.uri.queryParameters;
    expect(q['scope'], 'created_by_me');
    expect(DateTime.parse(q['updated_after']!), DateTime.utc(2026, 11, 10, 11, 59, 59));
    expect(q['order_by'], 'updated_at');
    expect(q['sort'], 'asc');
    expect(q['per_page'], '100');
    expect(q['page'], '1');
    expect(api.to('/api/v4/issues').single.headers.value('private-token'), 'pat');
  });

  test('first sync uses the initial import date', () async {
    await sync(ctx());
    final q = api.to('/api/v4/issues').single.uri.queryParameters;
    expect(DateTime.parse(q['updated_after']!), now.subtract(const Duration(days: 30)));
  });

  test('events: closed issues and comments, since the cursor\'s day', () async {
    final c = ctx()..cursors['issue'] = '2026-11-10T12:00:00.000Z';
    await sync(c);
    final evs = api.to('/api/v4/events').map((h) => h.uri.queryParameters).toList();
    final closed = evs.where((q) => q['action'] == 'closed').single;
    expect(closed['target_type'], 'issue');
    final commented = evs.where((q) => q['action'] == 'commented').single;
    // `after` is exclusive: the day before the cursor's day includes the whole cursor day.
    expect({closed['after'], commented['after']}, {'2026-11-09'});
  });

  test('/issues paginates until a short page', () async {
    created = [
      for (var i = 1; i <= 101; i++)
        glIssue(
          5,
          i,
          updated: '2026-11-10T00:${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}.000Z',
        ),
    ];
    final obs = await sync(ctx());
    expect(api.to('/api/v4/issues').map((h) => h.uri.queryParameters['page']), ['1', '2']);
    expect(obs, hasLength(101));
  });

  test('event-only issues fetched; MR notes ignored; known issues not re-fetched; 404/410 skipped', () async {
    created = [glIssue(5, 1, updated: '2026-11-10T00:00:00.000Z')];
    closedEvents = [closedEv(5, 1), closedEv(6, 2), closedEv(6, 404)];
    commentedEvents = [noteEv(6, 3), noteEv(6, 7, type: 'MergeRequest'), noteEv(6, 2), noteEv(7, 410)];
    byRef['6#2'] = glIssue(6, 2, author: 'bob', state: 'closed', closedBy: 'ME', updated: '2026-11-12T00:00:00.000Z');
    byRef['6#3'] = glIssue(6, 3, author: 'bob', updated: '2026-11-11T00:00:00.000Z');
    notes['6#3'] = [glNote('me', 'hi')];
    fail['/api/v4/projects/7/issues/410'] = const Res({'message': 'Gone'}, status: 410);
    final c = ctx();
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['issue:5#1', 'issue:6#3', 'issue:6#2']);
    expect(api.to('/api/v4/projects/5/issues/1'), isEmpty);
    expect(api.to('/api/v4/projects/6/issues/2'), hasLength(1)); // closed + commented: fetched once
    expect(api.to('/api/v4/projects/6/issues/7'), isEmpty);
    expect(obs[2].content['roles'], ['closer']);
    expect(obs[2].content['closedBy'], 'ME');
    expect(obs[1].content['roles'], ['commenter']);
    expect(c.staged['issue'], '2026-11-12T00:00:00.000Z');
  });

  test('issues updated before the cursor are dropped (no notes fetched)', () async {
    commentedEvents = [noteEv(6, 1), noteEv(6, 2)];
    byRef['6#1'] = glIssue(6, 1, updated: '2026-11-09T00:00:00.000Z'); // before cursor
    byRef['6#2'] = glIssue(6, 2, updated: '2026-11-10T12:00:00.000Z'); // == cursor: kept
    final c = ctx()..cursors['issue'] = '2026-11-10T12:00:00.000Z';
    final obs = await sync(c);
    expect(obs.map((o) => o.externalId), ['issue:6#2']);
    expect(api.to('/api/v4/projects/6/issues/1/notes'), isEmpty);
  });

  test('my non-system notes only; notes paginate with sort=asc', () async {
    created = [glIssue(5, 1, author: 'bob')];
    notes['5#1'] = [
      glNote('me', 'sys', system: true),
      glNote('bob', 'other'),
      for (var i = 0; i < 99; i++) glNote('bob', 'filler$i'),
      glNote('mE', 'mine'), // index 101 → page 2
    ];
    final o = (await sync(ctx())).single;
    expect(o.content['roles'], ['commenter']);
    expect(o.content['comments'], [
      {'body': 'mine', 'createdAt': '2026-11-03T00:00:00.000Z'},
    ]);
    final hits = api.to('/api/v4/projects/5/issues/1/notes').map((h) => h.uri.queryParameters).toList();
    expect(hits.map((q) => q['page']), ['1', '2']);
    expect(hits.map((q) => q['sort']).toSet(), {'asc'});
  });

  test('only a system note of mine → no role, not emitted, cursor advances', () async {
    commentedEvents = [noteEv(6, 1)];
    byRef['6#1'] = glIssue(6, 1, author: 'bob', updated: '2026-11-11T00:00:00.000Z');
    notes['6#1'] = [glNote('me', 'changed the title', system: true)];
    final c = ctx();
    expect(await sync(c), isEmpty);
    expect(c.staged['issue'], '2026-11-11T00:00:00.000Z');
  });

  test('payload: externalId issue:{project_id}#{iid}, repo from references.full, all roles', () async {
    created = [glIssue(5, 4, state: 'closed', closedBy: 'me')];
    notes['5#4'] = [glNote('me', 'fixed')];
    final o = (await sync(ctx())).single;
    expect(o.externalId, 'issue:5#4');
    expect(o.kind, PayloadKind.issue);
    expect(o.title, 'Issue 4 (g/sub/p5#4)');
    expect(o.occurredStart, DateTime.utc(2026, 11, 1));
    expect(o.occurredEnd, DateTime.utc(2026, 11, 5));
    expect(o.content, {
      'repo': 'g/sub/p5',
      'number': 4,
      'title': 'Issue 4',
      'url': 'https://gl/g/sub/p5/-/issues/4',
      'body': 'desc 4',
      'state': 'closed',
      'author': 'me',
      'labels': ['bug'],
      'createdAt': '2026-11-01T00:00:00.000Z',
      'closedAt': '2026-11-05T00:00:00.000Z',
      'closedBy': 'me',
      'roles': ['author', 'closer', 'commenter'],
      'comments': [
        {'body': 'fixed', 'createdAt': '2026-11-03T00:00:00.000Z'},
      ],
    });
  });

  test('repo falls back to the web URL without references; open issue has no occurredEnd', () async {
    created = [glIssue(5, 1, refs: false)];
    final o = (await sync(ctx())).single;
    expect(o.content['repo'], 'g/sub/p5');
    expect(o.occurredEnd, isNull);
  });

  test('ascending by updated_at across list and event candidates', () async {
    created = [glIssue(5, 1, updated: '2026-11-12T00:00:00.000Z'), glIssue(5, 2, updated: '2026-11-14T00:00:00.000Z')];
    closedEvents = [closedEv(6, 1)];
    byRef['6#1'] = glIssue(6, 1, closedBy: 'me', state: 'closed', updated: '2026-11-13T00:00:00.000Z');
    final c = ctx();
    expect((await sync(c)).map((o) => o.externalId), ['issue:5#1', 'issue:6#1', 'issue:5#2']);
    expect(c.staged['issue'], '2026-11-14T00:00:00.000Z');
  });

  test('404 notes skipped with cursor advancing; 429 stops keeping the cursor; 401 fails', () async {
    created = [
      glIssue(5, 1, updated: '2026-11-10T00:00:00.000Z'),
      glIssue(5, 2, updated: '2026-11-11T00:00:00.000Z'),
      glIssue(5, 3, updated: '2026-11-12T00:00:00.000Z'),
    ];
    fail['/api/v4/projects/5/issues/1/notes'] = const Res({'message': '404'}, status: 404);
    fail['/api/v4/projects/5/issues/3/notes'] = const Res({'message': '429'}, status: 429);
    final c = ctx();
    expect((await sync(c)).map((o) => o.externalId), ['issue:5#2']);
    expect(c.staged['issue'], '2026-11-11T00:00:00.000Z');

    fail['/api/v4/projects/5/issues/3/notes'] = const Res({'message': 'x'}, status: 401);
    await expectLater(sync(ctx()), throwsA(anything));
  });

  test('rate limit on /events stops without staging an issue cursor', () async {
    created = [glIssue(5, 1)];
    fail['/api/v4/events'] = const Res({'message': 'Rate limit exceeded'}, status: 403);
    final c = ctx();
    expect(await sync(c), isEmpty);
    expect(c.staged.containsKey('issue'), isFalse);
  });
}

void main() {
  group('GitHub issues', githubTests);
  group('GitLab issues', gitlabTests);
}
