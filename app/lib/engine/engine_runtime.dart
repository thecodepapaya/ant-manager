/// Engine isolate (#68): owns the DB writer, job queue, recompute loop, sources and LLM calls
/// for the active profile only (#77). Pure Dart + dart:io; never touches Flutter plugins.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../platform/file_blob_store.dart';
import '../platform/io_file_watcher.dart';
import '../platform/rotating_log.dart';
import 'messages.dart';
import 'port_bridge.dart';

const pausedSettingKey = 'collection.paused';

/// Backup destination folder; default `<dataDir>/backups/<profileId>`.
const backupFolderSettingKey = 'backup.folder';
const backupKeepSettingKey = 'backup.keep';
const backupReadableSettingKey = 'backup.readableExport';
const backupLastSuccessSettingKey = 'backup.lastSuccessAt';
const backupLastErrorSettingKey = 'backup.lastError';

/// Job + schedule kind of the daily nudge notification.
const nudgeJobKind = 'nudge';

/// Isolate entry point. Spawned by `EngineHandle.start`.
Future<void> engineMain(EngineBoot boot) async {
  if (!boot.config.inMemory) Log.sink = RotatingFileLog(logsDir(boot.config.dataDir), 'engine');
  Log.isolate = 'engine';
  final started = Stopwatch()..start();
  Log.info('engine.start');
  final rx = ReceivePort('ant-engine');
  final bridge = UiBridge(boot.ui, rx.sendPort);
  EngineRuntime? rt;
  late final StreamSubscription<Object?> sub;
  sub = rx.listen((msg) async {
    switch (msg) {
      case PortReply():
        bridge.onReply(msg);
      case PortEvent():
        bridge.onEvent(msg);
      case RunCommand():
        try {
          final value = await msg.body(rt!);
          boot.ui.send(CommandResult(msg.id, value: value));
        } catch (e, st) {
          Log.error('command.fail', e, st);
          boot.ui.send(
            CommandResult(msg.id, error: e.toString(), stack: st.toString()),
          );
        }
        rt?.kick();
      case ShutdownEngine():
        Log.info('engine.stop');
        await rt?.stop();
        bridge.close();
        await sub.cancel();
        rx.close();
        msg.done.send(null);
        Isolate.exit();
    }
  });
  try {
    rt = await EngineRuntime.open(boot.config, bridge);
    boot.ui.send(
      EngineReady(
        commands: rx.sendPort,
        appDb: await rt.appDb.serializableConnection(),
        profileDb: await rt.db.serializableConnection(),
        profileId: rt.profile.id,
        timeZone: rt.profile.timeZone,
      ),
    );
    Log.info('engine.ready', {'profile': rt.profile.id, 'ms': started.elapsedMilliseconds});
    if (boot.config.startLoops) rt.startLoops();
  } catch (e, st) {
    Log.error('engine.failed', e, st);
    boot.ui.send(EngineFailed(e.toString(), st.toString()));
    await sub.cancel();
    rx.close();
  }
}

/// What a command sees inside the engine isolate.
class EngineRuntime {
  EngineRuntime._(
    this.config,
    this.appDb,
    this.db,
    this.profile,
    this.engine,
    this.scheduler,
    this.sync,
    this.reports,
    this.paused,
    this.utcOffset,
  );

  final EngineConfig config;
  final AppDb appDb;
  final ProfileDb db;
  final Profile profile;
  final AntEngine engine;
  final Scheduler scheduler;
  final SyncService sync;
  late final syncScheduler = SyncScheduler(sync);

  /// On-demand report generation (Reports and Today screens).
  final ReportGenerator reports;
  bool paused;

  /// The profile's time zone offset at an instant (#87, #109): day boundaries, schedules, the nudge.
  final UtcOffset utcOffset;

  var _stopped = false;
  Completer<void>? _wake;
  final _loops = <Future<void>>[];
  final _stopWaiters = <Completer<void>>[];

  static Future<EngineRuntime> open(
    EngineConfig config,
    UiBridge bridge,
  ) async {
    final appDb = AppDb(_open(config, p.join(config.dataDir, 'app.sqlite')));
    final profile = await ensureActiveProfile(appDb, config.timeZone);
    final db = ProfileDb(
      _open(config, p.join(config.dataDir, 'profiles', '${profile.id}.sqlite')),
    );
    final secrets = BridgedSecretStore(bridge);
    final offset = zoneOffset(profile.timeZone);
    final ports = EnginePorts(
      secrets: secrets,
      blobs: FileBlobStore(p.join(config.dataDir, 'blobs', profile.id)),
      git: ProcessGitExecutable(),
      watcher: IoFileWatcher(),
      calendar: config.calendarAvailable ? BridgedCalendar(bridge) : null,
      notifier: BridgedNotifier(bridge),
    );
    final engine = AntEngine(
      db: db,
      profileId: profile.id,
      ports: ports,
      router: DbModelRouter(appDb: appDb, profileDb: db, secrets: secrets),
      utcOffset: offset,
    );
    registerCodeSources(engine.sources);
    registerOtherSources(engine.sources);
    final sync = registerSyncJobs(
      engine,
    ); // sources.syncAll / sources.sync, IO lane
    registerBuiltinTools(engine.tools);
    registerNarrativePipeline(engine);
    await TemplateService(db).seedBuiltins();

    // Scheduled reports (LLM lane) and backups (IO lane), LLD 04 §4.11.
    final generator = ReportGenerator(
      db: db,
      router: engine.router,
      tools: engine.tools,
      profileId: profile.id,
    );
    for (final (kind, period) in const [
      (Scheduler.dailyReport, PeriodKind.daily),
      (Scheduler.weeklyReport, PeriodKind.weekly),
      (Scheduler.monthlyReport, PeriodKind.monthly),
      (Scheduler.quarterlyReport, PeriodKind.quarterly),
    ]) {
      engine.jobs.register(
        kind,
        JobLane.llm,
        scheduledReportHandler(generator, period, offset),
      );
    }
    late final EngineRuntime rt;
    engine.jobs.register(Scheduler.backup, JobLane.io, (_) => rt.backupNow());
    engine.jobs.register(nudgeJobKind, JobLane.io, (_) => rt._nudge());
    final scheduler = Scheduler(db, engine.jobs, utcOffset: offset);
    await scheduler.seedDefaults();
    // Daily nudge (SPEC §7): weekdays at 18:05 by default; edited in Settings → Schedule.
    await db
        .into(db.schedules)
        .insert(
          SchedulesCompanion.insert(
            id: nudgeJobKind,
            kind: nudgeJobKind,
            rule: jsonEncode(
              const ScheduleRule(
                hour: 18,
                minute: 5,
                weekdays: [1, 2, 3, 4, 5],
              ).toJson(),
            ),
            lastRunAt: Value(DateTime.now().toUtc()),
          ),
          mode: InsertMode.insertOrIgnore,
        );

    final pausedRow = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(pausedSettingKey))).getSingleOrNull();
    return rt = EngineRuntime._(
      config,
      appDb,
      db,
      profile,
      engine,
      scheduler,
      sync,
      generator,
      pausedRow?.value == 'true',
      offset,
    );
  }

  Future<String?> setting(String key) async => (await (db.select(
    db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> putSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  String get defaultBackupFolder =>
      p.join(config.dataDir, 'backups', profile.id);

  /// Runs a backup with the Settings → Backup options and records its status (SPEC §9).
  /// Returns the bundle path.
  Future<String> backupNow() async {
    final folder = await setting(backupFolderSettingKey) ?? defaultBackupFolder;
    final keep = int.tryParse(await setting(backupKeepSettingKey) ?? '') ?? 14;
    final readable = await setting(backupReadableSettingKey) == 'true';
    final service = BackupService(
      db,
      profileName: profile.name,
      appVersion: config.appVersion,
      blobs: engine.ports.blobs,
      keep: keep,
    );
    try {
      final file = await service.createBackup(folder, readableExport: readable);
      await putSetting(
        backupLastSuccessSettingKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      await putSetting(backupLastErrorSettingKey, '');
      return file.path;
    } catch (e) {
      await putSetting(backupLastErrorSettingKey, '$e');
      rethrow;
    }
  }

  /// "Your day is drafted" nudge; skipped on days with no evidence (SPEC §7).
  Future<void> _nudge() async {
    final today = todayIn(utcOffset);
    final any =
        await (db.select(db.evidences)
              ..where((e) => e.day.equals(today))
              ..limit(1))
            .getSingleOrNull();
    if (any == null) return;
    await engine.ports.notifier?.show(
      title: 'Your day is drafted',
      body: '2-minute review?',
      actionId: 'open-today',
    );
  }

  static QueryExecutor _open(EngineConfig config, String path) {
    if (config.inMemory) return NativeDatabase.memory();
    Directory(p.dirname(path)).createSync(recursive: true);
    return NativeDatabase(File(path));
  }

  /// First run creates "Work" in the system time zone; otherwise returns the active profile
  /// (activating the oldest one if none is flagged).
  static Future<Profile> ensureActiveProfile(AppDb appDb, String timeZone) =>
      appDb.transaction(() async {
        final all = await (appDb.select(
          appDb.profiles,
        )..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();
        if (all.isEmpty) {
          final id = newId();
          await appDb
              .into(appDb.profiles)
              .insert(
                ProfilesCompanion.insert(
                  id: id,
                  name: 'Work',
                  timeZone: timeZone,
                  active: const Value(true),
                  createdAt: DateTime.now().toUtc(),
                ),
              );
          return (appDb.select(
            appDb.profiles,
          )..where((p) => p.id.equals(id))).getSingle();
        }
        final active = all.where((p) => p.active).firstOrNull;
        if (active != null) return active;
        await _setActive(appDb, all.first.id);
        return all.first.copyWith(active: true);
      });

  static Future<void> _setActive(AppDb appDb, String id) async {
    await appDb
        .update(appDb.profiles)
        .write(const ProfilesCompanion(active: Value(false)));
    await (appDb.update(appDb.profiles)..where((p) => p.id.equals(id))).write(
      const ProfilesCompanion(active: Value(true)),
    );
  }

  // ---------- app-level commands (profiles, collection) ----------

  /// Marks [id] active. The UI then restarts the engine on that profile (#77).
  Future<void> setActiveProfile(String id) =>
      appDb.transaction(() => _setActive(appDb, id));

  Future<String> createProfile(String name) async {
    final id = newId();
    await appDb
        .into(appDb.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: id,
            name: name,
            timeZone: config.timeZone,
            createdAt: DateTime.now().toUtc(),
          ),
        );
    return id;
  }

  /// Pause collection: the IO lane (source syncs) stops; recompute and LLM work continue.
  /// TODO(core): move into AntEngine once it has a settings API.
  Future<void> setPaused(bool value) async {
    paused = value;
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: pausedSettingKey, value: '$value'),
        );
  }

  /// Enqueues a sync of every enabled source.
  Future<bool> syncNow() async {
    await engine.jobs.enqueue(SyncService.syncAllJob);
    return true;
  }

  // ---------- loops ----------

  void startLoops() {
    _loops
      ..add(_laneLoop(JobLane.io))
      ..add(_laneLoop(JobLane.llm))
      ..add(_schedulerLoop());
    unawaited(
      sync.startWatching(onEnqueue: kick).catchError((Object e, StackTrace st) {
        Log.error('engine.watchers', e, st);
      }),
    );
  }

  /// Scheduler tick on launch and every minute (missed runs catch up once, #79).
  Future<void> _schedulerLoop() async {
    while (!_stopped) {
      try {
        final reports = await scheduler.tick();
        final syncs = await syncScheduler
            .tick(); // per-source polls when due (LLD 04 §4.3)
        if (reports.isNotEmpty || syncs.isNotEmpty) kick();
      } catch (e, st) {
        Log.error('engine.scheduler', e, st);
      }
      final wait = Completer<void>();
      _stopWaiters.add(wait);
      await wait.future.timeout(const Duration(minutes: 1), onTimeout: () {});
      _stopWaiters.remove(wait);
    }
  }

  /// Wakes idle loops (after a command that may have enqueued work).
  void kick() {
    final w = _wake;
    _wake = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<void> _laneLoop(JobLane lane) async {
    while (!_stopped) {
      var worked = false;
      try {
        if (!(lane == JobLane.io && paused)) worked = await engine.jobs.runOne(lane);
        // Recompute shares the IO loop; handlers are registered by core's narrative layer.
        if (lane == JobLane.io) worked = await engine.recompute.drain() > 0 || worked;
      } catch (e, st) {
        Log.error('engine.loop', e, st, {'lane': lane});
      }
      if (!worked && !_stopped) {
        await (_wake ??= Completer<void>()).future.timeout(
          config.idlePoll,
          onTimeout: () {},
        );
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    await sync.stopWatching();
    kick();
    for (final w in [..._stopWaiters]) {
      w.complete();
    }
    await Future.wait(_loops);
    await db.close();
    await appDb.close();
  }
}
