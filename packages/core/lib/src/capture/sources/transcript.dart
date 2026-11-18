/// Meeting transcripts (drag-drop .vtt / .srt / .txt). Not a syncing source: the engine ingests the observation
/// directly; the app suggests attaching it to the overlapping calendar event (SPEC §5).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/enums.dart';
import '../source.dart';

/// [at] is when the meeting started (the user can correct it). The end comes from the last cue, when timed.
PayloadObservation transcriptObservation(String fileName, String text, DateTime at) {
  final ext = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase() : '';
  final (plain, length) = (ext == 'vtt' || ext == 'srt') ? parseCues(text) : (text.trim(), null);
  final title = ext.isEmpty ? fileName : fileName.substring(0, fileName.lastIndexOf('.'));
  return PayloadObservation(
    externalId: 'transcript:${sha256.convert(utf8.encode('$fileName\n$plain')).toString().substring(0, 32)}',
    kind: PayloadKind.transcript,
    content: {'fileName': fileName, 'text': plain},
    occurredStart: at.toUtc(),
    occurredEnd: length == null ? null : at.toUtc().add(length),
    title: title,
  );
}

final _timing = RegExp(
  r'^\s*(\d{1,2}:)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->\s*(\d{1,2}:)?(\d{1,2}):(\d{2})[.,](\d{1,3})',
);
final _voice = RegExp(r'<v(?:\.[^\s>]*)?\s+([^>]+)>');
final _tag = RegExp(r'<[^>]*>');

/// WebVTT / SRT → plain text (one line per cue, consecutive duplicates dropped) and the last cue's end time.
(String, Duration?) parseCues(String src) {
  final lines = const LineSplitter().convert(src.replaceFirst('﻿', ''));
  final out = <String>[];
  Duration? end;
  var skipBlock = false; // NOTE / STYLE / REGION blocks and the WEBVTT header
  var inCue = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      skipBlock = false;
      inCue = false;
      continue;
    }
    if (!inCue && (line.startsWith('WEBVTT') || line.startsWith('NOTE') || line == 'STYLE' || line == 'REGION')) {
      skipBlock = true;
    }
    if (skipBlock) continue;
    final t = _timing.firstMatch(line);
    if (t != null) {
      inCue = true;
      end = _dur(t[5], t[6]!, t[7]!, t[8]!);
      continue;
    }
    if (!inCue) continue; // cue number / identifier before the timing line
    final speaker = _voice.firstMatch(line)?[1]?.trim();
    final text = _decode(line.replaceAll(_tag, '').trim());
    if (text.isEmpty) continue;
    final entry = speaker == null ? text : '$speaker: $text';
    if (out.isEmpty || out.last != entry) out.add(entry);
  }
  return (out.join('\n'), end);
}

Duration _dur(String? h, String m, String s, String ms) => Duration(
  hours: h == null ? 0 : int.parse(h.substring(0, h.length - 1)),
  minutes: int.parse(m),
  seconds: int.parse(s),
  milliseconds: int.parse(ms.padRight(3, '0')),
);

String _decode(String s) =>
    s.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
