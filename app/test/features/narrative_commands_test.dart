/// Engine-level tests for the narrative-side screens (Today, Timeline, Narrative, Reports, Wins,
/// Projects): every write goes through the commands in `engine/commands.dart`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/state/data.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:ant_manager/widgets/common.dart' show originLabel;
import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

final _png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
final _jpg = Uint8List.fromList([255, 216, 255, 224, 9, 9]);

// The harness profile zone is UTC (support/fakes.dart), so days are UTC days.
String _day(DateTime d) => dayOf(d, Duration.zero);

EngineCommand<void> _setStarredCmd(String id) => (rt) => rt.engine.setStarred(id, true);

void main() {
  late Directory dir;
  late EngineHandle h;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> start() async {
    h = await startEngine(dir);
    addTearDown(h.shutdown);
  }

  String blob(String rel) => p.join(dir.path, 'blobs', h.profileId, rel);

  Future<String> note(String text, {DateTime? at, List<(Uint8List, String)> images = const []}) =>
      h.runtime(addNoteCmd(text: text, at: at ?? DateTime.now(), images: images));

  Future<List<Payload>> payloadsOf(String evidenceId) =>
      (h.db.select(h.db.payloads)
            ..where((x) => x.evidenceId.equals(evidenceId))
            ..orderBy([(x) => OrderingTerm.asc(x.id)])) // same order as evidenceProvider
          .get();

  group('notes and evidence', () {
    setUp(start);

    test('a note at local noon of a past day lands on that day', () async {
      final at = DateTime(2026, 3, 4, 12);
      final id = await note('Fixed the flaky deploy', at: at);
      final e = await evidenceOf(h, id);
      expect(e.day, '2026-03-04');
      expect(e.occurredStart.toLocal(), at);
      expect(e.title, 'Fixed the flaky deploy');
    });

    test('annotate adds a note payload to the existing evidence', () async {
      final id = await note('Release 1.2');
      final again = await h.runtime(addNoteCmd(text: 'Took 3 days: flaky CI', at: DateTime.now(), attachTo: id));
      expect(again, id);
      expect(await h.db.select(h.db.evidences).get(), hasLength(1));
      final ps = await payloadsOf(id);
      expect(ps, hasLength(2));
      expect(ps.map((x) => x.kind).toSet(), {PayloadKind.note});
      final item = EvidenceItem(await evidenceOf(h, id), ps, const {});
      expect(item.annotations.map(payloadText), ['Took 3 days: flaky CI']);
    });

    test('pasted / dropped images become attachments with blobs on disk', () async {
      final id = await note('Screenshot', images: [(_png, 'png'), (_jpg, 'jpg')]);
      final ps = await payloadsOf(id);
      expect(ps.single.kind, PayloadKind.image);
      final atts = await (h.db.select(h.db.attachments)..where((a) => a.payloadId.equals(ps.single.id))).get();
      expect(atts.map((a) => a.mime).toList()..sort(), ['image/jpeg', 'image/png']);
      for (final a in atts) {
        expect(File(blob(a.path)).readAsBytesSync(), a.mime == 'image/png' ? _png : _jpg);
      }
      final item = EvidenceItem(await evidenceOf(h, id), ps, const {});
      expect(item.attachments.toSet(), atts.map((a) => a.path).toSet());
    });

    test(
      'dropped GIF / WebP images keep their own mime type',
      skip: 'BUG: packages/core/lib/src/engine/engine.dart:117 maps every non-.png attachment to image/jpeg, '
          'but NoteComposer accepts gif/webp/heic (app/lib/widgets/note_composer.dart:14)',
      () async {
        final id = await note('Anim', images: [(_png, 'gif'), (_png, 'webp')]);
        final ps = await payloadsOf(id);
        final atts = await (h.db.select(h.db.attachments)..where((a) => a.payloadId.equals(ps.single.id))).get();
        expect(atts.map((a) => a.mime).toSet(), {'image/gif', 'image/webp'});
      },
    );

    test('annotating a screenshot note shows the annotation, not the screenshot body', () async {
      final id = await note('Screenshot', images: [(_png, 'png')]);
      await h.runtime(addNoteCmd(text: 'This is the bug', at: DateTime.now(), attachTo: id));
      final item = EvidenceItem(await evidenceOf(h, id), await payloadsOf(id), const {});
      expect(item.annotations.map(payloadText), ['This is the bug']);
    });

    test('hide and unhide', () async {
      final id = await note('Lunch');
      await h.runtime(setHiddenCmd(id, true));
      var e = await evidenceOf(h, id);
      expect(e.hidden, isTrue);
      expect(e.importance, 0);
      await h.runtime(setHiddenCmd(id, false));
      e = await evidenceOf(h, id);
      expect(e.hidden, isFalse);
      expect(e.importanceSetBy, isNull, reason: 'back to model/rule scoring');
    });

    test('unstar clears the star', () async {
      final id = await note('Shipped search');
      // An Outcome fact already covers it, so starring needs no model call.
      await h.runtime(createFactCmd([id], statement: 'Shipped search'));
      await h.runtime(starEvidenceCmd(id));
      expect((await evidenceOf(h, id)).starred, isTrue);
      await h.runtime(unstarEvidenceCmd(id));
      final e = await evidenceOf(h, id);
      expect(e.starred, isFalse);
      expect(e.importanceSetBy, isNull);
    });
  });

  group('starring', () {
    late FakeLlm llm;
    setUp(() async {
      llm = await FakeLlm.start();
      addTearDown(llm.close);
      await start();
      await addFakeModel(h, llm);
    });

    test('evidence with no Outcome fact gets an accepted win from one model call', () async {
      final id = await note('Migrated billing to v2');
      final before = llm.chatCalls;
      final factId = await h.runtime(starEvidenceCmd(id));
      expect(llm.chatCalls - before, 1);
      final f = await factOf(h, factId);
      expect(f.type, FactType.outcome);
      expect(f.winStatus, WinStatus.accepted);
      expect(f.origin, FactOrigin.userCreated);
      expect(f.statement, 'Shipped the thing');
      final cites = await (h.db.select(h.db.citations)..where((c) => c.factId.equals(factId))).get();
      expect(cites.map((c) => c.payloadId), (await payloadsOf(id)).map((x) => x.id));
      expect((await evidenceOf(h, id)).starred, isTrue);
    });

    test('an existing Outcome fact becomes the win without a model call', () async {
      final id = await note('Cut p99 latency');
      final factId = await h.runtime(createFactCmd([id], statement: 'Cut p99 latency by 40%'));
      final before = llm.chatCalls;
      expect(await h.runtime(starEvidenceCmd(id)), factId);
      expect(llm.chatCalls, before);
      final f = await factOf(h, factId);
      expect(f.winStatus, WinStatus.accepted);
      expect(f.origin, FactOrigin.confirmed);
    });

    test('when the model call fails the evidence stays starred and is "not written up yet"', () async {
      final id = await note('Mentored the new hire');
      llm.fail = true;
      await expectLater(h.runtime(starEvidenceCmd(id)), throwsA(isA<EngineCommandException>()));
      expect((await evidenceOf(h, id)).starred, isTrue);
      expect(await h.db.select(h.db.facts).get(), isEmpty);

      final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
      addTearDown(c.dispose);
      final starred = await _next(c, starredWithoutWinProvider((start: null, end: null)), (v) => v.isNotEmpty);
      expect(starred.map((e) => e.id), [id]);
      // Bounded by a period (Wins page filters), it is still listed.
      final today = _day(DateTime.now());
      final inPeriod = await _next(c, starredWithoutWinProvider((start: today, end: today)), (_) => true);
      expect(inPeriod.map((e) => e.id), [id]);

      // A subscribed list picks up later stars.
      final id2 = await note('Later star');
      final live = c.listen(starredWithoutWinProvider((start: today, end: today)), (_, _) {});
      addTearDown(live.close);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await h.runtime(_setStarredCmd(id2));
      final end = DateTime.now().add(const Duration(seconds: 5));
      while ((live.read().value?.length ?? 0) < 2 && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(live.read().value?.map((e) => e.id).toSet(), {id, id2});
      await h.runtime(unstarEvidenceCmd(id2));

      // Retrying once the model is back writes the win and clears the list.
      llm.fail = false;
      await h.runtime(starEvidenceCmd(id));
      expect(await _next(c, starredWithoutWinProvider((start: null, end: null)), (v) => v.isEmpty), isEmpty);
    });
  });

  group('delete permanently', () {
    setUp(start);

    test('removes the evidence, facts citing only it, and its blobs', () async {
      final a = await note('Pairing session', images: [(_png, 'png')]);
      await h.runtime(addNoteCmd(text: 'context', at: DateTime.now(), attachTo: a));
      final b = await note('Design review');
      final only = await h.runtime(createFactCmd([a], statement: 'Only A'));
      final both = await h.runtime(createFactCmd([a, b], statement: 'A and B'));
      final blobs = [for (final x in await h.db.select(h.db.attachments).get()) blob(x.path)];
      expect(blobs, hasLength(1));
      expect(File(blobs.single).existsSync(), isTrue);

      await h.runtime(deleteEvidenceCmd(a));

      expect((await h.db.select(h.db.evidences).get()).map((e) => e.id), [b]);
      expect(await payloadsOf(a), isEmpty);
      expect(await h.db.select(h.db.attachments).get(), isEmpty);
      expect(File(blobs.single).existsSync(), isFalse);
      final facts = await h.db.select(h.db.facts).get();
      expect(facts.map((f) => f.id), [both], reason: '$only cited only the deleted evidence');
      final cites = await (h.db.select(h.db.citations)..where((c) => c.factId.equals(both))).get();
      expect(cites.map((c) => c.payloadId), (await payloadsOf(b)).map((x) => x.id));
      expect(await (h.db.select(h.db.factRevisions)..where((r) => r.factId.equals(only))).get(), isEmpty);
    });
  });

  group('facts, review, reports', () {
    late FakeLlm llm;
    late String ev;
    late String fact;
    late String report;
    late String snap;

    setUp(() async {
      llm = await FakeLlm.start();
      addTearDown(llm.close);
      await start();
      await addFakeModel(h, llm);
      final today = _day(DateTime.now());
      ev = await note('Shipped onboarding v2');
      fact = await h.runtime(createFactCmd([ev], statement: 'Shipped onboarding v2', day: today));
      report = await h.runtime(ensureReportCmd(PeriodKind.daily, today, today, defaultTemplateFor[PeriodKind.daily]!));
      snap = await h.runtime(generateReportCmd(report));
      await h.runtime(clearRecomputeCmd());
    });

    Future<bool> stale() => StalenessService(h.db).isStale((type: EntityType.reportSnapshot, id: snap));

    test('a generated report cites the fact and is up to date', () async {
      final s = await (h.db.select(h.db.reportSnapshots)..where((x) => x.id.equals(snap))).getSingle();
      expect(s.markdown, contains('(fact:$fact)'));
      expect(await stale(), isFalse);
    });

    test('confirm: Inferred → Confirmed and re-queues the report snapshot', () async {
      expect(originLabel((await factOf(h, fact)).origin), 'Inferred');
      await h.runtime(confirmFactCmd(fact));
      expect(originLabel((await factOf(h, fact)).origin), 'Confirmed');
      expect(await recomputeEntries(h), contains((EntityType.reportSnapshot, snap)));
      expect(await stale(), isTrue);
    });

    test('edit: new statement, "Edited by you", re-queues the report snapshot', () async {
      await h.runtime(editFactCmd(fact, 'Shipped onboarding v2 to all users'));
      final f = await factOf(h, fact);
      expect(f.statement, 'Shipped onboarding v2 to all users');
      expect(originLabel(f.origin), 'Edited by you');
      expect(await recomputeEntries(h), contains((EntityType.reportSnapshot, snap)));
      expect(await stale(), isTrue);
    });

    test('reject: retired, rejected, "Edited by you", re-queues the report snapshot', () async {
      await h.runtime(rejectFactCmd(fact));
      final f = await factOf(h, fact);
      expect(f.retired, isTrue);
      expect(f.winStatus, WinStatus.rejected);
      expect(originLabel(f.origin), 'Edited by you');
      expect(await recomputeEntries(h), contains((EntityType.reportSnapshot, snap)));
      expect(await stale(), isTrue);
    });

    test('review: Accept applies the proposed statement', () async {
      await h.runtime(confirmFactCmd(fact));
      await h.runtime(proposeCmd(fact, {'op': 'review', 'statement': 'Shipped onboarding v3'}));
      expect((await factOf(h, fact)).reviewState, ReviewState.needsReview);
      await h.runtime(resolveReviewCmd(fact, accept: true));
      final f = await factOf(h, fact);
      expect(f.statement, 'Shipped onboarding v3');
      expect(f.retired, isFalse);
      expect(f.reviewState, ReviewState.ok);
      expect(f.reviewProposal, isNull);
      expect(f.origin, FactOrigin.confirmed);
    });

    test('review: Accept on a retire proposal retires the fact', () async {
      await h.runtime(confirmFactCmd(fact));
      await h.runtime(proposeCmd(fact, {'op': 'review', 'retire': true}));
      await h.runtime(resolveReviewCmd(fact, accept: true));
      final f = await factOf(h, fact);
      expect(f.retired, isTrue);
      expect(f.reviewState, ReviewState.ok);
    });

    test('review: Keep mine clears the review and keeps the statement', () async {
      await h.runtime(editFactCmd(fact, 'My wording'));
      final rev = (await factOf(h, fact)).revision;
      await h.runtime(proposeCmd(fact, {'op': 'review', 'statement': 'Model wording'}));
      await h.runtime(resolveReviewCmd(fact, accept: false));
      final f = await factOf(h, fact);
      expect(f.statement, 'My wording');
      expect(f.reviewState, ReviewState.ok);
      expect(f.reviewProposal, isNull);
      expect(f.revision, rev);
    });

    test('a locked report is not regenerated, on demand or on schedule', () async {
      await h.runtime(lockReportCmd(report));
      final calls = llm.chatCalls;
      await expectLater(
        h.runtime(generateReportCmd(report)),
        throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('locked'))),
      );
      final today = DateTime.now().toUtc(); // the harness profile zone is UTC
      await h.runtime(enqueueJobCmd(
        Scheduler.dailyReport,
        args: {'due': DateTime.utc(today.year, today.month, today.day, 23).toIso8601String()},
      ));
      expect(await h.runtime(runJobCmd(JobLane.llm)), isTrue);
      expect(llm.chatCalls, calls);
      expect(await (h.db.select(h.db.reportSnapshots)..where((s) => s.reportId.equals(report))).get(), hasLength(1));
      final r = await (h.db.select(h.db.reports)..where((x) => x.id.equals(report))).getSingle();
      expect(r.lockedSnapshotId, snap);

      await h.runtime(unlockReportCmd(report));
      await h.runtime(generateReportCmd(report));
      expect(await (h.db.select(h.db.reportSnapshots)..where((s) => s.reportId.equals(report))).get(), hasLength(2));
    });

    test('a locked report goes stale ("facts changed since lock") when a cited fact changes', () async {
      await h.runtime(lockReportCmd(report));
      expect(await stale(), isFalse);
      await h.runtime(editFactCmd(fact, 'Changed after lock'));
      expect(await stale(), isTrue);
    });
  });

  group('workstreams', () {
    setUp(start);

    test('merging moves every fact and deletes the source workstream', () async {
      final ev = await note('Work');
      await h.runtime(insertWorkstreamCmd('ws-a', 'Checkout'));
      await h.runtime(insertWorkstreamCmd('ws-b', 'Payments'));
      final f1 = await h.runtime(createFactCmd([ev], workstreamId: 'ws-a'));
      final f2 = await h.runtime(createFactCmd([ev], workstreamId: 'ws-a'));
      final f3 = await h.runtime(createFactCmd([ev], workstreamId: 'ws-b'));
      await h.runtime(mergeWorkstreamsCmd('ws-a', 'ws-b'));
      final ws = await h.db.select(h.db.workstreams).get();
      expect(ws.map((w) => w.id), ['ws-b']);
      expect(ws.single.userTouched, isTrue);
      for (final f in [f1, f2, f3]) {
        expect((await factOf(h, f)).workstreamId, 'ws-b');
      }
    });

    test('moving a fact marks the target workstream user-touched', () async {
      final ev = await note('Work');
      await h.runtime(insertWorkstreamCmd('ws-a', 'Checkout'));
      await h.runtime(insertWorkstreamCmd('ws-b', 'Payments'));
      final f = await h.runtime(createFactCmd([ev], workstreamId: 'ws-a'));
      await h.runtime(moveFactToWorkstreamCmd(f, 'ws-b'));
      expect((await factOf(h, f)).workstreamId, 'ws-b');
      final ws = {for (final w in await h.db.select(h.db.workstreams).get()) w.id: w};
      expect(ws['ws-b']!.userTouched, isTrue);
      expect(ws['ws-b']!.spanStart, (await factOf(h, f)).periodStart);
      await h.runtime(moveFactToWorkstreamCmd(f, null));
      expect((await factOf(h, f)).workstreamId, isNull);
    });
  });

  group('projects', () {
    setUp(start);

    test('create, rename, archive and the evidence / fact / win counts', () async {
      final id = await h.runtime(createProjectCmd('Checkout', colour: '#112233'));
      final ev = await note('Built cart');
      await h.runtime(setEvidenceProjectCmd(ev, id));
      await h.runtime(createFactCmd([ev], projectId: id));
      await h.runtime(createFactCmd([ev], projectId: id, winStatus: WinStatus.accepted));
      await h.runtime(createFactCmd([ev], projectId: id, type: FactType.hiccup));
      await h.runtime(updateProjectCmd(id, name: 'Checkout v2'));
      await h.runtime(updateProjectCmd(id, archived: true));

      final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
      addTearDown(c.dispose);
      final stats = await _next(c, projectStatsProvider, (v) => v.isNotEmpty);
      final s = stats.single;
      expect(s.p.name, 'Checkout v2');
      expect(s.p.colour, '#112233');
      expect(s.p.archived, isTrue);
      expect((s.evidence, s.facts, s.wins), (1, 3, 1));
      // Archived projects leave the pickers.
      expect(await _next(c, projectsProvider, (_) => true), isEmpty);
    });
  });

  group('timeline queries', () {
    setUp(start);

    test('a page is the newest N; source and project filters narrow it', () async {
      final base = DateTime(2026, 1, 1, 9);
      final ids = [for (var i = 0; i < 5; i++) await note('n$i', at: base.add(Duration(days: i)))];
      final proj = await h.runtime(createProjectCmd('P'));
      await h.runtime(setEvidenceProjectCmd(ids[1], proj));
      await h.runtime(setEvidenceProjectCmd(ids[3], proj));
      final transcript = await h.runtime(importTranscriptCmd('standup.txt', 'We talked', base.add(const Duration(days: 9))));
      final transcriptSource = (await payloadsOf(transcript)).single.sourceId;

      final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
      addTearDown(c.dispose);
      Future<List<String>> q({String? source, String? project, int limit = 100}) async => [
            for (final e in await _next(
                c, evidenceProvider((day: null, sourceId: source, projectId: project, limit: limit)), (_) => true))
              e.e.id,
          ];
      expect(await q(limit: 3), [transcript, ids[4], ids[3]]);
      expect(await q(project: proj), [ids[3], ids[1]]);
      expect(await q(source: transcriptSource), [transcript]);
    });
  });
}

/// Serves an already started handle through [engineProvider] (for read-model providers).
class _FixedEngine extends EngineController {
  _FixedEngine(this.h);
  final EngineHandle h;
  @override
  Future<EngineHandle> build() async => h;
}

Future<T> _next<T>(ProviderContainer c, ProviderListenable<AsyncValue<T>> provider, bool Function(T) where) {
  final done = Completer<T>();
  final sub = c.listen(provider, (_, v) {
    final value = v.value;
    if (value is T && where(value) && !done.isCompleted) done.complete(value);
  }, fireImmediately: true);
  return done.future.timeout(const Duration(seconds: 5)).whenComplete(sub.close);
}
