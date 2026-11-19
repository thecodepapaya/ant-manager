import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:drift/native.dart';

class TestClock implements Clock {
  TestClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

class MemSecrets implements SecretStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

class NoRouter implements ModelRouter {
  @override
  Future<ResolvedModel> resolve(LlmRoute route) => throw UnimplementedError();
}

class Unused implements BlobStore, GitExecutable, FileWatcher {
  @override
  Future<String> put(Uint8List bytes, {required String extension}) => throw UnimplementedError();
  @override
  Future<Uint8List> get(String path) => throw UnimplementedError();
  @override
  Future<void> delete(String path) => throw UnimplementedError();
  @override
  Future<String?> locate() => throw UnimplementedError();
  @override
  Future<String> run(String repoPath, List<String> args) => throw UnimplementedError();
  @override
  Stream<void> watch(List<String> paths) => throw UnimplementedError();
}

typedef SyncScript = Stream<PayloadObservation> Function(SourceContext ctx);

/// A source driven by a script; records every context it was given.
class ScriptSource implements Source {
  ScriptSource(this.kind, this.script);
  @override
  final SourceKind kind;
  SyncScript script;
  final contexts = <SourceContext>[];
  Future<SourceHealth> Function(SourceContext ctx)? onValidate;

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    contexts.add(ctx);
    return onValidate == null ? const SourceHealth.ok() : onValidate!(ctx);
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) {
    contexts.add(ctx);
    return script(ctx);
  }
}

/// A watchable source; each `changes()` call gets its own single-subscription controller, so we can
/// count live subscriptions per source id.
class WatchSource extends ScriptSource implements WatchableSource {
  WatchSource(SourceKind kind, {Set<String>? throwFor})
      : throwFor = throwFor ?? {},
        super(kind, _empty);
  final Set<String> throwFor;
  final _streams = <String, List<StreamController<void>>>{};

  static Stream<PayloadObservation> _empty(SourceContext _) => const Stream.empty();

  @override
  Stream<void> changes(SourceContext ctx) {
    if (throwFor.contains(ctx.sourceId)) throw StateError('misconfigured ${ctx.sourceId}');
    final c = StreamController<void>();
    (_streams[ctx.sourceId] ??= []).add(c);
    return c.stream;
  }

  List<StreamController<void>> _live(String id) =>
      [for (final c in _streams[id] ?? const <StreamController<void>>[]) if (c.hasListener) c];

  /// Number of subscriptions currently listening for [id].
  int active(String id) => _live(id).length;

  void emit(String id) {
    for (final c in _live(id)) {
      c.add(null);
    }
  }

  void emitError(String id) {
    for (final c in _live(id)) {
      c.addError(StateError('watch error'));
    }
  }
}

PayloadObservation obs(String id, {Map<String, Object?>? content, DateTime? at}) => PayloadObservation(
      externalId: id,
      kind: PayloadKind.commit,
      content: content ?? {'id': id},
      occurredStart: at ?? DateTime.utc(2026, 11, 17, 10),
      title: 'obs $id',
    );

class Harness {
  Harness._(this.db, this.engine, this.clock, this.secrets);

  final ProfileDb db;
  final AntEngine engine;
  final TestClock clock;
  final MemSecrets secrets;

  static Harness create({DateTime? now}) {
    final db = ProfileDb(NativeDatabase.memory());
    final clock = TestClock(now ?? DateTime.utc(2026, 11, 18, 12));
    final secrets = MemSecrets();
    final u = Unused();
    final engine = AntEngine(
      db: db,
      profileId: 'p',
      ports: EnginePorts(secrets: secrets, blobs: u, git: u, watcher: u, clock: clock),
      router: NoRouter(),
      utcOffset: (_) => Duration.zero,
    );
    return Harness._(db, engine, clock, secrets);
  }

  /// Sync service with the job handlers registered (so enqueue works).
  SyncService service({int batchSize = 200, Duration debounce = const Duration(milliseconds: 40)}) {
    registerSyncJobs(engine); // registers handlers on the queue
    return SyncService(engine, batchSize: batchSize, debounce: debounce);
  }

  Future<void> addRow(String id, SourceKind kind, {bool enabled = true, String config = '{}', String? cred}) =>
      db.into(db.sources).insert(SourcesCompanion.insert(
            id: id,
            kind: kind,
            name: id,
            enabled: Value(enabled),
            config: Value(config),
            credentialRef: Value(cred),
          ));

  Future<List<SyncCursor>> cursors(String sourceId) =>
      (db.select(db.syncCursors)..where((c) => c.sourceId.equals(sourceId))).get();

  Future<Map<String, String?>> cursorMap(String sourceId) async =>
      {for (final c in await cursors(sourceId)) c.scope: c.cursor};

  Future<SyncCursor?> status(String sourceId) =>
      (db.select(db.syncCursors)..where((c) => c.sourceId.equals(sourceId) & c.scope.equals(''))).getSingleOrNull();

  Future<List<String>> externalIds(String sourceId) async =>
      [for (final p in await (db.select(db.payloads)..where((p) => p.sourceId.equals(sourceId))).get()) p.externalId]
        ..sort();

  Future<List<Job>> jobs([String? kind]) async {
    final all = await db.select(db.jobs).get();
    return [for (final j in all) if (kind == null || j.kind == kind) j];
  }
}
