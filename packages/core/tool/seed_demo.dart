// Seeds a demo data folder for screenshots / manual UI review (not used by the app).
//
//   dart run packages/core/tool/seed_demo.dart <dataDir>
//   cd app && flutter run -d macos --dart-define=ANT_DATA_DIR=<dataDir>
import 'dart:io';

import 'package:core/core.dart';
import 'package:core/src/util/ids.dart' show canonicalJson, sha256Hex;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> args) async {
  final dir = args.single;
  Directory('$dir/profiles').createSync(recursive: true);
  final appDb = AppDb(NativeDatabase(File('$dir/app.sqlite')));
  const pid = 'DEMOPROFILE';
  await appDb.into(appDb.profiles).insertOnConflictUpdate(ProfilesCompanion.insert(
        id: pid,
        name: 'Work',
        timeZone: 'Europe/London',
        active: const Value(true),
        createdAt: DateTime.now().toUtc(),
      ));
  await appDb.close();

  final db = ProfileDb(NativeDatabase(File('$dir/profiles/$pid.sqlite')));
  final now = DateTime.now();
  String day(int d) => dayOf(now.subtract(Duration(days: d)), now.timeZoneOffset);
  DateTime at(int d, int h, int m) {
    final x = now.subtract(Duration(days: d));
    return DateTime(x.year, x.month, x.day, h, m);
  }

  await db.transaction(() async {
    for (final (id, kind, name) in [
      ('S-GH', SourceKind.github, 'GitHub'),
      ('S-GIT', SourceKind.gitRepo, 'checkout-svc'),
      ('S-CAL', SourceKind.googleCalendar, 'Google Calendar'),
      ('S-JIRA', SourceKind.jira, 'Jira'),
      ('S-NOTE', SourceKind.manualNote, 'Notes'),
    ]) {
      await db.into(db.sources).insert(SourcesCompanion.insert(id: id, kind: kind, name: name));
    }
    for (final (id, name, colour) in [
      ('P-CHK', 'Checkout v2', '#E8A54B'),
      ('P-PLAT', 'Platform & CI', '#7FA8E8'),
      ('P-HIRE', 'Hiring', '#B3A3F0'),
    ]) {
      await db.into(db.projects).insert(ProjectsCompanion.insert(id: id, name: name, colour: Value(colour)));
    }

    var n = 0;
    Future<String> ev(int d, int h, int m, String title, String? project, String source, PayloadKind kind,
        {Map<String, Object?> content = const {}, bool starred = false, bool hidden = false}) async {
      final id = 'E${n++}';
      final t = at(d, h, m);
      await db.into(db.evidences).insert(EvidencesCompanion.insert(
            id: id,
            occurredStart: t.toUtc(),
            day: day(d),
            title: title,
            projectId: Value(project),
            starred: Value(starred),
            hidden: Value(hidden),
            createdAt: t.toUtc(),
            updatedAt: t.toUtc(),
          ));
      final c = canonicalJson({'title': title, ...content});
      await db.into(db.payloads).insert(PayloadsCompanion.insert(
            id: 'PL$id',
            evidenceId: id,
            sourceId: source,
            kind: kind,
            externalId: id,
            content: c,
            contentHash: sha256Hex(c),
            title: Value(title),
          ));
      return id;
    }

    Future<void> note(String evidenceId, int d, String text) async {
      final c = canonicalJson({'text': text, 'link': null, 'attachments': <String>[]});
      await db.into(db.payloads).insert(PayloadsCompanion.insert(
            id: 'N$evidenceId',
            evidenceId: evidenceId,
            sourceId: 'S-NOTE',
            kind: PayloadKind.note,
            externalId: 'N$evidenceId',
            content: c,
            contentHash: sha256Hex(c),
            title: Value(text),
          ));
    }

    final pr = await ev(0, 9, 42, 'Idempotent payment confirmation (checkout#482)', 'P-CHK', 'S-GH', PayloadKind.pullRequest,
        content: {'url': 'https://github.com/acme/checkout/pull/482'}, starred: true);
    final c1 = await ev(0, 10, 15, 'Add retry-safe confirm endpoint', 'P-CHK', 'S-GIT', PayloadKind.commit);
    await note(c1, 0, 'Took 3 days because of flaky CI on the payments suite');
    final t1 = await ev(0, 11, 3, 'PAY-311 Duplicate charges on retry', 'P-CHK', 'S-JIRA', PayloadKind.issue);
    final ci = await ev(0, 13, 30, 'Fix flaky integration runner cache', 'P-PLAT', 'S-GIT', PayloadKind.commit);
    final rv = await ev(0, 14, 10, 'Reviewed: migrate build images to arm64', 'P-PLAT', 'S-GH', PayloadKind.review);
    final m1 = await ev(0, 15, 0, 'Interview loop: senior backend', 'P-HIRE', 'S-CAL', PayloadKind.calendarEvent);
    await ev(0, 12, 30, 'Lunch', null, 'S-CAL', PayloadKind.calendarEvent, hidden: true);
    await ev(0, 16, 20, 'Daily sync', null, 'S-CAL', PayloadKind.calendarEvent);
    final n1 = 'E${n++}';
    await db.into(db.evidences).insert(EvidencesCompanion.insert(
          id: n1,
          occurredStart: at(0, 17, 5).toUtc(),
          day: day(0),
          title: 'Paired with Priya on the refund edge cases',
          projectId: const Value('P-CHK'),
          createdAt: now.toUtc(),
          updatedAt: now.toUtc(),
        ));
    await note(n1, 0, 'Paired with Priya on the refund edge cases');
    final y1 = await ev(1, 10, 0, 'Design review: checkout state machine', 'P-CHK', 'S-CAL', PayloadKind.calendarEvent);
    final y2 = await ev(1, 15, 12, 'Bump runner image, pin node 22', 'P-PLAT', 'S-GIT', PayloadKind.commit);
    for (var d = 2; d < 9; d++) {
      await ev(d, 11, 0, 'Checkout cleanup part $d', 'P-CHK', 'S-GIT', PayloadKind.commit);
    }

    var f = 0;
    Future<String> fact(FactType type, String statement, int d, List<String> evidence,
        {String? project, FactOrigin origin = FactOrigin.inferred, WinStatus win = WinStatus.none, String? ws,
        ReviewState review = ReviewState.ok, String? proposal, String details = '{}'}) async {
      final id = 'F${f++}';
      await db.into(db.facts).insert(FactsCompanion.insert(
            id: id,
            type: type,
            statement: statement,
            details: Value(details),
            periodStart: day(d),
            periodEnd: day(d),
            projectId: Value(project),
            workstreamId: Value(ws),
            origin: origin,
            winStatus: Value(win),
            reviewState: Value(review),
            reviewProposal: Value(proposal),
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
          ));
      for (final e in evidence) {
        await db.into(db.citations).insert(CitationsCompanion.insert(factId: id, payloadId: 'PL$e', payloadRevision: 1));
      }
      return id;
    }

    await db.into(db.workstreams).insert(WorkstreamsCompanion.insert(
        id: 'W1', title: 'Payments idempotency', projectId: const Value('P-CHK'),
        summary: const Value('Stop duplicate charges on retries.'), spanStart: Value(day(1)), spanEnd: Value(day(0))));
    await db.into(db.workstreams).insert(WorkstreamsCompanion.insert(
        id: 'W2', title: 'CI reliability', projectId: const Value('P-PLAT'), spanStart: Value(day(1)), spanEnd: Value(day(0))));
    await db.into(db.workstreams).insert(WorkstreamsCompanion.insert(
        id: 'W3', title: 'Build images', projectId: const Value('P-PLAT'), spanStart: Value(day(0)), spanEnd: Value(day(0))));

    final f0 = await fact(FactType.outcome, 'Shipped idempotent payment confirmation for Checkout v2, ending duplicate charges on retry.', 0,
        [pr, c1, t1], project: 'P-CHK', win: WinStatus.accepted, origin: FactOrigin.confirmed, ws: 'W1');
    final f1 = await fact(FactType.problemSolved, 'Fixed the flaky integration runner cache that was failing CI for three teams.', 0, [ci],
        project: 'P-PLAT', ws: 'W2', win: WinStatus.suggested);
    final f2 = await fact(FactType.invisibleWork, 'Reviewed the arm64 build image migration and interviewed a senior backend candidate.', 0,
        [rv, m1], project: 'P-PLAT', ws: 'W3');
    final f3 = await fact(FactType.hiccup, 'Payments confirmation took three days longer because of flaky CI.', 0, [c1], project: 'P-CHK', ws: 'W1');
    final f4 = await fact(FactType.timeAllocation, '~3h of coding in Checkout v2 (estimated from commits)', 0, [pr, c1],
        project: 'P-CHK', details: '{"basis":"estimated","minutes":180}');
    await fact(FactType.decision, 'Chose a state machine for checkout over ad-hoc flags.', 1, [y1],
        project: 'P-CHK', origin: FactOrigin.userEdited, review: ReviewState.needsReview, ws: 'W1',
        proposal: canonicalJson({'op': 'update', 'statement': 'Chose an explicit state machine for checkout, replacing four boolean flags.', 'retire': false}));
    await fact(FactType.problemSolved, 'Pinned Node 22 in the runner image to stop toolchain drift.', 1, [y2], project: 'P-PLAT', ws: 'W2');

    await db.into(db.templates).insert(TemplatesCompanion.insert(
        id: 'builtin.standup', name: 'Standup', periodKinds: 'daily', prompt: '', builtIn: const Value(true)));
    await db.into(db.templates).insert(TemplatesCompanion.insert(
        id: 'builtin.weekly_review', name: 'Weekly review', periodKinds: 'weekly', prompt: '', builtIn: const Value(true)));
    await db.into(db.reports).insert(ReportsCompanion.insert(
        id: 'R1', periodKind: PeriodKind.daily, periodStart: day(0), periodEnd: day(0), templateId: 'builtin.standup'));
    final md = '''# Standup — ${day(0)}

## Done

- Shipped idempotent payment confirmation for Checkout v2, so retries no longer double-charge. [^f1]
- Fixed the flaky integration runner cache that was failing CI for three teams. [^f2]
- Reviewed the arm64 build image migration and ran a senior backend interview. [^f3]

## Blockers

- Payments confirmation slipped three days on flaky CI; now resolved. [^f4][^f2]

[^f1]: Shipped idempotent payment confirmation for Checkout v2, ending duplicate charges on retry. (fact:$f0)
[^f2]: Fixed the flaky integration runner cache that was failing CI for three teams. (fact:$f1)
[^f3]: Reviewed the arm64 build image migration and interviewed a senior backend candidate. (fact:$f2)
[^f4]: Payments confirmation took three days longer because of flaky CI. (fact:$f3)
''';
    await db.into(db.reportSnapshots).insert(ReportSnapshotsCompanion.insert(
        id: 'RS1', reportId: 'R1', version: 1, json: '{}', markdown: md, modelId: 'claude-sonnet-5.5',
        generatedAt: now.toUtc()));
    for (final id in [f0, f1, f2, f3, f4]) {
      await db.into(db.dependencies).insert(DependenciesCompanion.insert(
          dependentType: EntityType.reportSnapshot, dependentId: 'RS1', dependentRevision: 1,
          inputType: EntityType.fact, inputId: id, inputRevision: 1));
    }
    final week = Period.containing(PeriodKind.weekly, day(0));
    await db.into(db.reports).insert(ReportsCompanion.insert(
        id: 'R2', periodKind: PeriodKind.weekly, periodStart: week.start, periodEnd: week.end,
        templateId: 'builtin.weekly_review', locked: const Value(true), lockedSnapshotId: const Value('RS2')));
    await db.into(db.reportSnapshots).insert(ReportSnapshotsCompanion.insert(
        id: 'RS2', reportId: 'R2', version: 1, json: '{}',
        markdown: md.replaceFirst('# Standup — ${day(0)}', '# Weekly review — Week of ${week.start}')
            .replaceFirst('## Done', '## Outcomes'),
        modelId: 'claude-sonnet-5.5', generatedAt: now.toUtc()));
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
        sourceId: 'S-GH', lastSuccessAt: Value(now.subtract(const Duration(minutes: 2)).toUtc())));
    await db.delete(db.recomputeQueue).go();
  });
  await db.close();
  stdout.writeln('Seeded $dir');
}
