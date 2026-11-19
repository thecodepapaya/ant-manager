/// Independent tests (#99) for the app side of DECISIONS #115: attachment mime through the real
/// blob store, re-adding a removed git repo, the picker's "Added" marks, starred evidence without
/// a win, and cleanup after a failed restore.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/settings/kit.dart' show PanelRow;
import 'package:ant_manager/features/sources/git_setup.dart';
import 'package:ant_manager/state/data.dart' show starredWithoutWinProvider;
import 'package:ant_manager/state/providers.dart';
import 'package:archive/archive.dart';
import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ui/ui.dart';

import 'support.dart';

final _png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);

// The harness profile zone is UTC (support/fakes.dart), so days are UTC days.
String _day(DateTime d) => dayOf(d, Duration.zero);

EngineCommand<void> _setStarredCmd(String id) => (rt) => rt.engine.setStarred(id, true);

/// sources.sync jobs for [sourceId], any state.
Future<int> _syncJobs(EngineHandle h, String sourceId) async => [
      for (final j in await h.db.select(h.db.jobs).get())
        if (j.kind == 'sources.sync' && (jsonDecode(j.args) as Map)['source_id'] == sourceId) j,
    ].length;

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('engine', () {
    late EngineHandle h;
    Future<void> start({bool inMemory = true}) async {
      h = await startEngine(dir, inMemory: inMemory);
      addTearDown(h.shutdown);
    }

    test('dropped images keep their mime through the real blob store, whatever the case', () async {
      await start();
      final id = await h.runtime(addNoteCmd(
        text: 'shots',
        at: DateTime.now(),
        images: [(_png, 'JPG'), (_png, 'jpeg'), (_png, 'HEIC'), (_png, 'PNG'), (_png, 'Gif'), (_png, 'webp')],
      ));
      final payload = (await (h.db.select(h.db.payloads)..where((x) => x.evidenceId.equals(id))).get()).single;
      final atts = await (h.db.select(h.db.attachments)..where((a) => a.payloadId.equals(payload.id))).get();
      expect(atts, hasLength(6), reason: 'one attachment row per image');
      final byExt = {for (final a in atts) p.extension(a.path).substring(1): a.mime};
      expect(byExt, {
        'JPG': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'HEIC': 'image/heic',
        'PNG': 'image/png',
        'Gif': 'image/gif',
        'webp': 'image/webp',
      });
    });

    test('starred evidence: an accepted non-Outcome fact is not a win; an accepted Outcome is', () async {
      await start();
      final now = DateTime.now();
      final decisionOnly = await h.runtime(addNoteCmd(text: 'Chose Postgres', at: now));
      final won = await h.runtime(addNoteCmd(text: 'Shipped search', at: now));
      final suggestedOnly = await h.runtime(addNoteCmd(text: 'Fixed flaky CI', at: now));
      final retiredWin = await h.runtime(addNoteCmd(text: 'Cut costs', at: now));
      final notStarred = await h.runtime(addNoteCmd(text: 'Not starred', at: now));
      final older = await h.runtime(addNoteCmd(text: 'Older star', at: now.subtract(const Duration(days: 3))));
      for (final id in [decisionOnly, won, suggestedOnly, retiredWin, older]) {
        await h.runtime(_setStarredCmd(id));
      }
      await h.runtime(createFactCmd([decisionOnly], type: FactType.decision, winStatus: WinStatus.accepted));
      await h.runtime(createFactCmd([won], type: FactType.outcome, winStatus: WinStatus.accepted));
      await h.runtime(createFactCmd([suggestedOnly], type: FactType.outcome, winStatus: WinStatus.suggested));
      final retired = await h.runtime(createFactCmd([retiredWin], type: FactType.outcome, winStatus: WinStatus.accepted));
      await h.runtime(_retireCmd(retired));
      await h.runtime(createFactCmd([notStarred], type: FactType.decision, winStatus: WinStatus.accepted));

      final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
      addTearDown(c.dispose);
      final expected = {decisionOnly, suggestedOnly, retiredWin};
      final all = await _next(c, starredWithoutWinProvider((start: null, end: null)), (v) => v.isNotEmpty);
      expect(all.map((e) => e.id).toSet(), {...expected, older});
      final today = _day(now);
      final inPeriod =
          await _next(c, starredWithoutWinProvider((start: today, end: today)), (v) => v.isNotEmpty);
      expect(inPeriod.map((e) => e.id).toSet(), expected, reason: 'the older star is outside the period');
    });

    test('a failed restore (unsafe attachment path) leaves no profile row, DB file or blobs', () async {
      await start(inMemory: false);
      await h.runtime(addNoteCmd(text: 'with a screenshot', at: DateTime.now(), images: [(_png, 'png')]));
      final good = await h.runtime(backupNowCmd());
      final src = ZipDecoder().decodeBytes(File(good).readAsBytesSync());
      expect(src.files.where((f) => f.name.startsWith('attachments/')), hasLength(1), reason: 'precondition');
      // The good attachment (and the DB) are written before the unsafe entry is reached.
      final bad = Archive();
      for (final f in src.files) {
        bad.addFile(ArchiveFile.bytes(f.name, f.readBytes()!));
      }
      bad.addFile(ArchiveFile.bytes('attachments/../x', Uint8List.fromList([1])));
      expect(bad.files.map((f) => f.name).last, 'attachments/../x', reason: 'unsafe entry comes after the DB and blob');
      final badFile = File(p.join(dir.path, 'bad.antbackup'))..writeAsBytesSync(ZipEncoder().encodeBytes(bad));
      expect((await h.runtime(inspectBackupCmd(badFile.path))).profile, 'Work', reason: 'manifest still readable');

      await expectLater(
        h.runtime(restoreBackupCmd(badFile.path)),
        throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('Unsafe path'))),
      );
      expect((await h.appDb.select(h.appDb.profiles).get()).map((x) => x.id), [h.profileId]);
      final dbFiles = Directory(p.join(dir.path, 'profiles')).listSync().map((f) => p.basename(f.path));
      expect(dbFiles.where((f) => !f.startsWith(h.profileId)), isEmpty, reason: 'no restored DB file left');
      final blobDirs = Directory(p.join(dir.path, 'blobs')).listSync().map((f) => p.basename(f.path));
      expect(blobDirs.toList(), [h.profileId], reason: 'no restored blobs dir left, nothing escaped to blobs/x');
    });
  });

  group('repo paths', () {
    SourceStatus src(String id, SourceKind kind, Map<String, Object?> config, {bool enabled = true}) =>
        SourceStatus(SourceRow(id: id, kind: kind, name: id, config: jsonEncode(config), enabled: enabled), null, null);

    final sources = [
      src('a', SourceKind.gitRepo, {'path': '/r/a'}, enabled: false),
      src('b', SourceKind.gitRepo, {'path': '/r/b'}),
      src('nopath', SourceKind.gitRepo, {}),
      src('ics', SourceKind.ics, {'path': '/r/ics'}),
    ];

    test('repoSourcesByPath: git repos only, disabled included, no path skipped', () {
      final m = repoSourcesByPath(sources);
      expect(m.map((k, v) => MapEntry(k, (v.id, v.enabled))), {'/r/a': ('a', false), '/r/b': ('b', true)});
    });

    test('existingRepoPaths includes removed repos; activeRepoPaths only enabled ones', () {
      expect(existingRepoPaths(sources), {'/r/a', '/r/b'});
      expect(activeRepoPaths(sources), {'/r/b'});
    });
  });

  testWidgets('re-adding a removed repo re-enables its row and syncs it; an added one is skipped', (tester) async {
    late WidgetRef ref;
    final (c, h) = await bootPage(tester, dir, Consumer(builder: (context, r, _) {
      ref = r;
      return const SizedBox();
    }));
    final a = await cmd(tester, h, addSourceCmd(SourceKind.gitRepo, 'a', {'path': '/r/a'}));
    final b = await cmd(tester, h, addSourceCmd(SourceKind.gitRepo, 'b', {'path': '/r/b'}));
    await cmd(tester, h, removeSourceCmd(a));
    final sources = c.listen(sourcesProvider, (_, _) {});
    addTearDown(sources.close);
    await settle(tester,
        until: () => (sources.read().value ?? const []).any((s) => s.row.id == a && !s.row.enabled));
    expect(await read(tester, () => _syncJobs(h, a)), 0, reason: 'precondition');
    expect(await read(tester, () => _syncJobs(h, b)), 0, reason: 'precondition');

    final scan = RepoScanController(ref);
    addTearDown(scan.dispose);
    scan.selected.addAll(['/r/a', '/r/b']);
    expect(await tester.runAsync(() => scan.addSelected(sources.read().value!)), 1);

    final rows = await read(tester, () => h.db.select(h.db.sources).get());
    final forA = rows.where((r) => jsonDecode(r.config)['path'] == '/r/a').toList();
    expect(forA.map((r) => (r.id, r.enabled)), [(a, true)], reason: 'one row, re-enabled, not duplicated');
    expect(rows, hasLength(2));
    expect(await read(tester, () => _syncJobs(h, a)), 1);
    expect(await read(tester, () => _syncJobs(h, b)), 0, reason: 'an already-added repo is skipped');

    // Once the stream shows it enabled, a second run adds nothing.
    await settle(tester, until: () => (sources.read().value ?? const []).every((s) => s.row.enabled));
    expect(await tester.runAsync(() => scan.addSelected(sources.read().value!)), 0);
    expect(await read(tester, () => h.db.select(h.db.sources).get()), hasLength(2));
    expect(await read(tester, () => _syncJobs(h, a)), 1);
    await killEngine(tester, h);
  });

  group('git setup dialog', () {
    late _PendingHandle h;
    setUp(() => h = _PendingHandle());

    SourceStatus repo(String id, String path, {required bool enabled}) => SourceStatus(
        SourceRow(id: id, kind: SourceKind.gitRepo, name: id, config: jsonEncode({'path': path}), enabled: enabled),
        null,
        null);

    Future<void> flush(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    Finder rowOf(String name) => find.ancestor(of: find.text(name), matching: find.byType(PanelRow));

    testWidgets('a removed repo is tickable, not "Added", and Add re-enables it (update + sync, no new source)', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          engineProvider.overrideWith(() => _FakeEngine(h)),
          profilesProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
          sourcesProvider.overrideWith((ref) => Stream.value([
                repo('a', '/r/removed', enabled: false),
                repo('b', '/r/active', enabled: true),
              ])),
          identitiesProvider.overrideWith((ref) => Stream.value(const <Identity>[])),
        ],
        child: pageApp(Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const GitSetupDialog()),
            child: const Text('open'),
          ),
        )),
      ));
      await tester.tap(find.text('open'));
      await flush(tester);
      h.calls[0].complete(const GitStatus('/usr/bin/git', '2.40'));
      await flush(tester);
      const authors = {'x@y.z': ('X', 3)};
      h.calls[1].complete([
        const RepoScan(path: '/r/removed', lastCommitAt: null, myCommits: 0, authors: authors),
        const RepoScan(path: '/r/active', lastCommitAt: null, myCommits: 0, authors: authors),
      ]);
      await flush(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.descendant(of: rowOf('active'), matching: find.text('Added')), findsOneWidget);
      expect(find.descendant(of: rowOf('removed'), matching: find.text('Added')), findsNothing);
      // Auto-selected (has commits) and counted; the active one is not counted.
      AntCheckbox box(String name) => tester.widget(find.descendant(of: rowOf(name), matching: find.byType(AntCheckbox)));
      expect((box('removed').value, box('removed').onChanged != null), (true, true));
      expect((box('active').value, box('active').onChanged), (true, null));
      expect(find.text('Add 1 repo'), findsOneWidget);

      await tester.tap(find.text('removed'));
      await tester.pump();
      expect(box('removed').value, isFalse, reason: 'tickable');
      expect(find.text('Add repos'), findsOneWidget);
      await tester.tap(find.text('removed'));
      await tester.pump();
      expect(find.text('Add 1 repo'), findsOneWidget);
      expect(h.calls, hasLength(2), reason: 'nothing written yet');

      // Add: the removed repo is re-enabled (a void update), then synced; never added as a new source.
      await tester.tap(find.text('Add 1 repo'));
      await flush(tester);
      expect(h.types.sublist(2), [_typeOf<void>()], reason: 'updateSourceCmd, not addSourceCmd (String)');
      h.calls[2].complete(null);
      await flush(tester);
      expect(h.types.sublist(2), [_typeOf<void>(), bool], reason: 'then syncSourceCmd');
      h.calls[3].complete(true);
      await flush(tester);
      expect(h.calls, hasLength(4), reason: 'the already-added repo is skipped');
      await tester.pumpAndSettle();
      expect(find.text('Added 1 repo · importing the last 30 days'), findsOneWidget);
      expect(find.byType(GitSetupDialog), findsNothing, reason: 'dialog closed');
      await tester.pump(const Duration(seconds: 10)); // let the toast expire
    });
  });
}

EngineCommand<void> _retireCmd(String factId) => (rt) =>
    (rt.db.update(rt.db.facts)..where((f) => f.id.equals(factId))).write(const FactsCompanion(retired: Value(true)));

class _FixedEngine extends EngineController {
  _FixedEngine(this.h);
  final EngineHandle h;
  @override
  Future<EngineHandle> build() async => h;
}

/// Every runtime() call stays pending until the test completes it, in call order.
class _PendingHandle implements EngineHandle {
  final calls = <Completer<Object?>>[];

  /// The result type of each call (commands are closures; their type tells them apart).
  final types = <Type>[];
  @override
  Future<T> runtime<T>(EngineCommand<T> cmd) {
    final c = Completer<Object?>();
    calls.add(c);
    types.add(T);
    return c.future.then((v) => v as T);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnsupportedError('_PendingHandle: ${i.memberName}');
}

class _FakeEngine extends EngineController {
  _FakeEngine(this.h);
  final _PendingHandle h;
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

Type _typeOf<T>() => T;
