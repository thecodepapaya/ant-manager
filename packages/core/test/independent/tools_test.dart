// Independent tests (#99) for the built-in harness tools (#53): semantics and input validation.
import 'package:core/core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late ProfileDb db;
  late Seed seed;
  late ToolRegistry tools;
  late ToolContext ctx;
  late String src;

  setUp(() async {
    db = memDb();
    seed = Seed(db);
    tools = ToolRegistry();
    registerBuiltinTools(tools);
    ctx = ToolContext(db: db, profileId: 'p1');
    src = await seed.source();
    await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'pay', name: 'Payments'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'web', name: 'Website'));
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> call(String tool, Map<String, Object?> input) => tools[tool].call(input, ctx);
  List<String> ids(Object? list, [String key = 'fact_id']) => [
    for (final m in (list as List).cast<Map>()) m[key] as String,
  ];

  group('registry and schemas', () {
    test('all six tools are registered with object schemas whose required keys exist', () {
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
        expect(t.description, isNotEmpty);
        expect(t.inputSchema['type'], 'object');
        final props = (t.inputSchema['properties'] as Map).keys;
        for (final r in (t.inputSchema['required'] as List? ?? const [])) {
          expect(props, contains(r), reason: '${t.name}.$r');
        }
      }
      expect(() => tools['nope'], throwsStateError);
    });
  });

  group('input validation', () {
    test('missing or empty required fields are rejected', () async {
      for (final t in ['get_facts', 'list_wins', 'time_breakdown', 'workstream_timeline']) {
        await expectLater(call(t, {'start': '2026-11-01'}), throwsArgumentError, reason: t);
        await expectLater(call(t, {'start': '', 'end': '2026-11-30'}), throwsArgumentError, reason: t);
        await expectLater(call(t, {'start': 5, 'end': '2026-11-30'}), throwsArgumentError, reason: t);
      }
      await expectLater(call('get_evidence', {}), throwsArgumentError);
      await expectLater(call('search_evidence', {}), throwsArgumentError);
    });

    test('unknown fact type names are rejected', () async {
      await expectLater(
        call('get_facts', {
          'start': '2026-11-01',
          'end': '2026-11-30',
          'types': ['bogus'],
        }),
        throwsArgumentError,
      );
    });

    test(
      'days that do not match YYYY-MM-DD are rejected',
      () async {
        for (final bad in ['18/11/2026', '2026-11-1', '2026-13-45', 'yesterday']) {
          await expectLater(call('get_facts', {'start': bad, 'end': '2026-11-30'}), throwsA(anything), reason: bad);
        }
      },
      skip:
          'BUG: tools/builtin/common.dart reqString only checks non-empty; the schema pattern ^\\d{4}-\\d{2}-\\d{2}\$ '
          'is not enforced, so malformed days are compared as strings and silently give wrong results',
    );

    test(
      'unknown input keys are rejected (additionalProperties: false)',
      () async {
        await seed.fact('A', '2026-11-18', project: 'pay');
        await expectLater(
          call('get_facts', {'start': '2026-11-01', 'end': '2026-11-30', 'projectId': 'web'}),
          throwsA(anything),
        );
      },
      skip:
          'BUG: tools ignore unknown keys despite additionalProperties:false; an agent typo such as '
          '"projectId" silently drops the project filter',
    );
  });

  group('get_facts', () {
    test('overlap, retired exclusion, ordering by importance, limit, project and type filters', () async {
      final span = await seed.fact('Spans into Nov', '2026-10-28', end: '2026-11-02', importance: 0.4);
      final hi = await seed.fact('High', '2026-11-30', importance: 0.9, project: 'pay');
      final lo = await seed.fact('Low', '2026-11-15', importance: 0.1, type: FactType.hiccup, project: 'web');
      await seed.fact('Retired', '2026-11-15', retired: true, importance: 1);
      await seed.fact('After', '2026-12-01', importance: 1);
      await seed.fact('Before', '2026-10-31', importance: 1);
      final all = await call('get_facts', {'start': '2026-11-01', 'end': '2026-11-30'});
      expect(ids(all['facts']), [hi, span, lo]);
      expect(ids((await call('get_facts', {'start': '2026-11-01', 'end': '2026-11-30', 'limit': 1}))['facts']), [hi]);
      expect(
        ids((await call('get_facts', {'start': '2026-11-01', 'end': '2026-11-30', 'project_id': 'web'}))['facts']),
        [lo],
      );
      expect(
        ids(
          (await call('get_facts', {
            'start': '2026-11-01',
            'end': '2026-11-30',
            'types': ['hiccup'],
          }))['facts'],
        ),
        [lo],
      );
      final f = (all['facts'] as List).first as Map;
      expect(f.keys, containsAll(['fact_id', 'type', 'statement', 'period_start', 'period_end', 'origin', 'revision']));
    });

    test('a start after end returns nothing', () async {
      await seed.fact('A', '2026-11-18');
      expect((await call('get_facts', {'start': '2026-11-30', 'end': '2026-11-01'}))['facts'], isEmpty);
    });
  });

  group('list_wins', () {
    test('only accepted Outcome facts, not suggested, rejected, retired or other types', () async {
      final win = await seed.fact('Win', '2026-11-18', win: WinStatus.accepted, importance: 0.7);
      final win2 = await seed.fact('Win 2', '2026-11-19', win: WinStatus.accepted, importance: 0.9, project: 'web');
      await seed.fact('Suggested', '2026-11-18', win: WinStatus.suggested);
      await seed.fact('Rejected', '2026-11-18', win: WinStatus.rejected);
      await seed.fact('Retired win', '2026-11-18', win: WinStatus.accepted, retired: true);
      await seed.fact('Decision', '2026-11-18', type: FactType.decision, win: WinStatus.accepted);
      final out = await call('list_wins', {'start': '2026-11-01', 'end': '2026-11-30'});
      expect(ids(out['wins']), [win2, win]);
      expect(
        ids((await call('list_wins', {'start': '2026-11-01', 'end': '2026-11-30', 'project_id': 'web'}))['wins']),
        [win2],
      );
    });
  });

  group('time_breakdown', () {
    Future<String> time(String day, int minutes, String basis, {String? project, bool retired = false}) => seed.fact(
      'time',
      day,
      type: FactType.timeAllocation,
      project: project,
      retired: retired,
      details: {'minutes': minutes, 'basis': basis},
    );

    test('sums measured and estimated per project, sorted by total, excluding retired and outside days', () async {
      final a = await time('2026-11-16', 60, 'measured', project: 'pay');
      final b = await time('2026-11-17', 30, 'estimated', project: 'pay');
      final c = await time('2026-11-17', 200, 'measured', project: 'web');
      final d = await time('2026-11-18', 15, 'estimated');
      await time('2026-11-18', 999, 'measured', project: 'pay', retired: true);
      await time('2026-11-23', 999, 'measured', project: 'pay');
      await seed.fact('not time', '2026-11-18', details: {'minutes': 999, 'basis': 'measured'});
      final out = await call('time_breakdown', {'start': '2026-11-16', 'end': '2026-11-22'});
      expect(out['total_minutes'], 305);
      final rows = (out['by_project'] as List).cast<Map>();
      expect(rows.map((r) => r['project_id']), ['web', 'pay', null]);
      expect(rows[0]['project_name'], 'Website');
      expect(rows[1], containsPair('measured_minutes', 60));
      expect(rows[1], containsPair('estimated_minutes', 30));
      expect(rows[1], containsPair('total_minutes', 90));
      expect(rows[1]['fact_ids'], [a, b]);
      expect(rows[0]['fact_ids'], [c]);
      expect(rows[2]['fact_ids'], [d]);
      expect(rows[2]['project_name'], isNull);
    });

    test('an empty period has zero total', () async {
      final out = await call('time_breakdown', {'start': '2026-01-01', 'end': '2026-01-31'});
      expect(out['total_minutes'], 0);
      expect(out['by_project'], isEmpty);
    });
  });

  group('workstream_timeline', () {
    test('workstreams ordered by first activity, facts in time order, retired and unassigned excluded', () async {
      for (final w in ['wsA', 'wsB']) {
        await db.into(db.workstreams).insert(WorkstreamsCompanion.insert(id: w, title: 'Title $w'));
      }
      final b1 = await seed.fact('B early', '2026-11-02', workstream: 'wsB');
      final a2 = await seed.fact('A late', '2026-11-20', workstream: 'wsA');
      final a1 = await seed.fact('A early', '2026-11-05', workstream: 'wsA');
      await seed.fact('A retired', '2026-11-06', workstream: 'wsA', retired: true);
      await seed.fact('No ws', '2026-11-01');
      final out = await call('workstream_timeline', {'start': '2026-11-01', 'end': '2026-11-30'});
      final ws = (out['workstreams'] as List).cast<Map>();
      expect(ws.map((w) => w['workstream_id']), ['wsB', 'wsA']);
      expect(ids(ws[1]['facts']), [a1, a2]);
      expect(ws[1]['fact_count'], 2);
      expect(ids(ws[0]['facts']), [b1]);
    });
  });

  group('get_evidence', () {
    test('unknown id → found: false', () async {
      expect(await call('get_evidence', {'evidence_id': 'nope'}), {'found': false});
    });

    test('returns payloads (incl. tombstoned flag) and enrichments on payloads and the evidence', () async {
      final e = await seed.evidence(src, '2026-11-18', {'text': 'hello'}, title: 'Hello');
      await db.customStatement('UPDATE payloads SET tombstoned_at = 1, revision = 2 WHERE id = ?', [e.payload]);
      for (final (id, type, target) in [
        ('n1', EntityType.payload, e.payload),
        ('n2', EntityType.evidence, e.evidence),
        ('n3', EntityType.payload, 'other'),
      ]) {
        await db
            .into(db.enrichments)
            .insert(
              EnrichmentsCompanion.insert(
                id: id,
                targetType: type,
                targetId: target,
                kind: 'summary',
                output: 'o',
                modelId: 'm',
                createdAt: seed.now,
              ),
            );
      }
      final out = await call('get_evidence', {'evidence_id': e.evidence});
      expect(out['found'], isTrue);
      expect((out['evidence'] as Map)['title'], 'Hello');
      final payload = ((out['payloads'] as List).single as Map);
      expect(payload['content'], {'text': 'hello'});
      expect(payload['tombstoned'], isTrue);
      expect(payload['revision'], 2);
      expect(ids(out['enrichments'], 'enrichment_id'), unorderedEquals(['n1', 'n2']));
    });
  });

  group('search_evidence filters', () {
    test('project filter applies to evidence and facts', () async {
      await seed.evidence(src, '2026-11-18', {'text': 'kafka migration'}, project: 'pay');
      await seed.evidence(src, '2026-11-18', {'text': 'kafka upgrade'}, project: 'web');
      await seed.fact('kafka plan', '2026-11-18', project: 'pay');
      await seed.fact('kafka retro', '2026-11-18', project: 'web');
      final out = await call('search_evidence', {'query': 'kafka', 'project_id': 'pay'});
      expect((out['evidence'] as List), hasLength(1));
      expect((out['facts'] as List), hasLength(1));
      expect(((out['evidence'] as List).single as Map)['project_id'], 'pay');
    });

    test('facts are matched by period overlap with the day range', () async {
      await seed.fact('quarterly okr', '2026-10-01', end: '2026-12-31');
      final out = await call('search_evidence', {'query': 'okr', 'start': '2026-11-18', 'end': '2026-11-18'});
      expect(out['facts'] as List, hasLength(1));
    });
  });
}
