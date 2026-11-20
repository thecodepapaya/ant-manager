// Independent tests (#99) for DECISIONS #116: a workstream created in a batch with a blank summary
// takes the first later non-blank new_summary for the same new title in that batch; a non-blank
// creation summary is never overwritten by later ones; creation summaries are trimmed. Workstreams
// that existed before the batch still follow #109/#115.
import 'package:core/core.dart';
import 'package:core/src/narrative/workstreams.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late WorkstreamAssigner ws;
  late String p;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    h = H();
    await h.setUp();
    ws = WorkstreamAssigner(h.ctx);
    p = await h.pid(await h.commit('a1', at(10)));
  });
  tearDown(() => h.close());

  void answer(List<Map<String, Object?>> assignments) =>
      h.router.responders['workstreams'] = (_) => {'assignments': assignments};

  Map<String, Object?> a(String fact, {String? ws, String? title, String? summary}) => {
    'fact_id': fact,
    'workstream_id': ws,
    'new_title': title,
    'new_summary': summary,
  };

  Future<void> facts(List<String> ids) async {
    for (final id in ids) {
      await h.insertFact(id, [p]);
    }
  }

  Future<List<Workstream>> all() => h.db.select(h.db.workstreams).get();

  Future<Workstream> byTitle(String title) async => (await all()).singleWhere((w) => w.title == title);

  group('created in the batch', () {
    for (final (label, blank) in [('null', null), ('empty', ''), ('whitespace', '  \n\t ')]) {
      test('a $label creation summary takes the first later non-blank one for the same title', () async {
        await facts(['f1', 'f2', 'f3']);
        answer([
          a('f1', title: 'Search revamp', summary: blank),
          a('f2', title: 'Search revamp', summary: 'First later.'),
          a('f3', title: 'Search revamp', summary: 'Second later.'),
        ]);
        await ws.assignDay(day);
        final w = await byTitle('Search revamp');
        expect(w.summary, 'First later.');
        expect((await all()), hasLength(1), reason: 'one workstream, reused by title');
        for (final f in ['f1', 'f2', 'f3']) {
          expect((await h.fact(f)).workstreamId, w.id);
        }
      });
    }

    test('a blank creation summary stays empty when no later summary is non-blank', () async {
      await facts(['f1', 'f2', 'f3']);
      answer([
        a('f1', title: 'Search revamp', summary: '   '),
        a('f2', title: 'Search revamp', summary: ''),
        a('f3', title: 'Search revamp'),
      ]);
      await ws.assignDay(day);
      final w = await byTitle('Search revamp');
      expect(w.summary, '');
      expect((await all()), hasLength(1));
      for (final f in ['f1', 'f2', 'f3']) {
        expect((await h.fact(f)).workstreamId, w.id, reason: 'every fact still joins');
      }
    });

    test('blank later summaries are skipped; the first non-blank one after them wins', () async {
      await facts(['f1', 'f2', 'f3', 'f4']);
      answer([
        a('f1', title: 'Search revamp'),
        a('f2', title: 'Search revamp', summary: ' '),
        a('f3', title: 'Search revamp', summary: '  Filled later.\n'),
        a('f4', title: 'Search revamp', summary: 'Too late.'),
      ]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, 'Filled later.', reason: 'trimmed, first non-blank');
    });

    test('a later assignment matching the new title in another case / with padding fills it', () async {
      await facts(['f1', 'f2']);
      answer([
        a('f1', title: 'Search Revamp', summary: ''),
        a('f2', title: '  search revamp ', summary: 'Rebuilding search.'),
      ]);
      await ws.assignDay(day);
      final w = await byTitle('Search Revamp');
      expect(w.summary, 'Rebuilding search.');
      expect((await all()), hasLength(1));
    });

    test('a non-blank creation summary is not overwritten by later ones', () async {
      await facts(['f1', 'f2', 'f3']);
      answer([
        a('f1', title: 'Search revamp', summary: 'Original.'),
        a('f2', title: 'Search revamp', summary: 'Later.'),
        a('f3', title: 'Search revamp', summary: 'Even later.'),
      ]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, 'Original.');
    });

    test('blank later summaries leave a non-blank creation summary alone', () async {
      await facts(['f1', 'f2', 'f3']);
      answer([
        a('f1', title: 'Search revamp', summary: 'Original.'),
        a('f2', title: 'Search revamp', summary: ''),
        a('f3', title: 'Search revamp', summary: '  '),
      ]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, 'Original.');
    });

    test('the created workstream takes the creating fact\'s project', () async {
      await h.insertFact('f1', [p], project: 'pay');
      await h.insertFact('f2', [p], project: 'web');
      answer([a('f1', title: 'Search revamp'), a('f2', title: 'Search revamp', summary: 'Filled.')]);
      await ws.assignDay(day);
      final w = await byTitle('Search revamp');
      expect((w.projectId, w.summary), ('pay', 'Filled.'), reason: 'a later fill does not change the project');
    });

    test('the creation summary is trimmed', () async {
      await facts(['f1']);
      answer([a('f1', title: 'Search revamp', summary: '\n  Rebuilding search.  \t')]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, 'Rebuilding search.');
    });

    test('two blank new titles each take their own later summary', () async {
      await facts(['f1', 'f2', 'f3', 'f4']);
      answer([
        a('f1', title: 'Alpha'),
        a('f2', title: 'Beta', summary: ''),
        a('f3', title: 'Beta', summary: 'Beta words.'),
        a('f4', title: 'Alpha', summary: 'Alpha words.'),
      ]);
      await ws.assignDay(day);
      expect((await byTitle('Alpha')).summary, 'Alpha words.');
      expect((await byTitle('Beta')).summary, 'Beta words.');
    });

    test('a summary on another title does not fill a blank one', () async {
      await facts(['f1', 'f2']);
      answer([a('f1', title: 'Alpha'), a('f2', title: 'Beta', summary: 'Beta words.')]);
      await ws.assignDay(day);
      expect((await byTitle('Alpha')).summary, '');
      expect((await byTitle('Beta')).summary, 'Beta words.');
    });

    test('a dropped later assignment (unknown fact) does not fill the blank summary', () async {
      await facts(['f1', 'f2']);
      answer([
        a('f1', title: 'Search revamp'),
        a('ghost', title: 'Search revamp', summary: 'From a ghost.'),
        a('f2', title: 'Search revamp', summary: 'Real.'),
      ]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, 'Real.');
    });

    test('a later fact edited during the model call is dropped and does not fill the blank summary', () async {
      await facts(['f1', 'f2']);
      answer([a('f1', title: 'Search revamp'), a('f2', title: 'Search revamp', summary: 'Stale.')]);
      h.router.onCall = (_) => (h.db.update(h.db.facts)..where((f) => f.id.equals('f2'))).write(
        const FactsCompanion(revision: Value(2)),
      );
      await ws.assignDay(day);
      final w = await byTitle('Search revamp');
      expect(w.summary, '');
      expect((await h.fact('f1')).workstreamId, w.id);
      expect((await h.fact('f2')).workstreamId, isNull, reason: 'stale revision → dropped');
    });

    test('in a later batch the now-existing workstream follows #109 (last non-blank wins)', () async {
      // Next batch: the workstream now exists before the batch, so a non-blank new_summary refreshes it
      // the #109 way (last non-blank wins), not the first-later way.
      await facts(['f1']);
      answer([a('f1', title: 'Search revamp')]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, '');
      await facts(['f2', 'f3']);
      answer([
        a('f2', title: 'Search revamp', summary: 'One.'),
        a('f3', title: 'Search revamp', summary: 'Two.'),
      ]);
      await ws.assignDay(day);
      expect((await byTitle('Search revamp')).summary, 'Two.');
      expect((await all()), hasLength(1));
    });
  });

  group('existing before the batch (#109/#115)', () {
    Future<void> existing(String id, String title, String summary, {bool touched = false}) => h.db
        .into(h.db.workstreams)
        .insert(
          WorkstreamsCompanion.insert(
            id: id,
            title: title,
            summary: Value(summary),
            userTouched: Value(touched),
            spanStart: const Value(day),
            spanEnd: const Value(day),
          ),
        );

    test('a user-touched blank-summary workstream reused by title stays blank', () async {
      await existing('mine', 'Search revamp', '', touched: true);
      await facts(['f1', 'f2']);
      answer([a('f1', title: 'search revamp'), a('f2', title: 'Search revamp', summary: 'Model words.')]);
      await ws.assignDay(day);
      final w = (await all()).single;
      expect((w.id, w.summary), ('mine', ''));
      expect((await h.fact('f2')).workstreamId, 'mine');
    });

    test('a non-touched workstream reused by title takes the last non-blank summary, not the first', () async {
      await existing('auto', 'Search revamp', '');
      await facts(['f1', 'f2', 'f3']);
      answer([
        a('f1', title: 'Search revamp'),
        a('f2', title: 'Search revamp', summary: 'First.'),
        a('f3', title: 'Search revamp', summary: 'Last.'),
      ]);
      await ws.assignDay(day);
      final w = (await all()).single;
      expect((w.id, w.summary), ('auto', 'Last.'));
    });

    test('a non-touched workstream reused by title with only blank summaries keeps its summary', () async {
      await existing('auto', 'Search revamp', 'Kept.');
      await facts(['f1', 'f2']);
      answer([a('f1', title: 'Search revamp', summary: ' '), a('f2', title: 'Search revamp')]);
      await ws.assignDay(day);
      expect((await all()).single.summary, 'Kept.');
    });
  });
}
