// Independent tests (#99) for #109 in the engine isolate: the profile's IANA zone drives evidence
// days, the nudge's "today" and the UI-side profileUtcOffset; backups record the real appVersion.
import 'dart:io';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/engine_runtime.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/platform/time_zone.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

EngineConfig _config(String dir, String zone, {String? appVersion}) => appVersion == null
    ? EngineConfig(dataDir: dir, timeZone: zone, inMemory: true, startLoops: false)
    : EngineConfig(dataDir: dir, timeZone: zone, inMemory: true, startLoops: false, appVersion: appVersion);

void main() {
  late Directory dir;
  late UtcOffset saved;
  setUp(() {
    dir = tempDir();
    saved = profileUtcOffset;
  });
  tearDown(() {
    profileUtcOffset = saved;
    dir.deleteSync(recursive: true);
  });

  test('the profile zone sets the runtime offset and the UI-side profileUtcOffset', () async {
    final h = await EngineHandle.start(_config(dir.path, 'Asia/Kolkata'));
    addTearDown(h.shutdown);
    final summer = DateTime.utc(2026, 6, 1, 12);
    expect(await h.runtime(_offsetAtCmd(summer)), const Duration(hours: 5, minutes: 30));
    expect(profileUtcOffset(summer), const Duration(hours: 5, minutes: 30));
    expect(profileDayOf(DateTime.utc(2026, 11, 16, 18, 30)), '2026-11-17');
  });

  test('a DST zone gives a per-instant runtime offset', () async {
    final h = await EngineHandle.start(_config(dir.path, 'Europe/London'));
    addTearDown(h.shutdown);
    expect(await h.runtime(_offsetAtCmd(DateTime.utc(2026, 3, 29, 0, 30))), Duration.zero);
    expect(await h.runtime(_offsetAtCmd(DateTime.utc(2026, 3, 29, 1, 30))), const Duration(hours: 1));
  });

  test('evidence lands on the profile-zone day', () async {
    final h = await EngineHandle.start(_config(dir.path, 'Asia/Kolkata'));
    addTearDown(h.shutdown);
    final lateNote = await h.run(_noteAt(DateTime.utc(2026, 11, 16, 18, 30)));
    final early = await h.run(_noteAt(DateTime.utc(2026, 11, 16, 18, 29)));
    final rows = {for (final e in await h.db.select(h.db.evidences).get()) e.id: e.day};
    expect(rows[lateNote], '2026-11-17');
    expect(rows[early], '2026-11-16');
  });

  test('a negative profile zone puts early-UTC evidence on the previous day', () async {
    final h = await EngineHandle.start(_config(dir.path, 'America/New_York'));
    addTearDown(h.shutdown);
    await h.run(_noteAt(DateTime.utc(2026, 11, 17, 3)));
    expect((await h.db.select(h.db.evidences).getSingle()).day, '2026-11-16');
  });

  group('nudge', () {
    // +14 vs -11: their "today" always differs, so the check can only pass in the profile zone.
    const zone = 'Pacific/Kiritimati', other = 'Pacific/Pago_Pago';

    Future<(EngineHandle, FakeNotifier)> start() async {
      final notifier = FakeNotifier();
      final h = await EngineHandle.start(_config(dir.path, zone), host: fakeHost(notifier: notifier));
      addTearDown(h.shutdown);
      return (h, notifier);
    }

    test("fires when there is evidence on the profile zone's today", () async {
      final (h, notifier) = await start();
      await h.runtime(_evidenceOnCmd(todayIn(zoneOffset(zone))));
      expect(await h.runtime(_runNudgeCmd()), isTrue);
      expect(notifier.shown, [('Your day is drafted', '2-minute review?', 'open-today')]);
    });

    test("is skipped when evidence is only on another zone's today", () async {
      final (h, notifier) = await start();
      await h.runtime(_evidenceOnCmd(todayIn(zoneOffset(other))));
      expect(await h.runtime(_runNudgeCmd()), isTrue);
      expect(notifier.shown, isEmpty);
    });
  });

  group('backup manifest', () {
    test('records EngineConfig.appVersion', () async {
      final h = await EngineHandle.start(_config(dir.path, 'UTC', appVersion: '0.7.3'));
      addTearDown(h.shutdown);
      final file = await h.runtime(backupNowCmd());
      final m = await h.runtime(inspectBackupCmd(file));
      expect(m.appVersion, '0.7.3');
    });

    test('defaults to the dev marker when the app passes none', () async {
      final h = await EngineHandle.start(_config(dir.path, 'UTC'));
      addTearDown(h.shutdown);
      final m = await h.runtime(inspectBackupCmd(await h.runtime(backupNowCmd())));
      expect(m.appVersion, '0.0.0-dev');
    });
  });
}

// ---------- engine commands (top-level so closures capture only plain data) ----------

EngineCommand<Duration> _offsetAtCmd(DateTime t) => (rt) async => rt.utcOffset(t);

Future<String> Function(AntEngine) _noteAt(DateTime t) => (e) => e.addNote(text: 'note', at: t);

EngineCommand<void> _evidenceOnCmd(String day) => (rt) async {
      final now = DateTime.now().toUtc();
      await rt.db.into(rt.db.evidences).insert(EvidencesCompanion.insert(
            id: newId(),
            occurredStart: now,
            day: day,
            title: 'x',
            createdAt: now,
            updatedAt: now,
          ));
    };

/// Enqueues the nudge job and runs it (IO lane). True when a job ran without error.
EngineCommand<bool> _runNudgeCmd() => (rt) async {
      final id = await rt.engine.jobs.enqueue(nudgeJobKind);
      await rt.engine.jobs.runOne(JobLane.io);
      final job = await (rt.db.select(rt.db.jobs)..where((j) => j.id.equals(id))).getSingle();
      return job.state == JobState.done && job.lastError == null;
    };
