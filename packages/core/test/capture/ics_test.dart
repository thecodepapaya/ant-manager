import 'dart:io';

import 'package:core/src/capture/sources/ics.dart';
import 'package:core/src/capture/sources/ics_parser.dart';
import 'package:test/test.dart';

import 'calendar_fakes.dart';

String cal(String body) => 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$body\r\nEND:VCALENDAR\r\n';

String ev(String uid, List<String> lines) => ['BEGIN:VEVENT', 'UID:$uid', ...lines, 'END:VEVENT'].join('\r\n');

const newYork = '''BEGIN:VTIMEZONE
TZID:America/New_York
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

final from = DateTime.utc(2025, 1, 1);
final to = DateTime.utc(2027, 1, 1);

List<DateTime> starts(String ics) => icsOccurrences(ics, from, to).map((o) => o.start).toList();

void main() {
  group('parser', () {
    test('unfolds lines, unescapes text, reads params', () {
      final root = parseIcs(
        cal(
          ev('u1', [
            'SUMMARY:Plan\\, review\\nnext',
            '  steps',
            'ORGANIZER;CN="Doe, Jane":mailto:jane@x.com',
            'DTSTART:20261110T150000Z',
          ]),
        ),
      );
      final e = root.children.single.where('VEVENT').single;
      expect(e.text('SUMMARY'), 'Plan, review\nnext steps');
      expect(e.prop('ORGANIZER')!.params['CN'], 'Doe, Jane');
      expect(e.prop('ORGANIZER')!.value, 'mailto:jane@x.com');
    });

    test('TZID resolves through VTIMEZONE across a DST change', () {
      final ics = cal(
        '$newYork\r\n${ev('w', ['DTSTART;TZID=America/New_York:20260302T090000', 'DTEND;TZID=America/New_York:20260302T093000', 'RRULE:FREQ=WEEKLY;COUNT=3'])}',
      );
      final occ = icsOccurrences(ics, from, to);
      expect(occ.map((o) => o.start), [
        DateTime.utc(2026, 3, 2, 14), // EST
        DateTime.utc(2026, 3, 9, 13), // EDT
        DateTime.utc(2026, 3, 16, 13),
      ]);
      expect(occ[1].end, DateTime.utc(2026, 3, 9, 13, 30));
      expect(occ.first.instant, occ.first.start);
    });

    test('all-day DATE uses local midnight and lasts one day', () {
      final o = icsOccurrences(cal(ev('d', ['DTSTART;VALUE=DATE:20261110'])), from, to).single;
      expect(o.allDay, isTrue);
      expect(o.start, DateTime(2026, 11, 10).toUtc());
      expect(o.end, DateTime(2026, 11, 11).toUtc());
      expect(o.instant, isNull);
    });

    test('DURATION sets the end', () {
      final o = icsOccurrences(cal(ev('d', ['DTSTART:20261110T150000Z', 'DURATION:PT45M'])), from, to).single;
      expect(o.end, DateTime.utc(2026, 11, 10, 15, 45));
    });
  });

  group('RRULE', () {
    test('DAILY with UNTIL, EXDATE, a moved and a cancelled instance', () {
      final ics = cal(
        [
          ev('s', [
            'SUMMARY:Standup',
            'DTSTART:20261102T100000Z',
            'DTEND:20261102T101500Z',
            'RRULE:FREQ=DAILY;UNTIL=20261106T100000Z',
            'EXDATE:20261104T100000Z',
          ]),
          ev('s', ['RECURRENCE-ID:20261103T100000Z', 'DTSTART:20261103T150000Z', 'SUMMARY:Standup (moved)']),
          ev('s', ['RECURRENCE-ID:20261105T100000Z', 'DTSTART:20261105T100000Z', 'STATUS:CANCELLED']),
        ].join('\r\n'),
      );
      final occ = icsOccurrences(ics, from, to);
      expect(occ.map((o) => o.start), [
        DateTime.utc(2026, 11, 2, 10),
        DateTime.utc(2026, 11, 3, 15),
        DateTime.utc(2026, 11, 6, 10),
      ]);
      expect(occ[1].instant, DateTime.utc(2026, 11, 3, 10));
      expect(occ[1].event.text('SUMMARY'), 'Standup (moved)');
    });

    test('WEEKLY with INTERVAL, BYDAY and COUNT', () {
      expect(starts(cal(ev('w', ['DTSTART:20261102T090000Z', 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5']))), [
        DateTime.utc(2026, 11, 2, 9),
        DateTime.utc(2026, 11, 4, 9),
        DateTime.utc(2026, 11, 16, 9),
        DateTime.utc(2026, 11, 18, 9),
        DateTime.utc(2026, 11, 30, 9),
      ]);
    });

    test('MONTHLY on the last Friday', () {
      expect(starts(cal(ev('m', ['DTSTART:20260130T120000Z', 'RRULE:FREQ=MONTHLY;BYDAY=-1FR;COUNT=3']))), [
        DateTime.utc(2026, 1, 30, 12),
        DateTime.utc(2026, 2, 27, 12),
        DateTime.utc(2026, 3, 27, 12),
      ]);
    });

    test('MONTHLY on the 31st skips short months', () {
      expect(starts(cal(ev('m', ['DTSTART:20260131T120000Z', 'RRULE:FREQ=MONTHLY;COUNT=3']))), [
        DateTime.utc(2026, 1, 31, 12),
        DateTime.utc(2026, 3, 31, 12),
        DateTime.utc(2026, 5, 31, 12),
      ]);
    });

    test('expansion stops at the window end', () {
      final occ = icsOccurrences(
        cal(ev('d', ['DTSTART:20261101T080000Z', 'RRULE:FREQ=DAILY'])),
        DateTime.utc(2026, 11, 10),
        DateTime.utc(2026, 11, 12, 12),
      );
      expect(occ.map((o) => o.start), [
        DateTime.utc(2026, 11, 10, 8),
        DateTime.utc(2026, 11, 11, 8),
        DateTime.utc(2026, 11, 12, 8),
      ]);
    });

    test('unsupported rule parts keep only the first instance', () {
      expect(starts(cal(ev('x', ['DTSTART:20261102T090000Z', 'RRULE:FREQ=MONTHLY;BYDAY=MO,TU;BYSETPOS=-1']))), [
        DateTime.utc(2026, 11, 2, 9),
      ]);
    });
  });

  group('IcsSource', () {
    late RawServer server;
    var body = '';
    var etag = '"v1"';

    setUp(() async {
      server = await RawServer.start((req, res) async {
        if (req.headers.value('if-none-match') == etag) {
          res.statusCode = 304;
          return;
        }
        res.headers.set('etag', etag);
        res.headers.contentType = ContentType('text', 'calendar', charset: 'utf-8');
        res.write(body);
      });
    });
    tearDown(() => server.close());

    test('maps events, honours ETag, tombstones events that vanish', () async {
      body = cal(
        [
          ev('A', [
            'SUMMARY:Design review',
            'DTSTART:20261110T150000Z',
            'DTEND:20261110T160000Z',
            'ATTENDEE:mailto:a@x',
            'ATTENDEE:mailto:b@x',
            'ORGANIZER;CN=Jane:mailto:jane@x',
          ]),
          ev('B', ['SUMMARY:1:1', 'DTSTART:20261112T150000Z']),
          ev('Old', ['SUMMARY:Too old', 'DTSTART:20260101T150000Z']),
        ].join('\r\n'),
      );
      final ctx = CalContext(config: {'url': '${server.url}/feed.ics'}, now: DateTime.utc(2026, 11, 18, 12));
      final src = IcsSource();
      expect((await src.validate(ctx)).ok, isTrue);

      final first = await src.sync(ctx).toList();
      ctx.commit();
      expect(first.map((o) => o.externalId), ['A', 'B']);
      final a = first.first;
      expect(a.title, 'Design review');
      expect(a.groupKey, 'A@2026-11-10T15:00:00.000Z');
      expect(a.content['attendeesCount'], 2);
      expect(a.content['organizer'], 'Jane');
      expect(a.content['iCalUID'], 'A');
      expect(a.occurredEnd, DateTime.utc(2026, 11, 10, 16));

      expect(await src.sync(ctx).toList(), isEmpty); // 304
      expect(server.requests.last.headers.value('if-none-match'), '"v1"');

      etag = '"v2"';
      body = cal(ev('A', ['SUMMARY:Design review', 'DTSTART:20261110T150000Z', 'DTEND:20261110T160000Z']));
      final third = await src.sync(ctx).toList();
      expect(third.where((o) => o.tombstone).map((o) => o.externalId), ['B']);
    });
  });
}
