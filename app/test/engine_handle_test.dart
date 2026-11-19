import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/engine_runtime.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:core/core.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';

Future<String> _addNote(AntEngine e) => e.addNote(text: 'Shipped the bridge', at: DateTime.now());

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('start', () {
    test('creates "Work" as the only, active profile matching profileId', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      addTearDown(h.shutdown);
      final profiles = await h.appDb.select(h.appDb.profiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.single.name, 'Work');
      expect(profiles.single.active, isTrue);
      expect(profiles.single.timeZone, 'UTC');
      expect(profiles.single.id, h.profileId);
    });

    test('a second start on the same file DB reuses the profile', () async {
      final first = await EngineHandle.start(testConfig(dir.path, inMemory: false));
      final id = first.profileId;
      await first.shutdown();
      expect(File(p.join(dir.path, 'app.sqlite')).existsSync(), isTrue);
      expect(File(p.join(dir.path, 'profiles', '$id.sqlite')).existsSync(), isTrue);

      final second = await EngineHandle.start(testConfig(dir.path, inMemory: false));
      addTearDown(second.shutdown);
      expect(second.profileId, id);
      final profiles = await second.appDb.select(second.appDb.profiles).get();
      expect(profiles, hasLength(1));
    });
  });

  group('commands', () {
    late EngineHandle h;
    setUp(() async => h = await EngineHandle.start(testConfig(dir.path)));
    tearDown(() => h.shutdown());

    test('run(addNote) returns an evidence id and a UI-side watch() updates', () async {
      final counts = h.db.select(h.db.evidences).watch().map((r) => r.length);
      final seen = <int>[];
      final sub = counts.listen(seen.add);
      addTearDown(sub.cancel);
      await pumpUntil(() => seen.isNotEmpty);
      expect(seen.first, 0);

      final id = await h.run(_addNote);
      expect(id, isA<String>().having((s) => s, 'id', isNotEmpty));
      await pumpUntil(() => seen.last == 1);
      final ev = await h.db.select(h.db.evidences).getSingle();
      expect(ev.id, id);
      expect(ev.title, 'Shipped the bridge');
    });

    test('run accepts an inline closure that captures only plain data', () async {
      final id = await _inlineAdd(h, 'inline note');
      final ev = await h.db.select(h.db.evidences).getSingle();
      expect(ev.id, id);
      expect(ev.title, 'inline note');
    });

    test('a throwing command surfaces as EngineCommandException with the remote message', () async {
      await expectLater(
        h.runtime(throwingCmd('boom-42')),
        throwsA(isA<EngineCommandException>()
            .having((e) => e.message, 'message', contains('boom-42'))
            .having((e) => e.remoteStack, 'remoteStack', isNotNull)),
      );
      // The engine is still usable.
      expect(await h.run(_addNote), isNotEmpty);
    });

    test('an unsendable capture throws UI-side and leaves nothing pending', () async {
      final port = ReceivePort(); // not sendable
      addTearDown(port.close);
      await expectLater(h.runtime(_unsendableCmd(port)), throwsA(isNot(isA<EngineCommandException>())));
      // Still usable; a leftover pending completer would fail unhandled at shutdown below.
      expect(await h.run(_addNote), isNotEmpty);
      await h.shutdown();
    });

    test('setPausedCmd persists collection.paused and flips the runtime flag', () async {
      await h.runtime(setPausedCmd(true));
      final row = await (h.db.select(h.db.settings)..where((s) => s.key.equals(pausedSettingKey))).getSingle();
      expect(row.value, 'true');
      expect(await h.runtime(pausedFlagCmd()), isTrue);
      await h.runtime(setPausedCmd(false));
      expect(await h.runtime(pausedFlagCmd()), isFalse);
    });

    test('createProfileCmd adds an inactive profile in the app DB', () async {
      final id = await h.runtime(createProfileCmd('Side'));
      final rows = await (h.appDb.select(h.appDb.profiles)..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();
      expect(rows.map((r) => r.name), ['Work', 'Side']);
      expect(rows.firstWhere((r) => r.id == id).active, isFalse);
      expect(rows.firstWhere((r) => r.id == id).timeZone, 'UTC');
    });

    test('syncNowCmd reports false while no sync orchestrator is registered', () async {
      expect(await h.runtime(syncNowCmd()), isFalse);
    });
  });

  group('quick capture', () {
    test('addQuickNoteCmd(screenshotPath:) moves the file into the BlobStore as an image payload', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      addTearDown(h.shutdown);
      final shot = File(p.join(dir.path, 'shot.png'))..writeAsBytesSync([137, 80, 78, 71, 1, 2, 3]);

      final evidenceId = await h.runtime(addQuickNoteCmd(text: 'look', link: 'https://x.test', screenshotPath: shot.path));

      expect(shot.existsSync(), isFalse, reason: 'temp file deleted');
      final payload = await h.db.select(h.db.payloads).getSingle();
      expect(payload.evidenceId, evidenceId);
      expect(payload.kind, PayloadKind.image);
      final att = await h.db.select(h.db.attachments).getSingle();
      expect(att.payloadId, payload.id);
      expect(att.mime, 'image/png');
      expect(att.size, 7);
      final blob = File(p.join(dir.path, 'blobs', h.profileId, att.path));
      expect(blob.readAsBytesSync(), [137, 80, 78, 71, 1, 2, 3]);
      expect(payload.content, contains(att.path));
      expect(payload.content, contains('https://x.test'));
    });

    test('addQuickNoteCmd without a screenshot creates a note payload', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      addTearDown(h.shutdown);
      await h.runtime(addQuickNoteCmd(text: 'plain'));
      expect((await h.db.select(h.db.payloads).getSingle()).kind, PayloadKind.note);
      expect(await h.db.select(h.db.attachments).get(), isEmpty);
    });
  });

  group('shutdown', () {
    test('completes, closes DBs, rejects later commands and ends the isolate', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      final engineIsolate = await h.runtime(currentIsolateCmd());
      final exited = ReceivePort();
      engineIsolate.addOnExitListener(exited.sendPort);

      await h.shutdown().timeout(const Duration(seconds: 15));

      await expectLater(exited.first.timeout(const Duration(seconds: 5)), completes);
      exited.close();
      await expectLater(h.run(_addNote), throwsA(isA<EngineCommandException>()));
      await expectLater(h.db.select(h.db.evidences).get(), throwsA(anything));
      await h.shutdown(); // idempotent
    });

    test('completes while a UI-side profile DB watch() is still active', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      final sub = h.db.select(h.db.evidences).watch().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await h.shutdown().timeout(const Duration(seconds: 15));
      await sub.cancel();
    });

    test('completes while a UI-side app DB watch() is still active', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      final sub = h.appDb.select(h.appDb.profiles).watch().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await h.shutdown().timeout(const Duration(seconds: 15));
      await sub.cancel();
    });

    test('a file DB is closed cleanly and reopens with its data', () async {
      final h = await EngineHandle.start(testConfig(dir.path, inMemory: false));
      await h.run(_addNote);
      await h.shutdown();
      final again = await EngineHandle.start(testConfig(dir.path, inMemory: false));
      addTearDown(again.shutdown);
      expect(await again.db.select(again.db.evidences).get(), hasLength(1));
    });
  });

  group('scheduler', () {
    test('default schedules are seeded and a due tick enqueues jobs with handlers', () async {
      final h = await EngineHandle.start(testConfig(dir.path));
      addTearDown(h.shutdown);
      final schedules = await h.db.select(h.db.schedules).get();
      expect(schedules.map((s) => s.kind).toSet(), {
        'report:daily',
        'report:weekly',
        'report:monthly',
        'report:quarterly',
        'backup',
      });

      final ids = await h.runtime(tickCmd(DateTime.now().toUtc().add(const Duration(days: 400))));
      expect(ids, hasLength(5));
      final jobs = await h.db.select(h.db.jobs).get();
      expect(jobs.map((j) => j.kind).toSet(), schedules.map((s) => s.kind).toSet());
      expect(jobs.where((j) => j.kind == 'backup').single.lane, JobLane.io);
      expect(jobs.where((j) => j.kind == 'report:daily').single.lane, JobLane.llm);

      // Nothing is due again right after.
      expect(await h.runtime(tickCmd(DateTime.now().toUtc().add(const Duration(days: 400)))), isEmpty);
    });

    test('with loops running, the backup job runs into <dataDir>/backups/<profileId>', () async {
      final h = await EngineHandle.start(EngineConfig(
        dataDir: dir.path,
        timeZone: 'UTC',
        inMemory: true,
        idlePoll: const Duration(milliseconds: 50),
      ));
      addTearDown(h.shutdown);
      await h.runtime(_enqueueCmd('backup'));
      final backups = Directory(p.join(dir.path, 'backups', h.profileId));
      await pumpUntil(() => backups.existsSync() && backups.listSync().isNotEmpty, timeout: const Duration(seconds: 20));
      final job = await (h.db.select(h.db.jobs)..where((j) => j.kind.equals('backup'))).getSingle();
      expect(job.lastError, isNull);
    });
  });
}

EngineCommand<String> _enqueueCmd(String kind) => (rt) => rt.engine.jobs.enqueue(kind);

EngineCommand<Object?> _unsendableCmd(ReceivePort port) => (rt) async => port.hashCode;

/// Keeps the closure's context to [text] only (no test-scope variables).
Future<String> _inlineAdd(EngineHandle h, String text) => h.run((e) => e.addNote(text: text, at: DateTime.now()));

Future<void> pumpUntil(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
