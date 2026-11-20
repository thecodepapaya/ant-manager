import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:core/src/backup/backup.dart';
import 'package:core/src/reports/templates.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tools/fixtures.dart';

class MemoryBlobs implements BlobStore {
  final files = <String, Uint8List>{};
  @override
  Future<Uint8List> get(String path) async => files[path]!;
  @override
  Future<String> put(Uint8List bytes, {required String extension}) async {
    final path = 'img/${files.length}.$extension';
    files[path] = bytes;
    return path;
  }

  @override
  Future<void> delete(String path) async => files.remove(path);
}

void main() {
  // The test opens the restored file as a second ProfileDb on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late Fixture fx;
  late MemoryBlobs blobs;
  late FixedClock clock;
  late BackupService svc;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_test');
    fx = Fixture(ProfileDb(NativeDatabase(File(p.join(tmp.path, 'live.sqlite')))));
    await fx.base();
    await fx.evidence(
      '2026-11-10',
      'Standup notes',
      {'text': 'Discussed rollout', 'link': null},
      kind: PayloadKind.note,
      project: 'pay',
    );
    await fx.evidence('2026-11-12', 'commit', {'msg': 'fix'});
    await fx.fact(FactType.outcome, 'Shipped rollout', '2026-11-10', project: 'pay', win: WinStatus.accepted);
    await TemplateService(fx.db).seedBuiltins();
    await fx.db
        .into(fx.db.reports)
        .insert(
          ReportsCompanion.insert(
            id: 'r1',
            periodKind: PeriodKind.daily,
            periodStart: '2026-11-10',
            periodEnd: '2026-11-10',
            templateId: 'builtin.standup',
          ),
        );
    blobs = MemoryBlobs();
    final path = await blobs.put(Uint8List.fromList([1, 2, 3]), extension: 'png');
    await fx.db
        .into(fx.db.attachments)
        .insert(
          AttachmentsCompanion.insert(id: 'a1', payloadId: 'p1', path: path, mime: 'image/png', sha256: 'x', size: 3),
        );
    clock = FixedClock(DateTime.utc(2026, 11, 18, 2));
    svc = BackupService(fx.db, profileId: 'P1', profileName: 'Work Stuff', appVersion: '1.0.0', blobs: blobs, keep: 2, clock: clock);
  });
  tearDown(() async {
    await fx.db.close();
    await tmp.delete(recursive: true);
  });

  test('round trip: create, inspect, restore, reopen', () async {
    final folder = p.join(tmp.path, 'backups');
    final file = await svc.createBackup(folder, readableExport: true);
    expect(p.basename(file.path), 'Work_Stuff-P1-20261118T020000Z.antbackup');

    final m = await BackupService.inspect(file.path);
    expect(m.profile, 'Work Stuff');
    expect(m.appVersion, '1.0.0');
    expect(m.schemaVersion, fx.db.schemaVersion);
    expect((m.firstDay, m.lastDay), ('2026-11-10', '2026-11-12'));
    expect(m.counts['evidences'], 2);
    expect(m.counts['facts'], 1);
    expect(m.counts['attachment_files'], 1);

    final target = p.join(tmp.path, 'restored', 'profile.sqlite');
    final att = p.join(tmp.path, 'restored', 'blobs');
    await BackupService.restore(file.path, target, currentSchemaVersion: fx.db.schemaVersion, attachmentsDir: att);
    expect(await File(p.join(att, 'img/0.png')).readAsBytes(), [1, 2, 3]);
    final restored = ProfileDb(NativeDatabase(File(target)));
    expect((await restored.select(restored.facts).getSingle()).statement, 'Shipped rollout');
    expect(await restored.select(restored.evidences).get(), hasLength(2));
    final fts = await restored.customSelect("SELECT * FROM fts_payloads WHERE fts_payloads MATCH 'rollout'").get();
    expect(fts, hasLength(1));
    await restored.close();

    await expectLater(
      BackupService.restore(file.path, target, currentSchemaVersion: fx.db.schemaVersion),
      throwsA(isA<BackupException>()),
    );

    final export = Directory(p.join(folder, 'Work_Stuff-P1-export'));
    for (final f in ['facts.json', 'facts.md', 'wins.json', 'wins.md', 'reports.json', 'notes.md', 'evidence.json']) {
      expect(File(p.join(export.path, f)).existsSync(), isTrue, reason: f);
    }
    expect(File(p.join(export.path, 'notes.md')).readAsStringSync(), contains('Discussed rollout'));
    expect(jsonDecode(File(p.join(export.path, 'wins.json')).readAsStringSync()), hasLength(1));
  });

  test('keeps the last N backups of the profile only', () async {
    final folder = p.join(tmp.path, 'backups');
    await Directory(folder).create();
    final other = File(p.join(folder, 'Other-20200101T000000Z.antbackup'))..writeAsStringSync('x');
    for (var i = 0; i < 4; i++) {
      clock.t = DateTime.utc(2026, 11, 18 + i, 2);
      await svc.createBackup(folder);
    }
    final kept = (await svc.list(folder)).map((f) => p.basename(f.path)).toList();
    expect(kept, ['Work_Stuff-P1-20261121T020000Z.antbackup', 'Work_Stuff-P1-20261120T020000Z.antbackup']);
    expect(other.existsSync(), isTrue);
  });

  test('refuses newer schema versions and corrupted databases', () async {
    final file = await svc.createBackup(p.join(tmp.path, 'b'));
    Future<String> rewrite(Map<String, Object?> Function(Map<String, Object?>) edit, {bool corrupt = false}) async {
      final a = ZipDecoder().decodeBytes(await file.readAsBytes());
      final out = Archive();
      for (final f in a.files) {
        if (f.name == 'manifest.json') {
          final m = jsonDecode(utf8.decode(f.readBytes()!)) as Map<String, Object?>;
          out.addFile(ArchiveFile.string(f.name, jsonEncode(edit(m))));
        } else if (f.name == 'db.sqlite' && corrupt) {
          out.addFile(ArchiveFile.bytes(f.name, [...f.readBytes()!, 0]));
        } else {
          out.addFile(ArchiveFile.bytes(f.name, f.readBytes()!));
        }
      }
      final path = p.join(tmp.path, 'edited-${corrupt ? 'c' : 'n'}.antbackup');
      await File(path).writeAsBytes(ZipEncoder().encodeBytes(out));
      return path;
    }

    final newer = await rewrite((m) => {...m, 'schema_version': 999});
    expect((await BackupService.inspect(newer)).schemaVersion, 999);
    await expectLater(
      BackupService.restore(newer, p.join(tmp.path, 'n.sqlite'), currentSchemaVersion: 1),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', contains('newer version'))),
    );
    final corrupt = await rewrite((m) => m, corrupt: true);
    await expectLater(
      BackupService.restore(corrupt, p.join(tmp.path, 'c.sqlite'), currentSchemaVersion: 1),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', contains('checksum'))),
    );
  });
}
