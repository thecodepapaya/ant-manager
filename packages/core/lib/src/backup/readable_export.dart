import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/profile_db.dart';
import '../domain/enums.dart';

/// Readable export (SPEC §9): Markdown + JSON of facts, report snapshots, wins, notes and evidence
/// metadata. Rewritten from scratch on each run. Source configs and credential refs are left out.
class ReadableExporter {
  ReadableExporter(this.db);
  final ProfileDb db;

  static const _json = JsonEncoder.withIndent('  ');

  Future<void> export(String dir) async {
    final root = Directory(dir);
    if (await root.exists()) await root.delete(recursive: true);
    await Directory(p.join(dir, 'reports')).create(recursive: true);
    final projects = {for (final x in await db.select(db.projects).get()) x.id: x.name};

    // Facts (+ citations) and wins.
    final facts =
        await (db.select(db.facts)
              ..where((f) => f.retired.equals(false))
              ..orderBy([(f) => OrderingTerm.asc(f.periodStart), (f) => OrderingTerm.desc(f.importance)]))
            .get();
    final citations = <String, List<Map<String, Object?>>>{};
    for (final c in await db.select(db.citations).get()) {
      citations.putIfAbsent(c.factId, () => []).add({'payload_id': c.payloadId, 'payload_revision': c.payloadRevision});
    }
    Map<String, Object?> factMap(Fact f) => {
      'id': f.id,
      'type': f.type.name,
      'statement': f.statement,
      'details': jsonDecode(f.details),
      'period_start': f.periodStart,
      'period_end': f.periodEnd,
      'project': projects[f.projectId],
      'workstream_id': f.workstreamId,
      'importance': f.importance,
      'origin': f.origin.name,
      'win_status': f.winStatus.name,
      'revision': f.revision,
      'citations': citations[f.id] ?? const [],
    };
    final wins = facts.where((f) => f.type == FactType.outcome && f.winStatus == WinStatus.accepted).toList();
    await _write(dir, 'facts.json', _json.convert(facts.map(factMap).toList()));
    await _write(dir, 'wins.json', _json.convert(wins.map(factMap).toList()));
    await _write(dir, 'facts.md', _factsMarkdown('Facts', facts, projects));
    await _write(dir, 'wins.md', _factsMarkdown('Wins', wins, projects));

    // Report snapshots: every version as JSON, latest per report as Markdown.
    final reports = {for (final r in await db.select(db.reports).get()) r.id: r};
    final templates = {for (final t in await db.select(db.templates).get()) t.id: t.name};
    final snapshots = await (db.select(
      db.reportSnapshots,
    )..orderBy([(s) => OrderingTerm.asc(s.reportId), (s) => OrderingTerm.asc(s.version)])).get();
    final latest = <String, ReportSnapshot>{};
    for (final s in snapshots) {
      latest[s.reportId] = s;
    }
    await _write(
      dir,
      'reports.json',
      _json.convert([
        for (final s in snapshots)
          {
            'report_id': s.reportId,
            'period_kind': reports[s.reportId]?.periodKind.name,
            'period_start': reports[s.reportId]?.periodStart,
            'period_end': reports[s.reportId]?.periodEnd,
            'template': templates[reports[s.reportId]?.templateId],
            'version': s.version,
            'model': s.modelId,
            'style_instruction': s.styleInstruction,
            'generated_at': s.generatedAt.toUtc().toIso8601String(),
            'content': jsonDecode(s.json),
          },
      ]),
    );
    for (final s in latest.values) {
      final r = reports[s.reportId]!;
      final name = '${r.periodStart}_${r.periodKind.name}_${_slug(templates[r.templateId] ?? r.templateId)}.md';
      await _write(p.join(dir, 'reports'), name, s.markdown);
    }

    // Evidence metadata and notes.
    final evidences = await (db.select(db.evidences)..orderBy([(e) => OrderingTerm.asc(e.occurredStart)])).get();
    final payloads = await db.select(db.payloads).get();
    final byEvidence = <String, List<Payload>>{};
    for (final x in payloads) {
      byEvidence.putIfAbsent(x.evidenceId, () => []).add(x);
    }
    await _write(
      dir,
      'evidence.json',
      _json.convert([
        for (final e in evidences)
          {
            'id': e.id,
            'day': e.day,
            'title': e.title,
            'occurred_start': e.occurredStart.toUtc().toIso8601String(),
            'occurred_end': e.occurredEnd?.toUtc().toIso8601String(),
            'project': projects[e.projectId],
            'starred': e.starred,
            'hidden': e.hidden,
            'importance': e.importance,
            'payloads': [
              for (final x in byEvidence[e.id] ?? const <Payload>[])
                {'id': x.id, 'kind': x.kind.name, 'revision': x.revision, 'tombstoned': x.tombstonedAt != null},
            ],
          },
      ]),
    );
    final dayOf = {for (final e in evidences) e.id: e.day};
    final notes = payloads.where((x) => x.kind == PayloadKind.note && x.tombstonedAt == null).toList()
      ..sort((a, b) => (dayOf[a.evidenceId] ?? '').compareTo(dayOf[b.evidenceId] ?? ''));
    final nb = StringBuffer('# Notes\n');
    for (final n in notes) {
      final c = jsonDecode(n.content) as Map<String, Object?>;
      nb.write('\n## ${dayOf[n.evidenceId]}\n\n${c['text'] ?? ''}\n');
      if (c['link'] != null) nb.write('\n${c['link']}\n');
    }
    await _write(dir, 'notes.md', nb.toString());
  }

  static String _factsMarkdown(String title, List<Fact> facts, Map<String, String> projects) {
    final b = StringBuffer('# $title\n');
    String? day;
    for (final f in facts) {
      if (f.periodStart != day) {
        day = f.periodStart;
        b.write('\n## $day\n\n');
      }
      final project = projects[f.projectId];
      b.write('- **${f.type.name}**${project == null ? '' : ' ($project)'}: ${f.statement}\n');
    }
    return b.toString();
  }

  static String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  static Future<void> _write(String dir, String name, String content) => File(p.join(dir, name)).writeAsString(content);
}
