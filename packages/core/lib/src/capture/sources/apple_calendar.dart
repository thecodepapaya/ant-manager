/// Apple Calendar via the EventKit bridge (macOS only, LLD 04 §4.3).
///
/// Window: [last sync − 7 d (or initial import date), now + 1 d]. Bridge maps carry: id, title, start, end,
/// attendeesCount, declined, iCalUID, notes, location, calendarTitle. `id` must identify one occurrence
/// (EventKit's eventIdentifier is shared by a series, so the adapter appends the occurrence date).
library;

import 'dart:convert';

import '../../domain/enums.dart';
import '../source.dart';
import 'calendar_common.dart';

class AppleCalendarSource implements WatchableSource {
  static const _scope = 'window';

  @override
  SourceKind get kind => SourceKind.appleCalendar;

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    final cal = ctx.calendar;
    if (cal == null) return const SourceHealth.error('Apple Calendar is only available on macOS');
    return await cal.requestAccess()
        ? const SourceHealth.ok()
        : const SourceHealth.error('Calendar access was denied. Allow it in System Settings → Privacy → Calendars.');
  }

  @override
  Stream<void> changes(SourceContext ctx) => ctx.calendar?.changes() ?? const Stream.empty();

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final cal = ctx.calendar;
    if (cal == null) throw StateError('Apple Calendar is only available on macOS');
    final now = ctx.clock.now();
    final cursor = decodeCursor(await ctx.cursor(_scope));
    final last = DateTime.tryParse(cursor['lastSync'] as String? ?? '');
    final from = last?.subtract(const Duration(days: 7)) ?? ctx.initialImportFrom;
    final to = now.add(const Duration(days: 1));
    final prev = SeenWindow.decode(cursor['seen']);

    final seen = <String, String>{};
    for (final m in await cal.events(from, to)) {
      final id = m['id'] as String;
      final start = _date(m['start']);
      if (m['declined'] == true || start == null) {
        yield calendarTombstone(id, start ?? now);
        continue;
      }
      seen[id] = isoUtc(start);
      final title = m['title'] as String?;
      yield calendarObservation(
        externalId: id,
        title: (title == null || title.isEmpty) ? '(no title)' : title,
        start: start,
        end: _date(m['end']),
        uid: m['iCalUID'] as String?,
        attendeesCount: (m['attendeesCount'] as num?)?.toInt() ?? 0,
        description: m['notes'] as String?,
        location: m['location'] as String?,
        calendar: m['calendarTitle'] as String?,
      );
    }
    yield* Stream.fromIterable(prev.vanished(seen.keys.toSet(), from, to));
    ctx.setCursor(_scope, jsonEncode({'lastSync': isoUtc(now), 'seen': seen})); // the window only moves forward
  }

  /// Bridge dates: DateTime, ISO-8601 string, or epoch milliseconds.
  static DateTime? _date(Object? v) => switch (v) {
    DateTime d => d.toUtc(),
    String s => DateTime.tryParse(s)?.toUtc(),
    num n => DateTime.fromMillisecondsSinceEpoch(n.toInt(), isUtc: true),
    _ => null,
  };
}
