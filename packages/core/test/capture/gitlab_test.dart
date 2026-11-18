import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/capture/sources/gitlab.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'fake_context.dart';
import 'fake_server.dart';

Map<String, Object?> u(String name) => {'username': name};

Map<String, Object?> mr(int iid, String author, String updated, {List<String> reviewers = const []}) => {
      'id': 100 + iid,
      'iid': iid,
      'project_id': 5,
      'title': 'MR $iid',
      'description': 'desc $iid',
      'state': 'merged',
      'draft': false,
      'author': u(author),
      'assignees': <Object?>[],
      'reviewers': [for (final r in reviewers) u(r)],
      'web_url': 'https://gitlab.com/grp/sub/proj/-/merge_requests/$iid',
      'references': {'full': 'grp/sub/proj!$iid'},
      'created_at': '2026-11-10T10:00:00Z',
      'merged_at': '2026-11-11T10:00:00Z',
      'updated_at': updated,
      'source_branch': 'feat',
      'target_branch': 'main',
    };

void main() {
  late FakeApi api;
  final queries = <Map<String, String>>[];
  var limited = false;

  setUp(() async {
    queries.clear();
    limited = false;
    api = await FakeApi.start({
      '/api/v4/user': (_) => ok(u('me')),
      '/api/v4/merge_requests': (req) {
        final q = req.uri.queryParameters;
        queries.add(q);
        if (q.containsKey('author_username')) return ok([mr(1, 'me', '2026-11-12T10:00:00Z')]);
        if (q.containsKey('reviewer_username')) {
          return ok([mr(2, 'bob', '2026-11-13T10:00:00Z', reviewers: ['me'])]);
        }
        return ok([mr(1, 'me', '2026-11-12T10:00:00Z')]); // duplicate via assignee
      },
      '/api/v4/projects/5/merge_requests/1/commits': (_) => ok([
            {'id': 'aaa'},
          ]),
      '/api/v4/projects/5/merge_requests/1/notes': (_) => ok([
            {'id': 1, 'author': u('me'), 'system': true, 'body': 'changed the description', 'created_at': '2026-11-10T11:00:00Z'},
          ]),
      '/api/v4/projects/5/merge_requests/2/commits': (_) => limited
          ? (429, {'message': '429 Too Many Requests'})
          : ok([
              {'id': 'ccc'},
            ]),
      '/api/v4/projects/5/merge_requests/2/notes': (_) => ok([
            {
              'id': 20,
              'author': u('me'),
              'system': false,
              'body': 'nit: rename',
              'created_at': '2026-11-12T08:00:00Z',
              'position': {'new_path': 'a.go', 'new_line': 4},
            },
            {'id': 21, 'author': u('bob'), 'system': false, 'body': 'done', 'created_at': '2026-11-12T08:30:00Z'},
            {'id': 22, 'author': u('me'), 'system': true, 'body': 'approved this merge request', 'created_at': '2026-11-12T09:00:00Z'},
          ]),
    });
  });
  tearDown(() => api.close());

  FakeContext ctx() => FakeContext(
        sourceId: 'gl',
        config: {'baseUrl': api.url, 'username': 'me'},
        token: 'pat',
        now: DateTime.utc(2026, 11, 18),
      );

  test('emits MRs (deduped) and your notes and approvals', () async {
    final c = ctx();
    final obs = await GitLabSource().sync(c).toList();
    expect(queries, hasLength(3));
    expect(queries.first['updated_after'], '2026-10-19T00:00:00.000Z');
    expect(api.requests.first.headers.value('private-token'), 'pat');
    expect(obs.map((o) => o.externalId), ['mr:5!1', 'mr:5!2', 'note:5!2:20', 'note:5!2:22']);
    expect(obs[0].content['repo'], 'grp/sub/proj');
    expect(obs[0].content['roles'], ['author']);
    expect(obs[0].content['commits'], ['aaa']);
    expect(obs[1].content['roles'], ['reviewer', 'approver', 'commenter']);
    expect(obs[2].kind, PayloadKind.review);
    expect(obs[2].content['path'], 'a.go');
    expect(obs[3].content['state'], 'APPROVED');
    expect(obs[3].occurredStart, DateTime.utc(2026, 11, 12, 9));
    expect(c.staged[''], '2026-11-13T10:00:00Z');
  });

  test('re-sync is idempotent through the Ingestor', () async {
    final db = ProfileDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 'gl', kind: SourceKind.gitlab, name: 'gl'));
    final ingestor = Ingestor(db, utcOffset: (_) => Duration.zero);
    final c = ctx();
    expect((await ingestor.ingest('gl', await GitLabSource().sync(c).toList())).created, 4);
    c.commit();
    expect((await ingestor.ingest('gl', await GitLabSource().sync(c).toList())).unchanged, 4);
    expect(queries.last['updated_after'], '2026-11-13T09:59:59.000Z'); // 1 s overlap (#21)
  });

  test('429 stops the sync and keeps the cursor at the last finished MR', () async {
    limited = true;
    final c = ctx();
    final obs = await GitLabSource().sync(c).toList();
    expect(obs.map((o) => o.externalId), ['mr:5!1']);
    expect(c.staged[''], '2026-11-12T10:00:00Z');
  });

  test('validate', () async {
    expect((await GitLabSource().validate(ctx())).ok, isTrue);
    expect((await GitLabSource().validate(FakeContext(config: {'baseUrl': api.url}))).ok, isFalse);
  });
}
