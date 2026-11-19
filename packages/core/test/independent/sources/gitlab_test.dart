import 'package:core/core.dart';
import 'package:core/src/capture/sources/gitlab.dart';
import 'package:test/test.dart';

import 'support.dart';

Map<String, Object?> mr(int id, {String updated = '2026-11-10T00:00:00.000Z', String author = 'me'}) => {
  'id': id,
  'iid': id,
  'project_id': 5,
  'title': 'MR $id',
  'web_url': 'https://gl/g/sub/p/-/merge_requests/$id',
  'references': {'full': 'g/sub/p!$id'},
  'author': {'username': author},
  'state': 'opened',
  'created_at': '2026-11-01T00:00:00.000Z',
  'updated_at': updated,
};

void main() {
  late Api api;
  final now = DateTime.utc(2026, 11, 19);
  // role → list of all MRs; paged by per_page/page.
  late Map<String, List<Map<String, Object?>>> byRole;
  late Map<String, List<Map<String, Object?>>> notes; // mr iid → notes
  late Map<String, Res> fail;

  List<Object?> page(List<Object?> all, Hit h) {
    final per = int.parse(h.uri.queryParameters['per_page']!);
    final p = int.parse(h.uri.queryParameters['page']!);
    return all.skip((p - 1) * per).take(per).toList();
  }

  setUp(() async {
    api = await Api.start();
    byRole = {'author_username': [], 'reviewer_username': [], 'assignee_username': []};
    notes = {};
    fail = {};
    api.handler = (h) {
      final path = h.uri.path;
      if (fail[path] != null) return fail[path];
      if (path == '/api/v4/user') return const Res({'username': 'Me'});
      if (path == '/api/v4/merge_requests') {
        final role = byRole.keys.firstWhere((k) => h.uri.queryParameters.containsKey(k));
        return Res(page(byRole[role]!, h));
      }
      final m = RegExp(r'^/api/v4/projects/5/merge_requests/(\d+)/(commits|notes)$').firstMatch(path);
      if (m == null) return null;
      if (m[2] == 'commits') {
        return Res([
          {'id': 'sha${m[1]}'},
        ]);
      }
      return Res(page(notes[m[1]] ?? const [], h));
    };
  });
  tearDown(() => api.close());

  Ctx ctx() => Ctx(config: {'baseUrl': '${api.url}/', 'username': 'Me'}, token: 'pat', now: now);
  Future<List<PayloadObservation>> sync(Ctx c) => GitLabSource().sync(c).toList();

  test('MR list paginates until a short page; private token header; dedupe across roles', () async {
    byRole['author_username'] = [
      for (var i = 1; i <= 103; i++) mr(i, updated: '2026-11-10T00:00:${(i % 60).toString().padLeft(2, '0')}.000Z'),
    ];
    byRole['reviewer_username'] = [mr(1, updated: '2026-11-10T00:00:01.000Z')];
    final obs = await sync(ctx());
    final authorPages = api
        .to('/api/v4/merge_requests')
        .where((h) => h.uri.queryParameters.containsKey('author_username'))
        .map((h) => h.uri.queryParameters['page'])
        .toList();
    expect(authorPages, ['1', '2']);
    expect(obs.where((o) => o.kind == PayloadKind.pullRequest), hasLength(103));
    expect(api.hits.first.headers.value('private-token'), 'pat');
  });

  test('notes paginate until a short page', () async {
    byRole['author_username'] = [mr(1)];
    notes['1'] = [
      for (var i = 0; i < 101; i++)
        {
          'id': i,
          'author': {'username': 'me'},
          'body': 'n$i',
          'system': false,
          'created_at': '2026-11-02T00:00:00Z',
        },
    ];
    final obs = await sync(ctx());
    expect(obs.where((o) => o.kind == PayloadKind.review), hasLength(101));
    expect(api.to('/api/v4/projects/5/merge_requests/1/notes').map((h) => h.uri.queryParameters['page']), ['1', '2']);
  });

  test('updated_after = cursor − 1 s', () async {
    final c = ctx()..cursors[''] = '2026-11-10T10:00:00.000Z';
    await sync(c);
    final after = api.to('/api/v4/merge_requests').map((h) => h.uri.queryParameters['updated_after']).toSet();
    expect(after.length, 1);
    expect(DateTime.parse(after.single!), DateTime.utc(2026, 11, 10, 9, 59, 59));
  });

  test('first sync uses the initial import date', () async {
    await sync(ctx());
    final after = api.to('/api/v4/merge_requests').first.uri.queryParameters['updated_after']!;
    expect(DateTime.parse(after), now.subtract(const Duration(days: 30)));
  });

  test('approval comes from the system note; other system notes and others\' notes dropped', () async {
    byRole['reviewer_username'] = [
      mr(1, author: 'boss')
        ..['reviewers'] = [
          {'username': 'me'},
        ],
    ];
    notes['1'] = [
      {
        'id': 1,
        'author': {'username': 'me'},
        'body': 'approved this merge request',
        'system': true,
        'created_at': '2026-11-03T09:00:00Z',
      },
      {
        'id': 2,
        'author': {'username': 'me'},
        'body': 'added 1 commit',
        'system': true,
        'created_at': '2026-11-03T08:00:00Z',
      },
      {
        'id': 3,
        'author': {'username': 'boss'},
        'body': 'thanks',
        'system': false,
        'created_at': '2026-11-03T10:00:00Z',
      },
      {
        'id': 4,
        'author': {'username': 'ME'},
        'body': 'nit',
        'system': false,
        'created_at': '2026-11-03T07:00:00Z',
        'position': {'new_path': 'a.dart', 'new_line': 3},
      },
    ];
    final obs = await sync(ctx());
    final pr = obs.singleWhere((o) => o.kind == PayloadKind.pullRequest);
    expect(pr.content['roles'], containsAll(['reviewer', 'approver', 'commenter']));
    expect(pr.content['repo'], 'g/sub/p');
    expect(pr.content['commits'], ['sha1']);
    final reviews = {for (final o in obs.where((o) => o.kind == PayloadKind.review)) o.externalId: o};
    expect(reviews.keys.toSet(), {'note:5!1:1', 'note:5!1:4'});
    expect(reviews['note:5!1:1']!.content['state'], 'APPROVED');
    expect(reviews['note:5!1:1']!.occurredStart, DateTime.utc(2026, 11, 3, 9));
    expect(reviews['note:5!1:4']!.content['state'], 'COMMENTED');
    expect(reviews['note:5!1:4']!.content['path'], 'a.dart');
  });

  test('404 MR skipped with cursor advancing; 401 fails; 429 stops keeping the cursor', () async {
    byRole['author_username'] = [
      mr(1, updated: '2026-11-10T00:00:00.000Z'),
      mr(2, updated: '2026-11-11T00:00:00.000Z'),
      mr(3, updated: '2026-11-12T00:00:00.000Z'),
    ];
    fail['/api/v4/projects/5/merge_requests/1/commits'] = const Res({'message': '404'}, status: 404);
    var c = ctx();
    var obs = await sync(c);
    expect(obs.where((o) => o.kind == PayloadKind.pullRequest).map((o) => o.externalId), ['mr:5!2', 'mr:5!3']);
    expect(c.staged[''], '2026-11-12T00:00:00.000Z');

    fail
      ..clear()
      ..['/api/v4/projects/5/merge_requests/3/notes'] = const Res({'message': 'Retry later'}, status: 429);
    c = ctx();
    obs = await sync(c);
    expect(obs.where((o) => o.kind == PayloadKind.pullRequest).map((o) => o.externalId), ['mr:5!1', 'mr:5!2']);
    expect(c.staged[''], '2026-11-11T00:00:00.000Z');

    fail
      ..clear()
      ..['/api/v4/projects/5/merge_requests/2/notes'] = const Res({'message': '401 Unauthorized'}, status: 401);
    await expectLater(sync(ctx()), throwsA(anything));
  });
}
