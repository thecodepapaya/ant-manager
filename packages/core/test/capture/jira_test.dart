import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/capture/sources/jira.dart';
import 'package:test/test.dart';

import 'fake_context.dart';
import 'fake_server.dart';

const me = {'accountId': 'me-1'};
const other = {'accountId': 'other'};

Map<String, Object?> adf(String text) => {
  'type': 'doc',
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  ],
};

void main() {
  late FakeApi api;
  final pages = <Object?>[];

  setUp(() async {
    api = await FakeApi.start({
      '/rest/api/3/myself': (req) => ok(me),
      '/rest/api/3/search/jql': (req) => ok(pages.removeAt(0)),
    });
  });
  tearDown(() => api.close());

  FakeContext ctx() =>
      FakeContext(config: {'siteUrl': api.url, 'email': 'me@x.com'}, token: 'tok', now: DateTime.utc(2026, 11, 18));

  test('validate with basic auth', () async {
    expect((await JiraSource().validate(ctx())).ok, isTrue);
    expect(api.requests.single.headers.value('authorization'), 'Basic ${base64Encode(utf8.encode('me@x.com:tok'))}');
  });

  test('my transitions and comments from the changelog', () async {
    pages
      ..add({
        'issues': [
          {
            'id': '100',
            'key': 'PROJ-1',
            'fields': {
              'summary': 'Fix login',
              'status': {'name': 'Done'},
              'issuetype': {'name': 'Bug'},
              'project': {'key': 'PROJ'},
              'created': '2026-11-01T10:00:00.000+0000',
              'updated': '2026-11-16T10:00:00.000+0530',
              'reporter': other,
              'assignee': me,
              'comment': {
                'comments': [
                  {
                    'id': 'c1',
                    'author': me,
                    'body': adf('Root cause found'),
                    'created': '2026-11-14T09:00:00.000+0000',
                  },
                  {'id': 'c2', 'author': other, 'body': adf('thanks'), 'created': '2026-11-14T10:00:00.000+0000'},
                ],
              },
            },
            'changelog': {
              'histories': [
                {
                  'author': me,
                  'created': '2026-11-15T09:00:00.000+0000',
                  'items': [
                    {'field': 'status', 'fromString': 'In Progress', 'toString': 'Done'},
                    {'field': 'assignee', 'fromString': null, 'toString': 'Me'},
                  ],
                },
                {
                  'author': other,
                  'created': '2026-11-13T09:00:00.000+0000',
                  'items': [
                    {'field': 'status', 'fromString': 'To Do', 'toString': 'In Progress'},
                  ],
                },
              ],
            },
          },
        ],
        'nextPageToken': 'n1',
      })
      ..add({
        'issues': [
          {
            'id': '101',
            'key': 'PROJ-2',
            'fields': {'summary': 'Watched only', 'updated': '2026-11-17T10:00:00.000+0000', 'reporter': other},
          },
        ],
      });
    final c = ctx();
    final obs = await JiraSource().sync(c).toList();
    c.commit();
    final o = obs.single;
    expect(o.kind, PayloadKind.issue);
    expect(o.title, 'PROJ-1 Fix login');
    expect(o.occurredStart, DateTime.utc(2026, 11, 14, 9));
    expect(o.occurredEnd, DateTime.utc(2026, 11, 15, 9));
    expect(o.content['myTransitions'], [
      {'from': 'In Progress', 'to': 'Done', 'at': '2026-11-15T09:00:00.000+0000'},
    ]);
    expect((o.content['myComments'] as List).single, containsPair('body', 'Root cause found'));
    expect(o.content['url'], '${api.url}/browse/PROJ-1');
    expect(c.cursors['issues'], '2026-11-17T10:00:00.000Z');
  });
}
