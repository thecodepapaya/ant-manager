import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/capture/sources/jira.dart';
import 'package:core/src/capture/sources/linear.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Api api;
  setUp(() async => api = await Api.start());
  tearDown(() => api.close());
  final now = DateTime.utc(2026, 11, 19, 12);

  group('Linear', () {
    Map<String, Object?> node(
      String id, {
      bool creator = false,
      bool assignee = false,
      List<Map> comments = const [],
      String? completedAt,
      String updated = '2026-11-10T00:00:00.000Z',
    }) => {
      'id': id,
      'identifier': 'ENG-$id',
      'title': 'T$id',
      'url': 'https://linear.app/x/$id',
      'createdAt': '2026-11-01T00:00:00.000Z',
      'updatedAt': updated,
      'completedAt': completedAt,
      'state': {'name': 'Done', 'type': 'completed'},
      'team': {'key': 'ENG'},
      'creator': {'isMe': creator},
      'assignee': assignee ? {'isMe': true} : null,
      'comments': {'nodes': comments},
    };

    late List<Map<String, Object?>> pages;
    setUp(() {
      pages = [];
      api.handler = (h) => Res({'data': pages.removeAt(0)});
    });

    Ctx ctx() => Ctx(token: 'lin_api_key', now: now);
    LinearSource src() => LinearSource(endpoint: Uri.parse('${api.url}/graphql'));

    test('request shape: raw API key, filter on me, cursor variables and pagination', () async {
      pages = [
        {
          'issues': {
            'pageInfo': {'hasNextPage': true, 'endCursor': 'c1'},
            'nodes': [node('1', creator: true, updated: '2026-11-12T00:00:00.000Z')],
          },
        },
        {
          'issues': {
            'pageInfo': {'hasNextPage': false, 'endCursor': null},
            'nodes': [
              node('2', assignee: true, completedAt: '2026-11-11T00:00:00.000Z', updated: '2026-11-11T00:00:00.000Z'),
            ],
          },
        },
      ];
      final c = ctx()..cursors['issues'] = '2026-11-05T00:00:00.000Z';
      final obs = await src().sync(c).toList();
      expect(obs.map((o) => o.title), ['ENG-1 T1', 'ENG-2 T2']);
      expect(api.hits[0].method, 'POST');
      expect(api.hits[0].headers.value('authorization'), 'lin_api_key');
      final b0 = api.hits[0].json;
      expect(b0['query'], allOf(contains('isMe'), contains('updatedAt: { gt: \$since }')));
      expect(b0['variables'], {'since': '2026-11-05T00:00:00.000Z', 'after': null});
      expect((api.hits[1].json['variables'] as Map)['after'], 'c1');
      expect(c.staged['issues'], '2026-11-12T00:00:00.000Z');
      expect(obs[1].content['completedByMe'], true);
      expect(obs[1].occurredStart, DateTime.utc(2026, 11, 11));
    });

    test('filtering: nothing of mine → dropped; my comments kept with times', () async {
      pages = [
        {
          'issues': {
            'pageInfo': {'hasNextPage': false},
            'nodes': [
              node('1'),
              node(
                '2',
                comments: [
                  {'id': 'c', 'body': 'lgtm', 'createdAt': '2026-11-03T00:00:00.000Z'},
                  {'id': 'd', 'body': 'again', 'createdAt': '2026-11-04T00:00:00.000Z'},
                ],
              ),
            ],
          },
        },
      ];
      final obs = await src().sync(ctx()).toList();
      expect(obs.single.externalId, '2');
      expect(obs.single.occurredStart, DateTime.utc(2026, 11, 3));
      expect(obs.single.occurredEnd, DateTime.utc(2026, 11, 4));
      expect((obs.single.content['myComments'] as List), hasLength(2));
    });

    test('first sync uses the initial import date; GraphQL errors fail', () async {
      pages = [
        {
          'issues': {
            'pageInfo': {'hasNextPage': false},
            'nodes': [],
          },
        },
      ];
      final c = ctx();
      await src().sync(c).toList();
      expect(
        DateTime.parse((api.hits.single.json['variables'] as Map)['since'] as String),
        now.subtract(const Duration(days: 30)),
      );
      api.handler = (_) => const Res({
        'errors': [
          {'message': 'Authentication required'},
        ],
      });
      await expectLater(src().sync(ctx()).toList(), throwsA(anything));
    });
  });

  group('Jira', () {
    late List<Map<String, Object?>> pages;
    setUp(() {
      pages = [];
      api.handler = (h) {
        if (h.uri.path == '/rest/api/3/myself') return const Res({'accountId': 'me-id'});
        if (h.uri.path == '/rest/api/3/search/jql' && h.method == 'POST') return Res(pages.removeAt(0));
        return null;
      };
    });
    Ctx ctx() => Ctx(config: {'siteUrl': '${api.url}/', 'email': 'me@x.dev'}, token: 'jt', now: now);

    Map<String, Object?> issue(
      String id, {
      Map? reporter,
      Map? assignee,
      List<Map> histories = const [],
      List<Map> comments = const [],
      String updated = '2026-11-10T10:00:00.000+0000',
    }) => {
      'id': id,
      'key': 'PRJ-$id',
      'fields': {
        'summary': 'S$id',
        'status': {'name': 'In Progress'},
        'issuetype': {'name': 'Task'},
        'project': {'key': 'PRJ'},
        'created': '2026-11-01T10:00:00.000+0000',
        'updated': updated,
        'reporter': reporter,
        'assignee': assignee,
        'comment': {'comments': comments},
      },
      'changelog': {'histories': histories},
    };

    test('request shape, pagination, filtering, ADF comments, cursor', () async {
      const me = {'accountId': 'me-id'};
      const other = {'accountId': 'x'};
      pages = [
        {
          'issues': [
            issue('1', reporter: other, assignee: other), // watching only
            issue('2', reporter: me, updated: '2026-11-12T08:30:00.000+0200'),
          ],
          'nextPageToken': 'n2',
        },
        {
          'issues': [
            issue(
              '3',
              assignee: other,
              histories: [
                {
                  'author': me,
                  'created': '2026-11-05T09:00:00.000+0000',
                  'items': [
                    {'field': 'status', 'fromString': 'To Do', 'toString': 'Done'},
                    {'field': 'assignee', 'fromString': 'a', 'toString': 'b'},
                  ],
                },
                {
                  'author': other,
                  'created': '2026-11-06T09:00:00.000+0000',
                  'items': [
                    {'field': 'status', 'fromString': 'Done', 'toString': 'Reopened'},
                  ],
                },
              ],
              comments: [
                {
                  'id': 'c1',
                  'author': me,
                  'created': '2026-11-07T09:00:00.000+0000',
                  'body': {
                    'type': 'doc',
                    'content': [
                      {
                        'type': 'paragraph',
                        'content': [
                          {'type': 'text', 'text': 'Shipped '},
                          {'type': 'text', 'text': 'it'},
                        ],
                      },
                    ],
                  },
                },
              ],
            ),
            issue('4', assignee: me),
          ],
        },
      ];
      final c = ctx()..cursors['issues'] = '2026-11-08T00:00:00.000Z';
      final obs = await JiraSource().sync(c).toList();
      expect(obs.map((o) => o.externalId), ['2', '3', '4']);
      final auth = api.hits.first.headers.value('authorization');
      expect(auth, 'Basic ${base64Encode(utf8.encode('me@x.dev:jt'))}');
      final searches = api.to('/rest/api/3/search/jql').toList();
      final b0 = searches[0].json;
      expect(
        b0['jql'],
        allOf(contains('currentUser()'), contains('updated >= "2026-11-07"'), contains('ORDER BY updated ASC')),
      );
      expect(b0['expand'], 'changelog');
      expect(b0.containsKey('nextPageToken'), false);
      expect(searches[1].json['nextPageToken'], 'n2');

      final three = obs[1].content;
      expect(three['myTransitions'], [
        {'from': 'To Do', 'to': 'Done', 'at': '2026-11-05T09:00:00.000+0000'},
      ]);
      expect(((three['myComments'] as List).single as Map)['body'], 'Shipped it');
      expect(three['url'], '${api.url}/browse/PRJ-3');
      expect(obs[1].occurredStart, DateTime.utc(2026, 11, 5, 9));
      expect(obs[1].occurredEnd, DateTime.utc(2026, 11, 7, 9));
      expect(obs[0].content['createdByMe'], true);
      expect(obs[2].content['assignedToMe'], true);
      // 2026-11-12T08:30+02:00 = 06:30Z is the max updated.
      expect(DateTime.parse(c.staged['issues']!), DateTime.utc(2026, 11, 12, 6, 30));
    });
  });

  group('transcripts', () {
    final at = DateTime.utc(2026, 11, 10, 15);

    test('vtt: header/NOTE skipped, voice tags → speakers, duplicates dropped, end from last cue', () {
      const vtt =
          '﻿WEBVTT - Weekly\nKind: captions\n\nNOTE this is\na comment\n\n1\n00:00:01.000 --> 00:00:04.000\n<v Ann>Hello &amp; welcome</v>\n\n2\n00:00:04.000 --> 00:00:06.500 align:start\n<v Ann>Hello &amp; welcome</v>\n\n00:01:02.000 --> 01:00:05.250\n<v.loud Bob>Thanks <b>all</b></v>\n';
      final o = transcriptObservation('Weekly Sync.VTT', vtt, at);
      expect(o.kind, PayloadKind.transcript);
      expect(o.title, 'Weekly Sync');
      expect(o.content['text'], 'Ann: Hello & welcome\nBob: Thanks all');
      expect(o.occurredStart, at);
      expect(o.occurredEnd, at.add(const Duration(hours: 1, seconds: 5, milliseconds: 250)));
    });

    test('vtt without hours in timings', () {
      final o = transcriptObservation('a.vtt', 'WEBVTT\n\n00:01.000 --> 00:04.500\nhi\n', at);
      expect(o.content['text'], 'hi');
      expect(o.occurredEnd, at.add(const Duration(seconds: 4, milliseconds: 500)));
    });

    test('srt: numbers and comma milliseconds, CRLF', () {
      const srt =
          '1\r\n00:00:01,000 --> 00:00:02,000\r\nFirst line\r\nsecond line\r\n\r\n2\r\n00:10:00,000 --> 00:10:03,040\r\nLast\r\n';
      final o = transcriptObservation('call.srt', srt, at);
      expect(o.content['text'], 'First line\nsecond line\nLast');
      expect(o.occurredEnd, at.add(const Duration(minutes: 10, seconds: 3, milliseconds: 40)));
    });

    test('txt: trimmed plain text, no end; external id stable per name + text', () {
      final o = transcriptObservation('notes.txt', '\n  Ann: hi\nBob: yo  \n', at);
      expect(o.content['text'], 'Ann: hi\nBob: yo');
      expect(o.occurredEnd, isNull);
      expect(o.title, 'notes');
      expect(
        transcriptObservation('notes.txt', 'Ann: hi\nBob: yo', at.add(const Duration(hours: 1))).externalId,
        o.externalId,
      );
      expect(transcriptObservation('other.txt', 'Ann: hi\nBob: yo', at).externalId, isNot(o.externalId));
    });
  });
}
