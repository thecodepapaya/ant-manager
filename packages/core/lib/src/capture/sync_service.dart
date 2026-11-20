import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../engine/engine.dart';
import '../ports/ports.dart';
import '../util/ids.dart';
import 'ingestor.dart';
import 'source.dart';
import 'sources/transcript.dart';

/// Outcome of one source in [SyncService.syncAll].
class SourceSyncResult {
  const SourceSyncResult(this.sourceId, {this.result, this.error});
  final String sourceId;
  final IngestResult? result;
  final String? error;
  bool get ok => error == null;
  @override
  String toString() => ok ? '$sourceId: $result' : '$sourceId: error $error';
}

/// Runs sources (LLD 04 §4.1, §4.3): builds a [SourceContext] per Source row, feeds observations to the
/// Ingestor in batches and commits staged cursors only after each batch commits (#69). Also the
/// source-management commands the app calls.
class SyncService {
  SyncService(this.e, {Dio? http, this.batchSize = 200, this.debounce = const Duration(seconds: 5)})
      : http = http ?? Dio();

  final AntEngine e;
  final Dio http;
  final int batchSize;
  final Duration debounce;

  /// Job kinds (IO lane). `sources.sync` takes `{source_id}`.
  static const syncAllJob = 'sources.syncAll';
  static const syncJob = 'sources.sync';

  ProfileDb get _db => e.db;
  Clock get _clock => e.ports.clock;

  // ---------- sync ----------

  /// Syncs one source. On error the committed cursors stay, lastError is recorded and the error rethrown.
  Future<IngestResult> syncSource(String sourceId) async {
    final row = await _row(sourceId);
    final total = IngestResult();
    try {
      final source = e.sources.create(row.kind);
      final ctx = await _context(row);
      var batch = <PayloadObservation>[];
      Future<void> flush() async {
        final b = batch;
        batch = [];
        await _db.transaction(() async {
          final r = await e.ingestor.ingest(sourceId, b);
          await ctx.commit();
          total
            ..created += r.created
            ..updated += r.updated
            ..tombstoned += r.tombstoned
            ..unchanged += r.unchanged;
        });
      }

      await for (final o in source.sync(ctx)) {
        batch.add(o);
        if (batch.length >= batchSize) await flush(); // pauses the source stream while ingesting
      }
      await flush(); // the rest, plus cursors set after the last observation
      await _status(sourceId, lastSuccessAt: _clock.now(), lastError: null);
      return total;
    } catch (err) {
      await _status(sourceId, lastError: err.toString());
      rethrow;
    }
  }

  /// Every enabled, syncable source, one at a time; a failure doesn't stop the others.
  Future<List<SourceSyncResult>> syncAll() async {
    final out = <SourceSyncResult>[];
    for (final s in await _syncable()) {
      try {
        out.add(SourceSyncResult(s.id, result: await syncSource(s.id)));
      } catch (err) {
        out.add(SourceSyncResult(s.id, error: err.toString()));
      }
    }
    return out;
  }

  // ---------- watching (#69, #73) ----------

  final _watches = <StreamSubscription<void>>[];
  final _timers = <String, Timer>{};
  void Function()? _onEnqueue;
  bool _watching = false;

  /// Subscribes to `changes()` of every enabled [WatchableSource]; each burst of changes enqueues one
  /// `sources.sync` [debounce] after the last event. [onEnqueue] lets the runtime wake its job loop.
  Future<void> startWatching({void Function()? onEnqueue}) async {
    await stopWatching();
    await _subscribe(onEnqueue);
  }

  Future<void> _subscribe(void Function()? onEnqueue) async {
    _watching = true;
    _onEnqueue = onEnqueue;
    for (final row in await _syncable()) {
      final source = e.sources.create(row.kind);
      if (source is! WatchableSource) continue;
      final ctx = await _context(row);
      final Stream<void> changes;
      try {
        changes = source.changes(ctx);
      } catch (_) {
        continue; // misconfigured (e.g. no repo path): polling still reports the error
      }
      _watches.add(changes.listen((_) {
        _timers[row.id]?.cancel();
        _timers[row.id] = Timer(debounce, () async {
          _timers.remove(row.id);
          if (!_watching) return;
          if (await enqueueSync(row.id)) _onEnqueue?.call();
        });
      }, onError: (Object _) {}));
    }
  }

  Future<void> stopWatching() async {
    _watching = false;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    await _unsubscribe();
  }

  Future<void> _unsubscribe() async {
    final subs = [..._watches];
    _watches.clear();
    for (final s in subs) {
      await s.cancel();
    }
  }

  /// Enqueues `sources.sync` for [sourceId] unless one is already queued or running. Returns true if enqueued.
  /// Check and insert share one transaction so concurrent callers can't both enqueue.
  Future<bool> enqueueSync(String sourceId) => _db.transaction(() async {
        final args = {'source_id': sourceId};
        final pending = await (_db.select(_db.jobs)
              ..where((j) =>
                  j.kind.equals(syncJob) &
                  j.args.equals(jsonEncode(args)) &
                  j.state.isInValues([JobState.queued, JobState.running]))
              ..limit(1))
            .getSingleOrNull();
        if (pending != null) return false;
        await e.jobs.enqueue(syncJob, args: args);
        return true;
      });

  // ---------- commands ----------

  /// Adds a source; [secret] is stored in the SecretStore under its credentialRef. Returns the source id.
  Future<String> addSource(SourceKind kind, String name, Map<String, Object?> config, {String? secret}) async {
    final id = newId();
    final ref = secret == null ? null : 'source:$id';
    if (ref != null) await e.ports.secrets.write(ref, secret!);
    await _db.into(_db.sources).insert(SourcesCompanion.insert(
      id: id,
      kind: kind,
      name: name,
      config: Value(jsonEncode(config)),
      credentialRef: Value(ref),
    ));
    await _rewatch();
    return id;
  }

  /// Changes name / config / secret / enabled. Cursors are kept.
  Future<void> updateSource(String id,
      {String? name, Map<String, Object?>? config, String? secret, bool? enabled}) async {
    final row = await _row(id);
    var ref = row.credentialRef;
    if (secret != null) {
      ref ??= 'source:$id:${newId()}'; // fresh: a restored copy keeps the id but must not share the keychain item (#121)
      await e.ports.secrets.write(ref, secret);
    }
    await (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(SourcesCompanion(
      name: name == null ? const Value.absent() : Value(name),
      config: config == null ? const Value.absent() : Value(jsonEncode(config)),
      credentialRef: Value(ref),
      enabled: enabled == null ? const Value.absent() : Value(enabled),
    ));
    await _rewatch();
  }

  /// Disables the source; its evidence, cursors and secret are kept.
  Future<void> removeSource(String id) => updateSource(id, enabled: false);

  Future<SourceHealth> validateSource(String id) async {
    final row = await _row(id);
    return e.sources.create(row.kind).validate(await _context(row));
  }

  /// Ingests a dropped transcript under the built-in transcript source. Returns its evidence id.
  Future<String> importTranscript(String fileName, String text, DateTime at) async {
    final sourceId = await _builtinSource(SourceKind.transcript, 'Transcripts');
    final o = transcriptObservation(fileName, text, at);
    await e.ingestor.ingest(sourceId, [o]);
    final p = await (_db.select(_db.payloads)
          ..where((x) => x.sourceId.equals(sourceId) & x.externalId.equals(o.externalId)))
        .getSingle();
    return p.evidenceId;
  }

  // ---------- internals ----------

  Future<SourceRow> _row(String id) => (_db.select(_db.sources)..where((s) => s.id.equals(id))).getSingle();

  /// Enabled sources whose kind has a registered connector (not notes / transcripts).
  Future<List<SourceRow>> _syncable() async {
    final kinds = e.sources.kinds.toSet();
    final rows = await (_db.select(_db.sources)..where((s) => s.enabled.equals(true))).get();
    return [for (final r in rows) if (kinds.contains(r.kind)) r];
  }

  /// Re-subscribes after a source change but keeps pending debounce timers (a disabled source's timer may
  /// still enqueue; the `sources.sync` handler skips it). Chained so overlapping commands don't double-subscribe.
  Future<void> _rewatch() {
    final next = _rewatching.then((_) async {
      if (!_watching) return;
      await _unsubscribe();
      await _subscribe(_onEnqueue);
    });
    _rewatching = next.catchError((Object _) {});
    return next;
  }

  Future<void> _rewatching = Future.value();

  Future<_Context> _context(SourceRow row) async {
    final ids = <String, List<String>>{};
    for (final i in await _db.select(_db.identities).get()) {
      (ids[i.kind] ??= []).add(i.value);
    }
    return _Context(this, row, jsonDecode(row.config) as Map<String, Object?>, ids);
  }

  /// Upserts the '' scope row's status columns without touching its cursor.
  Future<void> _status(String sourceId, {DateTime? lastSuccessAt, required String? lastError}) =>
      _db.into(_db.syncCursors).insert(
            SyncCursorsCompanion.insert(
              sourceId: sourceId,
              lastSuccessAt: Value.absentIfNull(lastSuccessAt),
              lastError: Value(lastError),
            ),
            onConflict: DoUpdate((_) => SyncCursorsCompanion(
                  lastSuccessAt: Value.absentIfNull(lastSuccessAt),
                  lastError: Value(lastError),
                )),
          );

  Future<String> _builtinSource(SourceKind kind, String name) async {
    final existing =
        await (_db.select(_db.sources)..where((s) => s.kind.equalsValue(kind))..limit(1)).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await _db.into(_db.sources).insert(SourcesCompanion.insert(id: id, kind: kind, name: name));
    return id;
  }
}

class _Context implements SourceContext {
  _Context(this._s, this._row, this.config, this._ids) : initialImportFrom = _s._clock.now().subtract(_initial);

  static const _initial = Duration(days: 30); // #88

  final SyncService _s;
  final SourceRow _row;
  final Map<String, List<String>> _ids;
  final _staged = <String, String>{};

  @override
  final Map<String, Object?> config;
  @override
  final DateTime initialImportFrom;

  @override
  String get sourceId => _row.id;
  @override
  List<String> identities(String kind) => _ids[kind] ?? const [];

  @override
  Future<String?> cursor(String scope) async {
    if (_staged.containsKey(scope)) return _staged[scope];
    final db = _s._db;
    final c = await (db.select(db.syncCursors)..where((c) => c.sourceId.equals(sourceId) & c.scope.equals(scope)))
        .getSingleOrNull();
    return c?.cursor;
  }

  @override
  void setCursor(String scope, String value) => _staged[scope] = value;

  /// Writes staged cursors to SyncCursors (inside the batch's transaction).
  Future<void> commit() async {
    final db = _s._db;
    for (final MapEntry(:key, :value) in _staged.entries) {
      await db.into(db.syncCursors).insert(
            SyncCursorsCompanion.insert(sourceId: sourceId, scope: Value(key), cursor: Value(value)),
            onConflict: DoUpdate((_) => SyncCursorsCompanion(cursor: Value(value))),
          );
    }
    _staged.clear();
  }

  @override
  Future<String?> secret() async => _row.credentialRef == null ? null : _s.e.ports.secrets.read(_row.credentialRef!);
  @override
  Dio get http => _s.http;
  @override
  Clock get clock => _s._clock;
  @override
  GitExecutable get git => _s.e.ports.git;
  @override
  CalendarBridge? get calendar => _s.e.ports.calendar;
  @override
  FileWatcher get watcher => _s.e.ports.watcher;
}

/// Polls each syncable source when due (LLD 04 §4.3): ICS every 60 min, everything else every 15 min
/// (watched sources too, as a backstop). Call [tick] on launch and every minute.
class SyncScheduler {
  SyncScheduler(this.sync);
  final SyncService sync;

  static const apiInterval = Duration(minutes: 15);
  static const icsInterval = Duration(minutes: 60);

  static Duration intervalFor(SourceKind kind) => kind == SourceKind.ics ? icsInterval : apiInterval;

  /// Enqueues `sources.sync` for each source whose last success is older than its interval (or never),
  /// unless one is already pending. Returns the source ids enqueued.
  Future<List<String>> tick([DateTime? now]) async {
    final at = (now ?? sync._clock.now()).toUtc();
    final db = sync._db;
    final status = {
      for (final c in await (db.select(db.syncCursors)..where((c) => c.scope.equals(''))).get()) c.sourceId: c,
    };
    final out = <String>[];
    for (final s in await sync._syncable()) {
      final last = status[s.id]?.lastSuccessAt;
      if (last != null && at.isBefore(last.add(intervalFor(s.kind)))) continue;
      if (await sync.enqueueSync(s.id)) out.add(s.id);
    }
    return out;
  }
}

/// Registers `sources.syncAll` and `sources.sync {source_id}` on the IO lane. `sources.sync` rethrows (job
/// backoff) and skips disabled sources; `sources.syncAll` doesn't, since per-source errors are already recorded.
SyncService registerSyncJobs(AntEngine e, {Dio? http}) {
  final s = SyncService(e, http: http);
  e.jobs.register(SyncService.syncAllJob, JobLane.io, (_) => s.syncAll());
  e.jobs.register(SyncService.syncJob, JobLane.io, (args) async {
    final id = args['source_id']! as String;
    if ((await s._row(id)).enabled) await s.syncSource(id); // removed after it was queued
  });
  return s;
}
