// Fails (exit 1) when a visual literal appears outside the token source
// (DECISIONS #41, SPEC §10).
//
// Usage, from the repo root:
//   dart run packages/ui/tool/check_tokens.dart [dir ...]
//
// Default dirs: app/lib and packages/ui/lib. packages/ui/lib/src/tokens/ is
// the one place literals are allowed.
import 'dart:io';

const _defaultDirs = ['app/lib', 'packages/ui/lib'];
const _allowed = 'packages/ui/lib/src/tokens/';

final _simpleRules = <String, RegExp>{
  'Color(0x…) literal': RegExp(r'\bColor\(\s*0x'),
  'Colors.* constant': RegExp(r'\bColors\.'),
  'BorderRadius.circular(<number>)': RegExp(
    r'\bBorderRadius\.circular\(\s*-?(\d|\.\d)',
  ),
  'fontSize: <number>': RegExp(r'\bfontSize:\s*-?(\d|\.\d)'),
};

final _edgeInsetsStart = RegExp(r'\bEdgeInsets(Directional)?\.\w+\(');

/// A numeric literal not glued to an identifier or member access.
final _number = RegExp(r'(?<![\w.$])(\d+(\.\d+)?|\.\d+)(?![\w.])');

void main(List<String> args) {
  final dirs = args.isEmpty ? _defaultDirs : args;
  final violations = <String>[];
  var files = 0;
  for (final dir in dirs) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      // Match on the absolute path so the check works from any cwd.
      final abs = f.absolute.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || abs.contains('/$_allowed')) continue;
      files++;
      violations.addAll(_check(path, f.readAsStringSync()));
    }
  }
  if (violations.isEmpty) {
    stdout.writeln('check_tokens: OK ($files files)');
    return;
  }
  stderr.writeln(
    'check_tokens: ${violations.length} visual literal(s) '
    'outside $_allowed:',
  );
  violations.forEach(stderr.writeln);
  exit(1);
}

Iterable<String> _check(String path, String source) sync* {
  final code = _stripComments(source);
  for (final rule in _simpleRules.entries) {
    for (final m in rule.value.allMatches(code)) {
      yield '  $path:${_line(code, m.start)}: ${rule.key}';
    }
  }
  for (final m in _edgeInsetsStart.allMatches(code)) {
    final args = _balancedArgs(code, m.end);
    final hasLiteral = _number
        .allMatches(args)
        .any((n) => double.parse(n.group(0)!) != 0);
    if (hasLiteral) {
      yield '  $path:${_line(code, m.start)}: EdgeInsets with a number literal';
    }
  }
}

/// Text between the '(' ending at [start] and its matching ')'.
String _balancedArgs(String code, int start) {
  var depth = 1;
  var i = start;
  while (i < code.length && depth > 0) {
    final c = code[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    i++;
  }
  return code.substring(start, i - 1);
}

/// Blanks out comments, keeping offsets (and so line numbers) intact.
String _stripComments(String s) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < s.length) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';
    if (quote != null) {
      out.write(c);
      if (c == r'\' && next.isNotEmpty) {
        out.write(next);
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      i++;
    } else if (c == "'" || c == '"') {
      quote = c;
      out.write(c);
      i++;
    } else if (c == '/' && next == '/') {
      while (i < s.length && s[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (c == '/' && next == '*') {
      while (i < s.length &&
          !(s[i] == '*' && i + 1 < s.length && s[i + 1] == '/')) {
        out.write(s[i] == '\n' ? '\n' : ' ');
        i++;
      }
      out.write('  ');
      i += 2;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

int _line(String s, int offset) =>
    '\n'.allMatches(s.substring(0, offset)).length + 1;
