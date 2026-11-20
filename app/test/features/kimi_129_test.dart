/// Independent tests (#99) for DECISIONS #129 (Kimi review: backup, restore and delete integrity), app side:
/// FileBlobStore.sweep, the engine's startup orphan sweep, restore cleanup and EngineHandle.start failures.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/platform/file_blob_store.dart';
import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fakes.dart';

final _png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

EngineCommand<List<String>> _attachmentPathsCmd(String evidenceId) => (rt) async {
      final pls = await (rt.db.select(rt.db.payloads)..where((x) => x.evidenceId.equals(evidenceId))).get();
      final rows = await (rt.db.select(rt.db.attachments)..where((a) => a.payloadId.isIn(pls.map((x) => x.id)))).get();
      return rows.map((a) => a.path).toList();
    };

EngineCommand<void> _addCredentialSourceCmd() => (rt) => rt.db.into(rt.db.sources).insert(SourcesCompanion.insert(
      id: 'gh',
      kind: SourceKind.github,
      name: 'GitHub',
      credentialRef: const Value('github.token'),
    ));

EngineCommand<void> _sqlAppCmd(String sql) => (rt) => rt.appDb.customStatement(sql);

/// Copies [file] with an extra `attachments/../../escaped.txt` entry: restore writes the DB, then refuses it.
String _withUnsafeEntry(String file, Directory dir) {
  final a = ZipDecoder().decodeBytes(File(file).readAsBytesSync());
  final out = Archive();
  for (final f in a.files.where((f) => f.isFile)) {
    out.addFile(ArchiveFile.bytes(f.name, f.readBytes()!));
  }
  out.addFile(ArchiveFile.bytes('attachments/../../escaped.txt', utf8.encode('x')));
  final path = p.join(dir.path, 'unsafe.antbackup');
  File(path).writeAsBytesSync(ZipEncoder().encodeBytes(out));
  return path;
}

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('FileBlobStore.sweep', () {
    late String root;
    setUp(() => root = p.join(dir.path, 'blobs'));

    File write(String rel) => File(p.join(root, rel))
      ..createSync(recursive: true)
      ..writeAsBytesSync(_png);

    test('deletes unreferenced files and keeps referenced ones, at any depth', () async {
      final kept = [write('ab/keep.png'), write('cd/keep2.jpg'), write('top.png')];
      final gone = [write('ab/orphan.png'), write('zz/deep/orphan.png'), write('stray.bin')];
      await FileBlobStore(root).sweep({'ab/keep.png', 'cd/keep2.jpg', 'top.png', 'ab/not-on-disk.png'});
      for (final f in kept) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
      for (final f in gone) {
        expect(f.existsSync(), isFalse, reason: f.path);
      }
    });

    test('a non-normalized kept path still keeps its file', () async {
      final f = write('ab/keep.png');
      await FileBlobStore(root).sweep({'ab/./keep.png'});
      expect(f.existsSync(), isTrue);
    });

    test('an empty keep set deletes every file', () async {
      final files = [write('ab/a.png'), write('b.png')];
      await FileBlobStore(root).sweep({});
      expect(files.where((f) => f.existsSync()), isEmpty);
    });

    test('a missing root is a no-op and is not created', () async {
      await FileBlobStore(root).sweep({'ab/x.png'});
      expect(Directory(root).existsSync(), isFalse);
    });

    test('files written through put and kept by path survive', () async {
      final store = FileBlobStore(root);
      final a = await store.put(_png, extension: 'png');
      final b = await store.put(_png, extension: '.jpg');
      await store.sweep({a});
      expect(File(p.join(root, a)).existsSync(), isTrue);
      expect(File(p.join(root, b)).existsSync(), isFalse);
    });
  });

  group('startup orphan sweep', () {
    Future<EngineHandle> start() => EngineHandle.start(testConfig(dir.path, inMemory: false), host: fakeHost());

    String blobRoot(String profileId) => p.join(dir.path, 'blobs', profileId);

    test('a profile with no payloads deletes nothing at startup', () async {
      final first = await start();
      final id = first.profileId;
      await first.shutdown();
      final stray = File(p.join(blobRoot(id), 'ab', 'stray.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(_png);
      final second = await start();
      addTearDown(second.shutdown);
      expect(second.profileId, id);
      expect(stray.existsSync(), isTrue, reason: 'no payloads: the DB may be missing or replaced');
    });

    test('with payloads, an unreferenced file is removed at startup and referenced ones kept', () async {
      final first = await start();
      final id = first.profileId;
      final ev = await first.runtime(addNoteCmd(text: 'with image', at: DateTime.now(), images: [(_png, 'png')]));
      final kept = (await first.runtime(_attachmentPathsCmd(ev))).single;
      await first.shutdown();
      final stray = File(p.join(blobRoot(id), 'zz', 'stray.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(_png);
      // Another profile's blob folder is outside this profile's sweep.
      final otherProfile = File(p.join(blobRoot('other-profile'), 'zz', 'theirs.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(_png);
      final second = await start();
      addTearDown(second.shutdown);
      expect(stray.existsSync(), isFalse);
      expect(File(p.join(blobRoot(id), kept)).existsSync(), isTrue);
      expect(otherProfile.existsSync(), isTrue);
    });

    test('after a permanent delete whose blob deletion failed, a restart removes the file', () async {
      final first = await start();
      final id = first.profileId;
      final doomed = await first.runtime(addNoteCmd(text: 'doomed', at: DateTime.now(), images: [(_png, 'png')]));
      final keep = await first.runtime(addNoteCmd(text: 'keeper', at: DateTime.now(), images: [(_png, 'png')]));
      final doomedPath = (await first.runtime(_attachmentPathsCmd(doomed))).single;
      final keepPath = (await first.runtime(_attachmentPathsCmd(keep))).single;
      final doomedFile = File(p.join(blobRoot(id), doomedPath));
      // A read-only folder makes the post-commit blob delete fail.
      final folder = doomedFile.parent;
      Process.runSync('chmod', ['555', folder.path]);
      addTearDown(() => Process.runSync('chmod', ['755', folder.path]));
      await expectLater(first.runtime(deleteEvidenceCmd(doomed)), throwsA(isA<EngineCommandException>()));
      Process.runSync('chmod', ['755', folder.path]);
      expect(doomedFile.existsSync(), isTrue, reason: 'the blob delete really failed');
      expect(await first.runtime(_attachmentPathsCmd(doomed)), isEmpty, reason: 'the rows are gone');
      await first.shutdown();

      final second = await start();
      addTearDown(second.shutdown);
      expect(doomedFile.existsSync(), isFalse);
      expect(File(p.join(blobRoot(id), keepPath)).existsSync(), isTrue);
    });
  });

  group('restore', () {
    late EngineHandle h;
    setUp(() async {
      h = await EngineHandle.start(testConfig(dir.path), host: fakeHost());
      addTearDown(h.shutdown);
    });

    List<String> profileFiles() =>
        Directory(p.join(dir.path, 'profiles')).listSync().map((f) => p.basename(f.path)).toList();

    test('the restored DB has no credential_ref and no .sqlite.tmp is left', () async {
      await h.runtime(_addCredentialSourceCmd());
      final file = await h.runtime(backupNowCmd());
      final id = await h.runtime(restoreBackupCmd(file));
      final restored = ProfileDb(NativeDatabase(File(p.join(dir.path, 'profiles', '$id.sqlite'))));
      addTearDown(restored.close);
      final gh = (await restored.select(restored.sources).get()).singleWhere((s) => s.id == 'gh');
      expect(gh.credentialRef, isNull);
      expect(gh.enabled, isFalse);
      expect(profileFiles().where((f) => f.contains('.tmp')), isEmpty);
    });

    test('a failing cleanup step does not hide the restore error, and later steps still run', () async {
      await h.runtime(addNoteCmd(text: 'n', at: DateTime.now(), images: [(_png, 'png')]));
      final unsafe = _withUnsafeEntry(await h.runtime(backupNowCmd()), dir);
      // Block the first cleanup step (deleting the new profile row).
      await h.runtime(_sqlAppCmd(
        "CREATE TRIGGER block_delete BEFORE DELETE ON profiles BEGIN SELECT RAISE(ABORT, 'cleanup blocked'); END",
      ));
      addTearDown(() => h.runtime(_sqlAppCmd('DROP TRIGGER IF EXISTS block_delete')));
      await expectLater(
        h.runtime(restoreBackupCmd(unsafe)),
        throwsA(isA<EngineCommandException>()
            .having((e) => e.message, 'message', contains('Unsafe path'))
            .having((e) => e.message, 'message', isNot(contains('cleanup blocked')))),
      );
      // The row stayed (its delete was blocked); the files after it were still cleaned up.
      final left = (await h.appDb.select(h.appDb.profiles).get()).where((x) => x.id != h.profileId).single;
      expect(left.name, 'Work (restored)');
      expect(profileFiles().where((f) => f.startsWith(left.id)), isEmpty, reason: 'no .sqlite or .sqlite.tmp');
      expect(Directory(p.join(dir.path, 'blobs', left.id)).existsSync(), isFalse);
      expect(File(p.join(dir.path, 'blobs', 'escaped.txt')).existsSync(), isFalse);
    });

    test('a failed restore without cleanup trouble leaves no profile, DB, .tmp or blobs', () async {
      await h.runtime(addNoteCmd(text: 'n', at: DateTime.now(), images: [(_png, 'png')]));
      final unsafe = _withUnsafeEntry(await h.runtime(backupNowCmd()), dir);
      await expectLater(h.runtime(restoreBackupCmd(unsafe)), throwsA(isA<EngineCommandException>()));
      expect((await h.appDb.select(h.appDb.profiles).get()).map((x) => x.id), [h.profileId]);
      expect(profileFiles().where((f) => !f.startsWith(h.profileId)), isEmpty);
      final blobDirs = Directory(p.join(dir.path, 'blobs')).listSync().map((d) => p.basename(d.path));
      expect(blobDirs.where((d) => d != h.profileId), isEmpty);
    });
  });

  group('EngineHandle.start', () {
    // Covers the EngineFailed path only: spawn and DB-connect failures (#129 h) have no test seam.
    test('fails cleanly, without hanging, when the engine reports a startup failure', () async {
      // A file where the profiles folder should be: EngineRuntime.open throws, the engine sends EngineFailed.
      File(p.join(dir.path, 'profiles')).writeAsStringSync('not a folder');
      await expectLater(
        EngineHandle.start(testConfig(dir.path, inMemory: false), host: fakeHost())
            .timeout(const Duration(seconds: 20)),
        throwsA(isA<EngineCommandException>()),
      );
      // Nothing is left holding the data folder: once fixed, the engine starts normally.
      File(p.join(dir.path, 'profiles')).deleteSync();
      final h = await EngineHandle.start(testConfig(dir.path, inMemory: false), host: fakeHost())
          .timeout(const Duration(seconds: 20));
      addTearDown(h.shutdown);
      expect((await h.appDb.select(h.appDb.profiles).get()).single.id, h.profileId);
    });
  });
}
