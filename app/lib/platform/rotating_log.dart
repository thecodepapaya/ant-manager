/// [LogSink] adapter (#NEXT): appends lines to `<dataDir>/logs/<name>.log`, rotating at [maxBytes] into
/// `<name>.1.log` … `<name>.<keep-1>.log`. Each isolate writes its own file (`ui`, `engine`), so no locking.
/// Pure dart:io: the engine isolate uses it too.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:path/path.dart' as p;

String logsDir(String dataDir) => p.join(dataDir, 'logs');

class RotatingFileLog implements LogSink {
  RotatingFileLog(this.dir, this.name, {this.maxBytes = 1024 * 1024, this.keep = 3}) {
    Directory(dir).createSync(recursive: true);
    final f = File(_path(0));
    _size = f.existsSync() ? f.lengthSync() : 0;
  }

  final String dir;
  final String name;
  final int maxBytes;

  /// Files kept in total, the current one included.
  final int keep;
  late int _size;

  String _path(int i) => p.join(dir, i == 0 ? '$name.log' : '$name.$i.log');

  @override
  void write(String line) {
    try {
      final bytes = utf8.encode('$line\n');
      if (_size > 0 && _size + bytes.length > maxBytes) _rotate();
      File(_path(0)).writeAsBytesSync(bytes, mode: FileMode.append, flush: true);
      _size += bytes.length;
    } catch (_) {
      // A full disk or a removed folder must not break the app.
    }
  }

  void _rotate() {
    final oldest = File(_path(keep - 1));
    if (oldest.existsSync()) oldest.deleteSync();
    for (var i = keep - 2; i >= 0; i--) {
      final f = File(_path(i));
      if (f.existsSync()) f.renameSync(_path(i + 1));
    }
    _size = 0;
  }
}

/// The last [n] lines across every log file in [dir], oldest first (lines start with an ISO UTC timestamp,
/// so they sort as text across the `ui` and `engine` files).
List<String> tailLogs(String dir, {int n = 200}) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  final lines = <String>[];
  for (final f in d.listSync().whereType<File>().where((f) => f.path.endsWith('.log'))) {
    try {
      lines.addAll(const LineSplitter().convert(f.readAsStringSync()).where((l) => l.isNotEmpty));
    } catch (_) {
      // Unreadable or mid-rotation: skip.
    }
  }
  lines.sort();
  return lines.length <= n ? lines : lines.sublist(lines.length - n);
}
