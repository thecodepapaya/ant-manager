import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness.create());
  tearDown(() => h.db.close());

  ScriptSource register(SyncScript script, {SourceKind kind = SourceKind.github}) {
    final s = ScriptSource(kind, script);
    h.engine.sources.register(kind, () => s);
    return s;
  }

  group('batches and cursors (claim 1)', () {
    test('ingests everything and sums the counts across batches', () async {
      register((ctx) async* {
        for (var i = 0; i < 5; i++) {
          yield obs('o$i');
        }
      });
      await h.addRow('s', SourceKind.github);
      final r = await h.service(batchSize: 2).syncSource('s');
      expect(r.created, 5);
      expect(r.updated + r.unchanged + r.tombstoned, 0);
      expect(await h.externalIds('s'), ['o0', 'o1', 'o2', 'o3', 'o4']);
    });

    test('cursor set after the last observation is committed by the final flush', () async {
      register((ctx) async* {
        yield obs('a');
        yield obs('b');
        ctx.setCursor('page', 'end');
      });
      await h.addRow('s', SourceKind.github);
      await h.service(batchSize: 2).syncSource('s'); // batch fills exactly at 'b'
      expect((await h.cursorMap('s'))['page'], 'end');
    });

    test('cursors are committed even with zero observations', () async {
      register((ctx) async* {
        ctx.setCursor('since', '2026-11-18');
        ctx.setCursor('other', 'x');
      });
      await h.addRow('s', SourceKind.github);
      final r = await h.service().syncSource('s');
      expect(r.created, 0);
      expect(await h.cursorMap('s'), containsPair('since', '2026-11-18'));
      expect(await h.cursorMap('s'), containsPair('other', 'x'));
    });

    test('a staged cursor is visible to the source before commit, a committed one on the next run', () async {
      final seen = <String?>[];
      register((ctx) async* {
        seen.add(await ctx.cursor('c'));
        ctx.setCursor('c', 'v${seen.length}');
        seen.add(await ctx.cursor('c'));
      });
      await h.addRow('s', SourceKind.github);
      final svc = h.service();
      await svc.syncSource('s');
      await svc.syncSource('s');
      expect(seen, [null, 'v1', 'v1', 'v3']);
    });

    test('cursor update overwrites the previous value for the same scope', () async {
      var v = 'one';
      register((ctx) async* {
        ctx.setCursor('c', v);
      });
      await h.addRow('s', SourceKind.github);
      final svc = h.service();
      await svc.syncSource('s');
      v = 'two';
      await svc.syncSource('s');
      final rows = (await h.cursors('s')).where((c) => c.scope == 'c').toList();
      expect(rows, hasLength(1));
      expect(rows.single.cursor, 'two');
    });

    test('a staged cursor in an unflushed batch is not committed when the stream fails', () async {
      register((ctx) async* {
        yield obs('a');
        ctx.setCursor('c', 'after-a');
        throw StateError('boom');
      });
      await h.addRow('s', SourceKind.github);
      await expectLater(h.service(batchSize: 10).syncSource('s'), throwsStateError);
      expect(await h.externalIds('s'), isEmpty, reason: 'partial batch is not flushed');
      expect((await h.cursorMap('s')).containsKey('c'), isFalse);
    });

    test('a batch whose ingest fails rolls back its observations and its cursors together', () async {
      register((ctx) async* {
        yield obs('a');
        ctx.setCursor('c', 'b1');
        yield obs('b');
        // Batch 2: first observation is fine, the second can't be encoded -> ingest throws mid-batch.
        yield obs('c');
        ctx.setCursor('c', 'b2');
        yield obs('d', content: {'bad': Object()});
      });
      await h.addRow('s', SourceKind.github);
      await expectLater(h.service(batchSize: 2).syncSource('s'), throwsA(isA<JsonUnsupportedObjectError>()));
      expect(await h.externalIds('s'), ['a', 'b'], reason: "'c' was in the failed batch");
      expect((await h.cursorMap('s'))['c'], 'b1');
      expect((await h.status('s'))!.lastError, contains('Converting object'));
    });
  });

  group('mid-sync failure (claim 2)', () {
    Stream<PayloadObservation> failing(SourceContext ctx, {required bool fail}) async* {
      final start = int.parse(await ctx.cursor('n') ?? '0');
      for (var i = start; i < 6; i++) {
        if (fail && i == 3) throw StateError('network down');
        yield obs('o$i');
        ctx.setCursor('n', '${i + 1}');
      }
    }

    test('earlier batches stay committed, lastError recorded, lastSuccessAt untouched, error rethrown', () async {
      var fail = false;
      register((ctx) => failing(ctx, fail: fail));
      await h.addRow('s', SourceKind.github);
      final svc = h.service(batchSize: 2);

      await svc.syncSource('s'); // first a clean run, so lastSuccessAt exists
      final firstSuccess = (await h.status('s'))!.lastSuccessAt;
      expect(firstSuccess, isNotNull);

      // Reset items and cursor so the second run starts at 0 again.
      await h.db.delete(h.db.payloadRevisions).go();
      await h.db.delete(h.db.payloads).go();
      await (h.db.delete(h.db.syncCursors)..where((c) => c.scope.equals('n'))).go();

      h.clock.t = h.clock.t.add(const Duration(hours: 1));
      fail = true;
      await expectLater(svc.syncSource('s'), throwsA(isA<StateError>()));

      // Batches: [o0,o1] committed with cursor n=1 (n=2 was set after the yield of o1, i.e. after the flush).
      // o2 was in the unflushed second batch, so it and n=2/n=3 are lost; the re-run resumes from o1.
      expect(await h.externalIds('s'), ['o0', 'o1']);
      expect((await h.cursorMap('s'))['n'], '1');

      final st = (await h.status('s'))!;
      expect(st.lastError, contains('network down'));
      expect(st.lastSuccessAt!.isAtSameMomentAs(firstSuccess!), isTrue);
    });

    test('re-run after failure is idempotent: earlier items come back unchanged, rest created', () async {
      var fail = true;
      // Ignore cursors so the re-run re-yields everything.
      register((ctx) async* {
        for (var i = 0; i < 6; i++) {
          if (fail && i == 3) throw StateError('x');
          yield obs('o$i');
        }
      });
      await h.addRow('s', SourceKind.github);
      final svc = h.service(batchSize: 2);
      await expectLater(svc.syncSource('s'), throwsStateError);
      final committed = (await h.externalIds('s')).length;
      final revsBefore = (await h.db.select(h.db.payloadRevisions).get()).length;
      expect(committed, 2);

      fail = false;
      final r = await svc.syncSource('s');
      expect(r.unchanged, committed);
      expect(r.created, 6 - committed);
      expect(r.updated, 0);
      expect((await h.db.select(h.db.payloadRevisions).get()).length, revsBefore + (6 - committed));
      final st = (await h.status('s'))!;
      expect(st.lastError, isNull);
      expect(st.lastSuccessAt, isNotNull);
    });

    test('a cursor staged after a batch fills is not committed with that batch (no data skipped on resume)',
        () async {
      // o0,o1 fill batch 1; the source then stages cursor "through o2" before yielding o2 and failing.
      register((ctx) async* {
        yield obs('o0');
        yield obs('o1');
        ctx.setCursor('n', 'through-o2');
        yield obs('o2');
        throw StateError('fail');
      });
      await h.addRow('s', SourceKind.github);
      await expectLater(h.service(batchSize: 2).syncSource('s'), throwsStateError);
      expect(await h.externalIds('s'), ['o0', 'o1']);
      expect((await h.cursorMap('s'))['n'], isNull, reason: 'cursor would skip o2 on resume');
    });

    test('a failure creates the status row on first sync with lastSuccessAt null', () async {
      register((ctx) => Stream.error(Exception('nope')));
      await h.addRow('s', SourceKind.github);
      await expectLater(h.service().syncSource('s'), throwsException);
      final st = (await h.status('s'))!;
      expect(st.lastError, contains('nope'));
      expect(st.lastSuccessAt, isNull);
    });

    test('an unregistered kind fails with lastError recorded', () async {
      await h.addRow('s', SourceKind.jira);
      await expectLater(h.service().syncSource('s'), throwsStateError);
      expect((await h.status('s'))!.lastError, contains('jira'));
    });

    test('unknown source id throws', () async {
      await expectLater(h.service().syncSource('missing'), throwsStateError);
    });
  });

  group('success status (claim 3)', () {
    test('sets lastSuccessAt to clock time and clears lastError', () async {
      var fail = true;
      register((ctx) async* {
        if (fail) throw StateError('e');
        yield obs('a');
      });
      await h.addRow('s', SourceKind.github);
      final svc = h.service();
      await expectLater(svc.syncSource('s'), throwsStateError);
      expect((await h.status('s'))!.lastError, isNotNull);

      fail = false;
      h.clock.t = DateTime.utc(2026, 11, 19, 8, 30, 15);
      await svc.syncSource('s');
      final st = (await h.status('s'))!;
      expect(st.lastError, isNull);
      expect(st.lastSuccessAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 19, 8, 30, 15)), isTrue);
    });

    test("does not overwrite a cursor the source stores in the '' scope", () async {
      register((ctx) async* {
        ctx.setCursor('', 'root-cursor');
        yield obs('a');
      });
      await h.addRow('s', SourceKind.github);
      final svc = h.service();
      await svc.syncSource('s');
      var st = (await h.status('s'))!;
      expect(st.cursor, 'root-cursor');
      expect(st.lastSuccessAt, isNotNull);

      // Failure afterwards keeps the cursor too.
      h.engine.sources.register(SourceKind.github, () => ScriptSource(SourceKind.github, (_) => Stream.error('x')));
      await expectLater(svc.syncSource('s'), throwsA('x'));
      st = (await h.status('s'))!;
      expect(st.cursor, 'root-cursor');
      expect(st.lastError, 'x');
    });

    test("the source's own '' cursor commit does not clear lastSuccessAt (status kept on a later failure)",
        () async {
      register((ctx) async* {
        ctx.setCursor('', 'c2');
        yield obs('a'); // batch of 1 commits cursor c2 here
        throw StateError('later failure');
      });
      await h.addRow('s', SourceKind.github);
      final t1 = DateTime.utc(2026, 11, 1);
      await h.db.into(h.db.syncCursors).insert(SyncCursorsCompanion.insert(
            sourceId: 's',
            cursor: const Value('c1'),
            lastSuccessAt: Value(t1),
            lastError: const Value('old error'),
          ));
      await expectLater(h.service(batchSize: 1).syncSource('s'), throwsStateError);
      final st = (await h.status('s'))!;
      expect(st.cursor, 'c2');
      expect(st.lastSuccessAt!.isAtSameMomentAs(t1), isTrue);
      expect(st.lastError, contains('later failure'));
    });
  });

  group('context', () {
    test('exposes config, identities, sourceId, clock and initialImportFrom = now - 30d', () async {
      final s = register((ctx) => const Stream.empty());
      await h.addRow('s', SourceKind.github, config: '{"repo":"a/b","n":3}');
      await h.db.into(h.db.identities).insert(IdentitiesCompanion.insert(id: 'i1', kind: 'email', value: 'a@x'));
      await h.db.into(h.db.identities).insert(IdentitiesCompanion.insert(id: 'i2', kind: 'email', value: 'b@x'));
      await h.db.into(h.db.identities).insert(IdentitiesCompanion.insert(id: 'i3', kind: 'github_login', value: 'gh'));
      await h.service().syncSource('s');
      final ctx = s.contexts.single;
      expect(ctx.sourceId, 's');
      expect(ctx.config, {'repo': 'a/b', 'n': 3});
      expect(ctx.identities('email'), unorderedEquals(['a@x', 'b@x']));
      expect(ctx.identities('github_login'), ['gh']);
      expect(ctx.identities('nothing'), isEmpty);
      expect(ctx.clock.now(), h.clock.t);
      expect(ctx.initialImportFrom, h.clock.t.subtract(const Duration(days: 30)));
      expect(await ctx.secret(), isNull);
    });
  });
}
