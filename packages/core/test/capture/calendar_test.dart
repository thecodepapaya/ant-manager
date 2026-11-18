import 'dart:convert';
import 'dart:io';

import 'package:core/src/capture/sources/apple_calendar.dart';
import 'package:core/src/capture/sources/google_calendar.dart';
import 'package:core/src/capture/sources/google_oauth.dart';
import 'package:test/test.dart';

import 'calendar_fakes.dart';

final now = DateTime.utc(2026, 11, 18, 12);

void main() {
  group('Google Calendar', () {
    late RawServer server;
    late Map<String, String> lastForm;

    void json(HttpResponse res, Object body, [int status = 200]) {
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(body));
    }

    setUp(() async {
      server = await RawServer.start((req, res) async {
        if (req.uri.path == '/token') {
          lastForm = Uri.splitQueryString(await utf8.decoder.bind(req).join());
          return json(res, {'access_token': 'fresh', 'expires_in': 3600, 'refresh_token': 'r2'});
        }
        if (req.headers.value('authorization') != 'Bearer fresh') return json(res, {}, 401);
        final q = req.uri.queryParameters;
        if (req.uri.path.endsWith('/calendarList')) return json(res, {'items': []});
        if (!req.uri.path.endsWith('/calendars/primary/events')) return json(res, {}, 404);
        expect(q['singleEvents'], 'true');
        switch (q['syncToken']) {
          case 'expired':
            return json(res, {'error': 'gone'}, 410);
          case 'tok1':
            return json(res, {
              'items': [
                {'id': 'e1', 'status': 'cancelled'},
              ],
              'nextSyncToken': 'tok2',
            });
        }
        expect(q['timeMin'], '2026-10-19T12:00:00.000Z');
        if (q['pageToken'] == null) {
          return json(res, {
            'items': [
              {
                'id': 'e1',
                'status': 'confirmed',
                'summary': 'Design review',
                'description': 'Agenda',
                'iCalUID': 'uid1@google.com',
                'start': {'dateTime': '2026-11-10T10:00:00-05:00'},
                'end': {'dateTime': '2026-11-10T11:00:00-05:00'},
                'organizer': {'email': 'jane@x.com', 'displayName': 'Jane'},
                'attendees': [
                  {'email': 'me@x.com', 'self': true, 'responseStatus': 'accepted'},
                  {'email': 'jane@x.com', 'responseStatus': 'accepted'},
                ],
              },
              {
                'id': 'e2',
                'summary': 'Declined',
                'start': {'dateTime': '2026-11-11T10:00:00Z'},
                'attendees': [
                  {'email': 'me@x.com', 'self': true, 'responseStatus': 'declined'},
                ],
              },
            ],
            'nextPageToken': 'p2',
          });
        }
        return json(res, {
          'items': [
            {
              'id': 'e3_20261112',
              'summary': 'Offsite',
              'iCalUID': 'uid3',
              'recurringEventId': 'e3',
              'start': {'date': '2026-11-12'},
              'end': {'date': '2026-11-13'},
            },
          ],
          'nextSyncToken': 'tok1',
        });
      });
    });
    tearDown(() => server.close());

    GoogleCalendarSource source() => GoogleCalendarSource(
      apiBase: Uri.parse('${server.url}/calendar/v3/'),
      oauth: (http) => GoogleOAuth(http: http, tokenEndpoint: Uri.parse('${server.url}/token')),
    );

    final expiredSecret = GoogleTokens(
      accessToken: 'stale',
      refreshToken: 'r1',
      expiresAt: DateTime.utc(2026, 1, 1),
    ).encode();

    test('initial sync pages, skips declined, refreshes the token', () async {
      final ctx = CalContext(token: expiredSecret, now: now);
      final src = source();
      expect((await src.validate(ctx)).ok, isTrue);
      final obs = await src.sync(ctx).toList();
      ctx.commit();
      expect(lastForm['grant_type'], 'refresh_token');
      expect(lastForm['refresh_token'], 'r1');

      final live = obs.where((o) => !o.tombstone).toList();
      expect(live.map((o) => o.externalId), ['primary:e1', 'primary:e3_20261112']);
      expect(obs.where((o) => o.tombstone).map((o) => o.externalId), ['primary:e2']);
      final e1 = live.first;
      expect(e1.occurredStart, DateTime.utc(2026, 11, 10, 15));
      expect(e1.groupKey, 'uid1@google.com@2026-11-10T15:00:00.000Z');
      expect(e1.content, containsPair('attendeesCount', 2));
      expect(e1.content, containsPair('organizer', 'Jane'));
      expect(e1.content, containsPair('description', 'Agenda'));
      final e3 = live.last;
      expect(e3.content['allDay'], isTrue);
      expect(e3.occurredStart, DateTime(2026, 11, 12).toUtc());
      expect(e3.content['recurringEventId'], 'e3');
      expect(ctx.cursors['calendar:primary'], 'tok1');
    });

    test('incremental sync turns cancellations into tombstones', () async {
      final ctx = CalContext(token: expiredSecret, now: now)..cursors['calendar:primary'] = 'tok1';
      final obs = await source().sync(ctx).toList();
      ctx.commit();
      expect(obs.single.tombstone, isTrue);
      expect(obs.single.externalId, 'primary:e1');
      expect(ctx.cursors['calendar:primary'], 'tok2');
    });

    test('410 Gone triggers a full resync from the initial import date', () async {
      final ctx = CalContext(token: expiredSecret, now: now)..cursors['calendar:primary'] = 'expired';
      final obs = await source().sync(ctx).toList();
      ctx.commit();
      expect(obs.length, 3);
      expect(ctx.cursors['calendar:primary'], 'tok1');
    });

    test('OAuth loopback sign-in with PKCE', () async {
      final oauth = GoogleOAuth(tokenEndpoint: Uri.parse('${server.url}/token'));
      late Uri opened;
      final tokens = await oauth.signIn((uri) async {
        opened = uri;
        final q = uri.queryParameters;
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('${q['redirect_uri']}/?code=abc&state=${q['state']}'));
        final res = await req.close();
        expect(res.statusCode, 200);
        await res.drain<void>();
        client.close();
      });
      expect(opened.queryParameters['scope'], googleCalendarScope);
      expect(opened.queryParameters['code_challenge_method'], 'S256');
      expect(lastForm['code'], 'abc');
      expect(codeChallenge(lastForm['code_verifier']!), opened.queryParameters['code_challenge']);
      expect(tokens.accessToken, 'fresh');
      expect(tokens.refreshToken, 'r2');
      expect(GoogleTokens.decode(tokens.encode()).refreshToken, 'r2');
    });
  });

  group('Apple Calendar', () {
    Map<String, Object?> item(String id, DateTime start, {bool declined = false}) => {
      'id': id,
      'title': 'Event $id',
      'start': start.toIso8601String(),
      'end': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'attendeesCount': 3,
      'declined': declined,
      'iCalUID': 'uid-$id',
      'notes': 'notes',
      'location': 'Room 1',
      'calendarTitle': 'Work',
    };

    test('window, declined, vanished events and change events', () async {
      final bridge = FakeBridge()
        ..items = [
          item('a', DateTime.utc(2026, 11, 16, 9)),
          item('b', DateTime.utc(2026, 11, 17, 9)),
          item('c', DateTime.utc(2026, 11, 17, 11), declined: true),
        ];
      final ctx = CalContext(bridge: bridge, now: now);
      final src = AppleCalendarSource();
      expect((await src.validate(ctx)).ok, isTrue);

      final first = await src.sync(ctx).toList();
      ctx.commit();
      expect(bridge.calls.single, (DateTime.utc(2026, 10, 19, 12), DateTime.utc(2026, 11, 19, 12)));
      expect(first.where((o) => !o.tombstone).map((o) => o.externalId), ['a', 'b']);
      expect(first.where((o) => o.tombstone).map((o) => o.externalId), ['c']);
      final a = first.first;
      expect(a.groupKey, 'uid-a@2026-11-16T09:00:00.000Z');
      expect(a.occurredEnd, DateTime.utc(2026, 11, 16, 10));
      expect(a.content, containsPair('calendar', 'Work'));
      expect(a.content, containsPair('description', 'notes'));

      bridge.items = [item('a', DateTime.utc(2026, 11, 16, 9))];
      final second = await src.sync(ctx).toList();
      expect(bridge.calls.last.$1, DateTime.utc(2026, 11, 11, 12)); // last sync − 7 d
      expect(second.where((o) => o.tombstone).map((o) => o.externalId), ['b']);

      final changed = expectLater(src.changes(ctx), emits(null));
      bridge.changeCtl.add(null);
      await changed;
    });

    test('unavailable off macOS', () async {
      expect((await AppleCalendarSource().validate(CalContext(now: now))).ok, isFalse);
    });
  });
}
