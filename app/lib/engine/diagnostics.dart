/// "Copy diagnostics" (SPEC §10, #126): a plain-text report of app/OS versions, setup shape and the recent
/// log. Kinds, flags, counts and redacted errors only: no names, URLs, credentials or content.
library;

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'messages.dart';

/// The engine's section: profiles, schema versions, sources, providers and the job queue.
EngineCommand<String> diagnosticsCmd() => (rt) async {
  final b = StringBuffer();
  final profiles = await rt.appDb.select(rt.appDb.profiles).get();
  b
    ..writeln('Profiles: ${profiles.length}')
    ..writeln('Schema: app v${rt.appDb.schemaVersion}, profile v${rt.db.schemaVersion}')
    ..writeln('Collection paused: ${rt.paused}')
    ..writeln()
    ..writeln('Sources (active profile):');

  final db = rt.db;
  final status = {
    for (final c in await (db.select(db.syncCursors)..where((c) => c.scope.equals(''))).get()) c.sourceId: c,
  };
  final sources = await (db.select(db.sources)..orderBy([(s) => OrderingTerm.asc(s.kind)])).get();
  if (sources.isEmpty) b.writeln('  none');
  for (final s in sources) {
    final c = status[s.id];
    final last = switch (c) {
      _ when c?.lastError?.isNotEmpty ?? false => 'error: ${redact(c!.lastError!, max: 160)}',
      _ when c?.lastSuccessAt != null => 'ok ${c!.lastSuccessAt!.toUtc().toIso8601String()}',
      _ => 'never synced',
    };
    b.writeln('  ${s.kind.name.padRight(14)} ${s.enabled ? 'enabled ' : 'disabled'}  $last');
  }

  b
    ..writeln()
    ..writeln('AI providers:');
  final providers = await rt.appDb.select(rt.appDb.providers).get();
  final models = await rt.appDb.select(rt.appDb.models).get();
  if (providers.isEmpty) b.writeln('  none');
  for (final p in providers) {
    final n = models.where((m) => m.providerId == p.id).length;
    final where = requiresConsent(p.baseUrl) ? 'remote  ' : 'loopback';
    b.writeln('  ${p.kind.name.padRight(10)} ${p.protocol.name.padRight(7)} $where  $n model${n == 1 ? '' : 's'}');
  }
  final routes = [
    for (final r in await db.select(db.taskRoutes).get())
      if (r.modelId != null) r.route.name,
  ];
  b
    ..writeln('  routes set: ${routes.isEmpty ? 'none' : routes.join(', ')}')
    ..writeln()
    ..writeln('Jobs:');
  final rows = await db
      .customSelect(
        'SELECT kind, state, COUNT(*) AS n FROM jobs GROUP BY kind, state ORDER BY kind, state',
        readsFrom: {db.jobs},
      )
      .get();
  final byState = <String, int>{};
  for (final r in rows) {
    byState.update(r.read<String>('state'), (v) => v + r.read<int>('n'), ifAbsent: () => r.read<int>('n'));
  }
  b.writeln('  ${[for (final s in JobState.values) '${s.name} ${byState[s.name] ?? 0}'].join(' · ')}');
  for (final r in rows.where((r) => r.read<String>('state') != JobState.done.name)) {
    b.writeln('  ${r.read<String>('kind').padRight(18)} ${r.read<String>('state').padRight(8)} ${r.read<int>('n')}');
  }
  final failed =
      await (db.select(db.jobs)
            ..where((j) => j.lastError.isNotNull() & j.state.equalsValue(JobState.done).not())
            ..orderBy([(j) => OrderingTerm.desc(j.runAfter)])
            ..limit(1))
          .getSingleOrNull();
  if (failed?.lastError != null) {
    b.writeln('  last job error (${failed!.kind}): ${redact(failed.lastError!, max: 160)}');
  }
  return b.toString();
};

/// The full report. [app] is the UI isolate's facts (version, OS, Flutter/Dart), [engine] is
/// [diagnosticsCmd]'s text (or why it failed) and [logs] the recent log lines.
String diagnosticsReport({
  required Map<String, String> app,
  required String engine,
  required List<String> logs,
  DateTime? now,
}) {
  final b = StringBuffer()
    ..writeln('Ant Manager diagnostics')
    ..writeln('Generated: ${(now ?? DateTime.now()).toUtc().toIso8601String()}');
  for (final MapEntry(:key, :value) in app.entries) {
    b.writeln('$key: $value');
  }
  b
    ..writeln()
    ..write(engine)
    ..writeln()
    ..writeln('Recent log (${logs.length} lines, oldest first):');
  for (final l in logs) {
    b.writeln(l);
  }
  return b.toString();
}
