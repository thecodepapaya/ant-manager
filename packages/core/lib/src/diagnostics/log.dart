/// Local diagnostic log (SPEC §10, #126): one structural line per event, written to a [LogSink] set per
/// isolate (the app's rotating files). Lines carry kinds, counts, ids, durations and redacted error
/// summaries only: never secrets, content, prompts, model output, names, paths or emails.
library;

import '../ai/llm.dart';
import '../ports/ports.dart';

enum LogLevel { info, warn, error }

abstract final class Log {
  /// Where lines go in this isolate; null (tests, before setup) drops them.
  static LogSink? sink;

  /// Tags every line with the isolate that wrote it (`ui` or `engine`).
  static String isolate = 'engine';

  /// Line timestamps and the [repeatWindow]; tests swap it (#141).
  static Clock clock = const SystemClock();

  static void info(String event, [Map<String, Object?> fields = const {}]) => _write(LogLevel.info, event, fields);

  static void warn(String event, [Map<String, Object?> fields = const {}]) => _write(LogLevel.warn, event, fields);

  /// Logs [error] as its redacted summary plus the top stack frames.
  static void error(String event, Object error, [StackTrace? stack, Map<String, Object?> fields = const {}]) {
    String summary;
    String? frames;
    try {
      summary = errorSummary(error);
      frames = stack == null ? null : stackSummary(stack);
    } catch (_) {
      summary = error.runtimeType.toString(); // toString() itself threw; logging never breaks the app
    }
    _write(LogLevel.error, event, {...fields, 'error': summary, 'stack': ?frames});
  }

  /// A warning or error repeated with the same event and fields (ignoring `ms` and `stack`) is written
  /// at most once per [repeatWindow]; the next one written carries `repeated=<n suppressed>`. Keeps a
  /// retry loop against a down provider from flooding the files.
  static const repeatWindow = Duration(minutes: 10);
  static final _recent = <String, (DateTime, int)>{};

  static void _write(LogLevel level, String event, Map<String, Object?> fields) {
    final s = sink;
    if (s == null) return;
    try {
      final now = clock.now().toUtc();
      var out = fields;
      if (level != LogLevel.info) {
        final key = formatLogLine(DateTime.utc(0), level, isolate, event, {
          for (final e in fields.entries)
            if (e.key != 'ms' && e.key != 'stack') e.key: e.value,
        });
        final seen = _recent[key];
        if (seen != null && now.difference(seen.$1) < repeatWindow) {
          _recent[key] = (seen.$1, seen.$2 + 1);
          return;
        }
        if (_recent.length > 200) _recent.clear();
        _recent[key] = (now, 0);
        if (seen != null && seen.$2 > 0) out = {...fields, 'repeated': seen.$2};
      }
      s.write(formatLogLine(now, level, isolate, event, out));
    } catch (_) {
      // Logging never breaks the app.
    }
  }
}

/// `2026-11-20T10:00:00.000Z INFO  engine job.finish kind=sources.sync ms=120`. One line; string values are
/// redacted and quoted when they contain spaces.
String formatLogLine(DateTime at, LogLevel level, String isolate, String event, Map<String, Object?> fields) {
  // Millisecond precision always (toIso8601String drops zero microseconds), so lines sort as text.
  final ts = DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch, isUtc: true).toIso8601String();
  final b = StringBuffer('$ts ${level.name.toUpperCase().padRight(5)} $isolate $event');
  for (final MapEntry(:key, :value) in fields.entries) {
    if (value == null) continue;
    b.write(' $key=${_value(value)}');
  }
  return b.toString();
}

String _value(Object v) {
  if (v is num || v is bool) return '$v';
  if (v is Duration) return '${v.inMilliseconds}';
  if (v is Enum) return v.name;
  final s = redact('$v', max: 600); // errorSummary already caps errors at 240
  return s.contains(' ') || s.isEmpty ? '"${s.replaceAll('"', "'")}"' : s;
}

/// Short, redacted description of an error: its type plus a cut-down message. An [LlmFailure] is only its
/// type and HTTP status: its text can quote provider names, raw provider bodies or model output.
String errorSummary(Object error) {
  if (error is LlmFailure) return 'LlmFailure(${error.statusCode ?? '-'})';
  final type = error.runtimeType.toString();
  var message = '$error';
  // Drop the `Type: ` / `Type(…): ` prefix toString() usually repeats.
  final prefix = RegExp('^${RegExp.escape(type)}(\\([^)]*\\))?:\\s*').firstMatch(message);
  if (prefix != null) {
    final detail = prefix.group(1) == '(null)' ? '' : prefix.group(1) ?? '';
    message = '$detail ${message.substring(prefix.end)}'.trim();
  }
  final text = redact(message);
  return text.isEmpty ? type : '$type: $text';
}

/// The top [frames] stack frames, redacted, on one line.
String stackSummary(StackTrace stack, {int frames = 6}) => redact(
  '$stack'
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .take(frames)
      .map((l) => l.replaceFirst(RegExp(r'^#\d+\s+'), ''))
      .join(' < '),
  max: 600,
);

final _url = RegExp(r'''\b[a-z][a-z0-9+.-]*://[^\s'"<>]+''', caseSensitive: false);
final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final _bearer = RegExp(r'\b(bearer|basic)\s+[\w.~+/=-]{8,}', caseSensitive: false);
final _keyValue = RegExp(
  r'''\b(api[_-]?key|key|token|secret|password|authorization|auth)\s*[=:]\s*[^\s,;'"]+''',
  caseSensitive: false,
);
final _secretLike = RegExp(r'\b(sk-|ghp_|gho_|ghu_|ghs_|github_pat_|glpat-|lin_api_|xox[abp]-|AIza|ya29\.)[\w.-]*');
final _longToken = RegExp(r'\b(?=[\w-]*\d)(?=[\w-]*[A-Za-z])[\w-]{32,}\b');
final _winPath = RegExp(r'''\b[A-Za-z]:\\[^\s'"]*''');
final _path = RegExp(r'''(^|[\s('"=:])(~|\.{1,2})?/[^\s'"()]*[^\s'"().,;:]''');
final _quoted = RegExp(r'''"[^"]*"|“[^”]*”|‘[^’]*’|(?<!\w)'[^'\n]*'(?!\w)''');

/// Strips anything that could be a secret or user content from free text (error messages, stack lines):
/// URLs, emails, auth headers and key-like tokens, file paths, quoted strings and anything from the first
/// `{` (JSON bodies). Collapses whitespace and caps the length at [max].
String redact(String text, {int max = 240}) {
  // A stored or forwarded `LlmFailure(…): text` keeps only its prefix (see [errorSummary]).
  final llm = RegExp(r'LlmFailure(\([^)]*\))?').firstMatch(text);
  if (llm != null) return redact(text.substring(0, llm.start), max: max) + llm[0]!;
  var s = text.replaceAll(RegExp(r'\s+'), ' ');
  final brace = s.indexOf('{');
  if (brace >= 0) s = '${s.substring(0, brace)}{…}';
  s = s
      .replaceAll(_url, '<url>')
      .replaceAll(_email, '<email>')
      .replaceAll(_bearer, '<secret>')
      .replaceAllMapped(_keyValue, (m) => '${m[1]}=<secret>')
      .replaceAll(_secretLike, '<secret>')
      .replaceAll(_longToken, '<secret>')
      .replaceAll(_winPath, '<path>')
      .replaceAllMapped(_path, (m) => '${m[1]}<path>')
      .replaceAll(_quoted, '"…"')
      .trim();
  return s.length > max ? '${s.substring(0, max)}…' : s;
}
