/// drift `watch()` reads for the Sources, Settings and Onboarding screens.
library;

import 'package:core/core.dart' hide Provider;
import 'package:core/core.dart' as core show Provider;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Source kinds the user connects (built-in note/transcript/screenshot sources are hidden).
bool isConnector(SourceKind k) =>
    k != SourceKind.manualNote && k != SourceKind.transcript && k != SourceKind.screenshotCapture;

/// A source with its sync health (the '' scope cursor row; SyncService writes status there).
class SourceStatus {
  const SourceStatus(this.row, this.lastSuccessAt, this.lastError);
  final SourceRow row;
  final DateTime? lastSuccessAt;
  final String? lastError;
}

final sourcesProvider = StreamProvider<List<SourceStatus>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  final q = db.select(db.sources).join([
    leftOuterJoin(db.syncCursors, db.syncCursors.sourceId.equalsExp(db.sources.id) & db.syncCursors.scope.equals('')),
  ])
    ..orderBy([OrderingTerm.asc(db.sources.kind), OrderingTerm.asc(db.sources.name)]);
  yield* q.watch().map((rows) => [
        for (final r in rows)
          SourceStatus(r.readTable(db.sources), r.readTableOrNull(db.syncCursors)?.lastSuccessAt,
              r.readTableOrNull(db.syncCursors)?.lastError),
      ]);
});

final identitiesProvider = StreamProvider<List<Identity>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.identities)..orderBy([(i) => OrderingTerm.asc(i.kind), (i) => OrderingTerm.asc(i.value)]))
      .watch();
});

final curationRulesProvider = StreamProvider<List<CurationRule>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.curationRules)..orderBy([(r) => OrderingTerm.asc(r.priority)])).watch();
});

final llmProvidersProvider = StreamProvider<List<core.Provider>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.appDb.select(h.appDb.providers)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
});

final llmModelsProvider = StreamProvider<List<Model>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.appDb.select(h.appDb.models)..orderBy([(m) => OrderingTerm.asc(m.modelName)])).watch();
});

/// Route → model id (unset routes are absent).
final taskRoutesProvider = StreamProvider<Map<LlmRoute, String>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* h.db.select(h.db.taskRoutes).watch().map((rows) => {
        for (final r in rows)
          if (r.modelId != null) r.route: r.modelId!,
      });
});

final schedulesProvider = StreamProvider<Map<String, Schedule>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* h.db.select(h.db.schedules).watch().map((rows) => {for (final r in rows) r.id: r});
});

final settingsProvider = StreamProvider<Map<String, String>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* h.db.select(h.db.settings).watch().map((rows) => {for (final r in rows) r.key: r.value});
});

final templatesProvider = StreamProvider<List<Template>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.templates)..orderBy([(t) => OrderingTerm.desc(t.builtIn), (t) => OrderingTerm.asc(t.name)]))
      .watch();
});

/// Evidence count per source id (onboarding import progress).
final evidenceBySourceProvider = StreamProvider<Map<String, int>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  yield* db
      .customSelect('SELECT source_id AS s, COUNT(*) AS c FROM payloads GROUP BY source_id', readsFrom: {db.payloads})
      .watch()
      .map((rows) => {for (final r in rows) r.read<String>('s'): r.read<int>('c')});
});

const onboardingDoneSettingKey = 'onboarding.done';
const crashReportsSettingKey = 'crashReports.optIn';

/// Whether to show onboarding, decided once per engine start: no identities, no connected sources
/// and not finished or skipped before. Latched so adding sources mid-flow doesn't close it.
final onboardingNeededProvider = FutureProvider<bool>((ref) async {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  final row = await db.customSelect(
    "SELECT (SELECT value FROM settings WHERE key = '$onboardingDoneSettingKey') AS done, "
    '(SELECT COUNT(*) FROM identities) AS ids, '
    "(SELECT COUNT(*) FROM sources WHERE kind NOT IN ('manualNote', 'transcript', 'screenshotCapture')) AS srcs",
  ).getSingle();
  return row.read<String?>('done') != 'true' && row.read<int>('ids') == 0 && row.read<int>('srcs') == 0;
});
