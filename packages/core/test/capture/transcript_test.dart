import 'package:core/core.dart';
import 'package:core/src/capture/sources/transcript.dart';
import 'package:test/test.dart';

final at = DateTime.utc(2026, 11, 17, 15);

void main() {
  test('WebVTT: header, notes, cue ids, voices, tags and repeats removed', () {
    const vtt = '''﻿WEBVTT
Kind: captions

NOTE this is a note
spanning lines

intro
00:00:01.000 --> 00:00:04.000 align:start
<v Jane Doe>Let's <b>start</b> &amp; review.</v>

00:00:04.000 --> 00:00:05.500
<v Jane Doe>Let's <b>start</b> &amp; review.</v>

2
00:01:02.000 --> 00:01:10.250
<v.loud Bob>Sounds good.
Second line.
''';
    final o = transcriptObservation('standup.vtt', vtt, at);
    expect(o.kind, PayloadKind.transcript);
    expect(o.title, 'standup');
    expect(o.content['text'], "Jane Doe: Let's start & review.\nBob: Sounds good.\nSecond line.");
    expect(o.occurredEnd, at.add(const Duration(minutes: 1, seconds: 10, milliseconds: 250)));
  });

  test('SRT', () {
    const srt =
        '1\r\n00:00:01,000 --> 00:00:02,000\r\nHello there\r\n\r\n2\r\n00:00:02,500 --> 01:00:03,000\r\nGeneral Kenobi\r\n';
    final o = transcriptObservation('call.SRT', srt, at);
    expect(o.content['text'], 'Hello there\nGeneral Kenobi');
    expect(o.occurredEnd, at.add(const Duration(hours: 1, seconds: 3)));
  });

  test('plain text is kept and ids are stable', () {
    final a = transcriptObservation('notes.txt', '  hi\nthere  ', at);
    expect(a.content['text'], 'hi\nthere');
    expect(a.occurredEnd, isNull);
    expect(transcriptObservation('notes.txt', 'hi\nthere', at).externalId, a.externalId);
  });
}
