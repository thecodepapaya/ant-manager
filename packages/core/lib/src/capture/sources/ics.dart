/// ICS feed or file (also Outlook/M365, #82). Config: `{url}`: an http(s)/webcal URL, a file:// URL or a path.
/// Fetch with ETag, parse, expand RRULE within [initial import date, now + 1 d] (LLD 04 §4.3).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../source.dart';
import 'calendar_common.dart';
import 'ics_parser.dart';

class IcsSource implements Source {
  static const _scope = 'feed';

  @override
  SourceKind get kind => SourceKind.ics;

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    try {
      final body = (await _fetch(ctx, null)).$1;
      return body != null && body.contains('BEGIN:VCALENDAR')
          ? const SourceHealth.ok()
          : const SourceHealth.error('That link did not return a calendar (.ics) feed');
    } on DioException catch (e) {
      return SourceHealth.error('Calendar feed: ${e.response?.statusCode ?? e.message}');
    } on FileSystemException catch (e) {
      return SourceHealth.error('Calendar file: ${e.message}');
    }
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final now = ctx.clock.now();
    final today = isoUtc(now).substring(0, 10);
    final cursor = decodeCursor(await ctx.cursor(_scope));
    // The window end moves daily, so the ETag is only trusted within the same day.
    final etag = cursor['day'] == today ? cursor['etag'] as String? : null;
    final (body, newEtag) = await _fetch(ctx, etag);
    if (body == null) return; // 304 Not Modified

    final from = ctx.initialImportFrom;
    final to = now.add(const Duration(days: 1));
    final seen = <String, String>{};
    for (final o in icsOccurrences(body, from, to)) {
      final id = o.instant == null ? o.uid : '${o.uid}/${isoUtc(o.instant!)}';
      seen[id] = isoUtc(o.start);
      final e = o.event;
      final organizer = e.prop('ORGANIZER');
      final title = e.text('SUMMARY');
      yield calendarObservation(
        externalId: id,
        title: (title == null || title.isEmpty) ? '(no title)' : title,
        start: o.start,
        end: o.end,
        allDay: o.allDay,
        uid: o.uid,
        attendeesCount: e.all('ATTENDEE').length,
        organizer:
            organizer?.params['CN'] ?? organizer?.value.replaceFirst(RegExp('^mailto:', caseSensitive: false), ''),
        description: e.text('DESCRIPTION'),
        location: e.text('LOCATION'),
      );
    }
    yield* Stream.fromIterable(SeenWindow.decode(cursor['seen']).vanished(seen.keys.toSet(), from, to));
    ctx.setCursor(_scope, jsonEncode({'etag': newEtag, 'day': today, 'seen': seen}));
  }

  /// Returns (body, etag); body is null on 304.
  Future<(String?, String?)> _fetch(SourceContext ctx, String? etag) async {
    final raw = (ctx.config['url'] as String? ?? '').trim();
    if (raw.isEmpty) throw StateError('No calendar URL configured');
    var uri = Uri.parse(raw);
    if (uri.scheme == 'webcal' || uri.scheme == 'webcals') uri = uri.replace(scheme: 'https');
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      final file = uri.scheme == 'file' ? File.fromUri(uri) : File(raw);
      return (await file.readAsString(), null);
    }
    final r = await ctx.http.getUri<String>(
      uri,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'If-None-Match': ?etag},
        validateStatus: (s) => s != null && ((s >= 200 && s < 300) || s == 304),
      ),
    );
    if (r.statusCode == 304) return (null, etag);
    return (r.data ?? '', r.headers.value('etag'));
  }
}
