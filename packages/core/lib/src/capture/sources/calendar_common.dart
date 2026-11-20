/// Shared helpers for the calendar sources (Google, Apple, ICS). Same content shape everywhere (LLD 04 §4.3).
library;

import 'dart:convert';

import '../../domain/enums.dart';
import '../source.dart';

/// Exact-identity grouping key for one calendar occurrence (#57).
///
/// iCal UID alone is shared by every instance of a recurring series, so the occurrence start is part of the key.
/// Every calendar source builds it the same way, so the same meeting seen via Google, Apple and ICS lands on one
/// evidence row.
String calendarGroupKey(String uid, DateTime start) => '$uid@${isoUtc(start)}';

String isoUtc(DateTime t) => t.toUtc().toIso8601String();

/// Midnight in the machine's local time zone, as UTC (all-day events).
DateTime localMidnight(int y, int m, int d) => DateTime(y, m, d).toUtc();

PayloadObservation calendarObservation({
  required String externalId,
  required String title,
  required DateTime start,
  DateTime? end,
  bool allDay = false,
  String? uid,
  int attendeesCount = 0,
  String? organizer,
  String? description,
  String? location,
  String? recurringEventId,
  String? calendar,
}) {
  final content = <String, Object?>{
    'title': title,
    'start': isoUtc(start),
    'end': ?(end == null ? null : isoUtc(end)),
    'allDay': allDay,
    'attendeesCount': attendeesCount,
    'organizer': ?organizer,
    'description': ?_blankToNull(description),
    'location': ?_blankToNull(location),
    'iCalUID': ?uid,
    'recurringEventId': ?recurringEventId,
    'calendar': ?calendar,
  };
  return PayloadObservation(
    externalId: externalId,
    kind: PayloadKind.calendarEvent,
    content: content,
    occurredStart: start.toUtc(),
    occurredEnd: end?.toUtc(),
    title: title,
    groupKey: uid == null ? null : calendarGroupKey(uid, start),
  );
}

PayloadObservation calendarTombstone(String externalId, DateTime at) => PayloadObservation(
  externalId: externalId,
  kind: PayloadKind.calendarEvent,
  content: const {},
  occurredStart: at.toUtc(),
  title: '',
  tombstone: true,
);

String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s;

/// Occurrences seen in a fetch window, kept in a cursor so ones that vanish upstream become tombstones.
/// Only ids whose start is inside the current window are checked, so a moving window never deletes history.
class SeenWindow {
  SeenWindow(this.seen);
  final Map<String, String> seen; // externalId → start ISO (UTC)

  factory SeenWindow.decode(Object? json) =>
      SeenWindow(json is Map ? json.map((k, v) => MapEntry(k as String, v as String)) : {});

  Object toJson() => seen;

  /// Ids previously seen in [from, to] that are absent from [current].
  List<PayloadObservation> vanished(Set<String> current, DateTime from, DateTime to) => [
    for (final e in seen.entries)
      if (!current.contains(e.key))
        if (DateTime.parse(e.value) case final s when !s.isBefore(from) && !s.isAfter(to)) calendarTombstone(e.key, s),
  ];
}

Map<String, Object?> decodeCursor(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final v = jsonDecode(raw);
  return v is Map<String, Object?> ? v : {};
}
