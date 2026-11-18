import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/reports/generator.dart';
import 'package:core/src/reports/periods.dart';
import 'package:core/src/reports/render.dart';
import 'package:core/src/reports/scheduled.dart';
import 'package:core/src/reports/templates.dart';
import 'package:core/src/tools/builtin/register.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import '../tools/fixtures.dart';

void main() {
  group('periods', () {
    test('containing a day', () {
      expect(
        Period.containing(PeriodKind.daily, '2026-11-18'),
        const Period(PeriodKind.daily, '2026-11-18', '2026-11-18'),
      );
      // 2026-11-18 is a Wednesday.
      expect(
        Period.containing(PeriodKind.weekly, '2026-11-18'),
        const Period(PeriodKind.weekly, '2026-11-16', '2026-11-22'),
      );
      expect(Period.containing(PeriodKind.weekly, '2026-11-22').start, '2026-11-16'); // Sunday
      expect(Period.containing(PeriodKind.weekly, '2026-01-01').start, '2025-12-29'); // across a year
      expect(Period.containing(PeriodKind.monthly, '2028-02-10').end, '2028-02-29'); // leap year
      expect(
        Period.containing(PeriodKind.quarterly, '2026-11-18'),
        const Period(PeriodKind.quarterly, '2026-10-01', '2026-12-31'),
      );
      expect(() => Period.containing(PeriodKind.custom, '2026-11-18'), throwsArgumentError);
      expect(() => Period.custom('2026-11-19', '2026-11-18'), throwsArgumentError);
    });

    test('previous and labels', () {
      expect(Period.containing(PeriodKind.quarterly, '2026-01-05').previous().start, '2025-10-01');
      expect(Period.custom('2026-11-10', '2026-11-12').previous(), Period.custom('2026-11-07', '2026-11-09'));
      expect(Period.containing(PeriodKind.quarterly, '2026-11-18').label, '2026 Q4');
      expect(Period.containing(PeriodKind.monthly, '2026-11-18').label, '2026-11');
    });

    test('scheduled runs cover the right period', () {
      final mon9 = DateTime.utc(2026, 11, 16, 9);
      expect(
        scheduledPeriod(PeriodKind.weekly, mon9, Duration.zero),
        const Period(PeriodKind.weekly, '2026-11-09', '2026-11-15'),
      );
      expect(scheduledPeriod(PeriodKind.monthly, DateTime.utc(2026, 12, 1, 9), Duration.zero).start, '2026-11-01');
      // 18:00 local at UTC-8 is 02:00 UTC next day: still the local day.
      expect(
        scheduledPeriod(PeriodKind.daily, DateTime.utc(2026, 11, 19, 2), const Duration(hours: -8)).start,
        '2026-11-18',
      );
    });
  });

  group('render', () {
    test('drops uncited/invalid items and empty sections', () {
      final v = validateReport(
        {
          'sections': [
            {
              'heading': 'Done',
              'items': [
                {
                  'text': 'Good',
                  'fact_ids': ['a', 'zzz', 'a'],
                },
                {
                  'text': 'Invented',
                  'fact_ids': ['zzz'],
                },
                {'text': 'Uncited', 'fact_ids': []},
              ],
            },
            {
              'heading': 'Empty',
              'items': [
                {
                  'text': 'x',
                  'fact_ids': ['nope'],
                },
              ],
            },
          ],
        },
        {'a', 'b'},
      );
      expect(v, {
        'sections': [
          {
            'heading': 'Done',
            'items': [
              {
                'text': 'Good',
                'fact_ids': ['a'],
              },
            ],
          },
        ],
      });
    });

    test('markdown is deterministic with numbered footnotes', () {
      final md = renderReportMarkdown(
        title: 'T',
        report: {
          'sections': [
            {
              'heading': 'H',
              'items': [
                {
                  'text': 'one',
                  'fact_ids': ['b', 'a'],
                },
                {
                  'text': 'two',
                  'fact_ids': ['a'],
                },
              ],
            },
          ],
        },
        factStatements: {'a': 'Fact A', 'b': 'Fact\nB'},
      );
      expect(md, '# T\n\n## H\n\n- one [^f1][^f2]\n- two [^f2]\n\n[^f1]: Fact B (fact:b)\n[^f2]: Fact A (fact:a)\n');
      expect(
        renderReportMarkdown(title: 'T', report: {'sections': []}, factStatements: {}),
        contains('Nothing recorded'),
      );
    });
  });

  group('templates', () {
    late Fixture fx;
    late TemplateService svc;
    setUp(() async {
      fx = Fixture();
      svc = TemplateService(fx.db);
      await svc.seedBuiltins();
    });
    tearDown(() => fx.db.close());

    test('seeds the six built-ins idempotently', () async {
      await svc.seedBuiltins();
      final all = await svc.list();
      expect(
        all.map((t) => t.name),
        containsAll(['Standup', 'Manager update', 'Weekly review', 'Monthly recap', 'Wins summary', 'Brag doc']),
      );
      expect(all.where((t) => t.builtIn), hasLength(6));
    });

    test('editing a built-in duplicates it; reset restores the default', () async {
      final id = await svc.update('builtin.standup', prompt: 'Custom {period_label}');
      expect(id, startsWith('builtin.standup/'));
      expect((await svc.get('builtin.standup')).prompt, builtinById('builtin.standup')!.prompt);
      final t = await svc.get(id);
      expect((t.prompt, t.version, t.builtIn), ('Custom {period_label}', 2, false));
      await svc.resetToDefault(id);
      expect((await svc.get(id)).prompt, builtinById('builtin.standup')!.prompt);
    });

    test('create, delete rules', () async {
      final id = await svc.create(name: 'Mine', periodKinds: [PeriodKind.weekly], prompt: 'p');
      expect(parsePeriodKinds((await svc.get(id)).periodKinds), [PeriodKind.weekly]);
      expect(() => svc.resetToDefault(id), throwsStateError);
      expect(() => svc.delete('builtin.brag_doc'), throwsStateError);
      await svc.delete(id);
      expect(await svc.list(), hasLength(6));
    });

    test('renderPrompt fills variables', () {
      expect(
        renderPrompt(
          '{period_label} {start} {end} {period_kind} {other}',
          Period.containing(PeriodKind.weekly, '2026-11-18'),
        ),
        'Week of 2026-11-16 2026-11-16 2026-11-22 weekly {other}',
      );
    });
  });

  group('generator', () {
    late Fixture fx;
    late ToolRegistry tools;
    late String win, decision, time;

    setUp(() async {
      fx = Fixture();
      await fx.base();
      await TemplateService(fx.db).seedBuiltins();
      tools = ToolRegistry();
      registerBuiltinTools(tools);
      win = await fx.fact(
        FactType.outcome,
        'Shipped idempotency keys',
        '2026-11-17',
        project: 'pay',
        importance: 0.9,
        win: WinStatus.accepted,
      );
      decision = await fx.fact(FactType.decision, 'Chose Postgres advisory locks', '2026-11-17', project: 'pay');
      time = await fx.fact(
        FactType.timeAllocation,
        'time',
        '2026-11-17',
        project: 'pay',
        details: {'minutes': 120, 'basis': 'measured'},
      );
    });
    tearDown(() => fx.db.close());

    Map<String, Object?> answer(List<String> ids) => {
      'sections': [
        {
          'heading': 'Done',
          'items': [
            {'text': 'Shipped idempotency keys', 'fact_ids': ids},
            {
              'text': 'Invented claim',
              'fact_ids': ['made-up'],
            },
          ],
        },
      ],
    };

    ReportGenerator gen(FakeModelRouter router) => ReportGenerator(
      db: fx.db,
      router: router,
      tools: tools,
      profileId: 'p',
      clock: FixedClock(DateTime.utc(2026, 11, 17, 18)),
    );

    test('generates a cited snapshot with dependencies; versions increment', () async {
      final router = FakeModelRouter([
        answer([win, time]),
      ]);
      final g = gen(router);
      final report = await g.ensureReport(PeriodKind.daily, '2026-11-17', '2026-11-17', 'builtin.standup');
      expect((await g.ensureReport(PeriodKind.daily, '2026-11-17', '2026-11-17', 'builtin.standup')).id, report.id);

      final events = await g.generate(report.id, styleInstruction: 'shorter').toList();
      expect(events.whereType<ReportProgress>().map((e) => e.stage), [
        ReportStage.gathering,
        ReportStage.generating,
        ReportStage.saving,
      ]);
      expect(events.whereType<ReportDelta>(), isNotEmpty);
      final done = events.last as ReportDone;
      expect(done.markdown, contains('Shipped idempotency keys [^f1][^f2]'));
      expect(done.markdown, isNot(contains('Invented')));
      expect(done.snapshot!.version, 1);
      expect(done.snapshot!.styleInstruction, 'shorter');
      expect(done.snapshot!.modelId, 'fake-model');
      expect(jsonDecode(done.snapshot!.json), done.json);
      expect(router.routes, everyElement(LlmRoute.reports));

      final req = router.client.requests.single;
      final user = req.messages.last.text;
      expect(user, contains('[$win] outcome | 2026-11-17 | Payments | win: Shipped'));
      expect(user, contains('Payments: 120 min'));
      expect(req.messages.first.text, contains('Style instruction'));
      expect(req.schema, reportSchema);

      final deps = await (fx.db.select(
        fx.db.dependencies,
      )..where((d) => d.dependentId.equals(done.snapshot!.id))).get();
      expect(deps.map((d) => d.inputId), unorderedEquals([win, decision, time]));
      expect(deps.every((d) => d.inputType == EntityType.fact && d.inputRevision == 1), isTrue);

      final second = (await g.generate(report.id).last) as ReportDone;
      expect(second.snapshot!.version, 2);
      expect(
        await StalenessService(fx.db).isStale((type: EntityType.reportSnapshot, id: second.snapshot!.id)),
        isFalse,
      );
      await (fx.db.update(
        fx.db.facts,
      )..where((f) => f.id.equals(decision))).write(const FactsCompanion(revision: Value(2)));
      expect(await StalenessService(fx.db).isStale((type: EntityType.reportSnapshot, id: second.snapshot!.id)), isTrue);
    });

    test('locked reports are never regenerated', () async {
      final g = gen(
        FakeModelRouter([
          answer([win]),
        ]),
      );
      final report = await g.ensureReport(PeriodKind.daily, '2026-11-17', '2026-11-17', 'builtin.standup');
      await g.generate(report.id).drain<void>();
      await (fx.db.update(
        fx.db.reports,
      )..where((r) => r.id.equals(report.id))).write(const ReportsCompanion(locked: Value(true)));
      await expectLater(g.generate(report.id), emitsThrough(emitsError(isA<ReportLockedException>())));
      expect(await fx.db.select(fx.db.reportSnapshots).get(), hasLength(1));
    });

    test('budget keeps the most important facts and counts the rest', () async {
      for (var i = 0; i < 200; i++) {
        await fx.fact(
          FactType.invisibleWork,
          'Reviewed pull request number $i for the web team',
          '2026-11-17',
          project: 'web',
          importance: 0.1,
        );
      }
      final router = FakeModelRouter([
        answer([win]),
      ], contextLength: 1200);
      final g = gen(router);
      final done =
          (await g.preview('builtin.standup', Period.containing(PeriodKind.daily, '2026-11-17')).last) as ReportDone;
      expect(done.snapshot, isNull);
      expect(await fx.db.select(fx.db.reportSnapshots).get(), isEmpty);
      final user = router.client.requests.single.messages.last.text;
      expect(user, contains('[$win]'));
      expect(RegExp(r'Website: \d+ facts').hasMatch(user), isTrue);
      expect(user.length, lessThan(1200 * 4));
    });
  });
}
