import 'dart:io';
import 'dart:typed_data';

import 'package:ant_manager/platform/file_blob_store.dart';
import 'package:ant_manager/platform/io_file_watcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('FileBlobStore', () {
    test('put/get/delete round-trip under the root', () async {
      final store = FileBlobStore(p.join(dir.path, 'blobs'));
      final rel = await store.put(Uint8List.fromList([1, 2, 3]), extension: '.png');
      expect(p.isRelative(rel), isTrue);
      expect(rel, endsWith('.png'));
      expect(File(p.join(dir.path, 'blobs', rel)).existsSync(), isTrue);
      expect(await store.get(rel), [1, 2, 3]);

      final other = await store.put(Uint8List.fromList([9]), extension: 'jpg');
      expect(other, isNot(rel));
      expect(other, endsWith('.jpg'));

      await store.delete(rel);
      expect(File(p.join(dir.path, 'blobs', rel)).existsSync(), isFalse);
      await store.delete(rel); // deleting a missing blob is a no-op
      expect(await store.get(other), [9]);
    });

    test('rejects paths escaping the store', () async {
      final store = FileBlobStore(p.join(dir.path, 'blobs'));
      File(p.join(dir.path, 'secret.txt')).writeAsStringSync('x');
      for (final bad in ['../secret.txt', 'ab/../../secret.txt', p.join(dir.path, 'secret.txt'), '/etc/hosts']) {
        expect(() => store.get(bad), throwsArgumentError, reason: bad);
        await expectLater(() => store.delete(bad), throwsArgumentError, reason: bad);
      }
      expect(File(p.join(dir.path, 'secret.txt')).existsSync(), isTrue);
    });
  });

  group('IoFileWatcher', () {
    test('debounces a burst of writes into one event', () async {
      final watched = Directory(p.join(dir.path, 'repo'))..createSync();
      final watcher = IoFileWatcher(debounce: const Duration(milliseconds: 500));
      var events = 0;
      final sub = watcher.watch([watched.path]).listen((_) => events++);
      addTearDown(sub.cancel);
      // FSEvents replays the directory's own creation shortly after watching: let it settle.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      events = 0;

      for (var i = 0; i < 10; i++) {
        File(p.join(watched.path, 'f$i.txt')).writeAsStringSync('$i');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final end = DateTime.now().add(const Duration(seconds: 5));
      while (events == 0 && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(events, 1);
    });

    test('skips missing paths and still watches the rest', () async {
      final watched = Directory(p.join(dir.path, 'repo'))..createSync();
      final watcher = IoFileWatcher(debounce: const Duration(milliseconds: 100));
      final first = watcher.watch([p.join(dir.path, 'nope'), watched.path]).first;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      File(p.join(watched.path, 'a.txt')).writeAsStringSync('a');
      await expectLater(first.timeout(const Duration(seconds: 5)), completes);
    });
  });
}
