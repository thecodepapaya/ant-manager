// Runs tool/check_tokens.dart as a process against temp fixture trees.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _script = File('tool/check_tokens.dart').absolute.path;

/// Literal patterns the check must reject (SPEC §10, #41).
const _bad = <String, String>{
  'color_hex': 'final c = Color(0xFF112233);',
  'color_hex_const_spaced': 'const c = Color( 0x80FFFFFF );',
  'colors_constant': 'final c = Colors.red;',
  'colors_transparent': 'final c = Colors.transparent;',
  'radius_int': 'final r = BorderRadius.circular(8);',
  'radius_double': 'final r = BorderRadius.circular(4.5);',
  'radius_leading_dot': 'final r = BorderRadius.circular(.5);',
  'font_size': 'final s = TextStyle(fontSize: 13);',
  'font_size_double': 'final s = TextStyle(color: c, fontSize: 12.5);',
  'insets_all': 'final p = EdgeInsets.all(8);',
  'insets_symmetric': 'final p = EdgeInsets.symmetric(horizontal: 12);',
  'insets_only': 'final p = EdgeInsets.only(left: t.space.md, top: 4);',
  'insets_ltrb': 'final p = EdgeInsets.fromLTRB(0, 0, 0, 2);',
  'insets_directional': 'final p = EdgeInsetsDirectional.only(start: 6);',
  'insets_const_multiline': '''
const p = EdgeInsets.symmetric(
  vertical: 3,
);''',
  'insets_math': 'final p = EdgeInsets.all(t.space.md * 2);',
};

/// Token-based code the check must accept.
const _ok = <String, String>{
  'token_color': 'final c = t.accent;',
  'with_values': 'final c = t.hover.withValues(alpha: 0);',
  'radius_token': 'final r = BorderRadius.circular(t.radii.md);',
  'radius_expr': 'final r = BorderRadius.circular((a - b).clamp(0, 9));',
  'radius_scale': 'final r = t.radii.brLg;',
  'font_token':
      'final s = t.typo.body.copyWith(fontSize: t.typo.small.fontSize);',
  'insets_token': 'final p = EdgeInsets.all(t.space.md);',
  'insets_zero': 'final p = EdgeInsets.zero;',
  'insets_literal_zero':
      'final p = EdgeInsets.fromLTRB(0, 0.0, t.space.xs, 0);',
  'insets_identifier_digits': 'final p = EdgeInsets.all(t.space.x2);',
  'other_colors_class': 'final c = AntColors.red; final d = myColors.red;',
  'line_comment':
      '// Color(0xFF000000) Colors.red EdgeInsets.all(8)\nfinal a = 1;',
  'doc_comment': '/// Use BorderRadius.circular(4) or TextStyle(fontSize: 12).\nfinal a = 1;',
  'block_comment': '/* Colors.red\n   EdgeInsets.all(8) */\nfinal a = 1;',
  'url_in_string': "final u = 'https://example.com'; final c = t.text;",
};

late Directory _tmp;

Future<ProcessResult> _run(List<String> args, {String? cwd}) =>
    Process.run('dart', [_script, ...args], workingDirectory: cwd ?? _tmp.path);

void _write(String rel, String body) {
  final f = File('${_tmp.path}/$rel');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync('$body\n');
}

void main() {
  setUp(() => _tmp = Directory.systemTemp.createTempSync('check_tokens_'));
  tearDown(() => _tmp.deleteSync(recursive: true));

  test('fails (exit 1) on every documented literal pattern', () async {
    for (final e in _bad.entries) {
      _write('app/lib/${e.key}.dart', e.value);
    }
    final r = await _run(['app/lib']);
    expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    for (final name in _bad.keys) {
      expect(
        r.stderr as String,
        contains('$name.dart:'),
        reason: '$name must be reported',
      );
    }
  });

  test('each bad pattern alone fails', () async {
    for (final e in _bad.entries) {
      final dir = 'one_${e.key}';
      _write('$dir/x.dart', e.value);
      final r = await _run([dir]);
      expect(r.exitCode, 1, reason: '${e.key}: ${r.stdout}${r.stderr}');
    }
  });

  test('passes (exit 0) on token-based code and comments', () async {
    for (final e in _ok.entries) {
      _write('app/lib/${e.key}.dart', e.value);
    }
    final r = await _run(['app/lib']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout as String, contains('OK (${_ok.length} files)'));
  });

  test('reports the right line number after a block comment', () async {
    _write('lib/a.dart', '/* one\n two\n three */\nfinal c = Colors.red;');
    final r = await _run(['lib']);
    expect(r.exitCode, 1);
    expect(r.stderr as String, contains('a.dart:4:'));
  });

  test('ignores non-Dart files', () async {
    _write('lib/notes.md', 'Colors.red EdgeInsets.all(8)');
    final r = await _run(['lib']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('skips packages/ui/lib/src/tokens/ (run from repo root)', () async {
    _write('packages/ui/lib/src/tokens/t.dart', 'const c = Color(0xFF000000);');
    _write('packages/ui/lib/src/components/ok.dart', 'final c = t.accent;');
    final r = await _run(['packages/ui/lib']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');

    _write('packages/ui/lib/src/components/bad.dart', 'final c = Colors.red;');
    final bad = await _run(['packages/ui/lib']);
    expect(bad.exitCode, 1);
    expect(bad.stderr as String, contains('bad.dart'));
    expect(bad.stderr as String, isNot(contains('tokens/t.dart')));
  });

  test('default dirs are app/lib and packages/ui/lib', () async {
    _write('app/lib/a.dart', 'final c = Colors.red;');
    _write('packages/ui/lib/src/tokens/t.dart', 'const c = Color(0xFF000000);');
    _write('other/lib/b.dart', 'final c = Colors.red;');
    final r = await _run([]);
    expect(r.exitCode, 1);
    expect(r.stderr as String, contains('app/lib/a.dart'));
    expect(r.stderr as String, isNot(contains('other/lib')));
  });

  test('skips the tokens dir when run from inside packages/ui '
      '(BUG: tool/check_tokens.dart:12/37 matches the cwd-relative path '
      'against "packages/ui/lib/src/tokens/", so `dart run tool/check_tokens.dart '
      'lib` from packages/ui flags every token literal)', () async {
    _write('packages/ui/lib/src/tokens/t.dart', 'const c = Color(0xFF000000);');
    final r = await _run(['lib'], cwd: '${_tmp.path}/packages/ui');
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }, skip: bugSkip);

  test('the real repo passes the check', () async {
    final r = await _run([], cwd: Directory('../..').absolute.path);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });
}
