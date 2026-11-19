// Independent tests (#99) for #109: `new_summary` on an assignment refreshes an existing,
// non-user-touched workstream's summary.
import 'package:core/core.dart';
import 'package:core/src/narrative/workstreams.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late WorkstreamAssigner ws;
  late String p1;
  setUp(() async {
    h = H();
    await h.setUp();
    ws = WorkstreamAssigner(h.ctx);
    p1 = await h.pid(await h.commit('a1', at(10)));
    await h.db
        .into(h.db.workstreams)
        .insert(
          WorkstreamsCompanion.insert(
            id: 'w0',
            title: 'Payments retries',
            summary: const Value('Old summary.'),
            spanStart: const Value('2026-11-10'),
            spanEnd: const Value('2026-11-10'),
          ),
        );
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

  Future<Workstream> w(String id) => (h.db.select(h.db.workstreams)..where((w) => w.id.equals(id))).getSingle();

  test('a non-empty new_summary on joining an existing workstream replaces its summary', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', ws: 'w0', summary: 'Retries for card and bank payments.')]);
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'Retries for card and bank payments.');
    expect((await h.fact('f1')).workstreamId, 'w0');
    expect((await w('w0')).title, 'Payments retries', reason: 'title unchanged');
  });

  test('the refreshed summary is trimmed', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', ws: 'w0', summary: '  New summary.\n')]);
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'New summary.');
  });

  test('joining an existing workstream by its title also refreshes the summary', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', title: 'PAYMENTS RETRIES', summary: 'Refreshed.')]);
    await ws.assignDay(day);
    expect((await h.fact('f1')).workstreamId, 'w0');
    expect((await w('w0')).summary, 'Refreshed.');
    expect(await h.db.select(h.db.workstreams).get(), hasLength(1));
  });

  test('a user-touched workstream joined by title keeps its summary', () async {
    await (h.db.update(h.db.workstreams)..where((x) => x.id.equals('w0'))).write(
      const WorkstreamsCompanion(userTouched: Value(true)),
    );
    await h.insertFact('f1', [p1]);
    answer([a('f1', title: 'payments retries', summary: 'Model rewrite.')]);
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'Old summary.');
    expect((await h.fact('f1')).workstreamId, 'w0');
  });

  test('a user-touched workstream keeps its summary (the fact still joins)', () async {
    await (h.db.update(h.db.workstreams)..where((x) => x.id.equals('w0'))).write(
      const WorkstreamsCompanion(userTouched: Value(true)),
    );
    await h.insertFact('f1', [p1]);
    answer([a('f1', ws: 'w0', summary: 'Model rewrite.')]);
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'Old summary.');
    expect((await h.fact('f1')).workstreamId, 'w0');
  });

  for (final (label, summary) in [('null', null), ('empty', ''), ('blank', '   ')]) {
    test('a $label new_summary leaves the summary alone', () async {
      await h.insertFact('f1', [p1]);
      answer([a('f1', ws: 'w0', summary: summary)]);
      await ws.assignDay(day);
      expect((await w('w0')).summary, 'Old summary.');
      expect((await h.fact('f1')).workstreamId, 'w0');
    });
  }

  test('several facts joining the same workstream: the last non-empty summary wins', () async {
    await h.insertFact('f1', [p1]);
    await h.insertFact('f2', [p1]);
    await h.insertFact('f3', [p1]);
    await h.insertFact('f4', [p1]);
    answer([
      a('f1', ws: 'w0', summary: 'First.'),
      a('f2', ws: 'w0', summary: 'Second.'),
      a('f3', ws: 'w0', summary: ''),
      a('f4', ws: 'w0'),
    ]);
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'Second.');
  });

  test('a new workstream still takes new_summary on creation', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', title: 'Search revamp', summary: 'Rebuilding search.')]);
    await ws.assignDay(day);
    final created = (await h.db.select(h.db.workstreams).get()).singleWhere((x) => x.id != 'w0');
    expect((created.title, created.summary), ('Search revamp', 'Rebuilding search.'));
    expect((await w('w0')).summary, 'Old summary.');
  });

  test('an assignment that is dropped (unknown fact or workstream) changes no summary', () async {
    await h.insertFact('f1', [p1]);
    answer([a('ghost', ws: 'w0', summary: 'From a ghost.'), a('f1', ws: 'nope', summary: 'Nowhere.')]);
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'Old summary.');
    expect((await h.fact('f1')).workstreamId, isNull);
  });

  test('a fact the user touched while the model was thinking does not refresh the summary', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', ws: 'w0', summary: 'Stale.')]);
    h.router.onCall = (_) => (h.db.update(h.db.facts)..where((f) => f.id.equals('f1'))).write(
      const FactsCompanion(origin: Value(FactOrigin.confirmed)),
    );
    await ws.assignDay(day);
    expect((await w('w0')).summary, 'Old summary.');
    expect((await h.fact('f1')).workstreamId, isNull);
  });
}
