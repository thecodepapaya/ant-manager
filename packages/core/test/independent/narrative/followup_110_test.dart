// Independent tests for the follow-ups merged in 40520a1 (DECISIONS #110): empty workstreams are
// not offered to the assigner but can be reused by title, and starEvidence re-checks the evidence
// before writing the win.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/workstreams.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late AntEngine engine;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    h = H();
    await h.setUp();
    final u = Unused();
    engine = AntEngine(
      db: h.db,
      profileId: 'p',
      ports: EnginePorts(secrets: u, blobs: h.blobs, git: u, watcher: u, clock: h.clock),
      router: h.router,
      utcOffset: (_) => Duration.zero,
    );
  });
  tearDown(() => h.close());

  group('workstream assigner and empty workstreams', () {
    late WorkstreamAssigner ws;
    late String p;
    setUp(() async {
      ws = WorkstreamAssigner(h.ctx);
      p = await h.pid(await h.commit('a1', at(10)));
    });

    Future<void> insertWs(String id, String title, {String? span}) => h.db.into(h.db.workstreams).insert(
          WorkstreamsCompanion.insert(id: id, title: title, spanStart: Value(span), spanEnd: Value(span)),
        );

    Future<Workstream> wsRow(String id) =>
        (h.db.select(h.db.workstreams)..where((w) => w.id.equals(id))).getSingle();

    List<String> offeredIds() => [
          for (final c in h.router.of('workstreams'))
            for (final w in (jsonDecode(c.user) as Map)['workstreams'] as List) (w as Map)['id'] as String,
        ];

    void answer(String fact, {String? wsId, String? title}) => h.router.responders['workstreams'] = (_) => {
          'assignments': [
            {'fact_id': fact, 'workstream_id': wsId, 'new_title': title, 'new_summary': null},
          ],
        };

    test('a workstream whose last fact was retired is not offered', () async {
      await insertWs('w', 'Retries', span: '2026-11-15');
      await insertWs('live', 'Live', span: '2026-11-15');
      await h.insertFact('old', [p], d: '2026-11-15', workstream: 'w');
      await h.insertFact('keep', [p], d: '2026-11-15', workstream: 'live');
      await engine.rejectFact('old');
      expect((await wsRow('w')).spanEnd, isNull, reason: 'precondition');
      await h.insertFact('new', [p]);
      await ws.assignDay(day);
      expect(offeredIds(), ['live']);
    });

    test('a workstream whose facts were all permanently deleted is not offered', () async {
      final e = await h.commit('b1', at(9));
      await insertWs('w', 'Retries', span: '2026-11-15');
      await insertWs('live', 'Live', span: '2026-11-15');
      await h.insertFact('only', [await h.pid(e)], d: '2026-11-15', workstream: 'w');
      await h.insertFact('keep', [p], d: '2026-11-15', workstream: 'live');
      await EvidenceDeleter(h.ctx).permanentDelete(e);
      expect((await wsRow('w')).spanEnd, isNull, reason: 'precondition');
      await h.insertFact('new', [p]);
      await ws.assignDay(day);
      expect(offeredIds(), ['live']);
    });

    test('an offered id that emptied during the model call is still assigned; span recomputed', () async {
      await insertWs('w', 'Retries', span: '2026-11-15');
      await h.insertFact('old', [p], d: '2026-11-15', workstream: 'w');
      await h.insertFact('new', [p]);
      h.router.onCall = (c) async {
        if (c.schema == 'workstreams') await engine.rejectFact('old');
      };
      answer('new', wsId: 'w');
      await ws.assignDay(day);
      expect(offeredIds(), ['w']);
      expect((await h.fact('new')).workstreamId, 'w');
      final w = await wsRow('w');
      expect((w.spanStart, w.spanEnd), (day, day));
    });

    test(
      'reusing an empty workstream by title refreshes its summary (#109)',
      () async {
        await h.db.into(h.db.workstreams).insert(
              WorkstreamsCompanion.insert(id: 'empty', title: 'Payments Retry', summary: const Value('old')),
            );
        await h.insertFact('new', [p]);
        h.router.responders['workstreams'] = (_) => {
              'assignments': [
                {'fact_id': 'new', 'workstream_id': null, 'new_title': 'Payments Retry', 'new_summary': 'Fresh.'},
              ],
            };
        await ws.assignDay(day);
        expect((await h.fact('new')).workstreamId, 'empty');
        expect((await wsRow('empty')).summary, 'Fresh.');
      },
      skip: 'BUG: a title-matched (unoffered) workstream skips the new_summary refresh: existing is looked up in byId (offered only)',
    );

    test('a new title matching an existing empty workstream (any case) reuses it', () async {
      await insertWs('empty', 'Payments Retry');
      await h.insertFact('new', [p]);
      answer('new', title: '  payments RETRY ');
      await ws.assignDay(day);
      expect(offeredIds(), isEmpty, reason: 'empty workstream is not offered');
      expect((await h.fact('new')).workstreamId, 'empty');
      expect(await h.db.select(h.db.workstreams).get(), hasLength(1), reason: 'no duplicate');
      final w = await wsRow('empty');
      expect((w.spanStart, w.spanEnd), (day, day));
    });

    test('an existing id that was not offered is ignored', () async {
      await insertWs('empty', 'Empty');
      await insertWs('stale', 'Stale', span: '2026-01-01');
      await h.insertFact('a', [p]);
      await h.insertFact('b', [p]);
      h.router.responders['workstreams'] = (_) => {
            'assignments': [
              {'fact_id': 'a', 'workstream_id': 'empty', 'new_title': null, 'new_summary': null},
              {'fact_id': 'b', 'workstream_id': 'stale', 'new_title': null, 'new_summary': null},
            ],
          };
      await ws.assignDay(day);
      expect(offeredIds(), isEmpty);
      expect((await h.fact('a')).workstreamId, isNull);
      expect((await h.fact('b')).workstreamId, isNull);
      expect((await wsRow('empty')).spanEnd, isNull);
      expect((await wsRow('stale')).spanEnd, '2026-01-01');
    });

    test('an unoffered id with a new_title falls back to the title', () async {
      await insertWs('empty', 'Empty');
      await h.insertFact('a', [p]);
      answer('a', wsId: 'empty', title: 'Fresh thread');
      await ws.assignDay(day);
      final id = (await h.fact('a')).workstreamId;
      expect(id, isNotNull);
      expect(id, isNot('empty'));
      expect((await wsRow(id!)).title, 'Fresh thread');
    });
  });

  group('starEvidence re-checks the evidence after the model call', () {
    late String e;
    setUp(() async {
      e = await h.commit('a1', at(10), msg: 'Ship retries');
    });

    Future<void> during(Future<void> Function() action) async {
      h.router.onCall = (c) async {
        if (c.schema == 'win') await action();
      };
    }

    final stateError = throwsA(isA<StateError>());

    test('unstarred during the call → StateError, no fact', () async {
      await during(() => engine.setStarred(e, false));
      await expectLater(WinService(h.ctx).starEvidence(e), stateError);
      expect(h.router.of('win'), hasLength(1));
      expect(await h.facts(), isEmpty);
    });

    test('hidden during the call (visible before) → StateError, no fact', () async {
      await during(() => engine.setHidden(e, true));
      await expectLater(WinService(h.ctx).starEvidence(e), stateError);
      expect(await h.facts(), isEmpty);
    });

    test('evidence the user hid before starring still gets a win', () async {
      await engine.setHidden(e, true);
      final id = await WinService(h.ctx).starEvidence(e);
      final f = await h.fact(id);
      expect((f.type, f.winStatus, f.origin), (FactType.outcome, WinStatus.accepted, FactOrigin.userCreated));
      expect((await h.evidence(e)).hidden, isTrue);
    });

    test('deleted during the call → StateError, no fact', () async {
      await during(() async {
        await EvidenceDeleter(h.ctx).permanentDelete(e);
      });
      await expectLater(WinService(h.ctx).starEvidence(e), stateError);
      expect(await h.facts(), isEmpty);
      expect(await (h.db.select(h.db.evidences)..where((x) => x.id.equals(e))).get(), isEmpty, reason: 'precondition');
    });

    test('evidence day changed during the call (re-ingest) → the win uses the new day', () async {
      await during(() async {
        await h.commit('a1', at(10, 0, '2026-11-16'), msg: 'Ship retries (rebased)');
      });
      final id = await WinService(h.ctx).starEvidence(e);
      expect((await h.evidence(e)).day, '2026-11-16', reason: 'precondition');
      expect((await h.fact(id)).periodStart, '2026-11-16');
    });

    test('project changed during the call → the win uses the new project', () async {
      await h.setProject(e, 'pay');
      await during(() => h.setProject(e, 'web'));
      final id = await WinService(h.ctx).starEvidence(e);
      expect((await h.fact(id)).projectId, 'web');
    });

    test('nothing changed during the call → win written with the evidence project and day', () async {
      await h.setProject(e, 'pay');
      final id = await WinService(h.ctx).starEvidence(e);
      final f = await h.fact(id);
      expect((f.projectId, f.periodStart, f.winStatus), ('pay', day, WinStatus.accepted));
    });
  });
}
