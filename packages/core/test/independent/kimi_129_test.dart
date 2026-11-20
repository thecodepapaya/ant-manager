// Independent tests (#99) for DECISIONS #129 (Kimi review: backup, restore and delete integrity), core side:
// referenced blob paths for the orphan sweep, backup snapshot consistency, atomic bundle writes, bundle naming,
// restore on a temp file and the readable export's report file names.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:core/src/backup/readable_export.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:test/test.dart';

import 'fakes.dart';

/// A BlobStore over a map whose `get` can run a hook first (the seam between the snapshot and the blob reads)
/// or throw a chosen error.
class HookBlobs implements BlobStore {
  final files = <String, Uint8List>{};
  Future<void> Function()? beforeFirstGet;
  Object? Function(String path)? failWith;
  var gets = 0;

  @override
  Future<String> put(Uint8List bytes, {required String extension}) async {
    final path = 'ab/${files.length + 1}.$extension';
    files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List> get(String path) async {
    if (gets++ == 0 && beforeFirstGet != null) await beforeFirstGet!();
    final err = failWith?.call(path);
    if (err != null) throw err;
    return files[path] ?? (throw PathNotFoundException(path, const OSError('No such file', 2)));
  }

  @override
  Future<void> delete(String path) async => files.remove(path);
}

void main() {
  late Directory tmp;
  late ProfileDb db;
  late Seed seed;
  late String src;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kimi129');
    db = ProfileDb(NativeDatabase(File(p.join(tmp.path, 'live.sqlite'))));
    seed = Seed(db);
    src = await seed.source(SourceKind.manualNote);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> attachmentRow(String payloadId, String path) => db
      .into(db.attachments)
      .insert(
        AttachmentsCompanion.insert(
          id: 'att-$path',
          payloadId: payloadId,
          path: path,
          mime: 'image/png',
          sha256: 'x',
          size: 3,
        ),
      );

  group('referencedBlobPaths', () {
    test('collects attachments rows and payload attachments lists, nothing else', () async {
      final a = await seed.evidence(src, '2026-11-02', {
        'text': 'one',
        'attachments': ['p1/list.png', 'p1/both.png', 7],
      });
      await seed.evidence(src, '2026-11-03', {'text': 'two'});
      await attachmentRow(a.payload, 'p1/row.png');
      await attachmentRow(a.payload, 'p1/both.png');
      expect(await EvidenceDeleter.referencedBlobPaths(db), {'p1/list.png', 'p1/both.png', 'p1/row.png'});
    });

    test('a payload whose attachments is not a list does not throw and adds nothing', () async {
      await seed.evidence(src, '2026-11-02', {'text': 'one', 'attachments': 'p1/str.png'});
      await seed.evidence(src, '2026-11-03', {
        'text': 'two',
        'attachments': {'a': 'p1/map.png'},
      });
      final b = await seed.evidence(src, '2026-11-04', {
        'text': 'three',
        'attachments': ['p1/ok.png'],
      });
      await attachmentRow(b.payload, 'p1/row.png');
      expect(await EvidenceDeleter.referencedBlobPaths(db), {'p1/ok.png', 'p1/row.png'});
    });

    test('an empty DB references nothing', () async {
      expect(await EvidenceDeleter.referencedBlobPaths(db), isEmpty);
    });
  });

  group('backup', () {
    late HookBlobs blobs;
    late String payloadId;
    late MutableClock clock;

    setUp(() async {
      clock = MutableClock(DateTime.utc(2026, 11, 18, 2));
      blobs = HookBlobs();
      final p1 = await blobs.put(Uint8List.fromList([1, 2, 3]), extension: 'png');
      final p2 = await blobs.put(Uint8List.fromList([4, 5, 6]), extension: 'png');
      final e = await seed.evidence(src, '2026-11-02', {
        'text': 'shot',
        'attachments': [p1, p2],
      });
      payloadId = e.payload;
      await attachmentRow(payloadId, p1);
      await attachmentRow(payloadId, p2);
      await seed.evidence(src, '2026-11-05', {'text': 'later'});
    });

    BackupService service({String name = 'Work', String id = 'P1', int keep = 14}) => BackupService(
      db,
      profileId: id,
      profileName: name,
      appVersion: '1.0.0',
      blobs: blobs,
      keep: keep,
      clock: clock,
    );

    String dest() => p.join(tmp.path, 'backups');

    /// Opens the bundle's db.sqlite and returns (attachment paths, counts of the manifest's tables, max day).
    Future<(Set<String>, Map<String, int>, String?)> bundled(File bundle) async {
      final archive = ZipDecoder().decodeBytes(await bundle.readAsBytes());
      final file = File(p.join(tmp.path, 'bundled-${DateTime.now().microsecondsSinceEpoch}.sqlite'))
        ..writeAsBytesSync(archive.findFile('db.sqlite')!.readBytes()!);
      final s = sqlite3.open(file.path);
      try {
        return (
          {for (final r in s.select('SELECT path FROM attachments')) r['path'] as String},
          {
            for (final t in ['evidences', 'payloads', 'attachments'])
              t: s.select('SELECT COUNT(*) AS c FROM $t').first['c'] as int,
          },
          s.select('SELECT MAX(day) AS v FROM evidences').first['v'] as String?,
        );
      } finally {
        s.close();
      }
    }

    Set<String> zippedAttachments(File bundle) => {
      for (final f in ZipDecoder().decodeBytes(bundle.readAsBytesSync()).files)
        if (f.isFile && f.name.startsWith('attachments/')) f.name.substring('attachments/'.length),
    };

    test('rows changed after VACUUM INTO do not leak into the manifest: it matches the snapshot', () async {
      // The first blob read happens after the snapshot; change the live DB there.
      blobs.beforeFirstGet = () async {
        await db.customStatement('DELETE FROM attachments');
        await seed.evidence(src, '2026-11-30', {'text': 'added after the snapshot'});
        await seed.evidence(src, '2026-10-01', {'text': 'also added after the snapshot'});
      };
      final file = await service().createBackup(dest());
      final m = await BackupService.inspect(file.path);
      final (paths, counts, maxDay) = await bundled(file);
      expect(counts, {'evidences': 2, 'payloads': 2, 'attachments': 2}, reason: 'snapshot is pre-change');
      for (final t in counts.keys) {
        expect(m.counts[t], counts[t], reason: t);
      }
      expect(m.lastDay, maxDay);
      expect((m.firstDay, m.lastDay), ('2026-11-02', '2026-11-05'));
      expect(zippedAttachments(file), paths);
      expect(m.counts['attachment_files'], 2);
      // The live DB really did change.
      expect(await db.select(db.attachments).get(), isEmpty);
      expect((await db.select(db.evidences).get()), hasLength(4));
    });

    test('a blob gone with PathNotFoundException is skipped and attachment_files drops', () async {
      final gone = blobs.files.keys.first;
      blobs.beforeFirstGet = () async => blobs.files.remove(gone);
      final file = await service().createBackup(dest());
      final m = await BackupService.inspect(file.path);
      expect(m.counts['attachments'], 2, reason: 'rows come from the snapshot');
      expect(m.counts['attachment_files'], 1);
      expect(zippedAttachments(file), {blobs.files.keys.single});
    });

    test('any other blob read error fails the backup and leaves no bundle or .tmp', () async {
      blobs.failWith = (_) => const FileSystemException('Permission denied', 'x', OSError('denied', 13));
      await expectLater(service().createBackup(dest()), throwsA(isA<FileSystemException>()));
      final left = Directory(dest()).listSync().map((f) => p.basename(f.path));
      expect(left.where((n) => n.endsWith('.antbackup') || n.endsWith('.tmp')), isEmpty);
    });

    test('a non-file-system read error (StateError) also fails the backup', () async {
      blobs.failWith = (_) => StateError('broken store');
      await expectLater(service().createBackup(dest()), throwsA(isA<StateError>()));
    });

    test('a failed rename deletes the .tmp and leaves no .antbackup file', () async {
      // Block the final name with a directory: the .tmp write succeeds, the rename onto it fails.
      final blocked = Directory(p.join(dest(), 'Work-P1-20261118T020000Z.antbackup'))..createSync(recursive: true);
      await expectLater(service().createBackup(dest()), throwsA(isA<FileSystemException>()));
      final entries = Directory(dest()).listSync();
      expect(entries.whereType<File>(), isEmpty, reason: 'no .antbackup or .tmp file');
      expect(entries.map((e) => e.path), [blocked.path]);
      expect(await service().list(dest()), isEmpty);
    });

    test('a stray .tmp is neither listed nor pruned', () async {
      final stray = File(p.join(dest(), 'Work-P1-20200101T000000Z.antbackup.tmp'))
        ..createSync(recursive: true)
        ..writeAsStringSync('partial');
      final s = service(keep: 1);
      await s.createBackup(dest());
      clock.advance(const Duration(hours: 1));
      final second = await s.createBackup(dest());
      expect((await s.list(dest())).map((f) => f.path), [second.path]);
      expect(stray.existsSync(), isTrue);
    });

    test('a successful backup is named <profile>-<id>-<stamp> and leaves no .tmp', () async {
      final file = await service(name: 'My Work', id: 'abc').createBackup(dest());
      expect(p.basename(file.path), 'My_Work-abc-20261118T020000Z.antbackup');
      expect(Directory(dest()).listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
    });

    test('two profiles with the same name but different ids never prune each other', () async {
      final a = service(id: 'A', keep: 1);
      final b = service(id: 'B', keep: 1);
      await a.createBackup(dest());
      await b.createBackup(dest());
      clock.advance(const Duration(hours: 1));
      final a2 = await a.createBackup(dest());
      clock.advance(const Duration(hours: 1));
      final b2 = await b.createBackup(dest());
      expect((await a.list(dest())).map((f) => f.path), [a2.path]);
      expect((await b.list(dest())).map((f) => f.path), [b2.path]);
      expect(Directory(dest()).listSync().whereType<File>(), hasLength(2));
    });

    test('an old <profile>-<stamp> bundle is not listed or pruned, but still restores', () async {
      final made = await service().createBackup(dest());
      final old = made.copySync(p.join(dest(), 'Work-20200101T000000Z.antbackup'));
      final s = service(keep: 1);
      clock.advance(const Duration(hours: 1));
      await s.createBackup(dest());
      expect((await s.list(dest())).map((f) => p.basename(f.path)), ['Work-P1-20261118T030000Z.antbackup']);
      expect(old.existsSync(), isTrue, reason: 'left for the user');
      final target = p.join(tmp.path, 'restored', 'old.sqlite');
      final m = await BackupService.restore(old.path, target, currentSchemaVersion: db.schemaVersion);
      expect(m.profile, 'Work');
      final r = sqlite3.open(target);
      addTearDown(r.close);
      expect(r.select('SELECT COUNT(*) AS c FROM evidences').first['c'], 2);
    });

    test('restore clears every credential_ref, disables those sources, and leaves no .tmp', () async {
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
      final file = await service().createBackup(dest());
      final dir = p.join(tmp.path, 'restored');
      final target = p.join(dir, 'profile.sqlite');
      // Leftovers from an earlier crashed restore must not be picked up.
      File('$target.tmp-wal')
        ..createSync(recursive: true)
        ..writeAsStringSync('junk');
      await BackupService.restore(file.path, target, currentSchemaVersion: db.schemaVersion);
      final r = sqlite3.open(target);
      try {
        expect(r.select('SELECT COUNT(*) AS c FROM sources WHERE credential_ref IS NOT NULL').first['c'], 0);
        expect(r.select("SELECT enabled FROM sources WHERE id = 'gh'").first['enabled'], 0);
        expect(r.select("SELECT enabled FROM sources WHERE id = '$src'").first['enabled'], 1);
      } finally {
        r.close();
      }
      final names = Directory(dir).listSync().map((f) => p.basename(f.path));
      expect(names.where((n) => n.contains('.tmp')), isEmpty);
      expect(names, contains('profile.sqlite'));
    });
  });

  test('restore clears credential refs on the .tmp before it is renamed into place', () async {
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
    final file = await BackupService(db, profileId: 'P1', profileName: 'Work', appVersion: '1').createBackup(
      p.join(tmp.path, 'bk'),
    );
    // A directory at the target makes the final rename fail, so the .tmp is left to inspect.
    final target = p.join(tmp.path, 'r', 'profile.sqlite');
    Directory(target).createSync(recursive: true);
    await expectLater(
      BackupService.restore(file.path, target, currentSchemaVersion: db.schemaVersion, overwrite: true),
      throwsA(isA<FileSystemException>()),
    );
    final r = sqlite3.open('$target.tmp');
    try {
      expect(r.select("SELECT credential_ref, enabled FROM sources WHERE id = 'gh'").first['credential_ref'], isNull);
    } finally {
      r.close();
    }
  });

  group('readable export', () {
    Future<void> report(String id, String start) async {
      await db
          .into(db.reports)
          .insert(
            ReportsCompanion.insert(
              id: id,
              periodKind: PeriodKind.weekly,
              periodStart: start,
              periodEnd: '2026-11-08',
              templateId: 'builtin.weekly_review',
            ),
          );
      await db
          .into(db.reportSnapshots)
          .insert(
            ReportSnapshotsCompanion.insert(
              id: 'snap-$id',
              reportId: id,
              version: 1,
              json: '{"sections":[]}',
              markdown: '# $id',
              modelId: 'm',
              generatedAt: DateTime.utc(2026, 11, 9),
            ),
          );
    }

    test('a report whose periodStart is a path escape writes nothing outside, and is still in reports.json', () async {
      await TemplateService(db).seedBuiltins();
      await report('good', '2026-11-02');
      await report('up1', '../x');
      await report('up3', '../../../x');
      final root = p.join(tmp.path, 'a', 'b');
      final dir = p.join(root, 'export');
      await ReadableExporter(db).export(dir);
      // Every file the export wrote under tmp (outside the export folder only the live DB may exist).
      final all = Directory(tmp.path).listSync(recursive: true).whereType<File>().map((f) => f.path).toList();
      final outside = all.where((f) => !p.isWithin(dir, f) && !p.basename(f).startsWith('live.sqlite'));
      expect(outside, isEmpty);
      // Inside, only the valid report got a Markdown file, and nothing escaped reports/.
      final md = Directory(p.join(dir, 'reports')).listSync().map((f) => p.basename(f.path));
      expect(md, hasLength(1));
      expect(md.single, startsWith('2026-11-02_weekly_'));
      final rootFiles = Directory(dir).listSync().whereType<File>().map((f) => p.basename(f.path));
      expect(rootFiles.where((n) => n.contains('weekly')), isEmpty);
      final reports = jsonDecode(File(p.join(dir, 'reports.json')).readAsStringSync()) as List;
      expect(reports.map((r) => (r as Map)['period_start']), containsAll(['2026-11-02', '../x', '../../../x']));
    });
  });
}
