/// Engine isolate (#68): owns the DB writer, job queue, recompute loop, sources and LLM calls
/// for the active profile only (#77). Pure Dart + dart:io; never touches Flutter plugins.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../platform/file_blob_store.dart';
import '../platform/io_file_watcher.dart';
import 'messages.dart';
import 'port_bridge.dart';

const pausedSettingKey = 'collection.paused';

/// Backup destination folder; default `<dataDir>/backups/<profileId>`.
const backupFolderSettingKey = 'backup.folder';

/// Job kind the sync orchestrator (core, not built yet) registers to sync every enabled source.
const syncAllJobKind = 'sources.syncAll';

/// Isolate entry point. Spawned by `EngineHandle.start`.
Future<void> engineMain(EngineBoot boot) async {
  final rx = ReceivePort('ant-engine');
  final bridge = UiBridge(boot.ui);
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
          boot.ui.send(CommandResult(msg.id, error: e.toString(), stack: st.toString()));
        }
        rt?.kick();
      case ShutdownEngine():
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
    boot.ui.send(EngineReady(
      commands: rx.sendPort,
      appDb: await rt.appDb.serializableConnection(),
      profileDb: await rt.db.serializableConnection(),
      profileId: rt.profile.id,
    ));
    if (boot.config.startLoops) rt.startLoops();
  } catch (e, st) {
    boot.ui.send(EngineFailed(e.toString(), st.toString()));
    await sub.cancel();
    rx.close();
  }
}

/// What a command sees inside the engine isolate.
class EngineRuntime {
  EngineRuntime._(this.config, this.appDb, this.db, this.profile, this.engine, this.scheduler, this.paused);

  final EngineConfig config;
  final AppDb appDb;
  final ProfileDb db;
  final Profile profile;
  final AntEngine engine;
  final Scheduler scheduler;
  bool paused;

  var _stopped = false;
  Completer<void>? _wake;
  final _loops = <Future<void>>[];
  final _stopWaiters = <Completer<void>>[];

  static Future<EngineRuntime> open(EngineConfig config, UiBridge bridge) async {
    final appDb = AppDb(_open(config, p.join(config.dataDir, 'app.sqlite')));
    final profile = await ensureActiveProfile(appDb, config.timeZone);
    final db = ProfileDb(_open(config, p.join(config.dataDir, 'profiles', '${profile.id}.sqlite')));
    final secrets = BridgedSecretStore(bridge);
    // System zone, DST-correct. TODO(#87): resolve the profile's IANA zone once core has tz data.
    Duration offset(DateTime t) => t.toLocal().timeZoneOffset;
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
    registerBuiltinTools(engine.tools);
    await TemplateService(db).seedBuiltins();

    // Scheduled reports (LLM lane) and backups (IO lane), LLD 04 §4.11.
    final generator = ReportGenerator(db: db, router: engine.router, tools: engine.tools, profileId: profile.id);
    for (final (kind, period) in const [
      (Scheduler.dailyReport, PeriodKind.daily),
      (Scheduler.weeklyReport, PeriodKind.weekly),
      (Scheduler.monthlyReport, PeriodKind.monthly),
      (Scheduler.quarterlyReport, PeriodKind.quarterly),
    ]) {
      engine.jobs.register(kind, JobLane.llm, scheduledReportHandler(generator, period, offset));
    }
    final backup = BackupService(db, profileName: profile.name, appVersion: config.appVersion, blobs: ports.blobs);
    engine.jobs.register(Scheduler.backup, JobLane.io, (_) async {
      final row = await (db.select(db.settings)..where((s) => s.key.equals(backupFolderSettingKey))).getSingleOrNull();
      await backup.createBackup(row?.value ?? p.join(config.dataDir, 'backups', profile.id));
    });
    final scheduler = Scheduler(db, engine.jobs, utcOffset: offset);
    await scheduler.seedDefaults();

    final pausedRow =
        await (db.select(db.settings)..where((s) => s.key.equals(pausedSettingKey))).getSingleOrNull();
    return EngineRuntime._(config, appDb, db, profile, engine, scheduler, pausedRow?.value == 'true');
  }

  static QueryExecutor _open(EngineConfig config, String path) {
    if (config.inMemory) return NativeDatabase.memory();
    Directory(p.dirname(path)).createSync(recursive: true);
    return NativeDatabase(File(path));
  }

  /// First run creates "Work" in the system time zone; otherwise returns the active profile
  /// (activating the oldest one if none is flagged).
  static Future<Profile> ensureActiveProfile(AppDb appDb, String timeZone) => appDb.transaction(() async {
        final all = await (appDb.select(appDb.profiles)..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();
        if (all.isEmpty) {
          final id = newId();
          await appDb.into(appDb.profiles).insert(ProfilesCompanion.insert(
                id: id,
                name: 'Work',
                timeZone: timeZone,
                active: const Value(true),
                createdAt: DateTime.now().toUtc(),
              ));
          return (appDb.select(appDb.profiles)..where((p) => p.id.equals(id))).getSingle();
        }
        final active = all.where((p) => p.active).firstOrNull;
        if (active != null) return active;
        await _setActive(appDb, all.first.id);
        return all.first.copyWith(active: true);
      });

  static Future<void> _setActive(AppDb appDb, String id) async {
    await appDb.update(appDb.profiles).write(const ProfilesCompanion(active: Value(false)));
    await (appDb.update(appDb.profiles)..where((p) => p.id.equals(id)))
        .write(const ProfilesCompanion(active: Value(true)));
  }

  // ---------- app-level commands (profiles, collection) ----------

  /// Marks [id] active. The UI then restarts the engine on that profile (#77).
  Future<void> setActiveProfile(String id) => appDb.transaction(() => _setActive(appDb, id));

  Future<String> createProfile(String name) async {
    final id = newId();
    await appDb.into(appDb.profiles).insert(ProfilesCompanion.insert(
          id: id,
          name: name,
          timeZone: config.timeZone,
          createdAt: DateTime.now().toUtc(),
        ));
    return id;
  }

  /// Pause collection: the IO lane (source syncs) stops; recompute and LLM work continue.
  /// TODO(core): move into AntEngine once it has a settings API.
  Future<void> setPaused(bool value) async {
    paused = value;
    await db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: pausedSettingKey, value: '$value'));
  }

  /// Returns false when no sync orchestrator is registered yet.
  Future<bool> syncNow() async {
    try {
      await engine.jobs.enqueue(syncAllJobKind);
      return true;
    } on StateError {
      return false;
    }
  }

  // ---------- loops ----------

  void startLoops() {
    _loops
      ..add(_laneLoop(JobLane.io))
      ..add(_laneLoop(JobLane.llm))
      ..add(_schedulerLoop());
  }

  /// Scheduler tick on launch and every minute (missed runs catch up once, #79).
  Future<void> _schedulerLoop() async {
    while (!_stopped) {
      try {
        if ((await scheduler.tick()).isNotEmpty) kick();
      } catch (e, st) {
        stderr.writeln('engine scheduler: $e\n$st');
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
        stderr.writeln('engine ${lane.name} loop: $e\n$st');
      }
      if (!worked && !_stopped) {
        await (_wake ??= Completer<void>()).future.timeout(config.idlePoll, onTimeout: () {});
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    kick();
    for (final w in [..._stopWaiters]) {
      w.complete();
    }
    await Future.wait(_loops);
    await db.close();
    await appDb.close();
  }
}
