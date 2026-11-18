/// A small iCalendar (RFC 5545) reader: unfolding, VEVENT properties, DTSTART/DTEND (UTC, TZID via the feed's
/// VTIMEZONE, floating, DATE) and RRULE expansion for the common forms only (#67):
/// FREQ=DAILY/WEEKLY/MONTHLY with INTERVAL, COUNT, UNTIL, BYDAY (MONTHLY: ordinals like 2TU / -1FR), BYMONTHDAY
/// (MONTHLY), WKST, plus EXDATE and RECURRENCE-ID overrides. Any other rule part → only the first instance.
library;

final class IcsProp {
  const IcsProp(this.name, this.params, this.value);
  final String name;
  final Map<String, String> params;
  final String value;
}

final class IcsComponent {
  IcsComponent(this.name);
  final String name;
  final props = <IcsProp>[];
  final children = <IcsComponent>[];

  IcsProp? prop(String n) {
    for (final p in props) {
      if (p.name == n) return p;
    }
    return null;
  }

  Iterable<IcsProp> all(String n) => props.where((p) => p.name == n);
  String? text(String n) => switch (prop(n)) {
    final p? => unescapeText(p.value),
    null => null,
  };
  Iterable<IcsComponent> where(String n) => children.where((c) => c.name == n);
}

/// Parses [source] into a root component whose children are the VCALENDAR(s).
IcsComponent parseIcs(String source) {
  final root = IcsComponent('ROOT');
  final stack = [root];
  for (final line in unfold(source)) {
    final p = parseLine(line);
    if (p == null) continue;
    if (p.name == 'BEGIN') {
      final c = IcsComponent(p.value.toUpperCase());
      stack.last.children.add(c);
      stack.add(c);
    } else if (p.name == 'END') {
      if (stack.length > 1) stack.removeLast();
    } else {
      stack.last.props.add(p);
    }
  }
  return root;
}

/// RFC 5545 §3.1: a CRLF followed by a space or tab continues the previous line.
List<String> unfold(String s) {
  final out = <String>[];
  for (final raw in s.split(RegExp(r'\r\n|\n|\r'))) {
    if (raw.isEmpty) continue;
    if ((raw.startsWith(' ') || raw.startsWith('\t')) && out.isNotEmpty) {
      out.last += raw.substring(1);
    } else {
      out.add(raw);
    }
  }
  return out;
}

IcsProp? parseLine(String line) {
  var inQuote = false;
  var colon = -1;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') inQuote = !inQuote;
    if (c == ':' && !inQuote) {
      colon = i;
      break;
    }
  }
  if (colon < 0) return null;
  final head = _splitUnquoted(line.substring(0, colon), ';');
  final params = <String, String>{};
  for (final p in head.skip(1)) {
    final eq = p.indexOf('=');
    if (eq < 0) continue;
    var v = p.substring(eq + 1);
    if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
    params[p.substring(0, eq).toUpperCase()] = v;
  }
  return IcsProp(head.first.toUpperCase(), params, line.substring(colon + 1));
}

List<String> _splitUnquoted(String s, String sep) {
  final out = <String>[];
  var inQuote = false;
  var start = 0;
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '"') inQuote = !inQuote;
    if (s[i] == sep && !inQuote) {
      out.add(s.substring(start, i));
      start = i + 1;
    }
  }
  out.add(s.substring(start));
  return out;
}

String unescapeText(String v) => v.replaceAllMapped(RegExp(r'\\([nN\\;,])'), (m) {
  final c = m[1]!;
  return (c == 'n' || c == 'N') ? '\n' : c;
});

// ---------------------------------------------------------------------------------------------------------------
// Time

/// A parsed DATE / DATE-TIME. [wall] holds the written fields in a UTC DateTime used as a plain container.
final class IcsTime {
  const IcsTime(this.wall, {this.isDate = false, this.isUtc = false, this.tzid});
  final DateTime wall;
  final bool isDate;
  final bool isUtc;
  final String? tzid;

  IcsTime withWall(DateTime w) => IcsTime(w, isDate: isDate, isUtc: isUtc, tzid: tzid);
}

final _dateRe = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$');

IcsTime? parseIcsTime(String value, {String? tzid}) {
  final m = _dateRe.firstMatch(value.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m[i]!);
  if (m[4] == null) return IcsTime(DateTime.utc(g(1), g(2), g(3)), isDate: true);
  final wall = DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6));
  return IcsTime(wall, isUtc: m[7] != null, tzid: m[7] != null ? null : tzid);
}

final _durRe = RegExp(r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$');

Duration? parseIcsDuration(String v) {
  final m = _durRe.firstMatch(v.trim());
  if (m == null) return null;
  int g(int i) => int.tryParse(m[i] ?? '') ?? 0;
  final d = Duration(days: g(2) * 7 + g(3), hours: g(4), minutes: g(5), seconds: g(6));
  return m[1] == '-' ? -d : d;
}

/// Turns wall-clock times into UTC instants using the feed's VTIMEZONE blocks. Unknown TZIDs and floating times
/// use the machine's local zone (usually the user's own).
class IcsZones {
  IcsZones(IcsComponent root) {
    for (final cal in root.children) {
      for (final tz in cal.where('VTIMEZONE')) {
        final id = tz.prop('TZID')?.value;
        if (id == null) continue;
        final rules = [for (final c in tz.children) ?_TzRule.parse(c)];
        if (rules.isNotEmpty) _zones[id] = rules;
      }
    }
  }

  final _zones = <String, List<_TzRule>>{};

  DateTime toUtc(IcsTime t) {
    final w = t.wall;
    if (t.isUtc) return w;
    if (t.isDate) return DateTime(w.year, w.month, w.day).toUtc();
    final id = t.tzid;
    if (id != null && const {'UTC', 'Etc/UTC', 'GMT', 'Z'}.contains(id)) return w;
    final rules = id == null ? null : _zones[id];
    if (rules == null) return DateTime(w.year, w.month, w.day, w.hour, w.minute, w.second).toUtc();
    return w.subtract(_offsetAt(rules, w));
  }

  static Duration _offsetAt(List<_TzRule> rules, DateTime wall) {
    DateTime? best;
    Duration? offset;
    for (final r in rules) {
      for (final y in [wall.year - 1, wall.year]) {
        final at = r.transitionIn(y);
        if (at != null && !at.isAfter(wall) && (best == null || at.isAfter(best))) {
          best = at;
          offset = r.offsetTo;
        }
      }
    }
    return offset ?? (rules.firstWhere((r) => !r.daylight, orElse: () => rules.first)).offsetTo;
  }
}

class _TzRule {
  _TzRule(this.start, this.offsetTo, this.daylight, this.month, this.nth, this.weekday);
  final DateTime start;
  final Duration offsetTo;
  final bool daylight;
  final int? month, nth, weekday; // yearly rule, e.g. BYMONTH=3;BYDAY=2SU

  static _TzRule? parse(IcsComponent c) {
    if (c.name != 'STANDARD' && c.name != 'DAYLIGHT') return null;
    final start = parseIcsTime(c.prop('DTSTART')?.value ?? '');
    final off = _offset(c.prop('TZOFFSETTO')?.value ?? '');
    if (start == null || off == null) return null;
    int? month, nth, weekday;
    final rule = _parts(c.prop('RRULE')?.value);
    if (rule['FREQ'] == 'YEARLY') {
      month = int.tryParse(rule['BYMONTH'] ?? '');
      final d = _byDayRe.firstMatch(rule['BYDAY'] ?? '');
      if (d != null) {
        nth = int.tryParse(d[1] ?? '') ?? 1;
        weekday = _weekdays[d[2]];
      }
    }
    return _TzRule(start.wall, off, c.name == 'DAYLIGHT', month, nth, weekday);
  }

  DateTime? transitionIn(int year) {
    if (year < start.year) return null;
    if (month == null || nth == null || weekday == null) return year == start.year ? start : null;
    final d = _nthWeekday(year, month!, nth!, weekday!);
    return d == null ? null : DateTime.utc(year, month!, d.day, start.hour, start.minute, start.second);
  }

  static Duration? _offset(String v) {
    final m = RegExp(r'^([+-])(\d{2})(\d{2})(\d{2})?$').firstMatch(v.trim());
    if (m == null) return null;
    final d = Duration(hours: int.parse(m[2]!), minutes: int.parse(m[3]!), seconds: int.parse(m[4] ?? '0'));
    return m[1] == '-' ? -d : d;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Recurrence

const _weekdays = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
final _byDayRe = RegExp(r'^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$');
const _supportedParts = {'FREQ', 'INTERVAL', 'COUNT', 'UNTIL', 'BYDAY', 'BYMONTHDAY', 'WKST'};

Map<String, String> _parts(String? rrule) => {
  if (rrule != null)
    for (final kv in rrule.split(';'))
      if (kv.contains('=')) kv.substring(0, kv.indexOf('=')).toUpperCase(): kv.substring(kv.indexOf('=') + 1),
};

int _daysIn(int y, int m) => DateTime.utc(y, m + 1, 0).day;

DateTime? _nthWeekday(int y, int m, int nth, int weekday) {
  final days = [
    for (var d = 1; d <= _daysIn(y, m); d++)
      if (DateTime.utc(y, m, d).weekday == weekday) DateTime.utc(y, m, d),
  ];
  final i = nth > 0 ? nth - 1 : days.length + nth;
  return (i >= 0 && i < days.length) ? days[i] : null;
}

/// Wall-clock instants of a rule, in order, starting with [start]. Null when the rule uses unsupported parts.
/// [stop] is called with each candidate's wall time and ends generation when it returns true.
Iterable<DateTime>? expandRrule(
  String rrule,
  DateTime start,
  bool Function(DateTime wall) stop, {
  bool Function(DateTime wall)? beyondUntil,
}) {
  final p = _parts(rrule);
  if (p.keys.any((k) => !_supportedParts.contains(k))) return null;
  final freq = p['FREQ'];
  final interval = int.tryParse(p['INTERVAL'] ?? '1') ?? 1;
  final count = int.tryParse(p['COUNT'] ?? '');
  final byDay = <(int, int)>[]; // (ordinal or 0, weekday)
  for (final s in (p['BYDAY'] ?? '').split(',').where((s) => s.isNotEmpty)) {
    final m = _byDayRe.firstMatch(s.trim());
    if (m == null) return null;
    byDay.add((int.tryParse(m[1] ?? '') ?? 0, _weekdays[m[2]]!));
  }
  final byMonthDay = [
    for (final s in (p['BYMONTHDAY'] ?? '').split(',').where((s) => s.isNotEmpty)) int.tryParse(s) ?? -1,
  ];
  if (interval < 1 || byMonthDay.any((d) => d < 1 || d > 31)) return null;
  if (freq != 'MONTHLY' && (byMonthDay.isNotEmpty || byDay.any((d) => d.$1 != 0))) return null;
  if (freq == 'MONTHLY' && byDay.isNotEmpty && byMonthDay.isNotEmpty) return null;
  final wkst = _weekdays[p['WKST']] ?? DateTime.monday;

  DateTime at(DateTime day) => DateTime.utc(day.year, day.month, day.day, start.hour, start.minute, start.second);

  Iterable<DateTime> period(int k) sync* {
    switch (freq) {
      case 'DAILY':
        final d = DateTime.utc(start.year, start.month, start.day + k * interval);
        if (byDay.isEmpty || byDay.any((b) => b.$2 == d.weekday)) yield at(d);
      case 'WEEKLY':
        final ws = DateTime.utc(start.year, start.month, start.day - (start.weekday - wkst) % 7 + 7 * interval * k);
        final days = byDay.isEmpty ? [start.weekday] : byDay.map((b) => b.$2).toList();
        final offsets = days.map((d) => (d - wkst) % 7).toSet().toList()..sort();
        for (final o in offsets) {
          yield at(DateTime.utc(ws.year, ws.month, ws.day + o));
        }
      case 'MONTHLY':
        final first = DateTime.utc(start.year, start.month + k * interval);
        final y = first.year, m = first.month;
        final dates = <DateTime>{};
        if (byDay.isEmpty) {
          for (final d in byMonthDay.isEmpty ? [start.day] : byMonthDay) {
            if (d <= _daysIn(y, m)) dates.add(DateTime.utc(y, m, d)); // months without that day are skipped
          }
        }
        for (final (n, wd) in byDay) {
          if (n != 0) {
            if (_nthWeekday(y, m, n, wd) case final d?) dates.add(d);
            continue;
          }
          for (var d = 1; d <= _daysIn(y, m); d++) {
            if (DateTime.utc(y, m, d).weekday == wd) dates.add(DateTime.utc(y, m, d));
          }
        }
        for (final d in dates.toList()..sort()) {
          yield at(d);
        }
    }
  }

  if (!const {'DAILY', 'WEEKLY', 'MONTHLY'}.contains(freq)) return null;
  return () sync* {
    var emitted = 0;
    for (var k = 0; k < 100000; k++) {
      for (final w in period(k)) {
        if (w.isBefore(start)) continue;
        if (stop(w) || (beyondUntil?.call(w) ?? false)) return;
        yield w;
        if (count != null && ++emitted >= count) return;
      }
    }
  }();
}

// ---------------------------------------------------------------------------------------------------------------
// Events

final class IcsOccurrence {
  const IcsOccurrence({
    required this.uid,
    required this.start,
    required this.end,
    required this.allDay,
    required this.event,
    this.instant,
  });
  final String uid;
  final DateTime start, end; // UTC
  final bool allDay;
  final IcsComponent event;
  final DateTime? instant; // original (recurrence-id) instant, UTC; null for one-off events
}

/// All event occurrences whose start lies in [from, to] (UTC). Cancelled events/instances are omitted.
List<IcsOccurrence> icsOccurrences(String source, DateTime from, DateTime to) {
  final root = parseIcs(source);
  final zones = IcsZones(root);
  final events = [for (final cal in root.children) ...cal.where('VEVENT')];
  final out = <IcsOccurrence>[];
  bool inWindow(DateTime t) => !t.isBefore(from) && !t.isAfter(to);
  bool cancelled(IcsComponent e) => e.prop('STATUS')?.value.toUpperCase() == 'CANCELLED';

  IcsTime? time(IcsComponent e, String name) {
    final p = e.prop(name);
    return p == null ? null : parseIcsTime(p.value, tzid: p.params['TZID']);
  }

  // Overrides first: they replace generated instances with the same original instant.
  final overridden = <String, Set<DateTime>>{};
  final masters = <IcsComponent>[];
  for (final e in events) {
    final uid = e.prop('UID')?.value;
    final start = time(e, 'DTSTART');
    if (uid == null || start == null) continue;
    final rid = time(e, 'RECURRENCE-ID');
    if (rid == null) {
      masters.add(e);
      continue;
    }
    final instant = zones.toUtc(rid);
    (overridden[uid] ??= {}).add(instant);
    if (cancelled(e)) continue;
    final (s, en) = _span(e, start, zones, time(e, 'DTEND'));
    if (!inWindow(s)) continue;
    out.add(IcsOccurrence(uid: uid, start: s, end: en, allDay: start.isDate, event: e, instant: instant));
  }

  for (final e in masters) {
    if (cancelled(e)) continue;
    final uid = e.prop('UID')!.value;
    final start = time(e, 'DTSTART')!;
    final end = time(e, 'DTEND');
    final rrule = e.prop('RRULE')?.value;
    final (s0, e0) = _span(e, start, zones, end);
    if (rrule == null) {
      if (inWindow(s0)) out.add(IcsOccurrence(uid: uid, start: s0, end: e0, allDay: start.isDate, event: e));
      continue;
    }
    final wallLength = _wallLength(e, start, end);
    final until = _until(_parts(rrule)['UNTIL'], zones);
    final excluded = _exdates(e, zones);
    final skip = overridden[uid] ?? const {};
    final walls =
        expandRrule(
          rrule,
          start.wall,
          (w) => zones.toUtc(start.withWall(w)).isAfter(to),
          beyondUntil: until == null ? null : (w) => until(start.withWall(w)),
        ) ??
        [start.wall]; // unsupported rule → first instance only (#67)
    for (final w in walls) {
      final s = zones.toUtc(start.withWall(w));
      if (!inWindow(s) || skip.contains(s) || excluded(start.withWall(w), s)) continue;
      final en = zones.toUtc(start.withWall(w.add(wallLength)));
      out.add(IcsOccurrence(uid: uid, start: s, end: en, allDay: start.isDate, event: e, instant: s));
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

(DateTime, DateTime) _span(IcsComponent e, IcsTime start, IcsZones zones, IcsTime? end) {
  final s = zones.toUtc(start);
  if (end != null) return (s, zones.toUtc(end));
  return (s, zones.toUtc(start.withWall(start.wall.add(_wallLength(e, start, null)))));
}

/// Event length in wall-clock terms, so all-day and DST-crossing instances keep their written length.
Duration _wallLength(IcsComponent e, IcsTime start, IcsTime? end) {
  if (end != null) return end.wall.difference(start.wall);
  final d = parseIcsDuration(e.prop('DURATION')?.value ?? '');
  return d ?? (start.isDate ? const Duration(days: 1) : Duration.zero);
}

bool Function(IcsTime)? _until(String? v, IcsZones zones) {
  if (v == null) return null;
  final u = parseIcsTime(v);
  if (u == null) return null;
  if (u.isDate) return (t) => t.wall.isAfter(DateTime.utc(u.wall.year, u.wall.month, u.wall.day, 23, 59, 59));
  if (u.isUtc) return (t) => zones.toUtc(t).isAfter(u.wall);
  return (t) => t.wall.isAfter(u.wall);
}

bool Function(IcsTime wall, DateTime utc) _exdates(IcsComponent e, IcsZones zones) {
  final instants = <DateTime>{};
  final dates = <DateTime>{};
  for (final p in e.all('EXDATE')) {
    for (final v in p.value.split(',')) {
      final t = parseIcsTime(v, tzid: p.params['TZID']);
      if (t == null) continue;
      t.isDate ? dates.add(t.wall) : instants.add(zones.toUtc(t));
    }
  }
  return (wall, utc) =>
      instants.contains(utc) || dates.contains(DateTime.utc(wall.wall.year, wall.wall.month, wall.wall.day));
}
