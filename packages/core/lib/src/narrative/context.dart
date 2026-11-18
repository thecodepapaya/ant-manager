import 'dart:convert';

import '../ai/llm.dart';
import '../ai/structured.dart';
import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../engine/engine.dart';
import '../ports/ports.dart';
import '../staleness/staleness.dart';
import '../util/ids.dart';

/// What every narrative stage needs. Built from an [AntEngine] in production, by hand in tests.
class NarrativeContext {
  NarrativeContext({required this.db, required this.router, required this.blobs, this.clock = const SystemClock()})
    : structured = StructuredOutput(router),
      deps = DependencyRecorder(db);

  factory NarrativeContext.of(AntEngine e) =>
      NarrativeContext(db: e.db, router: e.router, blobs: e.ports.blobs, clock: e.ports.clock);

  final ProfileDb db;
  final ModelRouter router;
  final StructuredOutput structured;
  final BlobStore blobs;
  final Clock clock;
  final DependencyRecorder deps;

  /// Model context length in tokens for [route] (32k when the provider doesn't say).
  Future<int> contextTokens(LlmRoute route) async => (await router.resolve(route)).info.contextLength ?? 32000;

  Future<String> modelName(LlmRoute route) async => (await router.resolve(route)).modelName;

  Future<bool> isStale(EntityType type, String id) => StalenessService(db).isStale((type: type, id: id));

  /// Adds a recompute entry by hand (only for changes triggers can't see, e.g. permanent delete).
  Future<void> enqueue(EntityType type, String id, String reason) => db
      .into(db.recomputeQueue)
      .insert(RecomputeQueueCompanion.insert(entityType: type, entityId: id, reason: reason, enqueuedAt: clock.now()));
}

/// Rough token estimate used for prompt budgets: chars / 4.
int estimateTokens(String s) => (s.length / 4).ceil();

/// Payload content as compact text for prompts, without attachment paths, cut at [max] chars.
String excerpt(Payload p, int max) {
  var text = p.content;
  try {
    final m = jsonDecode(p.content);
    if (m is Map) {
      m.remove('attachments');
      text = jsonEncode(m);
    }
  } on FormatException {
    // keep raw text
  }
  return text.length <= max ? text : '${text.substring(0, max)}…[truncated]';
}

Map<String, Object?> contentOf(Payload p) {
  try {
    final m = jsonDecode(p.content);
    if (m is Map<String, Object?>) return m;
  } on FormatException {
    // fall through
  }
  return const {};
}

/// The day before/after [day] by [days] (YYYY-MM-DD in, YYYY-MM-DD out).
String shiftDay(String day, int days) =>
    dayOf(DateTime.parse('${day}T00:00:00Z').add(Duration(days: days)), Duration.zero);

extension NarrativeDb on ProfileDb {
  Future<Map<String, Payload>> payloadsById(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await (select(payloads)..where((p) => p.id.isIn(list))).get();
    return {for (final p in rows) p.id: p};
  }
}
