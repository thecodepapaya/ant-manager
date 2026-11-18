import 'dart:async';

import 'package:drift/drift.dart';

import '../ai/llm.dart';
import '../ai/structured.dart';
import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../ports/ports.dart';
import '../staleness/staleness.dart';
import '../tools/tool.dart';
import '../util/ids.dart';
import 'periods.dart';
import 'render.dart';
import 'templates.dart';

/// Progress of one report generation.
sealed class ReportEvent {}

enum ReportStage { gathering, generating, saving }

class ReportProgress extends ReportEvent {
  ReportProgress(this.stage);
  final ReportStage stage;
}

/// Raw JSON text streamed from the model (for a "writing…" indicator; not the rendered report).
class ReportDelta extends ReportEvent {
  ReportDelta(this.text);
  final String text;
}

/// Always the last event. [snapshot] is null for previews.
class ReportDone extends ReportEvent {
  ReportDone({required this.json, required this.markdown, required this.modelName, this.snapshot});
  final Map<String, Object?> json;
  final String markdown;
  final String modelName;
  final ReportSnapshot? snapshot;
}

/// Thrown when asked to regenerate a locked report (invariant 8).
class ReportLockedException implements Exception {
  ReportLockedException(this.reportId);
  final String reportId;
  @override
  String toString() => 'Report $reportId is locked; unlock it to regenerate';
}

/// Generates reports from the Narrative through the tool layer (LLD 04 §4.9).
class ReportGenerator {
  ReportGenerator({
    required this.db,
    required this.router,
    required this.tools,
    required this.profileId,
    this.clock = const SystemClock(),
  }) : _structured = StructuredOutput(router);

  final ProfileDb db;
  final ModelRouter router;

  /// Must contain the built-in tools (registerBuiltinTools).
  final ToolRegistry tools;
  final String profileId;
  final Clock clock;
  final StructuredOutput _structured;

  /// Share of the Reports model's context used for the prompt (§4.9 step 2).
  static const contextShare = 0.6;

  /// Rough token → character ratio for budgeting.
  static const charsPerToken = 4;

  /// Used when a model doesn't report its context length.
  static const fallbackContextTokens = 8192;

  /// Finds or creates the report row for a period + template.
  Future<Report> ensureReport(PeriodKind periodKind, String start, String end, String templateId) =>
      db.transaction(() async {
        final existing =
            await (db.select(db.reports)
                  ..where(
                    (r) =>
                        r.periodKind.equalsValue(periodKind) &
                        r.periodStart.equals(start) &
                        r.periodEnd.equals(end) &
                        r.templateId.equals(templateId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (existing != null) return existing;
        final id = newId();
        await db
            .into(db.reports)
            .insert(
              ReportsCompanion.insert(
                id: id,
                periodKind: periodKind,
                periodStart: start,
                periodEnd: end,
                templateId: templateId,
              ),
            );
        return (db.select(db.reports)..where((r) => r.id.equals(id))).getSingle();
      });

  /// Generates a new snapshot (version + 1) for [reportId]. Emits a [ReportLockedException] error
  /// for locked reports. [styleInstruction] changes wording only (#66) and is stored on the snapshot.
  Stream<ReportEvent> generate(String reportId, {String? styleInstruction}) => _run((emit) async {
    final report = await (db.select(db.reports)..where((r) => r.id.equals(reportId))).getSingle();
    if (report.locked) throw ReportLockedException(reportId);
    final template = await _template(report.templateId);
    final period = Period(report.periodKind, report.periodStart, report.periodEnd);
    final draft = await _draft(template, period, styleInstruction, emit);
    emit(ReportProgress(ReportStage.saving));
    final snapshot = await db.transaction(() async {
      final r = await (db.select(db.reports)..where((x) => x.id.equals(reportId))).getSingle();
      if (r.locked) throw ReportLockedException(reportId);
      final last =
          await (db.select(db.reportSnapshots)
                ..where((s) => s.reportId.equals(reportId))
                ..orderBy([(s) => OrderingTerm.desc(s.version)])
                ..limit(1))
              .getSingleOrNull();
      final version = (last?.version ?? 0) + 1;
      final id = newId(clock.now());
      await db
          .into(db.reportSnapshots)
          .insert(
            ReportSnapshotsCompanion.insert(
              id: id,
              reportId: reportId,
              version: version,
              json: canonicalJson(draft.json),
              markdown: draft.markdown,
              modelId: draft.modelName,
              styleInstruction: Value(styleInstruction),
              generatedAt: clock.now(),
            ),
          );
      await DependencyRecorder(db).record((type: EntityType.reportSnapshot, id: id), version, draft.inputs);
      return (db.select(db.reportSnapshots)..where((s) => s.id.equals(id))).getSingle();
    });
    emit(ReportDone(json: draft.json, markdown: draft.markdown, modelName: draft.modelName, snapshot: snapshot));
  });

  /// Live preview for the template editor (#86): generates against real data, saves nothing.
  Stream<ReportEvent> preview(String templateId, Period period, {String? styleInstruction}) => _run((emit) async {
    final draft = await _draft(await _template(templateId), period, styleInstruction, emit);
    emit(ReportDone(json: draft.json, markdown: draft.markdown, modelName: draft.modelName));
  });

  // ---------- internals ----------

  Future<Template> _template(String id) => (db.select(db.templates)..where((t) => t.id.equals(id))).getSingle();

  Stream<ReportEvent> _run(Future<void> Function(void Function(ReportEvent) emit) body) {
    late final StreamController<ReportEvent> c;
    c = StreamController<ReportEvent>(
      onListen: () async {
        try {
          await body(c.add);
        } catch (e, st) {
          c.addError(e, st);
        } finally {
          await c.close();
        }
      },
    );
    return c.stream;
  }

  Future<_Draft> _draft(Template template, Period period, String? style, void Function(ReportEvent) emit) async {
    emit(ReportProgress(ReportStage.gathering));
    final ctx = ToolContext(db: db, profileId: profileId);
    final range = {'start': period.start, 'end': period.end};
    final facts = ((await tools['get_facts'].call(range, ctx))['facts'] as List).cast<Map<String, Object?>>();
    final time = await tools['time_breakdown'].call(range, ctx);
    final winIds = {
      for (final w in ((await tools['list_wins'].call(range, ctx))['wins'] as List).cast<Map<String, Object?>>())
        w['fact_id'] as String,
    };
    final projects = {for (final p in await db.select(db.projects).get()) p.id: p.name};

    final resolved = await router.resolve(LlmRoute.reports);
    final system = _systemPrompt(style);
    final instructions = renderPrompt(template.prompt, period);
    final budget =
        ((resolved.info.contextLength ?? fallbackContextTokens) * contextShare * charsPerToken).floor() -
        system.length -
        instructions.length;

    final timeLines = [
      for (final r in (time['by_project'] as List).cast<Map<String, Object?>>())
        '- ${r['project_name'] ?? r['project_id'] ?? 'No project'}: ${r['total_minutes']} min '
            '(measured ${r['measured_minutes']}, estimated ${r['estimated_minutes']}) '
            '[${(r['fact_ids'] as List).join(', ')}]',
    ];
    var used = timeLines.fold<int>(0, (s, l) => s + l.length + 1);
    final included = <Map<String, Object?>>[];
    final omitted = <String, int>{};
    for (final f in facts) {
      if (f['type'] == FactType.timeAllocation.name) continue;
      final line = _factLine(f, projects, winIds);
      if (used + line.length + 1 > budget) {
        final p = projects[f['project_id']] ?? 'No project';
        omitted[p] = (omitted[p] ?? 0) + 1;
        continue;
      }
      used += line.length + 1;
      included.add(f);
    }

    final user = StringBuffer()
      ..writeln('Template instructions:')
      ..writeln(instructions)
      ..writeln()
      ..writeln('Period: ${period.label} (${period.start} to ${period.end})')
      ..writeln()
      ..writeln('Facts, most important first. Format: [fact id] type | days | project | flags: statement');
    if (included.isEmpty) user.writeln('(no facts)');
    for (final f in included) {
      user.writeln(_factLine(f, projects, winIds));
    }
    if (omitted.isNotEmpty) {
      user.writeln(
        'Not listed for space (mention only as counts, cite nothing): '
        '${omitted.entries.map((e) => '${e.key}: ${e.value} facts').join('; ')}',
      );
    }
    if (timeLines.isNotEmpty) {
      user
        ..writeln()
        ..writeln('Time breakdown by project, with the time fact ids to cite:')
        ..writeAll(timeLines, '\n')
        ..writeln();
    }

    emit(ReportProgress(ReportStage.generating));
    final raw = await _structured(
      LlmRoute.reports,
      system: system,
      user: user.toString(),
      schema: reportSchema,
      schemaName: 'report',
      onDelta: (d) => emit(ReportDelta(d)),
    );

    final timeIds = {
      for (final r in (time['by_project'] as List).cast<Map<String, Object?>>())
        ...(r['fact_ids'] as List).cast<String>(),
    };
    final valid = {...included.map((f) => f['fact_id'] as String), ...timeIds};
    final json = validateReport(raw, valid);
    final statements = {for (final f in facts) f['fact_id'] as String: f['statement'] as String};
    final markdown = renderReportMarkdown(
      title: '${template.name} — ${period.label}',
      report: json,
      factStatements: statements,
    );
    return _Draft(
      json: json,
      markdown: markdown,
      modelName: resolved.modelName,
      inputs: [
        for (final f in facts) (type: EntityType.fact, id: f['fact_id'] as String, revision: f['revision'] as int),
      ],
    );
  }

  static String _systemPrompt(String? style) {
    final b = StringBuffer('''
You write work reports from a list of facts about the user's work.
Rules:
- Use only the facts given. Never invent work, numbers, names, dates or impact.
- Every item must list, in fact_ids, the exact ids of the facts it is based on. Items without valid ids are discarded.
- Combine closely related facts into one item when it reads better; cite all of them.
- The template instructions shape structure and wording only, never the facts.
- Write in English, first person where natural. Plain text in items (no Markdown headings or citation marks).''');
    if (style != null && style.trim().isNotEmpty) {
      b.write('\n- Style instruction (wording only, never facts): ${style.trim()}');
    }
    return b.toString();
  }

  static String _factLine(Map<String, Object?> f, Map<String, String> projects, Set<String> winIds) {
    final days = f['period_start'] == f['period_end'] ? f['period_start'] : '${f['period_start']}..${f['period_end']}';
    final flags = [if (winIds.contains(f['fact_id'])) 'win', if (f['user_confirmed'] == true) 'user-confirmed'];
    final project = projects[f['project_id']] ?? 'No project';
    return '- [${f['fact_id']}] ${f['type']} | $days | $project | ${flags.join(', ')}: '
        '${(f['statement'] as String).replaceAll('\n', ' ')}';
  }
}

class _Draft {
  _Draft({required this.json, required this.markdown, required this.modelName, required this.inputs});
  final Map<String, Object?> json;
  final String markdown;
  final String modelName;
  final List<InputRef> inputs;
}
