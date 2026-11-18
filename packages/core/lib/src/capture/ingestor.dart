import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../util/ids.dart';
import 'source.dart';

class IngestResult {
  int created = 0, updated = 0, tombstoned = 0, unchanged = 0;
  @override
  String toString() => 'created=$created updated=$updated tombstoned=$tombstoned unchanged=$unchanged';
}

/// The only writer of capture tables (LLD 04 §4.1). One transaction per batch;
/// DB triggers enqueue recompute work atomically.
class Ingestor {
  Ingestor(this.db, {required this.utcOffset});
  final ProfileDb db;
  /// Profile time zone offset at a given instant (#87); per-timestamp so DST is correct.
  final Duration Function(DateTime at) utcOffset;

  Future<IngestResult> ingest(String sourceId, List<PayloadObservation> batch) {
    final r = IngestResult();
    return db.transaction(() async {
      for (final o in batch) {
        await _one(sourceId, o, r);
      }
      return r;
    });
  }

  Future<void> _one(String sourceId, PayloadObservation o, IngestResult r) async {
    final now = DateTime.now().toUtc();
    final existing = await (db.select(db.payloads)
          ..where((p) => p.sourceId.equals(sourceId) & p.externalId.equals(o.externalId)))
        .getSingleOrNull();
    final json = canonicalJson(o.content);
    final hash = sha256Hex(json);

    if (existing == null) {
      if (o.tombstone) return;
      String? evidenceId;
      if (o.groupKey != null) {
        final peer = await (db.select(db.payloads)
              ..where((p) => p.groupKey.equals(o.groupKey!) & p.tombstonedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
        evidenceId = peer?.evidenceId;
      }
      if (evidenceId == null) {
        evidenceId = newId(o.occurredStart);
        await db.into(db.evidences).insert(EvidencesCompanion.insert(
          id: evidenceId,
          occurredStart: o.occurredStart.toUtc(),
          occurredEnd: Value(o.occurredEnd?.toUtc()),
          day: dayOf(o.occurredStart, utcOffset(o.occurredStart)),
          title: o.title,
          createdAt: now,
          updatedAt: now,
        ));
      }
      final payloadId = newId(o.occurredStart);
      await db.into(db.payloads).insert(PayloadsCompanion.insert(
        id: payloadId,
        evidenceId: evidenceId,
        sourceId: sourceId,
        kind: o.kind,
        externalId: o.externalId,
        content: json,
        contentHash: hash,
        groupKey: Value(o.groupKey),
        title: Value(o.title),
      ));
      await _revision(payloadId, 1, json, hash, now);
      r.created++;
      return;
    }

    if (o.tombstone) {
      if (existing.tombstonedAt != null) return;
      final rev = existing.revision + 1;
      await (db.update(db.payloads)..where((p) => p.id.equals(existing.id)))
          .write(PayloadsCompanion(tombstonedAt: Value(now), revision: Value(rev)));
      await _revision(existing.id, rev, existing.content, existing.contentHash, now);
      await _promoteNextLivePayload(existing.evidenceId);
      r.tombstoned++;
      return;
    }

    final groupKey = o.groupKey ?? existing.groupKey;
    if (hash == existing.contentHash && existing.tombstonedAt == null && groupKey == existing.groupKey) {
      r.unchanged++; // invariant 2: no write, nothing goes stale
      return;
    }
    final rev = existing.revision + 1;
    await (db.update(db.payloads)..where((p) => p.id.equals(existing.id))).write(PayloadsCompanion(
      content: Value(json),
      contentHash: Value(hash),
      revision: Value(rev),
      tombstonedAt: const Value(null),
      groupKey: Value(groupKey),
      title: Value(o.title),
    ));
    await _revision(existing.id, rev, json, hash, now);
    r.updated++;
  }

  /// §4.1: evidence title follows its earliest live payload once the first one is tombstoned.
  Future<void> _promoteNextLivePayload(String evidenceId) async {
    final next = await (db.select(db.payloads)
          ..where((p) => p.evidenceId.equals(evidenceId) & p.tombstonedAt.isNull() & p.title.isNotNull())
          ..orderBy([(p) => OrderingTerm.asc(p.id)]) // ULIDs are time-ordered
          ..limit(1))
        .getSingleOrNull();
    if (next == null) return; // no live payloads: evidence hidden from views, kept for history
    await (db.update(db.evidences)..where((e) => e.id.equals(evidenceId)))
        .write(EvidencesCompanion(title: Value(next.title!), updatedAt: Value(DateTime.now().toUtc())));
  }

  Future<void> _revision(String payloadId, int rev, String json, String hash, DateTime at) =>
      db.into(db.payloadRevisions).insert(PayloadRevisionsCompanion.insert(
        payloadId: payloadId,
        revision: rev,
        content: json,
        contentHash: hash,
        cause: RevisionCause.sync,
        observedAt: at,
      ));
}
