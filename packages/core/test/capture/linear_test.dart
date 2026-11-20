import 'package:core/core.dart';
import 'package:core/src/capture/sources/linear.dart';
import 'package:test/test.dart';

import 'fake_context.dart';
import 'fake_server.dart';

Map<String, Object?> issue(
  String id, {
  bool creator = false,
  bool assignee = false,
  String? completedAt,
  List<Map<String, Object?>> comments = const [],
}) => {
  'id': id,
  'identifier': 'ENG-$id',
  'title': 'Issue $id',
  'description': 'desc',
  'url': 'https://linear.app/x/issue/ENG-$id',
  'createdAt': '2026-11-01T10:00:00.000Z',
  'updatedAt': '2026-11-17T10:00:00.000Z',
  'completedAt': completedAt,
  'state': {
    'name': completedAt == null ? 'In Progress' : 'Done',
    'type': completedAt == null ? 'started' : 'completed',
  },
  'team': {'key': 'ENG'},
  'project': null,
  'creator': {'isMe': creator},
  'assignee': assignee ? {'isMe': true} : null,
  'comments': {'nodes': comments},
};

void main() {
  late FakeApi api;
  final pages = <Object?>[];

  setUp(() async {
    api = await FakeApi.start({'/graphql': (req) => ok(pages.removeAt(0))});
  });
  tearDown(() => api.close());

  LinearSource src() => LinearSource(endpoint: Uri.parse('${api.url}/graphql'));

  test('validate uses the viewer query and the raw API key', () async {
    pages.add({
      'data': {
        'viewer': {'id': 'u1'},
      },
    });
    expect((await src().validate(FakeContext(token: 'lin_api_x'))).ok, isTrue);
    expect(api.requests.single.headers.value('authorization'), 'lin_api_x');
  });

  test('pages through my issues and keeps only my activity', () async {
    pages
      ..add({
        'data': {
          'issues': {
            'pageInfo': {'hasNextPage': true, 'endCursor': 'c1'},
            'nodes': [issue('1', creator: true), issue('2', assignee: true, completedAt: '2026-11-15T09:00:00.000Z')],
          },
        },
      })
      ..add({
        'data': {
          'issues': {
            'pageInfo': {'hasNextPage': false, 'endCursor': null},
            'nodes': [
              issue(
                '3',
                comments: [
                  {'id': 'k1', 'body': 'LGTM', 'createdAt': '2026-11-12T08:00:00.000Z'},
                ],
              ),
              issue('4'), // matched upstream but nothing of mine
            ],
          },
        },
      });
    final ctx = FakeContext(token: 'k', now: DateTime.utc(2026, 11, 18));
    final obs = await src().sync(ctx).toList();
    ctx.commit();
    expect(obs.map((o) => o.externalId), ['1', '2', '3']);
    expect(obs.every((o) => o.kind == PayloadKind.issue), isTrue);
    expect(obs[0].occurredStart, DateTime.utc(2026, 11, 1, 10));
    expect(obs[1].occurredStart, DateTime.utc(2026, 11, 15, 9));
    expect(obs[1].content['completedByMe'], isTrue);
    expect(obs[2].title, 'ENG-3 Issue 3');
    expect((obs[2].content['myComments'] as List).single, containsPair('body', 'LGTM'));
    expect(ctx.cursors['issues'], '2026-11-17T10:00:00.000Z');
  });

  test('GraphQL errors fail the sync', () async {
    pages.add({
      'errors': [
        {'message': 'Authentication required'},
      ],
    });
    expect(src().sync(FakeContext(token: 'k')).toList(), throwsStateError);
  });
}
