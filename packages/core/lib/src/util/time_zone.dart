import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'ids.dart';

/// The profile zone's UTC offset at an instant (#87).
typedef UtcOffset = Duration Function(DateTime at);

var _loaded = false;

/// Per-instant UTC offset of the IANA zone [name] (bundled `latest_10y` tz database, #109).
/// A name the database doesn't know (e.g. a Windows zone abbreviation) uses the system offset.
UtcOffset zoneOffset(String name) {
  if (!_loaded) {
    tzdata.initializeTimeZones();
    _loaded = true;
  }
  final tz.Location loc;
  try {
    loc = tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return (t) => t.toLocal().timeZoneOffset;
  }
  return (t) => Duration(milliseconds: loc.timeZone(t.millisecondsSinceEpoch).offset);
}

/// Today's YYYY-MM-DD in the zone given by [offset].
String todayIn(UtcOffset offset, [DateTime? now]) {
  final t = now ?? DateTime.now();
  return dayOf(t, offset(t));
}
