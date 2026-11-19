// Onboarding layout and repo-scan roots (#113, #114), with a scripted engine handle: every
// runtime() call stays pending until the test answers it, in call order.
import 'dart:async';
import 'dart:io';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/onboarding/onboarding_page.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/sources/git_setup.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

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

class _Host extends ConsumerStatefulWidget {
  const _Host();
  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  late final scan = RepoScanController(ref);
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Finder _button(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

const _git = GitStatus('/usr/bin/git', '2.40');
const _viewHeight = 900.0;

void main() {
  late _PendingHandle h;
  setUp(() => h = _PendingHandle());

  Widget scope(Widget child) => ProviderScope(
        overrides: [
          engineProvider.overrideWith(() => _FakeEngine(h)),
          profilesProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
          activeProfileProvider.overrideWithValue(null),
          sourcesProvider.overrideWith((ref) => Stream.value(const <SourceStatus>[])),
        ],
        child: MaterialApp(theme: antTheme(AntTokens.light()), home: Scaffold(body: child)),
      );

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, _viewHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('disposed on Welcome before any engine reply: no error', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(scope(const OnboardingPage()));
    await flush(tester);
    expect(find.text('Your work, quietly remembered.'), findsOneWidget);
    expect(find.text('Name your profile'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    // Late replies after dispose stay quiet too.
    for (final c in h.calls) {
      c.complete(_git);
    }
    await flush(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long repo list scrolls under a pinned footer: Back / Skip / Continue stay on screen',
      (tester) async {
    sizeView(tester);
    final repos = [
      for (var i = 0; i < 40; i++)
        RepoScan(path: '/tmp/repos/r$i', lastCommitAt: null, myCommits: 0, authors: const {}),
    ];
    await tester.pumpWidget(scope(const OnboardingPage()));
    await flush(tester);
    h.calls[0].complete(_git); // checkGit
    await flush(tester);
    h.calls[1].complete(repos); // scan
    await flush(tester);
    h.calls[2].complete(null); // git global email
    await flush(tester);

    await tester.tap(_button('Get started'));
    await flush(tester);
    await tester.tap(_button('Continue')); // profile (no active profile: nothing saved)
    await flush(tester);
    expect(find.text('Which of these are you?'), findsOneWidget);
    await tester.tap(_button('Skip'));
    await flush(tester);
    expect(find.text('Pick the repos to watch'), findsOneWidget);
    expect(find.text('40 repos found'), findsOneWidget);

    // The list really is longer than the window.
    final last = find.text('r39');
    expect(last, findsOneWidget);
    expect(tester.getRect(last).top, greaterThan(_viewHeight));

    for (final l in const ['Back', 'Skip', 'Continue']) {
      final r = tester.getRect(_button(l));
      expect(r.top, greaterThanOrEqualTo(0), reason: l);
      expect(r.bottom, lessThanOrEqualTo(_viewHeight), reason: l);
    }
    // And they still work without scrolling first.
    await tester.tap(_button('Skip'));
    await flush(tester);
    expect(find.text('Connect more sources'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan roots never list the same folder twice and keep every default root', (tester) async {
    await tester.pumpWidget(scope(const _Host()));
    final roots = tester.state<_HostState>(find.byType(_Host)).scan.roots;
    final defaults = defaultScanRoots();
    // Depends on this machine's home folder (HOME can't be overridden in-process). On a
    // case-insensitive disk with ~/Projects, defaults lists it twice (Projects, projects).
    if (defaults.isEmpty) return markTestSkipped('no default scan roots under HOME');
    for (var i = 0; i < roots.length; i++) {
      for (var j = i + 1; j < roots.length; j++) {
        expect(FileSystemEntity.identicalSync(roots[i], roots[j]), isFalse,
            reason: '${roots[i]} and ${roots[j]} are one folder');
      }
    }
    for (final d in defaults) {
      expect(roots.any((r) => FileSystemEntity.identicalSync(r, d)), isTrue, reason: '$d was dropped');
    }
    expect(roots.length, lessThanOrEqualTo(defaults.length));
  });
}
