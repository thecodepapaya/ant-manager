import 'dart:io';

import 'package:flutter/services.dart';

/// Rich clipboard on macOS (`macos/Runner/MainFlutterWindow.swift`, channel `ant/clipboard`):
/// HTML copy for "rich text" sharing and pasted screenshots. Elsewhere: plain text only, no images.
abstract final class RichClipboard {
  static const _ch = MethodChannel('ant/clipboard');

  /// Puts [html] (with [text] as the plain fallback) on the clipboard.
  static Future<void> setHtml(String html, String text) async {
    if (!Platform.isMacOS) return Clipboard.setData(ClipboardData(text: text));
    await _ch.invokeMethod<void>('setHtml', {'html': html, 'text': text});
  }

  /// PNG bytes of an image on the clipboard, or null.
  static Future<Uint8List?> readImage() async {
    if (!Platform.isMacOS) return null;
    return _ch.invokeMethod<Uint8List>('readImage');
  }
}
