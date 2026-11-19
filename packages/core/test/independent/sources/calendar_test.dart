import 'dart:convert';
import 'dart:io';

import 'package:core/src/capture/sources/apple_calendar.dart';
import 'package:core/src/capture/sources/google_calendar.dart';
import 'package:core/src/capture/sources/ics.dart';
import 'package:core/src/capture/sources/ics_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

const nyTz = '''BEGIN:VTIMEZONE
TZID:America/New_York
BEGIN:DAYLIGHT
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
DTSTART:20070311T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZNAME:EDT
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
DTSTART:20071104T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZNAME:EST
END:STANDARD
END:VTIMEZONE''';

String cal(String body, {String tz = ''}) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$tz\r\n$body\r\nEND:VCALENDAR\r\n'.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

String ev(String uid, String props) => 'BEGIN:VEVENT\nUID:$uid\n$props\nEND:VEVENT';

final from = DateTime.utc(2025, 12, 1);
final to = DateTime.utc(2026, 12, 31);

List<IcsOccurrence> occ(String src, [DateTime? f, DateTime? t]) => icsOccurrences(src, f ?? from, t ?? to);
List<DateTime> starts(String src, [DateTime? f, DateTime? t]) => occ(src, f, t).map((o) => o.start).toList();

void main() {
  group('ICS parser', () {
    test('DAILY COUNT', () {
      expect(starts(cal(ev('d', 'DTSTART:20260301T100000Z\nDTEND:20260301T103000Z\nRRULE:FREQ=DAILY;COUNT=5'))), [
        for (var d = 1; d <= 5; d++) DateTime.utc(2026, 3, d, 10),
      ]);
    });

    test('DAILY INTERVAL=3 UNTIL (UTC, inclusive)', () {
      expect(starts(cal(ev('d', 'DTSTART:20260301T100000Z\nRRULE:FREQ=DAILY;INTERVAL=3;UNTIL=20260310T100000Z'))), [
        DateTime.utc(2026, 3, 1, 10),
        DateTime.utc(2026, 3, 4, 10),
        DateTime.utc(2026, 3, 7, 10),
        DateTime.utc(2026, 3, 10, 10),
      ]);
    });

    test('WEEKLY INTERVAL=2 BYDAY=MO,WE with UNTIL', () {
      // 2026-03-02 is a Monday.
      expect(
        starts(
          cal(ev('w', 'DTSTART:20260302T090000Z\nRRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20260320T235959Z')),
        ),
        [
          DateTime.utc(2026, 3, 2, 9),
          DateTime.utc(2026, 3, 4, 9),
          DateTime.utc(2026, 3, 16, 9),
          DateTime.utc(2026, 3, 18, 9),
        ],
      );
    });

    test('WEEKLY without BYDAY repeats the DTSTART weekday', () {
      expect(starts(cal(ev('w', 'DTSTART:20260305T090000Z\nRRULE:FREQ=WEEKLY;COUNT=3'))), [
        DateTime.utc(2026, 3, 5, 9),
        DateTime.utc(2026, 3, 12, 9),
        DateTime.utc(2026, 3, 19, 9),
      ]);
    });

    test('MONTHLY BYMONTHDAY', () {
      expect(starts(cal(ev('m', 'DTSTART:20260115T120000Z\nRRULE:FREQ=MONTHLY;BYMONTHDAY=15;COUNT=3'))), [
        DateTime.utc(2026, 1, 15, 12),
        DateTime.utc(2026, 2, 15, 12),
        DateTime.utc(2026, 3, 15, 12),
      ]);
    });

    test('MONTHLY on the 31st skips short months', () {
      expect(starts(cal(ev('m', 'DTSTART:20260131T120000Z\nRRULE:FREQ=MONTHLY;COUNT=3'))), [
        DateTime.utc(2026, 1, 31, 12),
        DateTime.utc(2026, 3, 31, 12),
        DateTime.utc(2026, 5, 31, 12),
      ]);
    });

    test('MONTHLY BYDAY=2TU and -1FR', () {
      expect(starts(cal(ev('m', 'DTSTART:20260113T120000Z\nRRULE:FREQ=MONTHLY;BYDAY=2TU;COUNT=3'))), [
        DateTime.utc(2026, 1, 13, 12),
        DateTime.utc(2026, 2, 10, 12),
        DateTime.utc(2026, 3, 10, 12),
      ]);
      expect(starts(cal(ev('m', 'DTSTART:20260130T120000Z\nRRULE:FREQ=MONTHLY;BYDAY=-1FR;COUNT=3'))), [
        DateTime.utc(2026, 1, 30, 12),
        DateTime.utc(2026, 2, 27, 12),
        DateTime.utc(2026, 3, 27, 12),
      ]);
    });

    test('EXDATE removes an instance (still counted by COUNT)', () {
      expect(starts(cal(ev('x', 'DTSTART:20260301T100000Z\nRRULE:FREQ=DAILY;COUNT=3\nEXDATE:20260302T100000Z'))), [
        DateTime.utc(2026, 3, 1, 10),
        DateTime.utc(2026, 3, 3, 10),
      ]);
    });

    test('EXDATE with TZID matches a TZID series', () {
      final src = cal(
        ev(
          'x',
          'DTSTART;TZID=America/New_York:20260301T100000\nRRULE:FREQ=DAILY;COUNT=3\nEXDATE;TZID=America/New_York:20260302T100000',
        ),
        tz: nyTz,
      );
      expect(starts(src), [DateTime.utc(2026, 3, 1, 15), DateTime.utc(2026, 3, 3, 15)]);
    });

    test('RECURRENCE-ID override replaces its instance; cancelled override removes it', () {
      final src = cal(
        [
          ev('r', 'SUMMARY:Standup\nDTSTART:20260301T100000Z\nDTEND:20260301T101500Z\nRRULE:FREQ=DAILY;COUNT=3'),
          ev('r', 'SUMMARY:Moved\nRECURRENCE-ID:20260302T100000Z\nDTSTART:20260302T150000Z\nDTEND:20260302T151500Z'),
          ev('r', 'SUMMARY:Gone\nRECURRENCE-ID:20260303T100000Z\nSTATUS:CANCELLED\nDTSTART:20260303T100000Z'),
        ].join('\n'),
      );
      final o = occ(src);
      expect(o.map((e) => e.start), [DateTime.utc(2026, 3, 1, 10), DateTime.utc(2026, 3, 2, 15)]);
      expect(o[1].event.text('SUMMARY'), 'Moved');
      expect(o[1].instant, DateTime.utc(2026, 3, 2, 10));
      expect(o[1].end, DateTime.utc(2026, 3, 2, 15, 15));
    });

    test('TZID via VTIMEZONE: wall time kept across DST', () {
      // US DST starts 2026-03-08.
      final o = occ(
        cal(
          ev(
            'tz',
            'DTSTART;TZID=America/New_York:20260302T090000\nDTEND;TZID=America/New_York:20260302T100000\nRRULE:FREQ=WEEKLY;COUNT=2',
          ),
          tz: nyTz,
        ),
      );
      expect(o.map((e) => e.start), [DateTime.utc(2026, 3, 2, 14), DateTime.utc(2026, 3, 9, 13)]);
      expect(o.map((e) => e.end), [DateTime.utc(2026, 3, 2, 15), DateTime.utc(2026, 3, 9, 14)]);
    });

    test('TZID quoted parameter and summer/winter offsets', () {
      final src = cal(
        [
          ev('a', 'DTSTART;TZID="America/New_York":20260701T090000'),
          ev('b', 'DTSTART;TZID=America/New_York:20261201T090000'),
        ].join('\n'),
        tz: nyTz,
      );
      expect(starts(src), [DateTime.utc(2026, 7, 1, 13), DateTime.utc(2026, 12, 1, 14)]);
    });

    test('VTIMEZONE with historical rules: an ended (UNTIL) rule does not apply', () {
      const hist = '''BEGIN:VTIMEZONE
TZID:America/New_York
BEGIN:DAYLIGHT
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
DTSTART:19870405T020000
RRULE:FREQ=YEARLY;BYMONTH=4;BYDAY=1SU;UNTIL=20060402T070000Z
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
DTSTART:19671029T020000
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU;UNTIL=20061029T060000Z
END:STANDARD
BEGIN:DAYLIGHT
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
DTSTART:20070311T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
DTSTART:20071104T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE''';
      expect(starts(cal(ev('h', 'DTSTART;TZID=America/New_York:20261028T090000'), tz: hist)), [
        DateTime.utc(2026, 10, 28, 13),
      ]);
    });

    test('all-day events: local midnight, one day long, flagged', () {
      final o = occ(cal(ev('ad', 'DTSTART;VALUE=DATE:20260310\nDTEND;VALUE=DATE:20260311'))).single;
      expect(o.allDay, true);
      expect(o.start, DateTime(2026, 3, 10).toUtc());
      expect(o.end, DateTime(2026, 3, 11).toUtc());
      final noEnd = occ(cal(ev('ad2', 'DTSTART;VALUE=DATE:20260310'))).single;
      expect(noEnd.end, DateTime(2026, 3, 11).toUtc());
    });

    test('all-day recurring with UNTIL as a DATE (inclusive)', () {
      expect(starts(cal(ev('ad', 'DTSTART;VALUE=DATE:20260310\nRRULE:FREQ=DAILY;UNTIL=20260312'))), [
        DateTime(2026, 3, 10).toUtc(),
        DateTime(2026, 3, 11).toUtc(),
        DateTime(2026, 3, 12).toUtc(),
      ]);
    });

    test('line unfolding and text unescaping', () {
      final src = cal(
        ev(
          'u',
          'DTSTART:20260301T100000Z\nSUMMARY:Quarterly plan\n ning with\n\t the team\nDESCRIPTION:a\\, b\\; c\\nnext',
        ),
      );
      final e = occ(src).single.event;
      expect(e.text('SUMMARY'), 'Quarterly planning with the team');
      expect(e.text('DESCRIPTION'), 'a, b; c\nnext');
    });

    test('DURATION gives the end', () {
      expect(
        occ(cal(ev('d', 'DTSTART:20260301T100000Z\nDURATION:PT1H30M'))).single.end,
        DateTime.utc(2026, 3, 1, 11, 30),
      );
    });

    test('only occurrences inside the window', () {
      final src = cal(ev('d', 'DTSTART:20260301T100000Z\nRRULE:FREQ=DAILY'));
      expect(starts(src, DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 12, 12)), [
        DateTime.utc(2026, 3, 10, 10),
        DateTime.utc(2026, 3, 11, 10),
        DateTime.utc(2026, 3, 12, 10),
      ]);
    });

    test('cancelled master is omitted', () {
      final src = cal(
        [ev('c', 'DTSTART:20260301T100000Z\nSTATUS:CANCELLED'), ev('k', 'DTSTART:20260302T100000Z')].join('\n'),
      );
      expect(occ(src).map((o) => o.uid), ['k']);
    });
  });

  group('IcsSource', () {
    late Directory dir;
    late File file;
    final now = DateTime.utc(2026, 3, 20, 12);
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ind_ics_');
      file = File(p.join(dir.path, 'cal.ics'));
    });
    tearDown(() => dir.delete(recursive: true));

    Ctx ctx() => Ctx(config: {'url': file.path}, now: now);

    test('external ids, group keys, organizer and recurring occurrences stay separate', () async {
      file.writeAsStringSync(
        cal(
          [
            ev(
              'one@x',
              'SUMMARY:One-off\nDTSTART:20260310T100000Z\nORGANIZER;CN=Ann:mailto:ann@x.dev\nATTENDEE:mailto:a@x\nATTENDEE:mailto:b@x',
            ),
            ev('series@x', 'SUMMARY:Standup\nDTSTART:20260316T090000Z\nRRULE:FREQ=DAILY;COUNT=3'),
          ].join('\n'),
        ),
      );
      final c = ctx();
      final obs = await IcsSource().sync(c).toList();
      final one = obs.singleWhere((o) => o.externalId == 'one@x');
      expect(one.groupKey, 'one@x@2026-03-10T10:00:00.000Z');
      expect(one.content['organizer'], 'Ann');
      expect(one.content['attendeesCount'], 2);
      final series = obs.where((o) => o.externalId.startsWith('series@x/')).toList();
      expect(series, hasLength(3));
      expect(series.map((o) => o.groupKey).toSet(), hasLength(3));
      expect(series.first.externalId, 'series@x/2026-03-16T09:00:00.000Z');
    });

    test('an occurrence that vanishes inside the window becomes a tombstone', () async {
      file.writeAsStringSync(
        cal([ev('a', 'DTSTART:20260310T100000Z'), ev('b', 'DTSTART:20260311T100000Z')].join('\n')),
      );
      final c = ctx();
      await IcsSource().sync(c).toList();
      c.commit();
      file.writeAsStringSync(cal(ev('a', 'DTSTART:20260310T100000Z')));
      final obs = await IcsSource().sync(c).toList();
      final tomb = obs.where((o) => o.tombstone).toList();
      expect(tomb.map((o) => o.externalId), ['b']);
    });
  });

  group('Google Calendar', () {
    late Api api;
    final now = DateTime.utc(2026, 3, 20, 12);
    late List<Res Function(Hit)> pages;
    setUp(() async {
      api = await Api.start();
      pages = [];
      api.handler = (h) => h.uri.path.endsWith('/events') && pages.isNotEmpty ? pages.removeAt(0)(h) : null;
    });
    tearDown(() => api.close());

    final tokens = jsonEncode({'access_token': 'at', 'refresh_token': 'rt', 'expires_at': '2027-01-01T00:00:00Z'});
    Ctx ctx() => Ctx(
      config: const {
        'calendarIds': ['primary'],
      },
      token: tokens,
      now: now,
    );
    GoogleCalendarSource src() => GoogleCalendarSource(apiBase: Uri.parse('${api.url}/cal/'));

    Map<String, Object?> gev(String id, String start, {String? uid, Map<String, Object?> extra = const {}}) => {
      'id': id,
      'summary': 'S $id',
      'iCalUID': uid ?? '$id@google.com',
      'start': {'dateTime': start},
      'end': {'dateTime': start},
      ...extra,
    };

    test('first sync: timeMin + singleEvents, pagination, nextSyncToken stored, bearer token', () async {
      pages = [
        (_) => Res({
          'items': [gev('e1', '2026-03-10T10:00:00Z')],
          'nextPageToken': 'p2',
        }),
        (_) => Res({
          'items': [gev('e2', '2026-03-11T10:00:00Z')],
          'nextSyncToken': 'sync1',
        }),
      ];
      final c = ctx();
      final obs = await src().sync(c).toList();
      expect(obs.map((o) => o.externalId), ['primary:e1', 'primary:e2']);
      final hits = api.to('/cal/calendars/primary/events').toList();
      expect(hits[0].uri.queryParameters['singleEvents'], 'true');
      expect(DateTime.parse(hits[0].uri.queryParameters['timeMin']!), now.subtract(const Duration(days: 30)));
      expect(hits[1].uri.queryParameters['pageToken'], 'p2');
      expect(hits[0].headers.value('authorization'), 'Bearer at');
      expect(c.staged['calendar:primary'], 'sync1');
    });

    test('declined / cancelled → tombstone', () async {
      pages = [
        (_) => Res({
          'items': [
            gev(
              'd',
              '2026-03-10T10:00:00Z',
              extra: {
                'attendees': [
                  {'email': 'me@x', 'self': true, 'responseStatus': 'declined'},
                  {'email': 'o@x', 'responseStatus': 'accepted'},
                ],
              },
            ),
            {'id': 'c', 'status': 'cancelled'},
            gev('ok', '2026-03-12T10:00:00Z'),
          ],
          'nextSyncToken': 's',
        }),
      ];
      final obs = await src().sync(ctx()).toList();
      expect(
        {for (final o in obs) o.externalId: o.tombstone},
        {'primary:d': true, 'primary:c': true, 'primary:ok': false},
      );
    });

    test('410 on the sync token → full resync from timeMin', () async {
      pages = [
        (_) => const Res({
          'error': {'code': 410},
        }, status: 410),
        (_) => Res({
          'items': [gev('e1', '2026-03-10T10:00:00Z')],
          'nextSyncToken': 'fresh',
        }),
      ];
      final c = ctx()..cursors['calendar:primary'] = 'old';
      final obs = await src().sync(c).toList();
      expect(obs, hasLength(1));
      final hits = api.to('/cal/calendars/primary/events').toList();
      expect(hits[0].uri.queryParameters['syncToken'], 'old');
      expect(hits[1].uri.queryParameters.containsKey('syncToken'), false);
      expect(hits[1].uri.queryParameters['timeMin'], isNotNull);
      expect(c.staged['calendar:primary'], 'fresh');
    });

    test('recurring instances share iCalUID but get distinct group keys', () async {
      pages = [
        (_) => Res({
          'items': [
            gev('r_1', '2026-03-10T10:00:00Z', uid: 'series@x', extra: {'recurringEventId': 'r'}),
            gev('r_2', '2026-03-11T10:00:00Z', uid: 'series@x', extra: {'recurringEventId': 'r'}),
          ],
          'nextSyncToken': 's',
        }),
      ];
      final obs = await src().sync(ctx()).toList();
      expect(obs.map((o) => o.groupKey), ['series@x@2026-03-10T10:00:00.000Z', 'series@x@2026-03-11T10:00:00.000Z']);
    });

    test('all-day event uses local midnight', () async {
      pages = [
        (_) => Res({
          'items': [
            {
              'id': 'ad',
              'iCalUID': 'ad@x',
              'summary': 'Offsite',
              'start': {'date': '2026-03-10'},
              'end': {'date': '2026-03-11'},
            },
          ],
          'nextSyncToken': 's',
        }),
      ];
      final o = (await src().sync(ctx()).toList()).single;
      expect(o.content['allDay'], true);
      expect(o.occurredStart, DateTime(2026, 3, 10).toUtc());
    });
  });

  group('Apple Calendar', () {
    final now = DateTime.utc(2026, 3, 20, 12);

    test('declined → tombstone; vanished inside the window → tombstone; outside → kept', () async {
      final bridge = Bridge()
        ..items = [
          {'id': 'a', 'title': 'A', 'start': '2026-03-18T10:00:00Z', 'iCalUID': 'ua'},
          {'id': 'b', 'title': 'B', 'start': '2026-03-17T10:00:00Z', 'iCalUID': 'ub'},
          {'id': 'old', 'title': 'Old', 'start': '2026-03-01T10:00:00Z'},
          {'id': 'd', 'title': 'D', 'start': '2026-03-19T10:00:00Z', 'declined': true},
        ];
      final c = Ctx(now: now, calendar: bridge);
      final first = await AppleCalendarSource().sync(c).toList();
      expect({for (final o in first) o.externalId: o.tombstone}, {'a': false, 'b': false, 'old': false, 'd': true});
      c.commit();

      bridge.items = [
        {'id': 'a', 'title': 'A', 'start': '2026-03-18T10:00:00Z', 'iCalUID': 'ua'},
      ];
      final second = await AppleCalendarSource().sync(c).toList();
      expect(second.where((o) => o.tombstone).map((o) => o.externalId), ['b']);
      // The window moved: from = last sync − 7 days.
      expect(bridge.calls.last.$1, now.subtract(const Duration(days: 7)));
      expect(bridge.calls.last.$2, now.add(const Duration(days: 1)));
    });
  });

  test('same occurrence groups across Google, Apple and ICS', () async {
    const uid = 'shared-123@corp';
    final expected = 'shared-123@corp@2026-03-10T14:00:00.000Z';

    final api = await Api.start();
    addTearDown(api.close);
    api.handler = (_) => Res({
      'items': [
        {
          'id': 'g1',
          'iCalUID': uid,
          'summary': 'Sync',
          'start': {'dateTime': '2026-03-10T10:00:00-04:00'},
          'end': {'dateTime': '2026-03-10T10:30:00-04:00'},
        },
      ],
      'nextSyncToken': 's',
    });
    final now = DateTime.utc(2026, 3, 20);
    final tokens = jsonEncode({'access_token': 'at', 'refresh_token': 'rt', 'expires_at': '2027-01-01T00:00:00Z'});
    final g = (await GoogleCalendarSource(
      apiBase: Uri.parse('${api.url}/'),
    ).sync(Ctx(token: tokens, now: now)).toList()).single;

    final bridge = Bridge()
      ..items = [
        {'id': 'x', 'title': 'Sync', 'start': DateTime.utc(2026, 3, 10, 14), 'iCalUID': uid},
      ];
    final a = (await AppleCalendarSource().sync(Ctx(now: now, calendar: bridge)).toList()).single;

    final dir = await Directory.systemTemp.createTemp('ind_ics2_');
    addTearDown(() => dir.delete(recursive: true));
    final f = File(p.join(dir.path, 'c.ics'))
      ..writeAsStringSync(cal(ev(uid, 'SUMMARY:Sync\nDTSTART;TZID=America/New_York:20260310T100000'), tz: nyTz));
    final i = (await IcsSource().sync(Ctx(config: {'url': f.uri.toString()}, now: now)).toList()).single;

    expect([g.groupKey, a.groupKey, i.groupKey], [expected, expected, expected]);
  });
}
