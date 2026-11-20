import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import 'context.dart';
import 'fact_writer.dart';

typedef Interval = ({DateTime start, DateTime end});

/// Deterministic time facts, no model (LLD 04 §4.7, #90).
/// - measured: merged durations of non-declined, non-hidden calendar events per project.
/// - estimated: sessions of commits authored by you (#109), formed across all projects of the day
///   (commits < 90 min apart; a session starts 30 min before its first commit and ends at its last).
///   Each commit owns the stretch since the previous commit of its session (the first: its 30 min
///   lead), credited to that commit's project, minus time covered by any meeting that day.
/// One fact per (project, basis) per day: a project with both meetings and commits gets two facts,
/// so the measured/estimated label stays exact (N9).
class TimeAllocator {
  TimeAllocator(this.ctx) : writer = FactWriter(ctx);
  final NarrativeContext ctx;
  final FactWriter writer;
  ProfileDb get db => ctx.db;

  static const sessionGap = Duration(minutes: 90);
  static const sessionLead = Duration(minutes: 30);

  Future<void> computeDay(String day) async {
    final evidence = {
      for (final e in await (db.select(db.evidences)..where((e) => e.day.equals(day) & e.hidden.equals(false))).get())
        e.id: e,
    };
    final payloads = evidence.isEmpty
        ? <Payload>[]
        : await (db.select(db.payloads)..where(
                (p) =>
                    p.evidenceId.isIn(evidence.keys) &
                    p.tombstonedAt.isNull() &
                    p.kind.isInValues([PayloadKind.calendarEvent, PayloadKind.commit]),
              ))
              .get();

    final mine = {
      for (final i in await (db.select(db.identities)..where((i) => i.kind.equals('email'))).get())
        i.value.trim().toLowerCase(),
    };
    final meetings = <String?, List<(Interval, Payload)>>{};
    final commits = <(DateTime, String?, Payload)>[];
    for (final p in payloads) {
      final e = evidence[p.evidenceId]!;
      if (p.kind == PayloadKind.calendarEvent) {
        final iv = eventInterval(p, e);
        final c = contentOf(p);
        if (iv != null && !isDeclined(c) && c['allDay'] != true) {
          meetings.putIfAbsent(e.projectId, () => []).add((iv, p));
        }
      } else if (authoredByYou(contentOf(p), mine)) {
        commits.add((e.occurredStart, e.projectId, p));
      }
    }
    final allMeetings = merge(meetings.values.expand((l) => l.map((m) => m.$1)).toList());

    final wanted = <(String?, String), ({int minutes, List<String> cites})>{};
    for (final MapEntry(key: project, value: list) in meetings.entries) {
      final minutes = totalMinutes(merge(list.map((m) => m.$1).toList()));
      if (minutes > 0) wanted[(project, 'measured')] = (minutes: minutes, cites: list.map((m) => m.$2.id).toList());
    }
    final coding = <String?, ({List<Interval> ivs, List<String> cites})>{};
    for (final (iv, project, p) in segments(commits)) {
      final c = coding.putIfAbsent(project, () => (ivs: [], cites: []));
      c.ivs.add(iv);
      c.cites.add(p.id);
    }
    for (final MapEntry(key: project, value: c) in coding.entries) {
      final minutes = totalMinutes(subtract(merge(c.ivs), allMeetings));
      if (minutes > 0) wanted[(project, 'estimated')] = (minutes: minutes, cites: c.cites);
    }

    final names = {for (final p in await db.select(db.projects).get()) p.id: p.name};
    final all = await (db.select(
      db.facts,
    )..where((f) => f.periodStart.equals(day) & f.type.equalsValue(FactType.timeAllocation))).get();
    String basisOf(Fact f) => detailsOf(f)['basis'] as String? ?? '';
    // A (project, basis) the user rejected is never re-created (#NEXT); its key counts as seen.
    final seen = <(String?, String)>{
      for (final f in all)
        if (f.retired && f.winStatus == WinStatus.rejected) (f.projectId, basisOf(f)),
    };
    for (final f in all.where((f) => !f.retired)) {
      final key = (f.projectId, basisOf(f));
      final w = wanted[key];
      if (w == null || !seen.add(key)) {
        // No longer measured/estimated (or a duplicate or rejected key): retire, or ask the user if they touched it.
        if (isProtected(f)) {
          if (f.reviewState != ReviewState.needsReview) {
            final reason = w == null ? 'no time recorded any more' : 'duplicate or rejected time fact';
            await writer.propose(f, {'op': 'retire', 'retire': true, 'reason': reason});
          }
        } else {
          await writer.update(f, retired: true);
        }
        continue;
      }
      final details = {'minutes': w.minutes, 'basis': key.$2};
      final cites = await writer.citedPayloads(f.id);
      final sameCites = const SetEquality<String>().equals(cites.toSet(), w.cites.toSet());
      if (detailsOf(f)['minutes'] == w.minutes && sameCites) {
        if (!isProtected(f)) await writer.repin(f);
        continue;
      }
      final statement = _statement(w.minutes, key.$2, names[key.$1]);
      if (isProtected(f)) {
        await writer.propose(f, {
          'op': 'update',
          'statement': statement,
          'details': details,
          'citations': w.cites,
          'retire': false,
        });
      } else {
        await writer.update(f, statement: statement, details: details, citations: w.cites);
      }
    }
    for (final MapEntry(key: key, value: w) in wanted.entries) {
      if (seen.contains(key)) continue;
      await writer.create(
        type: FactType.timeAllocation,
        statement: _statement(w.minutes, key.$2, names[key.$1]),
        day: day,
        citations: w.cites,
        details: {'minutes': w.minutes, 'basis': key.$2},
        projectId: key.$1,
      );
    }
  }

  static String _statement(int minutes, String basis, String? project) {
    final h = minutes ~/ 60, m = minutes % 60;
    final dur = h == 0 ? '$m min' : (m == 0 ? '$h h' : '$h h $m min');
    final where = project == null ? 'with no project' : 'on $project';
    return basis == 'measured' ? '$dur in meetings $where' : '~$dur of coding $where (estimated from commits)';
  }

  /// Calendar start/end from content (`start`/`end` ISO strings), else the evidence's times.
  static Interval? eventInterval(Payload p, Evidence e) {
    final c = contentOf(p);
    final start = DateTime.tryParse('${c['start']}') ?? e.occurredStart;
    final end = DateTime.tryParse('${c['end']}') ?? e.occurredEnd;
    if (end == null || !end.isAfter(start)) return null;
    return (start: start.toUtc(), end: end.toUtc());
  }

  /// Declined events normally aren't synced; this also skips any that carry a declined status.
  static bool isDeclined(Map<String, Object?> c) =>
      c['declined'] == true || c['responseStatus'] == 'declined' || c['response_status'] == 'declined';

  /// A commit is yours unless its author email is known and not one of your email identities (the git
  /// source also keeps commits you only committed, e.g. someone else's work you rebased).
  static bool authoredByYou(Map<String, Object?> c, Set<String> emails) {
    final author = c['author'];
    final email = author is Map ? author['email'] : null;
    if (email is! String || email.trim().isEmpty) return true;
    return emails.contains(email.trim().toLowerCase());
  }

  /// Commit sessions across projects: each commit's stretch since the previous commit of its session
  /// (< [sessionGap] apart), or [sessionLead] before it when it starts a session.
  static List<(Interval, T, P)> segments<T, P>(List<(DateTime, T, P)> commits) {
    final sorted = [...commits]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = <(Interval, T, P)>[];
    DateTime? last;
    for (final (at, project, p) in sorted) {
      final t = at.toUtc();
      final from = last != null && t.difference(last) < sessionGap ? last : t.subtract(sessionLead);
      out.add(((start: from, end: t), project, p));
      last = t;
    }
    return out;
  }

  static List<Interval> merge(List<Interval> ivs) {
    if (ivs.isEmpty) return const [];
    final s = [...ivs]..sort((a, b) => a.start.compareTo(b.start));
    final out = <Interval>[s.first];
    for (final iv in s.skip(1)) {
      final last = out.last;
      if (!iv.start.isAfter(last.end)) {
        if (iv.end.isAfter(last.end)) out[out.length - 1] = (start: last.start, end: iv.end);
      } else {
        out.add(iv);
      }
    }
    return out;
  }

  /// [a] minus [b]; both merged and sorted.
  static List<Interval> subtract(List<Interval> a, List<Interval> b) {
    final out = <Interval>[];
    for (final iv in a) {
      var pieces = [iv];
      for (final cut in b) {
        pieces = [
          for (final p in pieces) ...[
            if (cut.start.isAfter(p.start)) (start: p.start, end: cut.start.isBefore(p.end) ? cut.start : p.end),
            if (cut.end.isBefore(p.end)) (start: cut.end.isAfter(p.start) ? cut.end : p.start, end: p.end),
          ],
        ].where((p) => p.end.isAfter(p.start)).toList();
      }
      out.addAll(pieces);
    }
    return out;
  }

  static int totalMinutes(List<Interval> ivs) =>
      (ivs.fold<int>(0, (s, iv) => s + iv.end.difference(iv.start).inSeconds) / 60).round();
}
