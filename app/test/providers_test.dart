import 'dart:async';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' show Profile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() => dir = tempDir());
  tearDown(() async {
    final h = container.read(engineProvider).value;
    container.dispose();
    await h?.shutdown();
    dir.deleteSync(recursive: true);
  });

  ProviderContainer make({bool inMemory = true}) => container = ProviderContainer(overrides: [
        engineConfigProvider.overrideWithValue(testConfig(dir.path, inMemory: inMemory)),
      ]);

  Future<T> next<T>(ProviderListenable<AsyncValue<T>> provider, bool Function(T) where) {
    final c = Completer<T>();
    final sub = container.listen(provider, (_, v) {
      final value = v.value;
      if (value is T && where(value) && !c.isCompleted) c.complete(value);
    }, fireImmediately: true);
    return c.future.timeout(const Duration(seconds: 5)).whenComplete(sub.close);
  }

  test('setPausedCmd(true) makes pausedProvider emit true', () async {
    make();
    final h = await container.read(engineProvider.future);
    expect(await next(pausedProvider, (v) => v == false), isFalse);
    await h.runtime(setPausedCmd(true));
    expect(await next(pausedProvider, (v) => v), isTrue);
  });

  test('activeProfileProvider resolves to the started profile', () async {
    make();
    final h = await container.read(engineProvider.future);
    await next<List<Profile>>(profilesProvider, (v) => v.isNotEmpty);
    expect(container.read(activeProfileProvider)?.id, h.profileId);
    expect(container.read(activeProfileProvider)?.name, 'Work');
  });

  test('createProfileCmd + switchProfile restarts on the new profile DB; one profile is active', () async {
    make(inMemory: false);
    final first = await container.read(engineProvider.future);
    final oldId = first.profileId;
    final newId = await first.runtime(createProfileCmd('Side project'));

    await container.read(engineProvider.notifier).switchProfile(newId);

    final second = await container.read(engineProvider.future);
    expect(second, isNot(same(first)));
    expect(second.profileId, newId);
    await expectLater(first.run((e) async => 1), throwsA(anything), reason: 'old engine is shut down');
    expect(File(p.join(dir.path, 'profiles', '$newId.sqlite')).existsSync(), isTrue);

    final profiles = await second.appDb.select(second.appDb.profiles).get();
    expect(profiles, hasLength(2));
    expect(profiles.where((p) => p.active).map((p) => p.id), [newId]);

    // The new profile's DB is separate: a note there doesn't show in the old one.
    await second.runtime(addQuickNoteCmd(text: 'on side'));
    await container.read(engineProvider.notifier).switchProfile(oldId);
    final back = await container.read(engineProvider.future);
    expect(back.profileId, oldId);
    expect(await back.db.select(back.db.evidences).get(), isEmpty);
  });

  test('shutdown completes while provider streams are still listened (DesktopShell.quit order)', () async {
    make();
    final h = await container.read(engineProvider.future);
    await next(countProvider(Counter.evidence), (v) => v == 0);
    final subs = [
      container.listen(countProvider(Counter.evidence), (_, _) {}),
      container.listen(pausedProvider, (_, _) {}),
      container.listen(profilesProvider, (_, _) {}),
    ];
    await next(pausedProvider, (v) => v == false);
    await h.shutdown().timeout(const Duration(seconds: 15));
    for (final s in subs) {
      s.close();
    }
  });

  test('countProvider(evidence) updates after a note', () async {
    make();
    final h = await container.read(engineProvider.future);
    expect(await next(countProvider(Counter.evidence), (v) => v == 0), 0);
    await h.runtime(addQuickNoteCmd(text: 'n'));
    expect(await next(countProvider(Counter.evidence), (v) => v == 1), 1);
    expect(await next(countProvider(Counter.notes), (v) => v == 1), 1);
  });
}
