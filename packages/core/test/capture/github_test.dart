import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/capture/sources/github.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'fake_context.dart';
import 'fake_server.dart';

Map<String, Object?> user(String login) => {'login': login};

Map<String, Object?> searchItem(int n, String updated) => {
      'number': n,
      'repository_url': 'https://api.github.com/repos/acme/api',
      'updated_at': updated,
    };

Map<String, Object?> pull(int n, String author) => {
      'number': n,
      'title': 'PR $n',
      'body': 'body $n',
      'state': 'closed',
      'draft': false,
      'html_url': 'https://github.com/acme/api/pull/$n',
      'user': user(author),
      'assignees': <Object?>[],
      'created_at': '2026-11-10T10:00:00Z',
      'closed_at': '2026-11-11T10:00:00Z',
      'merged_at': '2026-11-11T10:00:00Z',
      'updated_at': '2026-11-12T10:00:00Z', // volatile: not stored
      'base': {'ref': 'main'},
      'head': {'ref': 'feat-$n'},
      'additions': 10,
      'deletions': 2,
      'changed_files': 1,
    };

void main() {
  late FakeApi api;
  late String? lastQuery;
  var limitPull2 = false;

  setUp(() async {
    limitPull2 = false;
    lastQuery = null;
    api = await FakeApi.start({
      '/user': (_) => ok(user('me')),
      '/issues': (_) => ok([]),
      '/search/issues': (req) {
        lastQuery = req.uri.queryParameters['q'];
        return ok({
          'items': [searchItem(1, '2026-11-12T10:00:00Z'), searchItem(2, '2026-11-13T10:00:00Z')],
        });
      },
      '/repos/acme/api/pulls/1': (_) => ok(pull(1, 'me')),
      '/repos/acme/api/pulls/1/commits': (_) => ok([
            {'sha': 'aaa'},
            {'sha': 'bbb'},
          ]),
      '/repos/acme/api/pulls/1/reviews': (_) => ok([
            {'id': 7, 'user': user('bob'), 'state': 'APPROVED', 'submitted_at': '2026-11-11T09:00:00Z'},
          ]),
      '/repos/acme/api/pulls/1/comments': (_) => ok([]),
      '/repos/acme/api/pulls/2': (_) => limitPull2
          ? (403, {'message': 'API rate limit exceeded'})
          : ok(pull(2, 'bob')),
      '/repos/acme/api/pulls/2/commits': (_) => ok([
            {'sha': 'ccc'},
          ]),
      '/repos/acme/api/pulls/2/reviews': (_) => ok([
            {
              'id': 9,
              'user': user('Me'),
              'state': 'APPROVED',
              'body': 'lgtm',
              'submitted_at': '2026-11-12T09:00:00Z',
              'html_url': 'https://github.com/acme/api/pull/2#review-9',
            },
            {'id': 10, 'user': user('me'), 'state': 'PENDING', 'submitted_at': null},
          ]),
      '/repos/acme/api/pulls/2/comments': (_) => ok([
            {'pull_request_review_id': 9, 'user': user('me'), 'path': 'a.dart', 'line': 3, 'body': 'nit'},
            {'pull_request_review_id': 11, 'user': user('bob'), 'path': 'a.dart', 'line': 4, 'body': 'reply'},
          ]),
    });
  });
  tearDown(() => api.close());

  FakeContext ctx() => FakeContext(
        sourceId: 'gh',
        config: {'apiBaseUrl': '${api.url}/', 'login': 'me'},
        token: 't0k',
        now: DateTime.utc(2026, 11, 18),
      );

  test('emits PRs you are involved in and your submitted reviews', () async {
    final c = ctx();
    final obs = await GitHubSource().sync(c).toList();
    expect(lastQuery, 'is:pr involves:me updated:>=2026-10-19T00:00:00Z');
    expect(api.requests.first.headers.value('authorization'), 'Bearer t0k');
    expect(obs.map((o) => o.externalId), ['pr:acme/api#1', 'pr:acme/api#2', 'review:acme/api#2:9']);

    final pr1 = obs[0];
    expect(pr1.kind, PayloadKind.pullRequest);
    expect(pr1.content['roles'], ['author']);
    expect(pr1.content['commits'], ['aaa', 'bbb']);
    expect(pr1.content['mergedAt'], '2026-11-11T10:00:00Z');
    expect(pr1.content.containsKey('updated_at'), isFalse);
    expect(obs[1].content['roles'], ['reviewer', 'commenter']);

    final review = obs[2];
    expect(review.kind, PayloadKind.review);
    expect(review.content['state'], 'APPROVED');
    expect(review.content['comments'], hasLength(1));
    expect(review.occurredStart, DateTime.utc(2026, 11, 12, 9));
    expect(c.staged[''], '2026-11-13T10:00:00Z');
  });

  test('re-sync is idempotent through the Ingestor', () async {
    final db = ProfileDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 'gh', kind: SourceKind.github, name: 'gh'));
    final ingestor = Ingestor(db, utcOffset: (_) => Duration.zero);
    final c = ctx();
    expect((await ingestor.ingest('gh', await GitHubSource().sync(c).toList())).created, 3);
    c.commit();
    final r = await ingestor.ingest('gh', await GitHubSource().sync(c).toList());
    expect(r.unchanged, 3);
    expect(lastQuery, 'is:pr involves:me updated:>=2026-11-13T10:00:00Z');
  });

  test('rate limit stops the sync and keeps the cursor at the last finished PR', () async {
    limitPull2 = true;
    final c = ctx();
    final obs = await GitHubSource().sync(c).toList();
    expect(obs.map((o) => o.externalId), ['pr:acme/api#1']);
    expect(c.staged[''], '2026-11-12T10:00:00Z');
  });

  test('validate checks the token owner', () async {
    expect((await GitHubSource().validate(ctx())).ok, isTrue);
    final other = FakeContext(config: {'apiBaseUrl': api.url, 'login': 'alice'}, token: 'x');
    expect((await GitHubSource().validate(other)).ok, isFalse);
    expect((await GitHubSource().validate(FakeContext(config: {'apiBaseUrl': api.url}))).ok, isFalse);
  });
}
