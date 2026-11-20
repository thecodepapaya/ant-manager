import 'dart:io';

import 'package:path/path.dart' as p;

/// Interactive region screenshot for quick capture (SPEC §7).
///
/// - macOS: `screencapture -i -x` (needs Screen Recording permission; without it macOS
///   captures only the wallpaper and our own windows).
/// - Linux: the xdg-desktop-portal Screenshot flow is out of scope for now → unsupported.
/// - Windows: unsupported in v1 (follow-up).
class ScreenCapture {
  const ScreenCapture();

  bool get supported => Platform.isMacOS;

  /// Lets the user drag a region. Returns the PNG path in the temp dir,
  /// or null when the user cancelled (Esc).
  Future<String?> captureRegion() async {
    if (!supported) throw UnsupportedError('Screenshot capture is not available on this platform yet.');
    final path = p.join(Directory.systemTemp.path, 'ant_capture_${DateTime.now().microsecondsSinceEpoch}.png');
    final r = await Process.run('/usr/sbin/screencapture', ['-i', '-x', '-t', 'png', path]);
    if (r.exitCode != 0) throw ProcessException('screencapture', ['-i'], '${r.stderr}', r.exitCode);
    return File(path).existsSync() ? path : null;
  }
}
