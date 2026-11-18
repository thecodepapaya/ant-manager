import '../domain/enums.dart';

/// A report period: inclusive local days (YYYY-MM-DD) in the profile time zone (#87).
class Period {
  const Period(this.kind, this.start, this.end);
  final PeriodKind kind;
  final String start, end;

  /// The period of [kind] that contains [day]. Weeks run Monday–Sunday.
  factory Period.containing(PeriodKind kind, String day) {
    final d = parseDay(day);
    switch (kind) {
      case PeriodKind.daily:
        return Period(kind, day, day);
      case PeriodKind.weekly:
        final mon = d.subtract(Duration(days: d.weekday - DateTime.monday));
        return Period(kind, formatDay(mon), formatDay(mon.add(const Duration(days: 6))));
      case PeriodKind.monthly:
        return Period(kind, formatDay(DateTime.utc(d.year, d.month)), formatDay(DateTime.utc(d.year, d.month + 1, 0)));
      case PeriodKind.quarterly:
        final m = ((d.month - 1) ~/ 3) * 3 + 1;
        return Period(kind, formatDay(DateTime.utc(d.year, m)), formatDay(DateTime.utc(d.year, m + 3, 0)));
      case PeriodKind.custom:
        throw ArgumentError('Use Period.custom for custom ranges');
    }
  }

  factory Period.custom(String start, String end) {
    if (start.compareTo(end) > 0) throw ArgumentError('Period start $start is after end $end');
    return Period(PeriodKind.custom, start, end);
  }

  /// The period of the same kind just before this one (custom: same length, ending the day before).
  Period previous() {
    final before = formatDay(parseDay(start).subtract(const Duration(days: 1)));
    if (kind != PeriodKind.custom) return Period.containing(kind, before);
    final len = parseDay(end).difference(parseDay(start));
    return Period.custom(formatDay(parseDay(before).subtract(len)), before);
  }

  String get label => switch (kind) {
    PeriodKind.daily => start,
    PeriodKind.weekly => 'Week of $start',
    PeriodKind.monthly => start.substring(0, 7),
    PeriodKind.quarterly => '${start.substring(0, 4)} Q${(int.parse(start.substring(5, 7)) - 1) ~/ 3 + 1}',
    PeriodKind.custom => '$start to $end',
  };

  @override
  bool operator ==(Object other) => other is Period && other.kind == kind && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(kind, start, end);
  @override
  String toString() => 'Period(${kind.name}, $start..$end)';
}

/// YYYY-MM-DD → UTC midnight (used only for calendar arithmetic).
DateTime parseDay(String day) {
  final p = day.split('-');
  if (p.length != 3) throw FormatException('Bad day', day);
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
