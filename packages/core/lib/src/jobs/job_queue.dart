import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../ports/ports.dart';
import '../util/ids.dart';

typedef JobHandler = Future<void> Function(Map<String, Object?> args);

/// Durable job queue (LLD 04 §4.11). Two lanes: IO and LLM (one model call at a time).
class JobQueue {
  JobQueue(this.db, {this.clock = const SystemClock()});
  final ProfileDb db;
  final Clock clock;
  final _handlers = <String, (JobLane, JobHandler)>{};

  static const backoff = [Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 30)];
  static const leaseTtl = Duration(minutes: 10);

  void register(String kind, JobLane lane, JobHandler handler) => _handlers[kind] = (lane, handler);

  Future<String> enqueue(String kind, {Map<String, Object?> args = const {}, DateTime? runAfter}) async {
    final lane = _handlers[kind]?.$1 ?? (throw StateError('No handler for job $kind'));
    final id = newId();
    final now = clock.now();
    await db.into(db.jobs).insert(JobsCompanion.insert(
      id: id,
      kind: kind,
      args: Value(jsonEncode(args)),
      lane: lane,
      state: JobState.queued,
      runAfter: runAfter ?? now,
      createdAt: now,
    ));
    return id;
  }

  /// Leases and runs one ready job on [lane]. Returns false when nothing is ready.
  Future<bool> runOne(JobLane lane) async {
    final now = clock.now();
    final job = await db.transaction(() async {
      final j = await (db.select(db.jobs)
            ..where((t) =>
                t.lane.equalsValue(lane) &
                t.runAfter.isSmallerOrEqualValue(now) &
                (t.state.equalsValue(JobState.queued) |
                    (t.state.equalsValue(JobState.running) & t.leaseUntil.isSmallerThanValue(now))))
            ..orderBy([(t) => OrderingTerm.asc(t.runAfter)])
            ..limit(1))
          .getSingleOrNull();
      if (j == null) return null;
      await (db.update(db.jobs)..where((t) => t.id.equals(j.id))).write(JobsCompanion(
        state: const Value(JobState.running),
        leaseUntil: Value(now.add(leaseTtl)),
      ));
      return j;
    });
    if (job == null) return false;
    final handler = _handlers[job.kind]?.$2;
    try {
      if (handler == null) throw StateError('No handler for job ${job.kind}');
      await handler(jsonDecode(job.args) as Map<String, Object?>);
      await (db.update(db.jobs)..where((t) => t.id.equals(job.id)))
          .write(const JobsCompanion(state: Value(JobState.done), leaseUntil: Value(null)));
    } catch (e) {
      final attempt = job.attempts + 1; // attempts count failures, not leases
      final failed = attempt > backoff.length;
      final failedAt = clock.now();
      await (db.update(db.jobs)..where((t) => t.id.equals(job.id))).write(JobsCompanion(
        state: Value(failed ? JobState.failed : JobState.queued),
        attempts: Value(attempt),
        runAfter: Value(failed ? failedAt : failedAt.add(backoff[attempt - 1])),
        leaseUntil: const Value(null),
        lastError: Value(e.toString()),
      ));
    }
    return true;
  }
}
