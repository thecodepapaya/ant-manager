/// Independent tests (#99) for the diagnostic log (DECISIONS #126, LLD 04 §4.14): redact / errorSummary,
/// formatLogLine, the repeat limit, the null sink, and the job.* / sync.* / llm.* call sites.
/// Run known bugs with `dart test --run-skipped`.
library;

import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'sync/harness.dart';


class ListSink implements LogSink {
  final lines = <String>[];
  @override
  void write(String line) => lines.add(line);

  List<String> event(String name) => [for (final l in lines) if (_head.firstMatch(l)?.group(4) == name) l];
}

class ThrowingSink implements LogSink {
  @override
  void write(String line) => throw const FileSystemException('disk full');
}

/// `<ts> <LEVEL> <isolate> <event>` at the start of a line.
final _head = RegExp(r'^(\S+) +(INFO|WARN|ERROR) +(\S+) (\S+)');

/// `key=value` pairs after the event; quoted values are unquoted.
Map<String, String> fieldsOf(String line) {
  final rest = line.substring(_head.firstMatch(line)!.end);
  return {
    for (final m in RegExp(r' (\w+)=("[^"]*"|\S*)').allMatches(rest))
      m[1]!: m[2]!.startsWith('"') ? m[2]!.substring(1, m[2]!.length - 1) : m[2]!,
  };
}

var _n = 0;

/// A unique tag so the static repeat limiter never links two tests.
String uniq() => 'u${++_n}x${DateTime.now().microsecondsSinceEpoch}';

void main() {
  late ListSink sink;
  setUp(() {
    sink = ListSink();
    Log.sink = sink;
    Log.isolate = 'engine';
  });
  tearDown(() {
    Log.sink = null;
    Log.isolate = 'engine';
  });

  group('redact', () {
    test('URLs of any scheme', () {
      final r = redact('GET https://api.github.com/repos/acme/x?token=abc then ssh://git@host:22/r.git done');
      expect(r, 'GET <url> then <url> done');
    });

    test('emails', () {
      expect(redact('author bob.smith+tag@corp.example.co.uk pushed'), 'author <email> pushed');
    });

    test('Bearer and Basic credentials', () {
      final r = redact('sent Bearer abcDEF123456789xyz and basic dXNlcjpwYXNzd29yZA== ok');
      expect(r, 'sent <secret> and <secret> ok');
      expect(r, isNot(contains('abcDEF')));
      expect(r, isNot(contains('dXNl')));
    });

    test('key=, token:, secret, password and authorization pairs keep the key name only', () {
      final r = redact('api_key=k1 api-key=k2 apikey=k3 key=k4 token: t5, secret=s6; password = p7 auth=a8');
      for (final v in ['k1', 'k2', 'k3', 'k4', 't5', 's6', 'p7', 'a8']) {
        expect(r, isNot(contains(v)), reason: v);
      }
      expect(r, contains('api_key=<secret>'));
      expect(r, contains('token=<secret>'));
      expect(r, contains('password=<secret>'));
      expect(r, contains('auth=<secret>'));
    });

    test('Authorization header with a Bearer token', () {
      final r = redact('header Authorization: Bearer zzzzzzzz1234');
      expect(r, isNot(contains('zzzz')));
      expect(r, contains('<secret>'));
    });

    test('known token prefixes', () {
      const tokens = [
        'sk-or-v1-abc',
        'ghp_AbC123',
        'gho_x1',
        'ghu_x1',
        'ghs_x1',
        'github_pat_11ABC',
        'glpat-xyz9',
        'lin_api_q1',
        'xoxb-1-2',
        'xoxp-3-4',
        'AIzaSyX1',
        'ya29.a0Af',
      ];
      for (final t in tokens) {
        expect(redact('got $t here'), 'got <secret> here', reason: t);
      }
    });

    test('long key-like strings (32+ chars mixing letters and digits) but not short ids or plain words', () {
      expect(redact('id a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6 end'), 'id <secret> end');
      expect(redact('uuid 123e4567-e89b-12d3-a456-426614174000 end'), 'uuid <secret> end');
      // Short ids, 31-char mixes and long letter-only words survive.
      expect(redact('job abc123 failed'), 'job abc123 failed');
      expect(redact('x a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d y'), 'x a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d y');
      final word = 'a' * 40;
      expect(redact('w $word'), 'w $word');
    });

    test('absolute, home, relative and Windows paths', () {
      final r = redact(
        r'open /Users/bob/secret/file.txt failed, ~/notes/x.md and ./rel/p and ../up/z and C:\Users\bob\f.txt',
      );
      expect(r, 'open <path> failed, <path> and <path> and <path> and <path>');
    });

    test('a path after = or : or in parentheses', () {
      expect(redact('file=/etc/secret.conf'), 'file=<path>');
      expect(redact('at (/home/bob/app.dart:12)'), 'at (<path>)');
    });

    test('quoted text of every quote style', () {
      final r = redact('said "hello world" and \u2018single\u2019 and \u201ccurly\u201d and \'plain bit\'');
      expect(r, 'said "…" and "…" and "…" and "…"');
    });

    test('contractions are not treated as quotes', () {
      expect(redact("couldn't open, it's fine, don't retry"), "couldn't open, it's fine, don't retry");
      expect(redact("can't read 'notes.md' now"), "can't read \"…\" now");
    });

    test('everything from the first { is cut (JSON bodies)', () {
      expect(redact('HTTP 400 {"error": "bad key sk-123", "user": "bob"} trailing'), 'HTTP 400 {…}');
    });

    test('collapses whitespace onto one line', () {
      expect(redact('a\n  b\t\tc\r\nd'), 'a b c d');
    });

    test('caps the length at max with an ellipsis', () {
      final r = redact('x' * 300);
      expect(r.length, 241);
      expect(r, endsWith('…'));
      expect(redact('y' * 50, max: 10), '${'y' * 10}…');
      expect(redact('z' * 240), 'z' * 240);
    });

    test('a stored LlmFailure text keeps only LlmFailure(<status>)', () {
      expect(redact('LlmFailure(401): OpenRouter: invalid key sk-or-v1-abc'), 'LlmFailure(401)');
      expect(redact('LlmFailure(null): Model returned "secret output"'), 'LlmFailure(null)');
    });

    test('text before an embedded LlmFailure is still redacted', () {
      final r = redact('sync for bob@corp.com via https://api.example.com/v1 failed: LlmFailure(500): body');
      expect(r, isNot(contains('bob@corp.com')));
      expect(r, isNot(contains('api.example.com')));
      expect(r, isNot(contains('body')));
      expect(r, contains('LlmFailure(500)'));
    });
  });

  group('errorSummary', () {
    test('an LlmFailure is only its type and status', () {
      expect(errorSummary(LlmFailure('OpenRouter said {"error":"x"} for model acme/secret', statusCode: 429)),
          'LlmFailure(429)');
      expect(errorSummary(LlmFailure('Model output: my secret plan')), 'LlmFailure(-)');
    });

    test('an LlmFailure nested inside another error is reduced too', () {
      final s = errorSummary(StateError('job wrapped: LlmFailure(401): OpenRouter key rejected'));
      expect(s, startsWith('StateError'));
      expect(s, contains('LlmFailure(401)'));
      expect(s, isNot(contains('OpenRouter')));
      expect(s, isNot(contains('rejected')));
      final e = errorSummary(Exception('LlmFailure(503): Anthropic overloaded'));
      expect(e, contains('LlmFailure(503)'));
      expect(e, isNot(contains('Anthropic')));
    });

    test('type plus redacted message', () {
      final s = errorSummary(StateError('cannot read /Users/bob/private.txt for bob@x.com'));
      expect(s, 'StateError: Bad state: cannot read <path> for <email>');
    });

    test('drops the repeated Type: prefix', () {
      expect(errorSummary(const FormatException('bad json')), 'FormatException: bad json');
      expect(errorSummary(const FileSystemException('gone')), startsWith('FileSystemException: gone'));
    });

    test('an empty message leaves just the type', () {
      expect(errorSummary(_Silent()), '_Silent');
    });

    test('caps at 240 chars', () {
      final s = errorSummary(StateError('w ' * 400));
      expect(s.length, lessThanOrEqualTo('StateError: '.length + 241));
      expect(s, endsWith('…'));
    });
  });

  group('formatLogLine', () {
    test('millisecond UTC timestamp, padded level, isolate and event', () {
      expect(formatLogLine(DateTime.utc(2026, 11, 20, 10), LogLevel.info, 'engine', 'job.finish', {}),
          '2026-11-20T10:00:00.000Z INFO  engine job.finish');
      expect(formatLogLine(DateTime.utc(2026, 11, 20, 10, 0, 0, 123, 999), LogLevel.error, 'ui', 'x', {}),
          '2026-11-20T10:00:00.123Z ERROR ui x');
      expect(formatLogLine(DateTime.utc(2026, 1, 2, 3, 4, 5), LogLevel.warn, 'ui', 'x', {}),
          '2026-01-02T03:04:05.000Z WARN  ui x');
    });

    test('a local time is written in UTC', () {
      final local = DateTime.utc(2026, 11, 20, 10).toLocal();
      expect(formatLogLine(local, LogLevel.info, 'ui', 'x', {}), startsWith('2026-11-20T10:00:00.000Z '));
    });

    test('timestamps sort as text in time order', () {
      final a = formatLogLine(DateTime.utc(2026, 11, 20, 10, 0, 0, 900), LogLevel.info, 'ui', 'x', {});
      final b = formatLogLine(DateTime.utc(2026, 11, 20, 10, 0, 1), LogLevel.info, 'ui', 'x', {});
      expect(a.compareTo(b), lessThan(0));
    });

    test('values: numbers, bools, enums, durations, null skipped, quoting', () {
      final line = formatLogLine(DateTime.utc(2026), LogLevel.info, 'engine', 'e', {
        'n': 3,
        'f': 1.5,
        'b': false,
        'skip': null,
        'route': LlmRoute.vision,
        'lane': JobLane.llm,
        'took': const Duration(seconds: 2, milliseconds: 5),
        'plain': 'abc',
        'spaced': 'two words',
        'empty': '',
      });
      expect(line,
          '2026-01-01T00:00:00.000Z INFO  engine e n=3 f=1.5 b=false route=vision lane=llm took=2005 plain=abc spaced="two words" empty=""');
    });

    test('string values are redacted and inner double quotes cannot break the quoting', () {
      final line = formatLogLine(DateTime.utc(2026), LogLevel.info, 'engine', 'e', {
        'msg': 'push to https://github.com/acme/secret by bob@acme.com',
        'q': 'say "hi" now',
      });
      expect(line, contains('msg="push to <url> by <email>"'));
      expect(line, contains('q="say \'…\' now"'));
      expect(line, isNot(contains('github.com')));
    });

    test('a multi-line value stays on one line', () {
      final line = formatLogLine(DateTime.utc(2026), LogLevel.info, 'engine', 'e', {'m': 'a\nb'});
      expect(line, isNot(contains('\n')));
      expect(line, endsWith('m="a b"'));
    });
  });

  group('Log', () {
    test('info/warn/error write one formatted line tagged with the isolate', () {
      final t = uniq();
      Log.isolate = 'ui';
      Log.info('a.info', {'t': t, 'n': 1});
      Log.warn('a.warn', {'t': t});
      Log.error('a.error', StateError('bad /tmp/x'), null, {'t': t});
      expect(sink.lines, hasLength(3));
      expect(sink.lines[0], matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z INFO  ui a\.info t=\S+ n=1$')));
      expect(sink.lines[1], matches(RegExp(r'^\S+ WARN  ui a\.warn t=\S+$')));
      expect(sink.lines[2], contains(' ERROR ui a.error t=$t error="StateError: Bad state: bad <path>"'));
    });

    test('error adds a redacted stack summary of the top 6 frames', () {
      final t = uniq();
      final stack = StackTrace.fromString([
        for (var i = 0; i < 10; i++) '#$i      frame$i (file:///Users/bob/app/lib/f$i.dart:1:2)',
      ].join('\n'));
      Log.error('a.stack', StateError('x'), stack, {'t': t});
      final line = sink.lines.single;
      expect(line, contains('frame0'));
      expect(line, contains('frame5'));
      expect(line, isNot(contains('frame6')));
      expect(line, isNot(contains('/Users/bob')));
      expect(line, isNot(contains('#0')));
    });

    test('nothing is written and nothing throws when the sink is null', () {
      final t = uniq();
      Log.sink = null;
      Log.info('null.info', {'t': t});
      Log.warn('null.warn', {'t': t});
      Log.error('null.error', StateError('x'), StackTrace.current, {'t': t});
      expect(sink.lines, isEmpty);
      // A dropped warning does not count against the repeat limit once a sink is set.
      Log.sink = sink;
      Log.warn('null.warn', {'t': t});
      expect(sink.lines, hasLength(1));
      expect(sink.lines.single, isNot(contains('repeated')));
    });

    test('an error whose toString throws never breaks the caller', () {
      expect(() => Log.error('t.badtostring.${uniq()}', _BadToString()), returnsNormally);
    });

    test('a throwing sink never breaks the caller', () {
      Log.sink = ThrowingSink();
      expect(() => Log.info('t.info'), returnsNormally);
      expect(() => Log.error('t.err', StateError(uniq())), returnsNormally);
    });
  });

  group('repeat limit (10 min)', () {
    test('the window is 10 minutes', () {
      expect(Log.repeatWindow, const Duration(minutes: 10));
    });

    test('a repeated warning with the same event and fields is written once', () {
      final t = uniq();
      for (var i = 0; i < 5; i++) {
        Log.warn('rep.warn', {'t': t});
      }
      expect(sink.lines, hasLength(1));
    });

    test('a repeated error is written once even when ms and stack differ', () {
      final t = uniq();
      Log.error('rep.err', StateError('down $t'), StackTrace.fromString('#0 a (x.dart:1)'), {'ms': 1});
      Log.error('rep.err', StateError('down $t'), StackTrace.fromString('#0 b (y.dart:2)'), {'ms': 999});
      expect(sink.lines, hasLength(1));
    });

    test('a different field value, error or event is written', () {
      final t = uniq();
      Log.warn('rep.diff', {'t': t, 'kind': 'a'});
      Log.warn('rep.diff', {'t': t, 'kind': 'b'});
      Log.warn('rep.diff2', {'t': t, 'kind': 'a'});
      Log.error('rep.diff3', StateError('one $t'));
      Log.error('rep.diff3', StateError('two $t'));
      expect(sink.lines, hasLength(5));
    });

    test('warn and error with the same event and fields are limited separately', () {
      final t = uniq();
      // Same event and identical fields (error= included): only the level differs.
      Log.warn('rep.level', {'t': t, 'error': 'StateError: Bad state: x'});
      Log.error('rep.level', StateError('x'), null, {'t': t});
      expect(fieldsOf(sink.lines[0]), fieldsOf(sink.lines[1]));
      expect(sink.event('rep.level'), hasLength(2));
      expect(sink.lines, hasLength(2));
    });

    test('info lines are never limited', () {
      final t = uniq();
      for (var i = 0; i < 4; i++) {
        Log.info('rep.info', {'t': t});
      }
      expect(sink.lines, hasLength(4));
      expect(sink.lines.any((l) => l.contains('repeated')), isFalse);
    });

    // `repeated=<n>` on the first line after the window can't be checked: Log reads DateTime.now() and has
    // no injectable clock, so the 10-minute window can't elapse in a test.
  });

  group('job.* lines', () {
    late ProfileDb db;
    late TestClock clock;
    late JobQueue q;
    setUp(() {
      db = ProfileDb(NativeDatabase.memory());
      clock = TestClock(DateTime.utc(2026, 11, 20, 9));
      q = JobQueue(db, clock: clock);
    });
    tearDown(() => db.close());

    test('start and finish carry kind, lane, attempt and ms, and never the args', () async {
      final kind = 'diag.ok.${uniq()}';
      q.register(kind, JobLane.llm, (_) async {});
      await q.enqueue(kind, args: {'note': 'secret note text', 'path': '/Users/bob/x'});
      expect(await q.runOne(JobLane.llm), isTrue);

      final start = sink.event('job.start').single;
      expect(fieldsOf(start), {'kind': kind, 'lane': 'llm', 'attempt': '1'});
      expect(start, contains(' INFO  engine job.start '));
      final finish = sink.event('job.finish').single;
      expect(fieldsOf(finish).keys, ['kind', 'ms']);
      expect(fieldsOf(finish)['kind'], kind);
      expect(int.parse(fieldsOf(finish)['ms']!), greaterThanOrEqualTo(0));
      expect(sink.lines.join('\n'), isNot(contains('secret note')));
      expect(sink.lines.join('\n'), isNot(contains('/Users/bob')));
    });

    test('a failure logs a redacted error, the attempt and retry', () async {
      final kind = 'diag.fail.${uniq()}';
      q.register(kind, JobLane.io, (_) async => throw StateError('fetch https://api.x.com/u?token=abc as bob@x.com'));
      await q.enqueue(kind);
      await q.runOne(JobLane.io);

      final line = sink.event('job.fail').single;
      expect(line, contains(' ERROR engine job.fail '));
      expect(line, contains('kind=$kind'));
      expect(line, contains('attempt=1'));
      expect(line, contains('next=retry'));
      expect(line, contains(RegExp(r' ms=\d+')));
      expect(line, contains('error="StateError: Bad state: fetch <url> as <email>"'));
      expect(line, contains('stack='));
      expect(line, isNot(contains('api.x.com')));
      expect(line, isNot(contains('bob@x.com')));
      expect(sink.event('job.finish'), isEmpty);
    });

    test('the last allowed attempt logs gave_up', () async {
      final kind = 'diag.giveup.${uniq()}';
      q.register(kind, JobLane.io, (_) async => throw StateError('nope'));
      final id = await q.enqueue(kind);
      await (db.update(db.jobs)..where((j) => j.id.equals(id)))
          .write(JobsCompanion(attempts: Value(JobQueue.backoff.length)));
      await q.runOne(JobLane.io);

      final line = sink.event('job.fail').single;
      expect(line, contains('attempt=${JobQueue.backoff.length + 1}'));
      expect(line, contains('next=gave_up'));
      expect(fieldsOf(sink.event('job.start').single)['attempt'], '${JobQueue.backoff.length + 1}');
    });

    test('an LlmFailure from a job is logged as type and status only', () async {
      final kind = 'diag.llm.${uniq()}';
      q.register(kind, JobLane.llm, (_) async => throw LlmFailure('OpenRouter: "my private prompt"', statusCode: 402));
      await q.enqueue(kind);
      await q.runOne(JobLane.llm);
      final line = sink.event('job.fail').single;
      expect(line, contains('error=LlmFailure(402)'));
      expect(line, isNot(contains('OpenRouter')));
      expect(line, isNot(contains('private')));
    });

    test('no sink: jobs still run and fail normally', () async {
      Log.sink = null;
      final ok = 'diag.nosink.${uniq()}';
      final bad = 'diag.nosinkbad.${uniq()}';
      var ran = false;
      q.register(ok, JobLane.io, (_) async => ran = true);
      q.register(bad, JobLane.io, (_) async => throw StateError('x'));
      await q.enqueue(ok);
      await q.runOne(JobLane.io);
      clock.t = clock.t.add(const Duration(seconds: 1));
      await q.enqueue(bad);
      await q.runOne(JobLane.io);
      expect(ran, isTrue);
      expect((await db.select(db.jobs).get()).map((j) => j.state).toSet(), {JobState.done, JobState.queued});
      expect(sink.lines, isEmpty);
    });
  });

  group('sync.* lines', () {
    late Harness h;
    setUp(() => h = Harness.create());
    tearDown(() => h.db.close());

    Future<void> addSource(String id, SourceKind kind) => h.db.into(h.db.sources).insert(SourcesCompanion.insert(
          id: id,
          kind: kind,
          name: 'Acme Secret Project',
          config: const Value('{"repo":"acme/hidden","url":"https://git.acme.internal/x"}'),
        ));

    test('sync.ok carries source id, kind, ms and the ingest counts, not the source name', () async {
      final id = 'src-${uniq()}';
      h.engine.sources.register(
        SourceKind.github,
        () => ScriptSource(SourceKind.github, (ctx) async* {
          yield obs('a', content: {'body': 'private commit message'});
          yield obs('b');
        }),
      );
      await addSource(id, SourceKind.github);
      await h.service().syncSource(id);

      final line = sink.event('sync.ok').single;
      expect(fieldsOf(line), {
        'source': id,
        'kind': 'github',
        'ms': fieldsOf(line)['ms'],
        'created': '2',
        'updated': '0',
        'tombstoned': '0',
        'unchanged': '0',
      });
      expect(int.parse(fieldsOf(line)['ms']!), greaterThanOrEqualTo(0));
      final all = sink.lines.join('\n');
      expect(all, isNot(contains('Acme')));
      expect(all, isNot(contains('acme')));
      expect(all, isNot(contains('private commit')));
    });

    test('a second sync counts unchanged payloads', () async {
      final id = 'src-${uniq()}';
      h.engine.sources.register(
        SourceKind.gitlab,
        () => ScriptSource(SourceKind.gitlab, (ctx) async* {
          yield obs('a');
        }),
      );
      await addSource(id, SourceKind.gitlab);
      final s = h.service();
      await s.syncSource(id);
      await s.syncSource(id);
      final lines = sink.event('sync.ok');
      expect(lines, hasLength(2));
      expect(fieldsOf(lines[1])['created'], '0');
      expect(fieldsOf(lines[1])['unchanged'], '1');
    });

    test('sync.fail carries source id, kind, ms and a redacted error', () async {
      final id = 'src-${uniq()}';
      h.engine.sources.register(
        SourceKind.jira,
        () => ScriptSource(SourceKind.jira, (ctx) async* {
          throw StateError('401 from https://acme.atlassian.net/rest?x=1 Authorization: Bearer abcdefghijkl1234');
        }),
      );
      await addSource(id, SourceKind.jira);
      await expectLater(h.service().syncSource(id), throwsStateError);

      final line = sink.event('sync.fail').single;
      expect(line, contains(' ERROR engine sync.fail '));
      expect(line, contains('source=$id'));
      expect(line, contains('kind=jira'));
      expect(line, contains(RegExp(r' ms=\d+')));
      expect(line, contains('error="StateError: Bad state: 401 from <url>'));
      expect(line, isNot(contains('atlassian')));
      expect(line, isNot(contains('abcdefghijkl1234')));
      expect(sink.event('sync.ok'), isEmpty);
    });
  });

  group('llm.* lines', () {
    StructuredOutput out(LlmClient client, {String model = 'vendor/model-x', String? host = 'openrouter.ai'}) =>
        StructuredOutput(_Router(ResolvedModel(
          client: client,
          modelName: model,
          info: ModelInfo(name: model),
          providerKind: ProviderKind.openrouter,
          host: host,
        )));
    const schema = <String, Object?>{
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
      'required': ['name'],
    };
    const prompt = 'SECRET SYSTEM PROMPT';
    const userText = 'my private user content';

    test('llm.ok carries route, provider kind, host, model, ms and tokens, never prompt or output', () async {
      final model = 'vendor/model-${uniq()}';
      final r = await out(_Client(done: LlmDone(text: '{"name":"PRIVATE OUTPUT"}', inputTokens: 120, outputTokens: 7)),
              model: model)
          .call(LlmRoute.extraction, system: prompt, user: userText, schema: schema);
      expect(r['name'], 'PRIVATE OUTPUT');

      final line = sink.event('llm.ok').single;
      final f = fieldsOf(line);
      expect(f['route'], 'extraction');
      expect(f['provider'], 'openrouter');
      expect(f['host'], 'openrouter.ai');
      expect(f['model'], model);
      expect(f['in_tokens'], '120');
      expect(f['out_tokens'], '7');
      expect(int.parse(f['ms']!), greaterThanOrEqualTo(0));
      expect(line, isNot(contains('SECRET')));
      expect(line, isNot(contains('private')));
      expect(line, isNot(contains('PRIVATE')));
    });

    test('missing token counts are skipped', () async {
      await out(_Client(done: LlmDone(text: '{"name":"x"}')), model: 'm-${uniq()}')
          .call(LlmRoute.reports, system: 's', user: 'u', schema: schema);
      final f = fieldsOf(sink.event('llm.ok').single);
      expect(f.containsKey('in_tokens'), isFalse);
      expect(f.containsKey('out_tokens'), isFalse);
    });

    test('an HTTP failure logs type and status only, with the status field', () async {
      final model = 'vendor/fail-${uniq()}';
      await expectLater(
        out(_Client(error: LlmFailure('OpenRouter: invalid key sk-or-v1-deadbeef "$userText"', statusCode: 401)),
                model: model)
            .call(LlmRoute.vision, system: prompt, user: userText, schema: schema),
        throwsA(isA<LlmFailure>()),
      );
      final line = sink.event('llm.fail').single;
      expect(line, contains(' ERROR engine llm.fail '));
      final f = fieldsOf(line);
      expect(f['error'], 'LlmFailure(401)');
      expect(f['status'], '401');
      expect(f['route'], 'vision');
      expect(f['provider'], 'openrouter');
      expect(f['host'], 'openrouter.ai');
      expect(f['model'], model);
      expect(line, isNot(contains('OpenRouter')));
      expect(line, isNot(contains('deadbeef')));
      expect(line, isNot(contains('private')));
      expect(sink.event('llm.ok'), isEmpty);
    });

    test('invalid model output is logged without the output text', () async {
      await expectLater(
        out(_Client(done: LlmDone(text: 'not json: PRIVATE OUTPUT')), model: 'vendor/bad-${uniq()}')
            .call(LlmRoute.extraction, system: prompt, user: userText, schema: schema),
        throwsA(isA<LlmFailure>()),
      );
      final line = sink.event('llm.fail').single;
      expect(fieldsOf(line)['error'], 'LlmFailure(-)');
      expect(fieldsOf(line).containsKey('status'), isFalse);
      expect(line, isNot(contains('PRIVATE')));
      expect(line, isNot(contains('json')));
    });

    test('a transport exception is wrapped and logged as LlmFailure(-), without its text', () async {
      await expectLater(
        out(_Client(error: const SocketException('connect to https://10.0.0.5/v1 failed')), model: 'vendor/net-${uniq()}')
            .call(LlmRoute.defaultRoute, system: prompt, user: userText, schema: schema),
        throwsA(isA<LlmFailure>()),
      );
      final line = sink.event('llm.fail').single;
      expect(fieldsOf(line)['error'], 'LlmFailure(-)');
      expect(line, isNot(contains('10.0.0.5')));
      expect(line, isNot(contains('connect')));
    });

    test('a route with no model logs llm.fail without provider, host or model', () async {
      final route = LlmRoute.reports;
      await expectLater(
        StructuredOutput(_Router(null, failure: LlmFailure('No model for route ${uniq()}')))
            .call(route, system: prompt, user: userText, schema: schema),
        throwsA(isA<LlmFailure>()),
      );
      final f = fieldsOf(sink.event('llm.fail').single);
      expect(f['route'], 'reports');
      expect(f.containsKey('provider'), isFalse);
      expect(f.containsKey('host'), isFalse);
      expect(f.containsKey('model'), isFalse);
    });
  });
}

class _BadToString {
  @override
  String toString() => throw StateError('toString failed');
}

class _Silent implements Exception {
  @override
  String toString() => '';
}

class _Router implements ModelRouter {
  _Router(this.model, {this.failure});
  final ResolvedModel? model;
  final LlmFailure? failure;
  @override
  Future<ResolvedModel> resolve(LlmRoute route) async => model ?? (throw failure!);
}

class _Client implements LlmClient {
  _Client({this.done, this.error});
  final LlmDone? done;
  final Object? error;
  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;
  @override
  Future<List<ModelInfo>> listModels() async => const [];
  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    if (error != null) throw error!;
    yield LlmDelta(done!.text);
    yield done!;
  }
}
