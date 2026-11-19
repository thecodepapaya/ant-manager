import 'dart:io';

import 'package:core/core.dart';

/// The active profile's zone offset in the UI isolate (#87, #109), set when the engine starts.
/// Day labels, "today" and report dates use it.
UtcOffset profileUtcOffset = (t) => t.toLocal().timeZoneOffset;

/// Today's YYYY-MM-DD in the active profile's zone.
String profileToday() => todayIn(profileUtcOffset);

/// YYYY-MM-DD of [t] in the active profile's zone.
String profileDayOf(DateTime t) => dayOf(t, profileUtcOffset(t));

/// IANA name of the system time zone, used as a new profile's default (#87).
/// macOS/Linux: the `/etc/localtime` symlink target. Elsewhere (Windows) Dart has no IANA
/// name, so the zone abbreviation is stored and day boundaries fall back to the system offset.
String systemTimeZoneName() {
  final tz = Platform.environment['TZ'];
  if (tz != null && tz.contains('/')) return tz;
  if (!Platform.isWindows) {
    try {
      final target = Link('/etc/localtime').targetSync();
      final i = target.indexOf('zoneinfo/');
      if (i >= 0) return target.substring(i + 'zoneinfo/'.length);
    } on FileSystemException {
      // Not a symlink: fall through.
    }
  }
  return DateTime.now().timeZoneName;
}
