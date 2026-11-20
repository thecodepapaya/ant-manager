// RepoScanController (features/sources/git_setup.dart) drops updates once disposed (#110), so a scan
// that outlives its page neither throws nor changes state; pages disposed mid-scan stay quiet.
// (dispose() clears listeners, so "no notify" is checked via the debug assert that a disposed
// ChangeNotifier's notifyListeners would raise, surfaced by takeException.)
import 'dart:async';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/onboarding/onboarding_page.dart';
import 'package:ant_manager/features/sources/git_setup.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

/// Every runtime() call stays pending until the test completes it, in call order.
class PendingHandle implements EngineHandle {
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
  final PendingHandle h;
  @override
  Future<EngineHandle> build() async => h;
}

/// Exposes a RepoScanController built from a real WidgetRef.
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

const _git = GitStatus('/usr/bin/git', '2.40');
final _repo = RepoScan(path: '/tmp/r', lastCommitAt: null, myCommits: 0, authors: const {});

void main() {
  late PendingHandle h;
  setUp(() => h = PendingHandle());

  Widget scope(Widget child) => ProviderScope(
        overrides: [
          engineProvider.overrideWith(() => _FakeEngine(h)),
          profilesProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
        ],
        child: MaterialApp(theme: antTheme(AntTokens.dark()), home: Scaffold(body: child)),
      );

  Future<RepoScanController> controller(WidgetTester tester) async {
    await tester.pumpWidget(scope(const _Host()));
    return tester.state<_HostState>(find.byType(_Host)).scan;
  }

  /// Runs microtasks/timers so awaited futures resume.
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('after dispose, checkGit/scan/notifyListeners neither throw nor change state', (tester) async {
    final c = await controller(tester);
    c.git = _git;
    c.dispose();
    expect(c.notifyListeners, returnsNormally);
    await c.scan(); // returns early: no engine call
    expect(h.calls, isEmpty);
    final check = c.checkGit();
    await flush(tester);
    expect(h.calls, hasLength(1));
    h.calls.single.complete(const GitStatus('/other', '9'));
    await check;
    expect(c.git, _git, reason: 'a result arriving after dispose is dropped');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose while checkGit is pending: result dropped, no error', (tester) async {
    final c = await controller(tester);
    var notified = 0;
    c.addListener(() => notified++);
    final check = c.checkGit();
    expect(notified, 1, reason: 'checking=true notifies before dispose');
    await flush(tester);
    expect(h.calls, hasLength(1));
    c.dispose();
    h.calls.single.complete(_git);
    await check;
    expect((c.git, notified), (null, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose while scan is pending: repos unchanged, no error', (tester) async {
    final c = await controller(tester);
    c.git = _git;
    var notified = 0;
    c.addListener(() => notified++);
    final scan = c.scan();
    await flush(tester);
    expect(h.calls, hasLength(1));
    expect(c.scanning, isTrue);
    c.dispose();
    h.calls.single.complete([_repo]);
    await scan;
    expect((c.repos, c.scanning, notified), (const <RepoScan>[], true, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('not disposed: scan applies its result and notifies', (tester) async {
    final c = await controller(tester);
    c.git = _git;
    var notified = 0;
    c.addListener(() => notified++);
    final scan = c.scan();
    await flush(tester);
    h.calls.single.complete([_repo]);
    await scan;
    expect(c.repos.map((r) => r.path), ['/tmp/r']);
    expect((c.scanning, notified), (false, 2));
  });

  testWidgets('disposing onboarding during the first scan → no ref/notify errors', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scope(const OnboardingPage()));
    await flush(tester);
    expect(h.calls, hasLength(1), reason: 'checkGit pending');
    h.calls[0].complete(_git);
    await flush(tester);
    expect(h.calls, hasLength(2), reason: 'scan pending');
    await tester.pumpWidget(const SizedBox()); // dispose onboarding mid-scan
    h.calls[1].complete([_repo]);
    await flush(tester);
    expect(tester.takeException(), isNull);
    expect(h.calls, hasLength(2), reason: 'the follow-up email lookup is skipped');
  });

  testWidgets('closing the repo setup dialog during its first scan → no ref/notify errors', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scope(const GitSetupDialog()));
    await flush(tester);
    expect(h.calls, hasLength(1), reason: 'checkGit pending');
    h.calls[0].complete(_git);
    await flush(tester);
    expect(h.calls, hasLength(2), reason: 'scan pending');
    await tester.pumpWidget(const SizedBox()); // close the dialog mid-scan
    h.calls[1].complete([_repo]);
    await flush(tester);
    expect(tester.takeException(), isNull);
  });
}
