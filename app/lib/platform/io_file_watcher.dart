import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';

/// [FileWatcher] on `FileSystemEntity.watch`, debounced so a burst of writes
/// (e.g. a git commit touching many files) emits once. Pure `dart:io`: runs in the engine isolate.
///
/// Paths that don't exist or can't be watched are skipped (simple over complete, #67);
/// sources still poll on their schedule.
class IoFileWatcher implements FileWatcher {
  IoFileWatcher({this.debounce = const Duration(seconds: 2)});
  final Duration debounce;

  @override
  Stream<void> watch(List<String> paths) {
    final subs = <StreamSubscription<FileSystemEvent>>[];
    Timer? timer;
    late final StreamController<void> out;
    out = StreamController<void>(
      onListen: () {
        for (final path in paths) {
          final type = FileSystemEntity.typeSync(path);
          if (type == FileSystemEntityType.notFound) continue;
          final entity = type == FileSystemEntityType.directory ? Directory(path) : File(path);
          try {
            subs.add(entity.watch(recursive: type == FileSystemEntityType.directory).listen(
              (_) {
                timer?.cancel();
                timer = Timer(debounce, () => out.add(null));
              },
              onError: (Object _) {},
            ));
          } on FileSystemException {
            // Unwatchable path: skip.
          }
        }
      },
      onCancel: () async {
        timer?.cancel();
        await Future.wait(subs.map((s) => s.cancel()));
      },
    );
    return out.stream;
  }
}
