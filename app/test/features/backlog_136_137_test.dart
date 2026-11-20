/// Independent tests (#99) for DECISIONS #136 (search in long Identities / Repositories lists) and #137
/// (simpler onboarding Welcome; manage added providers on the AI-model step).
library;

import 'dart:async';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/onboarding/onboarding_page.dart';
import 'package:ant_manager/features/settings/kit.dart';
import 'package:ant_manager/features/settings/provider_dialog.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/sources/git_setup.dart';
import 'package:ant_manager/features/sources/identities_tab.dart';
import 'package:ant_manager/features/sources/sources_page.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

Finder _button(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

Finder _search(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

/// [title] as a list row's text (not the search field's own text).
Finder _rowText(String title) => find.descendant(of: find.byType(PanelRow), matching: find.text(title));

Finder _rowOf(String title) => find.ancestor(of: _rowText(title), matching: find.byType(PanelRow));

AntCheckbox _box(WidgetTester tester, String title) =>
    tester.widget<AntCheckbox>(find.descendant(of: _rowOf(title), matching: find.byType(AntCheckbox)));

/// Every runtime() call stays pending until the test answers it, in call order.
class _PendingHandle implements EngineHandle {
  final calls = <Completer<Object?>>[];
  @override
  Future<T> runtime<T>(EngineCommand<T> cmd) {
    final c = Completer<Object?>();
    calls.add(c);
    return c.future.then((v) => v as T);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnsupportedError('PendingHandle: ${i.memberName}');
}

class _FakeEngine extends EngineController {
  _FakeEngine(this.h);
  final _PendingHandle h;
  @override
  Future<EngineHandle> build() async => h;
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

String _person(int i) => 'Person ${i.toString().padLeft(2, '0')}';
String _email(int i) => 'p${i.toString().padLeft(2, '0')}@x.dev';
const _bot = 'dependabot[bot]@users.noreply.github.com';

/// [n] people across [n] repos: person i commits to n - i repos (so the order is fixed), the bot to all.
List<RepoScan> _scans(int n, {bool bot = true}) => [
      for (var j = 0; j < n; j++)
        RepoScan(path: '/tmp/repos/r$j', lastCommitAt: null, myCommits: 0, authors: {
          for (var i = 0; i <= j; i++) _email(i): (_person(i), 1),
          if (bot) _bot: ('dependabot[bot]', 1),
        }),
    ];

/// A host that owns a [RepoScanController] with scripted state and shows a [RepoPicker].
class _PickerHost extends ConsumerStatefulWidget {
  const _PickerHost(this.repos);
  final List<RepoScan> repos;
  @override
  ConsumerState<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends ConsumerState<_PickerHost> {
  late final c = RepoScanController(ref)
    ..git = const GitStatus('/usr/bin/git', '2.40')
    ..checking = false
    ..repos = widget.repos;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: RepoPicker(c: c));
}

void main() {
  group('matchesQuery', () {
    test('an empty or blank query matches everything', () {
      expect(matchesQuery('', ['a']), isTrue);
      expect(matchesQuery('   ', ['a']), isTrue);
      expect(matchesQuery('', const []), isTrue);
    });

    test('case-insensitive substring, query trimmed', () {
      expect(matchesQuery('ADA', ['Ada Lovelace']), isTrue);
      expect(matchesQuery('  love ', ['Ada Lovelace']), isTrue);
      expect(matchesQuery('LoVe', ['ada lovelace']), isTrue);
      expect(matchesQuery('grace', ['Ada Lovelace']), isFalse);
    });

    test('matches on any field', () {
      expect(matchesQuery('x.dev', ['Ada', 'ada@x.dev']), isTrue);
      expect(matchesQuery('ada', ['Someone', 'ada@x.dev']), isTrue);
      expect(matchesQuery('zz', ['Ada', 'ada@x.dev']), isFalse);
      expect(matchesQuery('ada', const []), isFalse);
    });

    test('the threshold is 8', () => expect(listSearchThreshold, 8));
  });

  group('onboarding identities step (#136)', () {
    late _PendingHandle h;
    setUp(() => h = _PendingHandle());

    Future<void> toIdentities(WidgetTester tester, List<RepoScan> repos, {String? me}) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          engineProvider.overrideWith(() => _FakeEngine(h)),
          profilesProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
          activeProfileProvider.overrideWithValue(null),
          sourcesProvider.overrideWith((ref) => Stream.value(const <SourceStatus>[])),
        ],
        child: pageApp(const OnboardingPage()),
      ));
      await _flush(tester);
      h.calls[0].complete(const GitStatus('/usr/bin/git', '2.40')); // checkGit
      await _flush(tester);
      h.calls[1].complete(repos); // scan
      await _flush(tester);
      h.calls[2].complete(me); // git global email
      await _flush(tester);
      await tester.tap(_button('Get started'));
      await _flush(tester);
      await tester.tap(_button('Continue')); // no active profile: nothing saved
      await _flush(tester);
      expect(find.text('Which of these are you?'), findsOneWidget);
      expect(h.calls, hasLength(3));
    }

    int boxes() => find.byType(AntCheckbox).evaluate().length;

    testWidgets('8 people (plus a bot): no search field, no "Show all", bot not listed', (tester) async {
      await toIdentities(tester, _scans(8));
      expect(find.byKey(const Key('onboarding-people-search')), findsNothing);
      expect(boxes(), 8);
      expect(find.textContaining('Show all'), findsNothing);
      expect(find.text('dependabot[bot]'), findsNothing);
    });

    testWidgets('more than 8 people: field shown; first 8 + "Show all 12 people" reveals the rest', (tester) async {
      await toIdentities(tester, _scans(12));
      expect(find.byKey(const Key('onboarding-people-search')), findsOneWidget);
      expect(boxes(), 8);
      expect(find.text(_person(0)), findsOneWidget);
      expect(find.text(_person(7)), findsOneWidget);
      expect(find.text(_person(8)), findsNothing);
      expect(_button('Show all 12 people'), findsOneWidget, reason: 'the bot is not counted');
      await tester.tap(_button('Show all 12 people'));
      await _flush(tester);
      expect(boxes(), 12);
      expect(find.text(_person(11)), findsOneWidget);
      expect(find.textContaining('Show all'), findsNothing);
      expect(find.text('dependabot[bot]'), findsNothing);
    });

    testWidgets('a query shows every match (name or email) and hides "Show all"', (tester) async {
      await toIdentities(tester, _scans(12));
      await tester.enterText(_search('onboarding-people-search'), 'PERSON 1');
      await _flush(tester);
      expect(boxes(), 2); // Person 10, Person 11 (Person 01 is "person 01")
      expect(find.text(_person(10)), findsOneWidget);
      expect(find.text(_person(11)), findsOneWidget);
      expect(find.textContaining('Show all'), findsNothing);

      // Email field; more than 8 matches are all shown when searching.
      await tester.enterText(_search('onboarding-people-search'), '@x.dev');
      await _flush(tester);
      expect(boxes(), 12);
      expect(find.textContaining('Show all'), findsNothing);

      // Clearing the query brings the cap back.
      await tester.enterText(_search('onboarding-people-search'), '');
      await _flush(tester);
      expect(boxes(), 8);
      expect(_button('Show all 12 people'), findsOneWidget);
    });

    testWidgets('"No matches" row for a query matching nobody', (tester) async {
      await toIdentities(tester, _scans(12));
      await tester.enterText(_search('onboarding-people-search'), 'zzz');
      await _flush(tester);
      expect(find.text('No matches'), findsOneWidget);
      expect(boxes(), 0);
    });

    testWidgets('a ticked person stays ticked while filtered out, and is saved on Continue', (tester) async {
      await toIdentities(tester, _scans(12));
      await tester.enterText(_search('onboarding-people-search'), _person(11));
      await _flush(tester);
      expect(_box(tester, _person(11)).value, isFalse);
      await tester.tap(_rowText(_person(11)));
      await _flush(tester);
      expect(_box(tester, _person(11)).value, isTrue);

      await tester.enterText(_search('onboarding-people-search'), _person(3));
      await _flush(tester);
      expect(find.text(_person(11)), findsNothing);

      await tester.enterText(_search('onboarding-people-search'), 'person 11');
      await _flush(tester);
      expect(_box(tester, _person(11)).value, isTrue, reason: 'still ticked after being filtered out');

      // Hidden again (query cleared: beyond the first 8), then Continue saves exactly that one identity.
      await tester.enterText(_search('onboarding-people-search'), '');
      await _flush(tester);
      expect(find.text(_person(11)), findsNothing);
      await tester.tap(_button('Continue'));
      await _flush(tester);
      expect(h.calls, hasLength(4), reason: 'one addIdentityCmd for the hidden, ticked person');
    });
  });

  group('RepoPicker search (#136)', () {
    final home = Platform.environment['HOME'] ?? '/home/test';
    List<RepoScan> repos(int n) => [
          for (var i = 0; i < n; i++)
            RepoScan(path: '$home/code/group${i % 3}/repo-$i', lastCommitAt: null, myCommits: 0, authors: const {}),
        ];

    Future<_PickerHostState> pump(WidgetTester tester, List<RepoScan> r) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(child: pageApp(_PickerHost(r))));
      await tester.pump();
      return tester.state<_PickerHostState>(find.byType(_PickerHost));
    }

    testWidgets('8 repos: no search field', (tester) async {
      await pump(tester, repos(8));
      expect(find.byKey(const Key('repo-picker-search')), findsNothing);
      expect(find.byType(AntCheckbox), findsNWidgets(8));
    });

    testWidgets('more than 8: filter by name and by ~/path; "No matches"', (tester) async {
      await pump(tester, repos(10));
      expect(find.byKey(const Key('repo-picker-search')), findsOneWidget);
      expect(find.byType(AntCheckbox), findsNWidgets(10));

      await tester.enterText(_search('repo-picker-search'), 'REPO-1');
      await tester.pump();
      expect(find.byType(AntCheckbox), findsNWidgets(1));
      expect(find.text('repo-1'), findsOneWidget);

      await tester.enterText(_search('repo-picker-search'), '~/code/group2');
      await tester.pump();
      expect(find.byType(AntCheckbox), findsNWidgets(3)); // 2, 5, 8
      expect(find.text('repo-5'), findsOneWidget);

      await tester.enterText(_search('repo-picker-search'), 'nothing-like-this');
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);
      expect(find.byType(AntCheckbox), findsNothing);
    });

    testWidgets('a ticked repo stays selected while filtered out', (tester) async {
      final s = await pump(tester, repos(10));
      await tester.enterText(_search('repo-picker-search'), 'repo-7');
      await tester.pump();
      await tester.tap(_rowText('repo-7'));
      await tester.pump();
      expect(_box(tester, 'repo-7').value, isTrue);
      await tester.enterText(_search('repo-picker-search'), 'repo-3');
      await tester.pump();
      expect(find.text('repo-7'), findsNothing);
      expect(s.c.selected, contains('$home/code/group1/repo-7'));
      await tester.enterText(_search('repo-picker-search'), '');
      await tester.pump();
      expect(_box(tester, 'repo-7').value, isTrue);
      expect(_box(tester, 'repo-3').value, isFalse);
    });
  });

  group('with a real engine', () {
    late Directory dir;
    setUp(() => dir = tempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    /// Boots the engine with nothing on screen, runs [prepare], then shows [page].
    Future<EngineHandle> bootWith(WidgetTester tester, Widget page, Future<void> Function(EngineHandle) prepare,
        {FakeSecrets? secrets}) async {
      final (container, h) = await bootPage(tester, dir, const SizedBox(), secrets: secrets, size: const Size(1400, 2400));
      await prepare(h);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: pageApp(page)));
      await settle(tester);
      return h;
    }

    group('Sources → Identities Suggested search (#136)', () {
      Future<void> addLogins(WidgetTester tester, EngineHandle h, int n) async {
        for (var i = 0; i < n; i++) {
          await cmd(tester, h, addSourceCmd(SourceKind.github, 'GitHub $i', {'login': 'user$i'}));
        }
      }

      testWidgets('8 suggestions: no field', (tester) async {
        final h = await bootWith(tester, const IdentitiesTab(), (h) => addLogins(tester, h, 8));
        await settle(tester, until: () => find.text('@user7').evaluate().isNotEmpty);
        expect(find.text('@user0'), findsOneWidget);
        expect(find.byKey(const Key('identities-suggested-search')), findsNothing);
        await killEngine(tester, h);
      });

      testWidgets('more than 8: filter by label/value; "No matches"', (tester) async {
        final h = await bootWith(tester, const IdentitiesTab(), (h) => addLogins(tester, h, 11));
        await settle(tester, until: () => find.text('@user10').evaluate().isNotEmpty);
        expect(find.byKey(const Key('identities-suggested-search')), findsOneWidget);
        expect(_button('This is me'), findsNWidgets(11));

        await tester.enterText(_search('identities-suggested-search'), 'USER1');
        await tester.pump();
        expect(_button('This is me'), findsNWidgets(2)); // user1, user10
        expect(find.text('@user1'), findsOneWidget);
        expect(find.text('@user10'), findsOneWidget);

        await tester.enterText(_search('identities-suggested-search'), '@user5');
        await tester.pump();
        expect(_button('This is me'), findsOneWidget);

        await tester.enterText(_search('identities-suggested-search'), 'zzz');
        await tester.pump();
        expect(find.text('No matches'), findsOneWidget);
        expect(_button('This is me'), findsNothing);
        await killEngine(tester, h);
      });
    });

    group('Sources grid search (#136)', () {
      Future<void> addRepos(WidgetTester tester, EngineHandle h, int n) async {
        for (var i = 0; i < n; i++) {
          await cmd(tester, h, addSourceCmd(SourceKind.gitRepo, 'proj-$i', {'path': '${dir.path}/folder$i/proj-$i'}));
        }
      }

      testWidgets('8 sources: no field', (tester) async {
        final h = await bootWith(tester, const SourcesPage(), (h) => addRepos(tester, h, 8));
        await settle(tester, until: () => find.text('proj-7').evaluate().isNotEmpty);
        expect(find.byKey(const Key('sources-search')), findsNothing);
        await killEngine(tester, h);
      });

      testWidgets('more than 8: filter by name and by path; "No matches"', (tester) async {
        final h = await bootWith(tester, const SourcesPage(), (h) => addRepos(tester, h, 10));
        await settle(tester, until: () => find.text('proj-9').evaluate().isNotEmpty);
        expect(find.byKey(const Key('sources-search')), findsOneWidget);
        for (var i = 0; i < 10; i++) {
          expect(find.text('proj-$i'), findsOneWidget);
        }

        await tester.enterText(_search('sources-search'), 'PROJ-3');
        await tester.pump();
        expect(find.text('proj-3'), findsOneWidget);
        expect(find.text('proj-4'), findsNothing);

        await tester.enterText(_search('sources-search'), 'folder8');
        await tester.pump();
        expect(find.text('proj-8'), findsOneWidget);
        expect(find.text('proj-3'), findsNothing);

        await tester.enterText(_search('sources-search'), 'zzz');
        await tester.pump();
        expect(find.text('No matches'), findsOneWidget);
        expect(find.text('proj-0'), findsNothing);
        await killEngine(tester, h);
      });
    });

    group('onboarding (#137)', () {
      const welcome = 'Your work, quietly remembered.';

      Future<EngineHandle> boot(WidgetTester tester, {FakeSecrets? secrets, Future<void> Function(EngineHandle)? prepare}) async {
        final h = await bootWith(tester, const OnboardingPage(), prepare ?? (_) async {}, secrets: secrets);
        await settle(tester, until: () => find.text(welcome).evaluate().isNotEmpty);
        return h;
      }

      Future<void> toModel(WidgetTester tester) async {
        await tester.tap(_button('Get started'));
        await settle(tester, until: () => find.text('Name your profile').evaluate().isNotEmpty);
        await tester.tap(_button('Continue'));
        for (var i = 0; i < 3; i++) {
          await settle(tester, until: () => _button('Skip').evaluate().isNotEmpty);
          await tester.tap(_button('Skip'));
          await settle(tester, until: () => _button('Saving…').evaluate().isEmpty);
        }
        await settle(tester, until: () => find.text('Choose a model').evaluate().isNotEmpty);
        expect(find.text('Choose a model'), findsOneWidget);
      }

      testWidgets('Welcome: four stages, one principles line, no "How it works"', (tester) async {
        final h = await boot(tester);
        for (final s in const ['Sources', 'Evidence', 'Narrative', 'Reports and wins']) {
          expect(find.text(s), findsWidgets, reason: s);
        }
        expect(
          find.text('Stays on this computer unless you pick a cloud model. Every line cites the work behind it.'),
          findsOneWidget,
        );
        expect(find.textContaining('How it works'), findsNothing);
        await killEngine(tester, h);
      });

      testWidgets('model step with no providers: no Manage list, every preset offered', (tester) async {
        final h = await boot(tester);
        await toModel(tester);
        expect(_button('Manage'), findsNothing);
        expect(find.text('OR ADD ANOTHER'), findsNothing);
        for (final p in ProviderPreset.cloud) {
          expect(find.text(p.name), findsOneWidget, reason: p.name);
        }
        expect(find.text('Custom endpoint'), findsOneWidget);
        await killEngine(tester, h);
      });

      testWidgets('an added provider: listed with Manage → dialog → Remove provider deletes it and its key',
          (tester) async {
        final secrets = FakeSecrets();
        late String pid;
        final h = await boot(tester, secrets: secrets, prepare: (h) async {
          (pid, _) = await cmd(
              tester,
              h,
              saveProviderCmd(
                kind: ProviderKind.openrouter,
                name: 'My OpenRouter',
                baseUrl: 'https://openrouter.ai/api/v1',
                protocol: ProviderProtocol.openai,
                apiKey: 'sk-or-test',
              ));
        });
        expect(secrets.values.values, contains('sk-or-test'));
        await toModel(tester);
        await settle(tester, until: () => _button('Manage').evaluate().isNotEmpty);

        expect(find.text('My OpenRouter'), findsOneWidget);
        expect(find.text('Key in Keychain · openrouter.ai · 0 models added'), findsOneWidget);
        expect(_button('Manage'), findsOneWidget);
        expect(find.text('OR ADD ANOTHER'), findsOneWidget, reason: 'Label upper-cases');
        // OpenRouter is no longer offered as an "add" option; the others are.
        expect(find.text('OpenRouter'), findsNothing);
        expect(find.textContaining('Recommended: one key'), findsNothing);
        for (final p in ProviderPreset.cloud.where((p) => p.kind != ProviderKind.openrouter)) {
          expect(find.text(p.name), findsOneWidget, reason: p.name);
        }

        await tester.tap(_button('Manage'));
        await settle(tester, until: () => _button('Remove provider').evaluate().isNotEmpty);
        expect(find.byType(ProviderDialog), findsOneWidget);
        await tester.tap(_button('Remove provider'));
        await settle(tester, until: () => find.byType(ProviderDialog).evaluate().isEmpty);
        await settle(tester, until: () => _button('Manage').evaluate().isEmpty);

        expect(find.byType(ProviderDialog), findsNothing);
        expect(find.text('My OpenRouter'), findsNothing);
        expect(_button('Manage'), findsNothing);
        expect(find.text('OpenRouter'), findsOneWidget, reason: 'offered again');
        expect(secrets.values, isEmpty, reason: 'the stored key is deleted');
        final rows = await read(tester, () => h.appDb.select(h.appDb.providers).get());
        expect(rows.where((r) => r.id == pid), isEmpty);
        await killEngine(tester, h);
      });
    });
  });

  group('removeProviderCmd (#137)', () {
    late Directory dir;
    late FakeSecrets secrets;
    late EngineHandle h;
    setUp(() async {
      dir = tempDir();
      secrets = FakeSecrets();
      h = await startEngine(dir, secrets: secrets);
    });
    tearDown(() async {
      await h.shutdown();
      dir.deleteSync(recursive: true);
    });

    test('deletes only that provider\'s key and header secrets', () async {
      final (a, _) = await h.runtime(saveProviderCmd(
        kind: ProviderKind.openai,
        name: 'A',
        baseUrl: 'https://api.openai.com/v1',
        protocol: ProviderProtocol.openai,
        apiKey: 'sk-a',
        headers: {'X-Team': 'team-a'},
      ));
      await h.runtime(saveProviderCmd(
        kind: ProviderKind.anthropic,
        name: 'B',
        baseUrl: 'https://api.anthropic.com',
        protocol: ProviderProtocol.native,
        apiKey: 'sk-b',
      ));
      expect(secrets.values.values.toSet(), {'sk-a', 'team-a', 'sk-b'});
      await h.runtime(removeProviderCmd(a));
      expect(secrets.values.values.toList(), ['sk-b']);
      final rows = await h.appDb.select(h.appDb.providers).get();
      expect(rows.map((r) => r.name), ['B']);
    });
  });
}
