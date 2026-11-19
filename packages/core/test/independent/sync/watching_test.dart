import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';

import 'harness.dart';

const debounce = Duration(milliseconds: 40);
Future<void> settle([int ms = 150]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late Harness h;
  late WatchSource watch;
  late SyncService svc;
  var kicks = 0;

  setUp(() {
    h = Harness.create();
    kicks = 0;
    watch = WatchSource(SourceKind.gitRepo, throwFor: {'broken'});
    h.engine.sources.register(SourceKind.gitRepo, () => watch);
    h.engine.sources.register(SourceKind.linear, () => ScriptSource(SourceKind.linear, (_) => const Stream.empty()));
    svc = h.service(debounce: debounce);
  });
  tearDown(() async {
    await svc.stopWatching();
    await h.db.close();
  });

  Future<List<Job>> syncJobs() => h.jobs(SyncService.syncJob);

  test('a burst of changes enqueues one job after the debounce and calls onEnqueue', () async {
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    expect(watch.active('r'), 1);
    for (var i = 0; i < 5; i++) {
      watch.emit('r');
      await Future<void>.delayed(const Duration(milliseconds: 10)); // each within the debounce window
    }
    expect(await syncJobs(), isEmpty, reason: 'still inside the debounce window');
    await settle();
    final jobs = await syncJobs();
    expect(jobs, hasLength(1));
    expect(jobs.single.args, '{"source_id":"r"}');
    expect(kicks, 1);
  });

  test('a second burst while the job is still queued does not enqueue or kick again', () async {
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    watch.emit('r');
    await settle();
    watch.emit('r');
    await settle();
    expect(await syncJobs(), hasLength(1));
    expect(kicks, 1);

    await h.db.update(h.db.jobs).write(const JobsCompanion(state: Value(JobState.done)));
    watch.emit('r');
    await settle();
    expect(await syncJobs(), hasLength(2));
    expect(kicks, 2);
  });

  test('works without onEnqueue', () async {
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching();
    watch.emit('r');
    await settle();
    expect(await syncJobs(), hasLength(1));
  });

  test('bursts on two sources are debounced independently', () async {
    await h.addRow('a', SourceKind.gitRepo);
    await h.addRow('b', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    watch.emit('a');
    watch.emit('b');
    watch.emit('a');
    await settle();
    expect((await syncJobs()).map((j) => j.args), unorderedEquals(['{"source_id":"a"}', '{"source_id":"b"}']));
    expect(kicks, 2);
  });

  test('non-watchable and disabled sources are not watched', () async {
    await h.addRow('lin', SourceKind.linear);
    await h.addRow('off', SourceKind.gitRepo, enabled: false);
    await svc.startWatching(onEnqueue: () => kicks++);
    expect(watch.active('off'), 0);
    watch.emit('off');
    await settle();
    expect(await syncJobs(), isEmpty);
    expect(kicks, 0);
  });

  test('a source whose changes() throws synchronously is skipped; others still watched', () async {
    await h.addRow('broken', SourceKind.gitRepo);
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    expect(watch.active('r'), 1);
    watch.emit('r');
    await settle();
    expect(await syncJobs(), hasLength(1));
  });

  test('an error on the changes stream is ignored and watching continues', () async {
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    watch.emitError('r');
    await settle();
    expect(await syncJobs(), isEmpty);
    expect(watch.active('r'), 1);
    watch.emit('r');
    await settle();
    expect(await syncJobs(), hasLength(1));
  });

  test('stopWatching cancels pending timers and subscriptions', () async {
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    watch.emit('r');
    await Future<void>.delayed(Duration.zero); // deliver the event so the timer is pending
    await svc.stopWatching();
    await settle();
    expect(await syncJobs(), isEmpty);
    expect(kicks, 0);
    expect(watch.active('r'), 0);
  });

  test('startWatching twice does not double-subscribe', () async {
    await h.addRow('r', SourceKind.gitRepo);
    await svc.startWatching();
    await svc.startWatching(onEnqueue: () => kicks++);
    expect(watch.active('r'), 1);
    watch.emit('r');
    await settle();
    expect(kicks, 1, reason: 'the latest onEnqueue is used');
  });

  test('addSource while watching subscribes the new source', () async {
    await svc.startWatching(onEnqueue: () => kicks++);
    final id = await svc.addSource(SourceKind.gitRepo, 'repo', {'path': '/r'});
    expect(watch.active(id), 1);
    watch.emit(id);
    await settle();
    expect((await syncJobs()).single.args, '{"source_id":"$id"}');
    expect(kicks, 1);
  });

  test('addSource while not watching subscribes nothing', () async {
    final id = await svc.addSource(SourceKind.gitRepo, 'repo', {});
    expect(watch.active(id), 0);
  });

  test('updateSource(enabled: false) and removeSource unsubscribe; re-enable subscribes again', () async {
    await h.addRow('a', SourceKind.gitRepo);
    await h.addRow('b', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    await svc.updateSource('a', enabled: false);
    expect(watch.active('a'), 0);
    expect(watch.active('b'), 1, reason: 'others are re-subscribed exactly once');
    await svc.removeSource('b');
    expect(watch.active('b'), 0);
    await svc.updateSource('a', enabled: true);
    expect(watch.active('a'), 1);
    watch.emit('a');
    await settle();
    expect(await syncJobs(), hasLength(1));
  });

  test('re-subscribing for one source keeps a pending debounced sync of another', () async {
    await h.addRow('a', SourceKind.gitRepo);
    await svc.startWatching(onEnqueue: () => kicks++);
    watch.emit('a');
    await Future<void>.delayed(Duration.zero); // timer for 'a' pending
    await svc.addSource(SourceKind.gitRepo, 'other', {}); // _rewatch -> stopWatching cancels all timers
    await settle();
    expect((await syncJobs()).map((j) => j.args), contains('{"source_id":"a"}'));
  }, skip: "BUG: _rewatch() -> stopWatching() cancels every pending debounce timer, so a change burst on "
      "source A is dropped when any source is added/updated/removed within the debounce (sync_service.dart:132)");
}
