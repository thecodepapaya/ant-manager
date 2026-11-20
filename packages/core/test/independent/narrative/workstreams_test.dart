import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/reconciler.dart';
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
  });
  tearDown(() => h.close());

  List<String> askedFactIds() => [
    for (final c in h.router.of('workstreams'))
      for (final f in (jsonDecode(c.user) as Map)['facts'] as List) (f as Map)['fact_id'] as String,
  ];

  void answer(List<Map<String, Object?>> assignments) =>
      h.router.responders['workstreams'] = (_) => {'assignments': assignments};

  Map<String, Object?> a(String fact, {String? ws, String? title, String summary = ''}) => {
    'fact_id': fact,
    'workstream_id': ws,
    'new_title': title,
    'new_summary': summary,
  };

  Future<void> insertWs(String id, String title, {String? start, String? end}) => h.db
      .into(h.db.workstreams)
      .insert(WorkstreamsCompanion.insert(id: id, title: title, spanStart: Value(start), spanEnd: Value(end)));

  test('only model-owned, non-time facts without a workstream are sent', () async {
    await insertWs('w0', 'Existing', start: day, end: day);
    await h.insertFact('ok', [p1]);
    await h.insertFact('user', [p1], origin: FactOrigin.confirmed);
    await h.insertFact('time', [p1], type: FactType.timeAllocation);
    await h.insertFact('has', [p1], workstream: 'w0');
    await h.insertFact('retired', [p1], retired: true);
    await ws.assignDay(day);
    expect(askedFactIds(), ['ok']);
    expect(h.router.of('workstreams').single.route, LlmRoute.extraction);
  });

  test('no candidate facts → no model call', () async {
    await h.insertFact('user', [p1], origin: FactOrigin.userCreated);
    await ws.assignDay(day);
    expect(h.router.calls, isEmpty);
  });

  test('new titles are de-duplicated within a batch and against existing workstreams (case-insensitive)', () async {
    await insertWs('w0', 'Payments retries', start: '2026-11-10', end: '2026-11-10');
    await h.insertFact('f1', [p1]);
    await h.insertFact('f2', [p1]);
    await h.insertFact('f3', [p1]);
    await h.insertFact('f4', [p1]);
    answer([
      a('f1', title: 'Search revamp', summary: 's'),
      a('f2', title: 'search REVAMP'),
      a('f3', title: 'PAYMENTS retries'),
      a('f4', ws: 'w0'),
    ]);
    await ws.assignDay(day);
    final rows = await h.db.select(h.db.workstreams).get();
    expect(rows, hasLength(2));
    final search = rows.firstWhere((w) => w.id != 'w0');
    expect((search.title, search.summary), ('Search revamp', 's'));
    expect((await h.fact('f1')).workstreamId, search.id);
    expect((await h.fact('f2')).workstreamId, search.id);
    expect((await h.fact('f3')).workstreamId, 'w0');
    expect((await h.fact('f4')).workstreamId, 'w0');
  });

  test('assignment does not bump the fact revision', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', title: 'X')]);
    await ws.assignDay(day);
    expect((await h.fact('f1')).revision, 1);
  });

  test('spans are recomputed from live facts', () async {
    await insertWs('w0', 'Old', start: '2026-11-01', end: '2026-11-05');
    await h.insertFact('early', [p1], d: '2026-11-01', workstream: 'w0');
    await h.insertFact('f1', [p1]);
    answer([a('f1', ws: 'w0')]);
    await ws.assignDay(day);
    final w = await (h.db.select(h.db.workstreams)..where((w) => w.id.equals('w0'))).getSingle();
    expect((w.spanStart, w.spanEnd), ('2026-11-01', day));
  });

  test('a new workstream spans its first day and takes the fact project', () async {
    await h.insertFact('f1', [p1], project: 'pay');
    answer([a('f1', title: 'Payments')]);
    await ws.assignDay(day);
    final w = await h.db.select(h.db.workstreams).getSingle();
    expect((w.spanStart, w.spanEnd, w.projectId), (day, day, 'pay'));
  });

  test('unknown workstream ids and unknown fact ids are ignored', () async {
    await h.insertFact('f1', [p1]);
    answer([a('f1', ws: 'nope'), a('ghost', title: 'Ghost')]);
    await ws.assignDay(day);
    expect((await h.fact('f1')).workstreamId, isNull);
    expect(await h.db.select(h.db.workstreams).get(), isEmpty);
  });

  test('workstreams older than 30 days are not offered', () async {
    await insertWs('old', 'Ancient', start: '2026-09-01', end: '2026-09-02');
    await insertWs('new', 'Recent', start: '2026-11-10', end: '2026-11-12');
    await h.insertFact('f1', [p1]);
    await ws.assignDay(day);
    final offered = [
      for (final w in (jsonDecode(h.router.calls.single.user) as Map)['workstreams'] as List) (w as Map)['id'],
    ];
    expect(offered, ['new']);
  });

  test(
    'retiring a fact recomputes its workstream span',
    () async {
      await insertWs('w0', 'Thread', start: '2026-11-10', end: day);
      await h.insertFact('early', [p1], d: '2026-11-10', workstream: 'w0');
      final p = await h.pid(await h.pr('pr1', at(11)));
      await h.insertFact('late', [p], workstream: 'w0');
      await h.setHidden((await h.payloadByExt(H.gh, 'pr1')).evidenceId, true);
      await FactReconciler(h.ctx).apply(FactChangeSet(day, const [])); // retires 'late' (no live citations)
      expect((await h.fact('late')).retired, isTrue);
      await ws.assignDay(day);
      final w = await (h.db.select(h.db.workstreams)..where((w) => w.id.equals('w0'))).getSingle();
      expect(w.spanEnd, '2026-11-10');
    },
  );
}
