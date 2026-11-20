import 'dart:async';

import 'package:core/core.dart' hide Provider, Notifier;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/commands.dart';
import '../engine/engine_handle.dart';
import '../engine/engine_runtime.dart' show pausedSettingKey;
import '../engine/messages.dart';
import '../engine/ui_port_host.dart';
import '../platform/time_zone.dart';

/// Overridden in `main.dart` (and in tests).
final engineConfigProvider = Provider<EngineConfig>((ref) => throw UnimplementedError('engineConfigProvider'));
final uiPortHostProvider = Provider<UiPortHost?>((ref) => null);

/// The running engine for the active profile. Switching profile restarts it (#77).
final engineProvider = AsyncNotifierProvider<EngineController, EngineHandle>(EngineController.new);

class EngineController extends AsyncNotifier<EngineHandle> {
  EngineHandle? _current;

  @override
  Future<EngineHandle> build() async {
    ref.onDispose(() => _current?.shutdown());
    return _start();
  }

  Future<EngineHandle> _start() async {
    final h = await EngineHandle.start(ref.read(engineConfigProvider), host: ref.read(uiPortHostProvider));
    _current = h;
    return h;
  }

  Future<void> switchProfile(String id) async {
    final old = _current;
    if (old == null || old.profileId == id) return;
    await old.runtime(setActiveProfileCmd(id));
    Log.info('engine.restart', {'reason': 'profile_switch'});
    state = const AsyncLoading();
    _current = null;
    await old.shutdown();
    state = await AsyncValue.guard(_start);
  }
}

/// Convenience for one-off commands from widgets: `ref.read(engineProvider.future)`.
Future<EngineHandle> engineOf(Ref ref) => ref.read(engineProvider.future);

final profilesProvider = StreamProvider<List<Profile>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.appDb.select(h.appDb.profiles)..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).watch();
});

final activeProfileProvider = Provider<Profile?>((ref) {
  final id = ref.watch(engineProvider).value?.profileId;
  return ref.watch(profilesProvider).value?.where((p) => p.id == id).firstOrNull;
});

final projectsProvider = StreamProvider<List<Project>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.projects)..where((p) => p.archived.equals(false))).watch();
});

final pausedProvider = StreamProvider<bool>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.settings)..where((s) => s.key.equals(pausedSettingKey)))
      .watchSingleOrNull()
      .map((s) => s?.value == 'true');
});

/// Today's YYYY-MM-DD in the profile zone, re-checked every minute so a long-running app rolls
/// over at midnight.
final todayProvider = NotifierProvider<TodayNotifier, String>(TodayNotifier.new);

class TodayNotifier extends Notifier<String> {
  @override
  String build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final d = profileToday();
      if (d != state) state = d;
    });
    ref.onDispose(timer.cancel);
    return profileToday();
  }
}

/// Live counts for the placeholder pages (proves the isolate + watch wiring).
enum Counter {
  evidence('SELECT COUNT(*) AS c FROM evidences'),
  evidenceToday('SELECT COUNT(*) AS c FROM evidences WHERE day = ?1'),
  notes("SELECT COUNT(*) AS c FROM payloads WHERE kind IN ('note', 'image')"),
  facts('SELECT COUNT(*) AS c FROM facts WHERE retired = 0'),
  wins("SELECT COUNT(*) AS c FROM facts WHERE win_status = 'accepted'"),
  reports('SELECT COUNT(*) AS c FROM reports'),
  projects('SELECT COUNT(*) AS c FROM projects'),
  sources('SELECT COUNT(*) AS c FROM sources'),
  queuedJobs("SELECT COUNT(*) AS c FROM jobs WHERE state IN ('queued', 'running')");

  const Counter(this.sql);
  final String sql;
}

final countProvider = StreamProvider.family<int, Counter>((ref, c) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  final vars = c == Counter.evidenceToday
      ? [Variable.withString(ref.watch(todayProvider))]
      : const <Variable<Object>>[];
  yield* db
      .customSelect(c.sql, variables: vars, readsFrom: {
        db.evidences,
        db.payloads,
        db.facts,
        db.reports,
        db.projects,
        db.sources,
        db.jobs,
      })
      .watchSingle()
      .map((r) => r.read<int>('c'));
});
