import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/services.dart';

/// [CalendarBridge] on EventKit (macOS), implemented in `macos/Runner/CalendarBridge.swift`.
/// Platform channels: UI isolate only (the engine reaches it through the port bridge).
///
/// Event maps: {id, title, start, end (ISO-8601 UTC), attendeesCount, declined, iCalUID,
/// notes, location, calendarTitle}.
class MacCalendarBridge implements CalendarBridge {
  static const _methods = MethodChannel('ant/calendar');
  static const _changes = EventChannel('ant/calendar/changes');

  /// EventKit exists on macOS only; elsewhere the engine gets no calendar bridge.
  static bool get supported => Platform.isMacOS;

  @override
  Future<bool> requestAccess() async => await _methods.invokeMethod<bool>('requestAccess') ?? false;

  @override
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to) async {
    final raw = await _methods.invokeListMethod<Object?>('events', {
      'from': from.toUtc().millisecondsSinceEpoch,
      'to': to.toUtc().millisecondsSinceEpoch,
    });
    return [
      for (final e in raw ?? const <Object?>[]) (e as Map<Object?, Object?>).cast<String, Object?>(),
    ];
  }

  @override
  Stream<void> changes() => _changes.receiveBroadcastStream().map((_) {});
}
