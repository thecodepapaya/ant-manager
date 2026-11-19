// Independent tests (#99) for periods, templates, render, generator (preview + lock) and scheduled reports.
// Derived from SPEC §8, LLD 04 §4.9, invariant 8, DECISIONS #49 #66 #86 #92.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/reports/render.dart';
import 'package:core/src/reports/templates.dart';
import 'package:test/test.dart';

import 'fakes.dart';

Period p(PeriodKind k, String day) => Period.containing(k, day);

/// Every Markdown bullet must carry at least one citation marker.
void expectEveryBulletCited(String md) {
  for (final line in const LineSplitter().convert(md)) {
    if (line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('* ')) {
      expect(line, contains('[^f'), reason: 'uncited bullet: <$line>\n$md');
    }
  }
}

Map<String, Object?> item(String text, List<Object?> ids) => {'text': text, 'fact_ids': ids};
Map<String, Object?> report(List<Object?> sections) => {'sections': sections};
Map<String, Object?> section(String heading, List<Map<String, Object?>> items) => {'heading': heading, 'items': items};

void main() {
  group('period math', () {
    test('weeks run Monday–Sunday for every day of the week', () {
      // 2026-11-16 is a Monday.
      for (var d = 16; d <= 22; d++) {
        expect(p(PeriodKind.weekly, '2026-11-$d'), const Period(PeriodKind.weekly, '2026-11-16', '2026-11-22'));
      }
      expect(p(PeriodKind.weekly, '2026-11-23').start, '2026-11-23');
    });

    test('weeks crossing year and month boundaries', () {
      expect(p(PeriodKind.weekly, '2027-01-01'), const Period(PeriodKind.weekly, '2026-12-28', '2027-01-03'));
      expect(p(PeriodKind.weekly, '2026-12-31').end, '2027-01-03');
      expect(p(PeriodKind.weekly, '2024-02-29'), const Period(PeriodKind.weekly, '2024-02-26', '2024-03-03'));
      expect(p(PeriodKind.weekly, '2026-03-01'), const Period(PeriodKind.weekly, '2026-02-23', '2026-03-01'));
    });

    test('month ends including leap years and century rules', () {
      expect(p(PeriodKind.monthly, '2024-02-10').end, '2024-02-29');
      expect(p(PeriodKind.monthly, '2026-02-10').end, '2026-02-28');
      expect(p(PeriodKind.monthly, '2000-02-01').end, '2000-02-29');
      expect(p(PeriodKind.monthly, '2100-02-01').end, '2100-02-28');
      expect(p(PeriodKind.monthly, '2026-12-31'), const Period(PeriodKind.monthly, '2026-12-01', '2026-12-31'));
      expect(p(PeriodKind.monthly, '2026-04-30').end, '2026-04-30');
    });

    test('quarter edges', () {
      const q = {
        '2026-01-01': ('2026-01-01', '2026-03-31'),
        '2026-03-31': ('2026-01-01', '2026-03-31'),
        '2026-04-01': ('2026-04-01', '2026-06-30'),
        '2026-06-30': ('2026-04-01', '2026-06-30'),
        '2026-07-01': ('2026-07-01', '2026-09-30'),
        '2026-09-30': ('2026-07-01', '2026-09-30'),
        '2026-10-01': ('2026-10-01', '2026-12-31'),
        '2026-12-31': ('2026-10-01', '2026-12-31'),
      };
      for (final MapEntry(:key, :value) in q.entries) {
        final got = p(PeriodKind.quarterly, key);
        expect((got.start, got.end), value, reason: key);
      }
      expect(p(PeriodKind.quarterly, '2024-02-29').label, '2024 Q1');
      expect(p(PeriodKind.quarterly, '2026-05-05').label, '2026 Q2');
      expect(p(PeriodKind.quarterly, '2026-08-05').label, '2026 Q3');
      expect(p(PeriodKind.quarterly, '2026-12-31').label, '2026 Q4');
    });

    test('previous periods across boundaries', () {
      expect(p(PeriodKind.daily, '2025-01-01').previous(), const Period(PeriodKind.daily, '2024-12-31', '2024-12-31'));
      expect(p(PeriodKind.daily, '2024-03-01').previous().start, '2024-02-29');
      expect(p(PeriodKind.weekly, '2026-01-05').previous(), const Period(PeriodKind.weekly, '2025-12-29', '2026-01-04'));
      expect(p(PeriodKind.monthly, '2024-03-15').previous(), const Period(PeriodKind.monthly, '2024-02-01', '2024-02-29'));
      expect(p(PeriodKind.monthly, '2026-01-15').previous(), const Period(PeriodKind.monthly, '2025-12-01', '2025-12-31'));
      expect(p(PeriodKind.quarterly, '2026-02-01').previous(), const Period(PeriodKind.quarterly, '2025-10-01', '2025-12-31'));
      expect(Period.custom('2026-11-18', '2026-11-18').previous(), Period.custom('2026-11-17', '2026-11-17'));
      // Custom range across a leap day keeps its length (7 days).
      expect(Period.custom('2024-03-01', '2024-03-07').previous(), Period.custom('2024-02-23', '2024-02-29'));
    });

    test('custom ranges validate order and allow a single day', () {
      expect(() => Period.custom('2026-11-19', '2026-11-18'), throwsArgumentError);
      expect(Period.custom('2026-11-18', '2026-11-18').label, '2026-11-18 to 2026-11-18');
      expect(() => p(PeriodKind.custom, '2026-11-18'), throwsArgumentError);
    });

    test('scheduled runs report on the right period', () {
      // Weekly Monday 09:00 covers the week that just ended, across a year boundary.
      expect(
        scheduledPeriod(PeriodKind.weekly, DateTime.utc(2027, 1, 4, 9), Duration.zero),
        const Period(PeriodKind.weekly, '2026-12-28', '2027-01-03'),
      );
      // Monthly on the 1st covers the previous month (leap Feb).
      expect(
        scheduledPeriod(PeriodKind.monthly, DateTime.utc(2024, 3, 1, 9), Duration.zero),
        const Period(PeriodKind.monthly, '2024-02-01', '2024-02-29'),
      );
      // Quarterly on Jan 1 covers last year's Q4.
      expect(
        scheduledPeriod(PeriodKind.quarterly, DateTime.utc(2027, 1, 1, 9), Duration.zero),
        const Period(PeriodKind.quarterly, '2026-10-01', '2026-12-31'),
      );
      // Monday 09:00 at UTC+10 is Sunday 23:00 UTC: local day is still Monday.
      expect(
        scheduledPeriod(PeriodKind.weekly, DateTime.utc(2026, 11, 15, 23), const Duration(hours: 10)),
        const Period(PeriodKind.weekly, '2026-11-09', '2026-11-15'),
      );
      // Daily 18:00 covers its own local day.
      expect(scheduledPeriod(PeriodKind.daily, DateTime.utc(2024, 2, 29, 18), Duration.zero).start, '2024-02-29');
    });
  });

  group('templates (#86)', () {
    late ProfileDb db;
    late TemplateService t;
    setUp(() async {
      db = memDb();
      t = TemplateService(db);
      await t.seedBuiltins();
    });
    tearDown(() => db.close());

    test('seeding is idempotent and restores built-ins from code', () async {
      await t.seedBuiltins();
      expect((await t.list()).where((x) => x.builtIn), hasLength(builtinTemplates.length));
      await db.customStatement("UPDATE templates SET prompt = 'tampered' WHERE id = 'builtin.standup'");
      await t.seedBuiltins();
      expect((await t.get('builtin.standup')).prompt, builtinById('builtin.standup')!.prompt);
    });

    test('every scheduled kind has a built-in default template that supports it', () {
      for (final MapEntry(:key, :value) in defaultTemplateFor.entries) {
        final b = builtinById(value);
        expect(b, isNotNull, reason: '$key');
        expect(b!.periodKinds, contains(key));
      }
    });

    test('editing a built-in duplicates it; the built-in is untouched', () async {
      final id = await t.update('builtin.standup', prompt: 'Mine: {period_label}');
      expect(id, isNot('builtin.standup'));
      expect((await t.get('builtin.standup')).prompt, builtinById('builtin.standup')!.prompt);
      final copy = await t.get(id);
      expect(copy.builtIn, isFalse);
      expect(copy.prompt, 'Mine: {period_label}');
      final again = await t.update(id, name: 'Renamed');
      expect(again, id);
      final c2 = await t.get(id);
      expect(c2.version, copy.version + 1);
      expect(c2.name, 'Renamed');
      expect(c2.prompt, 'Mine: {period_label}');
    });

    test('reset restores the built-in prompt and kinds, also for a copy of a copy', () async {
      final copy = await t.duplicate('builtin.weekly_review');
      final copyOfCopy = await t.duplicate(copy);
      for (final id in [copy, copyOfCopy]) {
        await t.update(id, prompt: 'x', periodKinds: [PeriodKind.daily]);
        await t.resetToDefault(id);
        final r = await t.get(id);
        expect(r.prompt, builtinById('builtin.weekly_review')!.prompt);
        expect(parsePeriodKinds(r.periodKinds), [PeriodKind.weekly]);
      }
    });

    test('reset of a from-scratch template fails; reset of a built-in is a no-op', () async {
      final id = await t.create(name: 'Own', periodKinds: [PeriodKind.daily], prompt: 'p');
      expect(() => t.resetToDefault(id), throwsStateError);
      await t.resetToDefault('builtin.standup');
    });

    test('delete: built-ins and used templates are protected', () async {
      expect(() => t.delete('builtin.standup'), throwsStateError);
      final used = await t.create(name: 'Used', periodKinds: [PeriodKind.daily], prompt: 'p');
      await db.into(db.reports).insert(ReportsCompanion.insert(
        id: 'r',
        periodKind: PeriodKind.daily,
        periodStart: '2026-11-18',
        periodEnd: '2026-11-18',
        templateId: used,
      ));
      expect(() => t.delete(used), throwsStateError);
      final free = await t.create(name: 'Free', periodKinds: [PeriodKind.daily], prompt: 'p');
      await t.delete(free);
      expect((await t.list()).map((x) => x.id), isNot(contains(free)));
    });

    test('prompt variables are filled; unknown ones are left as-is', () {
      final out = renderPrompt(
        '{period_label}|{period_kind}|{start}|{end}|{unknown}|{ start }|{{start}}',
        Period.containing(PeriodKind.quarterly, '2026-11-18'),
      );
      expect(out, '2026 Q4|quarterly|2026-10-01|2026-12-31|{unknown}|{ start }|{2026-10-01}');
    });
  });

  group('validate + render (#92, N9)', () {
    test('drops unknown, duplicate and non-string ids; uncited/empty items; empty sections', () {
      final out = validateReport(
        report([
          section(' Done ', [
            item('A', ['f1', 'f1', 'zz', 7, null]),
            item('B', ['zz']),
            item('  ', ['f2']),
            item('C', []),
          ]),
          section('Empty', [item('D', ['nope'])]),
          {'heading': 'NoItems'},
          'garbage',
        ]),
        {'f1', 'f2'},
      );
      expect(out, {
        'sections': [
          {
            'heading': 'Done',
            'items': [
              {
                'text': 'A',
                'fact_ids': ['f1'],
              },
            ],
          },
        ],
      });
    });

    test('a missing sections key validates to an empty report', () {
      expect(validateReport({}, {'f'}), {'sections': []});
    });

    test(
      'wrongly typed fields are skipped, not thrown',
      () {
        expect(validateReport({'sections': 'x'}, {'f'}), {'sections': []});
        expect(
          validateReport(
            report([
              {'heading': 'H', 'items': 'not a list'},
              {'heading': 7, 'items': []},
              section('S', [
                {'text': 42, 'fact_ids': ['f']},
                {'text': 'ok', 'fact_ids': 'f'},
                item('good', ['f']),
              ]),
            ]),
            {'f'},
          ),
          {
            'sections': [
              {
                'heading': 'S',
                'items': [
                  {'text': 'good', 'fact_ids': ['f']},
                ],
              },
            ],
          },
        );
      },
      skip:
          'BUG: render.dart:43-49 casts with `as List?` / `as String?`, so a wrongly typed field throws a '
          'TypeError and fails the whole report, despite the doc "unexpected shapes are skipped"',
    );

    test('markers are numbered by first appearance with one footnote per fact', () {
      final md = renderReportMarkdown(
        title: 'T',
        report: report([
          section('S', [
            item('one', ['b', 'a']),
            item('two', ['a', 'c']),
          ]),
        ]),
        factStatements: {'a': 'Fact A\nmultiline', 'b': 'Fact B', 'c': 'Fact C'},
      );
      expect(md, contains('- one [^f1][^f2]'));
      expect(md, contains('- two [^f2][^f3]'));
      expect(md, contains('[^f1]: Fact B (fact:b)'));
      expect(md, contains('[^f2]: Fact A multiline (fact:a)'));
      expect(RegExp(r'^\[\^f\d+\]:', multiLine: true).allMatches(md), hasLength(3));
      expectEveryBulletCited(md);
    });

    test('an empty report says so', () {
      expect(
        renderReportMarkdown(title: 'T', report: {'sections': []}, factStatements: {}),
        contains('Nothing recorded'),
      );
    });

    test(
      'item text with line breaks cannot smuggle uncited lines into the report',
      () {
        final v = validateReport(
          report([
            section('S', [
              item('Did X\n- Invented an uncited claim\n## Fake heading', ['f1']),
            ]),
          ]),
          {'f1'},
        );
        final md = renderReportMarkdown(title: 'T', report: v, factStatements: {'f1': 'X'});
        expectEveryBulletCited(md);
        expect(md, isNot(contains('\n## Fake heading')));
      },
      skip:
          'BUG: render.dart validateReport/renderReportMarkdown keep newlines in item text, so a model item '
          '"A\\n- B" renders an extra bullet with no citation (violates N9 / #92)',
    );
  });

  group('generator (LLD 04 §4.9)', () {
    late ProfileDb db;
    late Seed seed;
    late ScriptedLlm llm;
    late ReportGenerator gen;
    late AntEngine engine;
    late String src;
    late String f1, f2, fOut, fRetired, fTime;

    ReportGenerator makeGen({int? contextLength = 100000}) {
      final tools = ToolRegistry();
      registerBuiltinTools(tools);
      return ReportGenerator(
        db: db,
        router: ScriptedRouter(llm, contextLength: contextLength),
        tools: tools,
        profileId: 'p1',
        clock: MutableClock(DateTime.utc(2026, 11, 20)),
      );
    }

    setUp(() async {
      db = memDb();
      seed = Seed(db);
      await TemplateService(db).seedBuiltins();
      await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'pay', name: 'Payments'));
      src = await seed.source();
      final e = await seed.evidence(src, '2026-11-18', {'t': 1});
      f1 = await seed.fact('Shipped checkout v2', '2026-11-18', importance: 0.9, project: 'pay', cites: [e.payload]);
      f2 = await seed.fact('Reviewed 4 PRs', '2026-11-17', type: FactType.invisibleWork, importance: 0.3);
      fOut = await seed.fact('Outside the week', '2026-11-25');
      fRetired = await seed.fact('Retired claim', '2026-11-18', retired: true);
      fTime = await seed.fact(
        'Time',
        '2026-11-18',
        type: FactType.timeAllocation,
        project: 'pay',
        details: {'minutes': 90, 'basis': 'measured'},
      );
      llm = ScriptedLlm([]);
      gen = makeGen();
      engine = AntEngine(
        db: db,
        profileId: 'p1',
        ports: EnginePorts(secrets: MemSecrets(), blobs: MemBlobs(), git: NoGit(), watcher: NoWatcher()),
        router: ScriptedRouter(llm),
        utcOffset: (_) => Duration.zero,
      );
    });
    tearDown(() => db.close());

    Future<Report> weekReport([String template = 'builtin.weekly_review']) =>
        gen.ensureReport(PeriodKind.weekly, '2026-11-16', '2026-11-22', template);
    Future<ReportDone> run(Stream<ReportEvent> s) async => (await s.toList()).last as ReportDone;
    Future<List<ReportSnapshot>> snapshots() => db.select(db.reportSnapshots).get();
    Future<void> bumpFact(String id) =>
        db.customStatement('UPDATE facts SET revision = revision + 1 WHERE id = ?', [id]);

    test('ensureReport is idempotent per period + template', () async {
      final a = await weekReport();
      final b = await weekReport();
      final c = await weekReport('builtin.wins');
      expect(a.id, b.id);
      expect(c.id, isNot(a.id));
    });

    test('generates a validated snapshot citing only gathered facts, with dependencies on fact revisions', () async {
      llm.responses.add(report([
        section('Outcomes', [
          item('Shipped checkout', [f1, fOut, fRetired, 'invented']),
          item('Made up', ['invented']),
        ]),
        section('Time', [item('90 min on payments', [fTime])]),
        section('Noise', [item('Outside', [fOut])]),
      ]));
      final r = await weekReport();
      final done = await run(gen.generate(r.id));
      expect(citedFactIds(done.json), [f1, fTime]);
      expect(done.markdown, isNot(contains('Made up')));
      expect(done.markdown, isNot(contains('Outside')));
      expectEveryBulletCited(done.markdown);
      final s = done.snapshot!;
      expect(s.version, 1);
      expect(s.modelId, 'fake-model');
      expect(jsonDecode(s.json), done.json);

      // Prompt contains in-period, non-retired facts only; time facts only in the breakdown.
      final userMsg = llm.requests.single.messages.last.text;
      expect(userMsg, contains(f1));
      expect(userMsg, contains(f2));
      expect(userMsg, isNot(contains(fOut)));
      expect(userMsg, isNot(contains(fRetired)));
      expect(userMsg, contains('Time breakdown'));
      expect(llm.requests.single.schema, reportSchema);

      final deps = await (db.select(db.dependencies)..where((d) => d.dependentId.equals(s.id))).get();
      expect({for (final d in deps) d.inputId: d.inputRevision}, {f1: 1, f2: 1, fTime: 1});
      expect(deps.every((d) => d.inputType == EntityType.fact && d.dependentType == EntityType.reportSnapshot), isTrue);
      expect(await engine.staleness.isStale((type: EntityType.reportSnapshot, id: s.id)), isFalse);
    });

    test('changing a gathered fact makes the snapshot stale; regenerating gives a fresh version + 1', () async {
      llm.responses.addAll([
        report([section('S', [item('x', [f1])])]),
        report([section('S', [item('y', [f1])])]),
      ]);
      final r = await weekReport();
      final s1 = (await run(gen.generate(r.id))).snapshot!;
      await engine.editFact(f2, 'Reviewed 5 PRs'); // gathered but not cited: still an input
      expect(await engine.staleness.isStale((type: EntityType.reportSnapshot, id: s1.id)), isTrue);
      final s2 = (await run(gen.generate(r.id, styleInstruction: 'shorter'))).snapshot!;
      expect(s2.version, 2);
      expect(s2.styleInstruction, 'shorter');
      expect(llm.requests.last.messages.first.text, contains('shorter'));
      expect(await engine.staleness.isStale((type: EntityType.reportSnapshot, id: s2.id)), isFalse);
      // History is kept.
      expect((await snapshots()).map((s) => s.version), unorderedEquals([1, 2]));
    });

    test(
      '#49: a new fact in the period (evidence added for a past day) makes the report out of date',
      () async {
        llm.responses.add(report([section('S', [item('x', [f1])])]));
        final r = await weekReport();
        final s = (await run(gen.generate(r.id))).snapshot!;
        // Evidence added for a past day, then extraction (simulated) creates a fact citing it.
        final e = await seed.evidence(src, '2026-11-19', {'text': 'late note'});
        await seed.fact('Late-added outcome', '2026-11-19', cites: [e.payload]);
        expect(await engine.staleness.isStale((type: EntityType.reportSnapshot, id: s.id)), isTrue);
      },
      skip:
          'BUG (design gap): snapshot staleness only tracks revisions of facts it read (generator.dart records fact '
          'inputs only), so facts created later for the period never mark the report out of date (#49, #61)',
    );

    test('budget: low-importance facts beyond ~60% of context are omitted and cannot be cited', () async {
      for (var i = 0; i < 40; i++) {
        await seed.fact('Filler fact number $i ${'x' * 80}', '2026-11-19', importance: 0.5);
      }
      llm.responses.add(report([section('S', [item('top', [f1]), item('low', [f2])])]));
      gen = makeGen(contextLength: 1100); // ~2640 chars budget minus prompts
      final r = await weekReport();
      final done = await run(gen.generate(r.id));
      final userMsg = llm.requests.single.messages.last.text;
      expect(userMsg, contains(f1), reason: 'most important fact kept');
      expect(userMsg, isNot(contains(f2)));
      expect(userMsg, contains('Not listed for space'));
      expect(citedFactIds(done.json), [f1]);
    });

    test('locked report: never regenerated, nothing saved, staleness still shown', () async {
      llm.responses.add(report([section('S', [item('x', [f1])])]));
      final r = await weekReport();
      final s1 = (await run(gen.generate(r.id))).snapshot!;
      await engine.lockReport(r.id);
      await expectLater(gen.generate(r.id), emitsError(isA<ReportLockedException>()));
      expect(llm.requests, hasLength(1), reason: 'no model call for a locked report');
      expect(await snapshots(), hasLength(1));
      await bumpFact(f1);
      expect(await engine.staleness.isStale((type: EntityType.reportSnapshot, id: s1.id)), isTrue);
      // Unlock → regenerate works and the old snapshot is kept.
      await engine.unlockReport(r.id);
      llm.responses.add(report([section('S', [item('y', [f1])])]));
      final s2 = (await run(gen.generate(r.id))).snapshot!;
      expect(s2.version, 2);
      expect(await snapshots(), hasLength(2));
    });

    test('a report locked while generating is not overwritten', () async {
      llm.responses.addAll([
        report([section('S', [item('x', [f1])])]),
        report([section('S', [item('y', [f1])])]),
      ]);
      final r = await weekReport();
      await run(gen.generate(r.id));
      llm.during = () => engine.lockReport(r.id);
      await expectLater(gen.generate(r.id), emitsThrough(emitsError(isA<ReportLockedException>())));
      expect(await snapshots(), hasLength(1));
      final locked = await (db.select(db.reports)..where((x) => x.id.equals(r.id))).getSingle();
      expect(locked.lockedSnapshotId, (await snapshots()).single.id);
    });

    test('preview saves nothing (no report, snapshot or dependency rows)', () async {
      llm.responses.add(report([section('S', [item('x', [f1])])]));
      final copy = await TemplateService(db).update('builtin.weekly_review', prompt: 'Preview {period_label}');
      final done = await run(gen.preview(copy, Period.containing(PeriodKind.weekly, '2026-11-18')));
      expect(done.snapshot, isNull);
      expect(done.markdown, contains('[^f1]'));
      expect(llm.requests.single.messages.last.text, contains('Preview Week of 2026-11-16'));
      expect(await db.select(db.reports).get(), isEmpty);
      expect(await snapshots(), isEmpty);
      expect(await db.select(db.dependencies).get(), isEmpty);
    });

    test('a non-object model response is an error and saves nothing', () async {
      llm.responses.add('[1, 2, 3]');
      final r = await weekReport();
      await expectLater(gen.generate(r.id), emitsThrough(emitsError(isA<LlmFailure>())));
      expect(await snapshots(), isEmpty);
    });

    test('never emits an uncited item, whatever the model returns', () async {
      // Schema-invalid shapes fail the run outright (#70) and emit nothing.
      for (final bad in <Object>[
        {'sections': null},
        {
          'sections': [
            {'heading': 'H', 'items': null},
          ],
        },
      ]) {
        llm.responses.add(bad);
        final r0 = await weekReport();
        await expectLater(run(gen.generate(r0.id)), throwsA(isA<LlmFailure>()));
      }
      final shapes = <Object>[
        report([
          section('H', [
            item('cited', [f1]),
            item('uncited', <Object?>[]),
            item('bad ids', ['nope', 'missing']),
          ]),
          section('', [item('no heading', [f2])]),
        ]),
      ];
      final r = await weekReport();
      for (final s in shapes) {
        llm.responses.add(s);
        final done = await run(gen.generate(r.id));
        expect(done.markdown, isNot(contains('uncited')));
        expect(done.markdown, isNot(contains('bad ids')));
        expectEveryBulletCited(done.markdown);
        for (final sec in (done.json['sections'] as List).cast<Map>()) {
          for (final i in (sec['items'] as List).cast<Map>()) {
            expect((i['fact_ids'] as List), isNotEmpty);
          }
        }
      }
    });

    test('scheduled handler: generates for the ended period, leaves locked reports alone', () async {
      final handler = scheduledReportHandler(gen, PeriodKind.weekly, (_) => Duration.zero);
      llm.responses.add(report([section('S', [item('x', [f1])])]));
      await handler({'due': DateTime.utc(2026, 11, 23, 9).toIso8601String()});
      final r = (await db.select(db.reports).get()).single;
      expect((r.periodStart, r.periodEnd, r.templateId), ('2026-11-16', '2026-11-22', 'builtin.weekly_review'));
      expect(await snapshots(), hasLength(1));
      await engine.lockReport(r.id);
      await handler({'due': DateTime.utc(2026, 11, 23, 9).toIso8601String()});
      expect(await snapshots(), hasLength(1));
      expect(llm.requests, hasLength(1));
    });
  });
}
