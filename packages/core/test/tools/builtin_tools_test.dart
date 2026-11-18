import 'package:core/core.dart';
import 'package:core/src/tools/builtin/register.dart';
import 'package:core/src/tools/builtin/search_evidence.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  late Fixture fx;
  late ToolRegistry tools;
  late ToolContext ctx;

  setUp(() async {
    fx = Fixture();
    await fx.base();
    tools = ToolRegistry();
    registerBuiltinTools(tools);
    ctx = ToolContext(db: fx.db, profileId: 'p');
  });
  tearDown(() => fx.db.close());

  Future<Map<String, Object?>> call(String name, Map<String, Object?> input) => tools[name].call(input, ctx);
  List<String> ids(List list, [String key = 'fact_id']) => [for (final m in list) (m as Map)[key] as String];

  test('registers the six built-ins with object schemas', () {
    expect(
      tools.all.map((t) => t.name),
      unorderedEquals([
        'search_evidence',
        'get_evidence',
        'get_facts',
        'time_breakdown',
        'workstream_timeline',
        'list_wins',
      ]),
    );
    for (final t in tools.all) {
      expect(t.inputSchema['type'], 'object');
      expect(t.description, isNotEmpty);
    }
  });

  test('search_evidence matches payloads and facts with day + project filters', () async {
    await fx.evidence('2026-11-10', 'c1', {'msg': 'idempotency keys for payments'}, project: 'pay');
    await fx.evidence('2026-11-12', 'c2', {'msg': 'idempotency in website forms'}, project: 'web');
    await fx.evidence('2026-11-12', 'c3', {'msg': 'idempotency hidden'}, hidden: true);
    await fx.fact(FactType.outcome, 'Shipped idempotency keys', '2026-11-10', project: 'pay');
    await fx.fact(FactType.outcome, 'Old idempotency fact', '2026-11-10', retired: true);

    final all = await call('search_evidence', {'query': 'idempotency'});
    expect((all['evidence'] as List).length, 2);
    expect(ids(all['facts'] as List), hasLength(1));

    final ranged = await call('search_evidence', {'query': 'idempotency', 'start': '2026-11-11', 'end': '2026-11-30'});
    expect(ids(ranged['evidence'] as List, 'evidence_id'), ['e2']);
    expect(ranged['facts'], isEmpty);

    final proj = await call('search_evidence', {'query': 'idempotency', 'project_id': 'pay'});
    expect(ids(proj['evidence'] as List, 'evidence_id'), ['e1']);
    expect((proj['evidence'] as List).single['snippet'], contains('[idempotency]'));
  });

  test('search query syntax is neutralised', () async {
    expect(ftsQuery('a "b" OR c*'), '"a" """b""" "OR" "c*"');
    await fx.evidence('2026-11-10', 'c1', {'msg': 'x'});
    final r = await call('search_evidence', {'query': 'NEAR( AND "'});
    expect(r['evidence'], isEmpty);
  });

  test('get_evidence returns payloads and enrichments', () async {
    final e = await fx.evidence('2026-11-10', 'c1', {'msg': 'hello'});
    await fx.db
        .into(fx.db.enrichments)
        .insert(
          EnrichmentsCompanion.insert(
            id: 'n1',
            targetType: EntityType.payload,
            targetId: 'p1',
            kind: 'summary',
            output: 'Says hello',
            modelId: 'm',
            createdAt: DateTime.utc(2026),
          ),
        );
    final r = await call('get_evidence', {'evidence_id': e});
    expect(r['found'], isTrue);
    expect(((r['payloads'] as List).single as Map)['content'], {'msg': 'hello'});
    expect(((r['enrichments'] as List).single as Map)['output'], 'Says hello');
    expect((await call('get_evidence', {'evidence_id': 'nope'}))['found'], isFalse);
  });

  test('get_facts: overlap, importance order, excludes retired, filters', () async {
    final a = await fx.fact(FactType.outcome, 'A', '2026-11-10', importance: 0.3, project: 'pay');
    final b = await fx.fact(FactType.decision, 'B', '2026-11-01', end: '2026-11-12', importance: 0.9);
    await fx.fact(FactType.outcome, 'C', '2026-11-10', retired: true);
    await fx.fact(FactType.outcome, 'D', '2026-10-01');
    final r = await call('get_facts', {'start': '2026-11-10', 'end': '2026-11-16'});
    expect(ids(r['facts'] as List), [b, a]);
    expect(
      ids(
        (await call('get_facts', {
              'start': '2026-11-10',
              'end': '2026-11-16',
              'types': ['outcome'],
            }))['facts']
            as List,
      ),
      [a],
    );
    expect(
      ids(
        (await call('get_facts', {'start': '2026-11-10', 'end': '2026-11-16', 'project_id': 'pay'}))['facts'] as List,
      ),
      [a],
    );
    expect(((r['facts'] as List).first as Map)['revision'], 1);
  });

  test('time_breakdown sums minutes by project and basis', () async {
    Future<void> t(String day, String? p, int m, String basis) =>
        fx.fact(FactType.timeAllocation, 'time', day, project: p, details: {'minutes': m, 'basis': basis});
    await t('2026-11-10', 'pay', 60, 'measured');
    await t('2026-11-11', 'pay', 90, 'estimated');
    await t('2026-11-11', null, 30, 'measured');
    await t('2026-11-20', 'pay', 999, 'measured');
    final r = await call('time_breakdown', {'start': '2026-11-10', 'end': '2026-11-16'});
    expect(r['total_minutes'], 180);
    final rows = (r['by_project'] as List).cast<Map>();
    expect(rows.first['project_name'], 'Payments');
    expect(rows.first['measured_minutes'], 60);
    expect(rows.first['estimated_minutes'], 90);
    expect((rows.first['fact_ids'] as List), hasLength(2));
    expect(rows.last['project_id'], isNull);
  });

  test('workstream_timeline groups facts in the period', () async {
    await fx.db.into(fx.db.workstreams).insert(WorkstreamsCompanion.insert(id: 'w1', title: 'Checkout'));
    await fx.db.into(fx.db.workstreams).insert(WorkstreamsCompanion.insert(id: 'w2', title: 'Old'));
    await fx.fact(FactType.outcome, 'x', '2026-11-12', workstream: 'w1');
    await fx.fact(FactType.decision, 'y', '2026-11-10', workstream: 'w1');
    await fx.fact(FactType.outcome, 'z', '2026-09-10', workstream: 'w2');
    final r = await call('workstream_timeline', {'start': '2026-11-01', 'end': '2026-11-30'});
    final ws = (r['workstreams'] as List).cast<Map>();
    expect(ws.single['title'], 'Checkout');
    expect([for (final f in ws.single['facts'] as List) (f as Map)['statement']], ['y', 'x']);
  });

  test('list_wins returns accepted outcomes only', () async {
    final w = await fx.fact(FactType.outcome, 'win', '2026-11-10', win: WinStatus.accepted);
    await fx.fact(FactType.outcome, 'suggested', '2026-11-10', win: WinStatus.suggested);
    await fx.fact(FactType.decision, 'not outcome', '2026-11-10', win: WinStatus.accepted);
    final r = await call('list_wins', {'start': '2026-11-01', 'end': '2026-11-30'});
    expect(ids(r['wins'] as List), [w]);
  });
}
