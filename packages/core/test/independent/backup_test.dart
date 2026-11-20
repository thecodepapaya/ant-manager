// Independent tests (#99) for backups (SPEC §9, #78 #80): round-trip fidelity, keep-last-N, restore safety,
// secrets never included, readable export.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:core/src/backup/readable_export.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';

const secret = 'ghp_TOPSECRET_9f8e7d6c5b4a';

const countedTables = [
  'evidences',
  'payloads',
  'payload_revisions',
  'attachments',
  'enrichments',
  'facts',
  'fact_revisions',
  'citations',
  'workstreams',
  'projects',
  'templates',
  'reports',
  'report_snapshots',
  'schedules',
  'settings',
  'dependencies',
  'sources',
  'identities',
];

Future<Map<String, int>> tableCounts(ProfileDb db) async => {
  for (final t in countedTables)
    t: await db.customSelect('SELECT COUNT(*) AS c FROM $t').map((r) => r.read<int>('c')).getSingle(),
};

void main() {
  late Directory tmp;
  late ProfileDb db;
  late AntEngine engine;
  late MemBlobs blobs;
  late MutableClock clock;
  late MemSecrets secrets;
  late Uint8List image;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('indep_backup');
    db = ProfileDb(NativeDatabase(File(p.join(tmp.path, 'live.sqlite'))));
    blobs = MemBlobs();
    secrets = MemSecrets()..values['github.token'] = secret;
    clock = MutableClock(DateTime.utc(2026, 11, 18, 2));
    engine = AntEngine(
      db: db,
      profileId: 'p1',
      ports: EnginePorts(secrets: secrets, blobs: blobs, git: NoGit(), watcher: NoWatcher(), clock: clock),
      router: ScriptedRouter(ScriptedLlm([])),
      utcOffset: (_) => Duration.zero,
    );
    // A realistic profile: a source with a credential ref, notes (one with an image), facts, a report.
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'gh',
            kind: SourceKind.github,
            name: 'GitHub',
            credentialRef: const Value('github.token'),
          ),
        );
    await db.into(db.identities).insert(IdentitiesCompanion.insert(id: 'i1', kind: 'email', value: 'me@example.com'));
    await TemplateService(db).seedBuiltins();
    await Scheduler(db, engine.jobs, utcOffset: (_) => Duration.zero, clock: clock).seedDefaults();
    await engine.addNote(text: 'Unique zanzibar note', at: DateTime.utc(2026, 11, 3, 9), link: 'https://x.test/1');
    image = Uint8List.fromList(List.generate(300, (i) => (i * 37) % 256));
    final path = await blobs.put(image, extension: 'png');
    await engine.addNote(text: 'Screenshot of praise', at: DateTime.utc(2026, 11, 17, 9), attachmentPaths: [path]);
    final seed = Seed(db);
    final payloadId = (await db.select(db.payloads).get()).first.id;
    final f = await seed.fact('Accepted win', '2026-11-03', win: WinStatus.accepted, cites: [payloadId]);
    await seed.fact('Retired thing', '2026-11-03', retired: true);
    await engine.editFact(f, 'Accepted win, reworded');
    await db
        .into(db.reports)
        .insert(
          ReportsCompanion.insert(
            id: 'r1',
            periodKind: PeriodKind.weekly,
            periodStart: '2026-11-02',
            periodEnd: '2026-11-08',
            templateId: 'builtin.weekly_review',
          ),
        );
    for (final v in [1, 2]) {
      await db
          .into(db.reportSnapshots)
          .insert(
            ReportSnapshotsCompanion.insert(
              id: 'snap$v',
              reportId: 'r1',
              version: v,
              json: '{"sections":[]}',
              markdown: '# Weekly v$v',
              modelId: 'm',
              generatedAt: clock.now(),
            ),
          );
    }
    await engine.deps.record(
      (type: EntityType.reportSnapshot, id: 'snap2'),
      2,
      [(type: EntityType.fact, id: f, revision: 2)],
    );
    await db.into(db.settings).insert(SettingsCompanion.insert(key: 'theme', value: 'dark'));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  BackupService service({String name = 'Work', int keep = 14, bool withBlobs = true}) => BackupService(
    db,
    profileName: name,
    appVersion: '1.2.3',
    blobs: withBlobs ? blobs : null,
    keep: keep,
    clock: clock,
  );

  String dest([String sub = 'backups']) => p.join(tmp.path, sub);

  test('manifest reports schema, app version, date range and true row counts', () async {
    final file = await service().createBackup(dest());
    expect(p.basename(file.path), startsWith('Work-'));
    expect(file.path, endsWith('.antbackup'));
    final m = await BackupService.inspect(file.path);
    expect(m.schemaVersion, db.schemaVersion);
    expect(m.appVersion, '1.2.3');
    expect(m.profile, 'Work');
    expect((m.firstDay, m.lastDay), ('2026-11-03', '2026-11-17'));
    final live = await tableCounts(db);
    for (final t in ['evidences', 'payloads', 'facts', 'reports', 'report_snapshots', 'templates', 'attachments']) {
      expect(m.counts[t], live[t], reason: t);
    }
    expect(m.counts['attachment_files'], 1);
  });

  test('round trip: every table, FTS and staleness triggers survive restore', () async {
    final file = await service().createBackup(dest());
    final target = p.join(tmp.path, 'restored', 'profile.sqlite');
    final attachDir = p.join(tmp.path, 'restored', 'blobs');
    await BackupService.restore(file.path, target, currentSchemaVersion: db.schemaVersion, attachmentsDir: attachDir);
    final restored = ProfileDb(NativeDatabase(File(target)));
    addTearDown(restored.close);
    expect(await tableCounts(restored), await tableCounts(db));
    // Version history is in the bundle.
    final revs = await restored.select(restored.factRevisions).get();
    expect(revs.single.statement, 'Accepted win, reworded');
    // FTS still works.
    final tools = ToolRegistry();
    registerBuiltinTools(tools);
    final hits = await tools['search_evidence'].call({'query': 'zanzibar'}, ToolContext(db: restored, profileId: 'p1'));
    expect(hits['evidence'] as List, hasLength(1));
    // Triggers still fire.
    final pl = (await restored.select(restored.payloads).get()).first;
    await restored.customStatement('DELETE FROM recompute_queue');
    await restored.customStatement('UPDATE payloads SET revision = revision + 1 WHERE id = ?', [pl.id]);
    expect(await restored.select(restored.recomputeQueue).get(), isNotEmpty);
    // Attachment bytes are identical, at the attachment's relative path.
    final a = (await restored.select(restored.attachments).get()).single;
    expect(await File(p.join(attachDir, a.path)).readAsBytes(), image);
  });

  test('without a blob store attachments are skipped but rows are kept', () async {
    final file = await service(withBlobs: false).createBackup(dest());
    final m = await BackupService.inspect(file.path);
    expect(m.counts['attachment_files'], 0);
    expect(m.counts['attachments'], 1);
  });

  test('secrets are never included, in the bundle or the readable export', () async {
    final file = await service().createBackup(dest(), readableExport: true);
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    for (final f in archive.files.where((f) => f.isFile)) {
      expect(latin1.decode(f.readBytes()!, allowInvalid: true), isNot(contains(secret)), reason: f.name);
    }
    final exportDir = Directory(p.join(dest(), 'Work-export'));
    await for (final f in exportDir.list(recursive: true)) {
      if (f is File) {
        final text = await f.readAsString();
        expect(text, isNot(contains(secret)), reason: f.path);
        expect(text, isNot(contains('github.token')), reason: 'credential refs are left out: ${f.path}');
      }
    }
  });

  test('keeps only the last N backups, newest first', () async {
    final s = service(keep: 3);
    final made = <String>[];
    for (var i = 0; i < 5; i++) {
      made.add(p.basename((await s.createBackup(dest())).path));
      clock.advance(const Duration(days: 1));
    }
    final listed = (await s.list(dest())).map((f) => p.basename(f.path)).toList();
    expect(listed, made.reversed.take(3).toList());
  });

  test(
    "pruning and listing one profile never touch another profile's backups",
    () async {
      final work = service(name: 'Work', keep: 1);
      final workOld = service(name: 'Work-old', keep: 5);
      await workOld.createBackup(dest());
      clock.advance(const Duration(hours: 1));
      await workOld.createBackup(dest());
      clock.advance(const Duration(hours: 1));
      await work.createBackup(dest());
      expect(await workOld.list(dest()), hasLength(2));
      expect(await work.list(dest()), hasLength(1));
    },
  );

  group('restore safety', () {
    Future<String> rewrite(
      File src, {
      Map<String, Object?> Function(Map<String, Object?> m)? manifest,
      bool corruptDb = false,
      String? extraFile,
    }) async {
      final a = ZipDecoder().decodeBytes(await src.readAsBytes());
      final out = Archive();
      for (final f in a.files) {
        var bytes = f.readBytes()!;
        if (f.name == 'manifest.json' && manifest != null) {
          bytes = utf8.encode(jsonEncode(manifest(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>)));
        }
        if (f.name == 'db.sqlite' && corruptDb) bytes = Uint8List.fromList([...bytes]..[100] ^= 0xFF);
        out.addFile(ArchiveFile.bytes(f.name, bytes));
      }
      if (extraFile != null) out.addFile(ArchiveFile.bytes(extraFile, utf8.encode('x')));
      final path = p.join(tmp.path, 'mod-${DateTime.now().microsecondsSinceEpoch}.antbackup');
      await File(path).writeAsBytes(ZipEncoder().encodeBytes(out));
      return path;
    }

    late File backup;
    late String target;
    setUp(() async {
      backup = await service().createBackup(dest());
      target = p.join(tmp.path, 'r', 'db.sqlite');
    });

    test('a newer schema is refused with a clear message, and nothing is written', () async {
      final newer = await rewrite(backup, manifest: (m) => {...m, 'schema_version': db.schemaVersion + 1});
      await expectLater(
        BackupService.restore(newer, target, currentSchemaVersion: db.schemaVersion),
        throwsA(isA<BackupException>().having((e) => e.message, 'message', contains('newer'))),
      );
      expect(File(target).existsSync(), isFalse);
      // The preview still works for a newer backup.
      expect((await BackupService.inspect(newer)).schemaVersion, db.schemaVersion + 1);
    });

    test('a checksum mismatch is refused', () async {
      final bad = await rewrite(backup, corruptDb: true);
      await expectLater(
        BackupService.restore(bad, target, currentSchemaVersion: db.schemaVersion),
        throwsA(isA<BackupException>()),
      );
      expect(File(target).existsSync(), isFalse);
    });

    test('a zip that is not a backup is refused', () async {
      final path = p.join(tmp.path, 'other.zip');
      await File(path).writeAsBytes(ZipEncoder().encodeBytes(Archive()..addFile(ArchiveFile.string('x.txt', 'hi'))));
      await expectLater(BackupService.inspect(path), throwsA(isA<BackupException>()));
      await expectLater(BackupService.restore(path, target, currentSchemaVersion: 1), throwsA(isA<BackupException>()));
    });

    test('an existing target is only replaced with overwrite', () async {
      await BackupService.restore(backup.path, target, currentSchemaVersion: db.schemaVersion);
      await expectLater(
        BackupService.restore(backup.path, target, currentSchemaVersion: db.schemaVersion),
        throwsA(isA<BackupException>()),
      );
      // Change the first restore so a real replacement is visible (restore edits the file, #118, so
      // compare contents rather than the bundle checksum).
      final first = ProfileDb(NativeDatabase(File(target)));
      await first.into(first.settings).insert(SettingsCompanion.insert(key: 'only_in_first', value: 'x'));
      await first.close();
      await BackupService.restore(backup.path, target, currentSchemaVersion: db.schemaVersion, overwrite: true);
      final restored = ProfileDb(NativeDatabase(File(target)));
      addTearDown(restored.close);
      expect(await tableCounts(restored), await tableCounts(db));
      final keys = (await restored.select(restored.settings).get()).map((s) => s.key);
      expect(keys, isNot(contains('only_in_first')));
      expect(keys, contains('theme'));
    });

    test('attachment paths escaping the target folder are refused', () async {
      final evil = await rewrite(backup, extraFile: 'attachments/../../escaped.txt');
      await expectLater(
        BackupService.restore(
          evil,
          target,
          currentSchemaVersion: db.schemaVersion,
          attachmentsDir: p.join(tmp.path, 'r', 'blobs'),
        ),
        throwsA(isA<BackupException>()),
      );
      expect(File(p.join(tmp.path, 'escaped.txt')).existsSync(), isFalse);
    });
  });

  group('readable export', () {
    test('facts without retired, wins only accepted outcomes, latest report Markdown, notes', () async {
      final dir = p.join(tmp.path, 'export');
      await Directory(dir).create();
      await File(p.join(dir, 'stale.txt')).writeAsString('old run');
      await ReadableExporter(db).export(dir);
      expect(File(p.join(dir, 'stale.txt')).existsSync(), isFalse, reason: 'rewritten from scratch');
      final facts = jsonDecode(await File(p.join(dir, 'facts.json')).readAsString()) as List;
      expect(facts.map((f) => (f as Map)['statement']), ['Accepted win, reworded']);
      expect(((facts.single as Map)['citations'] as List), hasLength(1));
      final wins = jsonDecode(await File(p.join(dir, 'wins.json')).readAsString()) as List;
      expect(wins, hasLength(1));
      final reports = jsonDecode(await File(p.join(dir, 'reports.json')).readAsString()) as List;
      expect(reports.map((r) => (r as Map)['version']), [1, 2]);
      final mdFiles = Directory(p.join(dir, 'reports')).listSync().whereType<File>().toList();
      expect(mdFiles.single.readAsStringSync(), '# Weekly v2');
      final notes = await File(p.join(dir, 'notes.md')).readAsString();
      expect(notes, contains('Unique zanzibar note'));
      expect(notes, contains('https://x.test/1'));
      final evidence = jsonDecode(await File(p.join(dir, 'evidence.json')).readAsString()) as List;
      expect(evidence, hasLength(2));
    });
  });
}
