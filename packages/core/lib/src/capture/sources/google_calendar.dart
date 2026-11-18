/// Google Calendar API v3 (LLD 04 §4.3): `events.list` per calendar with `syncToken` incremental sync.
/// Config: `{calendarIds: [String]}` (default `['primary']`). Secret: [GoogleTokens] JSON.
library;

import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../source.dart';
import 'calendar_common.dart';
import 'google_oauth.dart';

class GoogleCalendarSource implements Source {
  GoogleCalendarSource({Uri? apiBase, GoogleOAuth Function(Dio http)? oauth})
    : apiBase = apiBase ?? Uri.parse('https://www.googleapis.com/calendar/v3/'),
      _oauth = oauth ?? ((http) => GoogleOAuth(http: http));

  final Uri apiBase;
  final GoogleOAuth Function(Dio) _oauth;
  GoogleTokens? _tokens; // refreshed access token, kept for this instance's lifetime

  @override
  SourceKind get kind => SourceKind.googleCalendar;

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    try {
      await _get(ctx, 'users/me/calendarList', {'maxResults': '1'});
      return const SourceHealth.ok();
    } on DioException catch (e) {
      return SourceHealth.error('Google Calendar: ${e.response?.statusCode ?? e.message}');
    } on StateError catch (e) {
      return SourceHealth.error(e.message);
    }
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final ids = (ctx.config['calendarIds'] as List?)?.cast<String>() ?? const ['primary'];
    for (final id in ids) {
      final scope = 'calendar:$id';
      yield* _list(ctx, id, scope, await ctx.cursor(scope));
    }
  }

  Stream<PayloadObservation> _list(SourceContext ctx, String calendarId, String scope, String? token) async* {
    var syncToken = token;
    String? pageToken;
    while (true) {
      final q = <String, String>{
        'singleEvents': 'true',
        'maxResults': '250',
        if (syncToken != null) 'syncToken': syncToken else 'timeMin': isoUtc(ctx.initialImportFrom),
        'pageToken': ?pageToken,
      };
      final Map<String, Object?> page;
      try {
        page = await _get(ctx, 'calendars/${Uri.encodeComponent(calendarId)}/events', q);
      } on DioException catch (e) {
        // 410 Gone: sync token expired → full resync from the initial import date.
        if (e.response?.statusCode != 410 || syncToken == null) rethrow;
        syncToken = null;
        pageToken = null;
        continue;
      }
      for (final e in (page['items'] as List? ?? const []).cast<Map<String, Object?>>()) {
        final o = _observation(ctx, calendarId, e);
        if (o != null) yield o;
      }
      pageToken = page['nextPageToken'] as String?;
      if (pageToken == null) {
        final next = page['nextSyncToken'] as String?;
        if (next != null) ctx.setCursor(scope, next);
        return;
      }
    }
  }

  PayloadObservation? _observation(SourceContext ctx, String calendarId, Map<String, Object?> e) {
    final externalId = '$calendarId:${e['id']}';
    final start = _time(e['start']) ?? _time(e['originalStartTime']);
    final declined = (e['attendees'] as List? ?? const []).cast<Map<String, Object?>>().any(
      (a) => a['self'] == true && a['responseStatus'] == 'declined',
    );
    // Cancelled or declined → tombstone (a no-op when never ingested).
    if (e['status'] == 'cancelled' || declined || e['eventType'] == 'workingLocation' || start == null) {
      return calendarTombstone(externalId, start ?? ctx.clock.now());
    }
    final organizer = e['organizer'] as Map<String, Object?>?;
    return calendarObservation(
      externalId: externalId,
      title: e['summary'] as String? ?? '(no title)',
      start: start,
      end: _time(e['end']),
      allDay: (e['start'] as Map?)?['date'] != null,
      uid: e['iCalUID'] as String?,
      attendeesCount: (e['attendees'] as List?)?.length ?? 0,
      organizer: (organizer?['displayName'] ?? organizer?['email']) as String?,
      description: e['description'] as String?,
      location: e['location'] as String?,
      recurringEventId: e['recurringEventId'] as String?,
    );
  }

  static DateTime? _time(Object? t) {
    if (t is! Map) return null;
    if (t['dateTime'] case final String s) return DateTime.parse(s).toUtc();
    if (t['date'] case final String s) {
      final d = DateTime.parse(s);
      return localMidnight(d.year, d.month, d.day);
    }
    return null;
  }

  Future<Map<String, Object?>> _get(SourceContext ctx, String path, Map<String, String> query) async {
    final uri = apiBase.resolve(path).replace(queryParameters: query);
    Future<Response<Map<String, Object?>>> go({bool refresh = false}) async => ctx.http.getUri<Map<String, Object?>>(
      uri,
      options: Options(
        headers: {'Authorization': 'Bearer ${(await _accessToken(ctx, refresh: refresh)).accessToken}'},
        responseType: ResponseType.json,
      ),
    );
    try {
      return (await go()).data ?? const {};
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
      return (await go(refresh: true)).data ?? const {}; // expired early or clock skew: refresh once, retry
    }
  }

  Future<GoogleTokens> _accessToken(SourceContext ctx, {bool refresh = false}) async {
    final now = ctx.clock.now();
    if (_tokens case final t? when !refresh && !t.expired(now)) return t;
    final raw = await ctx.secret();
    if (raw == null) throw StateError('Google Calendar is not signed in');
    final stored = GoogleTokens.decode(raw);
    // The refreshed access token isn't written back (no secret writes from sources); refreshing once per
    // instance/hour is cheap and the refresh token is long-lived.
    return _tokens = (!refresh && _tokens == null && !stored.expired(now))
        ? stored
        : await _oauth(ctx.http).refresh(stored.refreshToken);
  }
}
