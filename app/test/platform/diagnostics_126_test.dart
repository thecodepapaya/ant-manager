/// Independent tests (#99) for diagnostics (DECISIONS #126, LLD 04 §4.14) on the app side: the rotating log
/// files, tailLogs, the engine's diagnosticsCmd (seeded with fake secrets, then grepped) and diagnosticsReport.
/// Run known bugs with `--dart-define=RUN_BUGS=true`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/diagnostics.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/platform/rotating_log.dart';
import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fakes.dart';

const bugSkip = !bool.fromEnvironment('RUN_BUGS');

String ts(int sec, [int ms = 0]) => DateTime.utc(2026, 11, 20, 10, 0, sec, ms).toIso8601String();

List<String> filesIn(String dir) =>
    (Directory(dir).listSync().whereType<File>().map((f) => p.basename(f.path)).toList()..sort());

String read(String dir, String name) => File(p.join(dir, name)).readAsStringSync();

void main() {
  late Directory tmp;
  setUp(() => tmp = tempDir());
  tearDown(() => tmp.deleteSync(recursive: true));

  group('RotatingFileLog', () {
    test('appends one line per write under logs/<name>.log, creating the folder', () {
      final dir = logsDir(tmp.path);
      expect(dir, p.join(tmp.path, 'logs'));
      final log = RotatingFileLog(dir, 'engine');
      log.write('a');
      log.write('b');
      expect(read(dir, 'engine.log'), 'a\nb\n');
      expect(filesIn(dir), ['engine.log']);
    });

    test('rotates when the next line would pass maxBytes, keeping 3 files and dropping the oldest', () {
      final dir = logsDir(tmp.path);
      final log = RotatingFileLog(dir, 'ui', maxBytes: 10); // each 'nnnn' line is 5 bytes: two per file
      for (var i = 1; i <= 8; i++) {
        log.write('$i' * 4);
      }
      expect(filesIn(dir), ['ui.1.log', 'ui.2.log', 'ui.log']);
      expect(read(dir, 'ui.log'), '7777\n8888\n');
      expect(read(dir, 'ui.1.log'), '5555\n6666\n');
      expect(read(dir, 'ui.2.log'), '3333\n4444\n');
      // Lines 1 and 2 were in the oldest file, deleted on the last rotation.
      final all = filesIn(dir).map((f) => read(dir, f)).join();
      expect(all, isNot(contains('1111')));
      expect(all, isNot(contains('2222')));
    });

    test('a line exactly filling maxBytes does not rotate', () {
      final dir = logsDir(tmp.path);
      final log = RotatingFileLog(dir, 'ui', maxBytes: 10);
      log.write('aaaa');
      log.write('bbbb'); // 10 bytes total: at the limit, not past it
      expect(filesIn(dir), ['ui.log']);
      log.write('c');
      expect(filesIn(dir), ['ui.1.log', 'ui.log']);
      expect(read(dir, 'ui.log'), 'c\n');
    });

    test('keep: 1 keeps only the current file', () {
      final dir = logsDir(tmp.path);
      final log = RotatingFileLog(dir, 'x', maxBytes: 3, keep: 1);
      for (final l in ['aa', 'bb', 'cc']) {
        log.write(l);
      }
      expect(filesIn(dir), ['x.log']);
      expect(read(dir, 'x.log'), 'cc\n');
    });

    test('keep sets the total file count', () {
      final dir = logsDir(tmp.path);
      final log = RotatingFileLog(dir, 'x', maxBytes: 3, keep: 2);
      for (final l in ['aa', 'bb', 'cc', 'dd']) {
        log.write(l);
      }
      expect(filesIn(dir), ['x.1.log', 'x.log']);
      expect(read(dir, 'x.log'), 'dd\n');
      expect(read(dir, 'x.1.log'), 'cc\n');
    });

    test('a line bigger than the limit is still written whole, in a file of its own', () {
      final dir = logsDir(tmp.path);
      final big = 'z' * 50;
      final log = RotatingFileLog(dir, 'ui', maxBytes: 10);
      log.write(big); // empty file: written whole, no rotation
      expect(read(dir, 'ui.log'), '$big\n');
      log.write('next');
      expect(read(dir, 'ui.1.log'), '$big\n');
      expect(read(dir, 'ui.log'), 'next\n');
      log.write(big); // non-empty file: rotate first, then the big line alone
      expect(read(dir, 'ui.log'), '$big\n');
      expect(read(dir, 'ui.1.log'), 'next\n');
    });

    test('counts multi-byte characters as bytes', () {
      final dir = logsDir(tmp.path);
      final log = RotatingFileLog(dir, 'ui', maxBytes: 10);
      log.write('ééé'); // 6 bytes + newline
      log.write('ab'); // 7 + 3 = 10: fits
      expect(filesIn(dir), ['ui.log']);
      log.write('é'); // past the limit
      expect(filesIn(dir), ['ui.1.log', 'ui.log']);
      expect(utf8.encode(read(dir, 'ui.1.log')).length, 10);
    });

    test('a new instance picks up the existing file size', () {
      final dir = logsDir(tmp.path);
      RotatingFileLog(dir, 'ui', maxBytes: 10).write('aaaa');
      final again = RotatingFileLog(dir, 'ui', maxBytes: 10);
      again.write('bbbb');
      expect(filesIn(dir), ['ui.log']);
      again.write('cccc');
      expect(filesIn(dir), ['ui.1.log', 'ui.log']);
      expect(read(dir, 'ui.1.log'), 'aaaa\nbbbb\n');
    });

    test('an unwritable folder never throws, from the constructor or write', () {
      final blocker = File(p.join(tmp.path, 'not_a_dir'))..writeAsStringSync('x');
      final dir = p.join(blocker.path, 'logs'); // a folder under a regular file cannot be created
      late RotatingFileLog log;
      expect(() => log = RotatingFileLog(dir, 'ui', maxBytes: 10), returnsNormally);
      expect(() {
        for (var i = 0; i < 5; i++) {
          log.write('line $i');
        }
      }, returnsNormally);
      expect(Directory(dir).existsSync(), isFalse);
    });

    test('a folder removed after start never throws', () {
      final dir = logsDir(tmp.path);
      final log = RotatingFileLog(dir, 'ui', maxBytes: 10)..write('aaaa');
      Directory(dir).deleteSync(recursive: true);
      expect(() {
        log.write('bbbb');
        log.write('cccc');
      }, returnsNormally);
    });

    test('works as Log.sink', () {
      final dir = logsDir(tmp.path);
      Log.sink = RotatingFileLog(dir, 'ui');
      addTearDown(() => Log.sink = null);
      Log.isolate = 'ui';
      addTearDown(() => Log.isolate = 'engine');
      Log.info('diag.sink.test', {'n': 2});
      expect(read(dir, 'ui.log'), matches(RegExp(r'^\S+Z INFO  ui diag\.sink\.test n=2\n$')));
    });
  });

  group('tailLogs', () {
    test('a missing folder gives no lines', () {
      expect(tailLogs(p.join(tmp.path, 'nope')), isEmpty);
    });

    test('merges ui and engine logs, rotated files included, in time order', () {
      final dir = logsDir(tmp.path);
      Directory(dir).createSync();
      File(p.join(dir, 'ui.1.log')).writeAsStringSync('${ts(1)} INFO  ui a\n${ts(4)} INFO  ui d\n');
      File(p.join(dir, 'ui.log')).writeAsStringSync('${ts(6)} INFO  ui f\n');
      File(p.join(dir, 'engine.log')).writeAsStringSync('${ts(2)} INFO  engine b\n\n${ts(5)} WARN  engine e\n');
      File(p.join(dir, 'engine.1.log')).writeAsStringSync('${ts(3)} ERROR engine c\n');
      File(p.join(dir, 'notes.txt')).writeAsStringSync('${ts(0)} not a log\n');
      final lines = tailLogs(dir);
      expect(lines.map((l) => l.split(' ').last), ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('orders by milliseconds across files', () {
      final dir = logsDir(tmp.path);
      Directory(dir).createSync();
      File(p.join(dir, 'ui.log')).writeAsStringSync('${ts(1, 900)} INFO  ui late\n');
      File(p.join(dir, 'engine.log')).writeAsStringSync('${ts(1, 100)} INFO  engine early\n');
      expect(tailLogs(dir).map((l) => l.split(' ').last), ['early', 'late']);
    });

    test('takes the last n lines, oldest first', () {
      final dir = logsDir(tmp.path);
      Directory(dir).createSync();
      final ui = StringBuffer();
      final engine = StringBuffer();
      for (var i = 0; i < 30; i++) {
        (i.isEven ? ui : engine).writeln('${ts(i)} INFO  x l$i');
      }
      File(p.join(dir, 'ui.log')).writeAsStringSync('$ui');
      File(p.join(dir, 'engine.log')).writeAsStringSync('$engine');
      expect(tailLogs(dir, n: 5).map((l) => l.split(' ').last), ['l25', 'l26', 'l27', 'l28', 'l29']);
      expect(tailLogs(dir, n: 100), hasLength(30));
    });

    test('defaults to the last 200 lines', () {
      final dir = logsDir(tmp.path);
      Directory(dir).createSync();
      final b = StringBuffer();
      for (var i = 0; i < 250; i++) {
        b.writeln('${DateTime.utc(2026, 11, 20).add(Duration(seconds: i)).toIso8601String()} INFO  ui l$i');
      }
      File(p.join(dir, 'ui.log')).writeAsStringSync('$b');
      final lines = tailLogs(dir);
      expect(lines, hasLength(200));
      expect(lines.first, endsWith(' l50'));
      expect(lines.last, endsWith(' l249'));
    });

    test('reads what RotatingFileLog wrote across rotations', () {
      final dir = logsDir(tmp.path);
      final ui = RotatingFileLog(dir, 'ui', maxBytes: 80);
      final engine = RotatingFileLog(dir, 'engine', maxBytes: 80);
      for (var i = 0; i < 6; i++) {
        (i.isEven ? ui : engine).write('${ts(i)} INFO  x l$i');
      }
      expect(tailLogs(dir).map((l) => l.split(' ').last), ['l0', 'l1', 'l2', 'l3', 'l4', 'l5']);
    });
  });

  group('engine log file', () {
    test('an on-disk engine writes engine.start and engine.ready to logs/engine.log', () async {
      final h = await EngineHandle.start(testConfig(tmp.path, inMemory: false), host: fakeHost());
      await h.shutdown();
      final lines = tailLogs(logsDir(tmp.path));
      expect(lines.where((l) => l.contains(' INFO  engine engine.start')), hasLength(1));
      final ready = lines.singleWhere((l) => l.contains(' engine engine.ready '));
      expect(ready, matches(RegExp(r' profile=\S+ ms=\d+$')));
      expect(lines.join('\n'), isNot(contains(tmp.path)));
    });
  });

  group('diagnosticsCmd', () {
    late EngineHandle h;
    late FakeSecrets secrets;
    setUp(() async {
      secrets = FakeSecrets();
      h = await EngineHandle.start(testConfig(tmp.path), host: fakeHost(secrets: secrets));
      addTearDown(h.shutdown);
    });

    test('reports setup shape with no names, URLs, credentials or content', () async {
      final baseline = await h.runtime(diagnosticsCmd());
      await h.runtime(_seedCmd());
      final out = await h.runtime(diagnosticsCmd());

      // Nothing secret, named or addressable leaks.
      for (final s in _leaks) {
        expect(out.toLowerCase(), isNot(contains(s.toLowerCase())), reason: s);
      }
      expect(out, isNot(contains('://')));
      expect(out, isNot(contains('@')));

      // Shape.
      expect(out, contains('Profiles: 1'));
      expect(out, matches(RegExp(r'Schema: app v\d+, profile v\d+')));
      expect(out, contains('Collection paused: false'));
      expect(out, contains('Sources (active profile):'));
      expect(out, contains('  github         enabled   error: GET <url> failed for <email>: Authorization=<secret>\n'));
      expect(out, contains('  gitlab         enabled   ok 2026-11-19T08:30:00.000Z'));
      expect(out, contains('  jira           disabled  never synced'));
      expect(out, contains('  linear         enabled   error: LlmFailure(500)'));

      // Providers: remote vs loopback and model counts.
      expect(out, contains('  openrouter openai  remote    2 models'));
      expect(out, contains('  custom     ollama  loopback  1 model\n'));
      expect(out, contains('  custom     openai  loopback  0 models'));
      expect(out, contains('  custom     openai  remote    0 models')); // LAN counts as remote (#74)
      expect(out, contains('  routes set: extraction'));

      // Jobs: totals by state (baseline plus the seed) and per kind/state except done.
      int count(String text, String state) =>
          int.parse(RegExp('$state (\\d+)').firstMatch(text.split('Jobs:').last)!.group(1)!);
      expect(count(out, 'queued') - count(baseline, 'queued'), 2);
      expect(count(out, 'running') - count(baseline, 'running'), 1);
      expect(count(out, 'done') - count(baseline, 'done'), 3);
      expect(count(out, 'failed') - count(baseline, 'failed'), 1);
      expect(out, contains('  diag.alpha         queued   2'));
      expect(out, contains('  diag.alpha         failed   1'));
      expect(out, contains('  diag.beta          running  1'));
      expect(out, isNot(contains('diag.gamma'))); // done only
      // The latest non-done job error, redacted.
      expect(out, contains('  last job error (diag.alpha): StateError: fetch <url> as <email> token=<secret>'));
    });

    test('a fresh profile says none for sources and providers', () async {
      final out = await h.runtime(diagnosticsCmd());
      expect(out, contains('Sources (active profile):\n  none'));
      expect(out, contains('AI providers:\n  none'));
      expect(out, contains('routes set: none'));
      expect(out, isNot(contains('last job error')));
    });

    test('a long source error is capped at 160 chars', () async {
      await h.runtime(_longErrorCmd());
      final line = (await h.runtime(diagnosticsCmd())).split('\n').singleWhere((l) => l.contains('error: '));
      final error = line.substring(line.indexOf('error: ') + 'error: '.length);
      expect(error, '${('word ' * 100).trim().substring(0, 160)}…');
    });

    test('a secret before an embedded LlmFailure is redacted in the report', () async {
      await h.runtime(_llmPrefixCmd());
      final out = await h.runtime(diagnosticsCmd());
      expect(out, contains('LlmFailure(429)'));
      expect(out, isNot(contains('bob@acme.com')));
      expect(out, isNot(contains('api.acme.internal')));
    }, skip: bugSkip);

    test('reports the pause flag', () async {
      await h.runtime(_pauseCmd());
      expect(await h.runtime(diagnosticsCmd()), contains('Collection paused: true'));
    });
  });

  group('diagnosticsReport', () {
    test('header, app facts, engine section and log lines in order', () {
      final r = diagnosticsReport(
        app: {'App': '1.2.3 (45)', 'OS': 'macos 15'},
        engine: 'Profiles: 1\n',
        logs: ['${ts(1)} INFO  ui a', '${ts(2)} INFO  engine b'],
        now: DateTime.utc(2026, 11, 20, 12),
      );
      expect(
        r,
        'Ant Manager diagnostics\n'
        'Generated: 2026-11-20T12:00:00.000Z\n'
        'App: 1.2.3 (45)\n'
        'OS: macos 15\n'
        '\n'
        'Profiles: 1\n'
        '\n'
        'Recent log (2 lines, oldest first):\n'
        '${ts(1)} INFO  ui a\n'
        '${ts(2)} INFO  engine b\n',
      );
    });
  });
}

const _leaks = [
  'Acme Hush Repo',
  'Bob Private Profile',
  'Work OpenRouter',
  'My Ollama',
  'acme/hush',
  'git.acme.internal',
  'api.github.com',
  'hooks.example.net',
  'openrouter.ai',
  '127.0.0.1',
  'localhost',
  '192.168.1.20',
  'bob@acme.com',
  'ghp_SECRET',
  'SECRETSECRET',
  'sk-or-v1',
  'deadbeef',
  'hunter2',
  'Anthropic said',
  'vendor/model-a',
  'llama3',
  'cred.ref',
  'private payload',
];

EngineCommand<void> _sourceErrorCmd(String error) => (rt) async {
  await rt.db.into(rt.db.sources).insert(SourcesCompanion.insert(id: 's-x', kind: SourceKind.github, name: 'n'));
  await rt.db.into(rt.db.syncCursors).insert(SyncCursorsCompanion.insert(sourceId: 's-x', lastError: Value(error)));
};

EngineCommand<void> _longErrorCmd() => _sourceErrorCmd('word ' * 100);

EngineCommand<void> _llmPrefixCmd() =>
    _sourceErrorCmd('sync for bob@acme.com via https://api.acme.internal/v1 failed: LlmFailure(429): slow down');

EngineCommand<void> _pauseCmd() => (rt) async => rt.paused = true;

/// Seeds the active profile and app DB with names, URLs and fake secrets the report must not show.
EngineCommand<void> _seedCmd() => (rt) async {
  final app = rt.appDb;
  final db = rt.db;
  await app.update(app.profiles).write(const ProfilesCompanion(name: Value('Bob Private Profile')));
  await rt.engine.ports.secrets.write('cred.ref.github', 'ghp_SECRETSECRET123456');

  // Sources: one per status, configs and errors full of secrets.
  Future<void> source(String id, SourceKind kind, {bool enabled = true}) =>
      db.into(db.sources).insert(SourcesCompanion.insert(
            id: id,
            kind: kind,
            name: 'Acme Hush Repo',
            config: const Value('{"repo":"acme/hush","url":"https://git.acme.internal/x","token":"hunter2"}'),
            credentialRef: const Value('cred.ref.github'),
            enabled: Value(enabled),
          ));
  await source('s-gh', SourceKind.github);
  await source('s-gl', SourceKind.gitlab);
  await source('s-jira', SourceKind.jira, enabled: false);
  await source('s-lin', SourceKind.linear);
  await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
        sourceId: 's-gh',
        lastError: const Value(
          'GET https://api.github.com/repos/acme/hush failed for bob@acme.com: Authorization: Bearer ghp_SECRETSECRET123456',
        ),
      ));
  await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
        sourceId: 's-gl',
        lastSuccessAt: Value(DateTime.utc(2026, 11, 19, 8, 30)),
      ));
  await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
        sourceId: 's-lin',
        lastError: const Value('LlmFailure(500): Anthropic said "private payload"'),
      ));

  // Providers: remote with a key in the URL, loopback by IP and by name, and a LAN host.
  Future<void> provider(String id, ProviderKind kind, String name, String url, ProviderProtocol protocol) =>
      app.into(app.providers).insert(ProvidersCompanion.insert(
            id: id,
            kind: kind,
            name: name,
            baseUrl: url,
            protocol: protocol,
            credentialRef: const Value('cred.ref.provider'),
            headers: const Value('{"X-Secret":"cred.ref.header"}'),
          ));
  await provider('p-or', ProviderKind.openrouter, 'Work OpenRouter',
      'https://bob:hunter2@openrouter.ai/api/v1?key=sk-or-v1-deadbeef', ProviderProtocol.openai);
  await provider('p-ol', ProviderKind.custom, 'My Ollama', 'http://127.0.0.1:11434', ProviderProtocol.ollama);
  await provider('p-lm', ProviderKind.custom, 'My Ollama', 'http://localhost:1234/v1', ProviderProtocol.openai);
  await provider('p-lan', ProviderKind.custom, 'My Ollama', 'http://192.168.1.20:8080/v1', ProviderProtocol.openai);
  await rt.engine.ports.secrets.write('cred.ref.provider', 'sk-or-v1-deadbeef');
  for (final (id, pid, name) in [('m1', 'p-or', 'vendor/model-a'), ('m2', 'p-or', 'vendor/model-b'), ('m3', 'p-ol', 'llama3')]) {
    await app.into(app.models).insert(ModelsCompanion.insert(id: id, providerId: pid, modelName: name));
  }
  await db.into(db.taskRoutes).insertOnConflictUpdate(
        TaskRoutesCompanion.insert(route: LlmRoute.extraction, modelId: const Value('m1')),
      );

  // Jobs: args and errors with secrets; the latest non-done error is the queued alpha one.
  var n = 0;
  Future<void> job(String kind, JobState state, DateTime runAfter, {String? error}) =>
      db.into(db.jobs).insert(JobsCompanion.insert(
            id: 'diag-job-${n++}',
            kind: kind,
            args: const Value('{"note":"private payload","url":"https://hooks.example.net/x"}'),
            lane: JobLane.io,
            state: state,
            runAfter: runAfter,
            createdAt: DateTime.utc(2026, 11, 20),
            lastError: Value(error),
          ));
  await job('diag.alpha', JobState.queued, DateTime.utc(2099));
  await job('diag.alpha', JobState.queued, DateTime.utc(2099, 1, 3),
      error: 'StateError: fetch https://hooks.example.net/x?y=1 as bob@acme.com token=hunter2');
  await job('diag.alpha', JobState.failed, DateTime.utc(2099, 1, 2), error: 'LlmFailure(401): Anthropic said "private payload"');
  await job('diag.beta', JobState.running, DateTime.utc(2099));
  for (var i = 0; i < 3; i++) {
    await job('diag.gamma', JobState.done, DateTime.utc(2099, 2), error: 'old error deadbeef');
  }
};
