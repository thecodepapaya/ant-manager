// Independent tests (#99) for the profile IANA time zone (#87, #109): zoneOffset / todayIn and
// their use by the Ingestor and AntEngine for evidence days.
import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  group('zoneOffset', () {
    test('Europe/London: 0 before the 2026-03-29 01:00Z spring-forward, +1 h after', () {
      final london = zoneOffset('Europe/London');
      expect(london(DateTime.utc(2026, 3, 29, 0, 30)), Duration.zero);
      expect(london(DateTime.utc(2026, 3, 29, 0, 59, 59)), Duration.zero);
      expect(london(DateTime.utc(2026, 3, 29, 1, 0)), const Duration(hours: 1));
      expect(london(DateTime.utc(2026, 3, 29, 1, 30)), const Duration(hours: 1));
    });

    test('Europe/London falls back to 0 at 2026-10-25 01:00Z', () {
      final london = zoneOffset('Europe/London');
      expect(london(DateTime.utc(2026, 10, 25, 0, 30)), const Duration(hours: 1));
      expect(london(DateTime.utc(2026, 10, 25, 1, 30)), Duration.zero);
    });

    test('fixed and negative zones', () {
      expect(zoneOffset('Asia/Kolkata')(DateTime.utc(2026, 6, 1)), const Duration(hours: 5, minutes: 30));
      expect(zoneOffset('Asia/Kolkata')(DateTime.utc(2026, 12, 1)), const Duration(hours: 5, minutes: 30));
      expect(zoneOffset('America/New_York')(DateTime.utc(2026, 11, 17, 12)), const Duration(hours: -5));
      expect(zoneOffset('America/New_York')(DateTime.utc(2026, 7, 1, 12)), const Duration(hours: -4));
      expect(zoneOffset('UTC')(DateTime.utc(2026, 7, 1)), Duration.zero);
    });

    test('the offset depends on the instant, not on the DateTime being local or UTC', () {
      final london = zoneOffset('Europe/London');
      final instant = DateTime.utc(2026, 7, 1, 12);
      expect(london(instant.toLocal()), london(instant));
    });

    test('an unknown name (e.g. "IST") does not throw and uses the system offset', () {
      late UtcOffset f;
      expect(() => f = zoneOffset('IST'), returnsNormally);
      for (final t in [DateTime.utc(2026, 1, 15, 12), DateTime.utc(2026, 7, 15, 12)]) {
        expect(f(t), t.toLocal().timeZoneOffset);
      }
      expect(() => zoneOffset('Not/AZone')(DateTime.utc(2026)), returnsNormally);
      expect(() => zoneOffset('')(DateTime.utc(2026)), returnsNormally);
    });
  });

  group('todayIn', () {
    test('a DST zone: London is GMT in winter, BST in summer', () {
      final london = zoneOffset('Europe/London');
      expect(todayIn(london, DateTime.utc(2026, 3, 28, 23, 30)), '2026-03-28');
      expect(todayIn(london, DateTime.utc(2026, 7, 10, 23, 30)), '2026-07-11');
    });

    test('+5:30 zone: the day turns at 18:30Z', () {
      final ist = zoneOffset('Asia/Kolkata');
      expect(todayIn(ist, DateTime.utc(2026, 11, 16, 18, 29, 59)), '2026-11-16');
      expect(todayIn(ist, DateTime.utc(2026, 11, 16, 18, 30)), '2026-11-17');
      expect(todayIn(ist, DateTime.utc(2026, 12, 31, 18, 30)), '2027-01-01');
    });

    test('a hand-written +5:30 offset behaves the same', () {
      Duration plus530(DateTime _) => const Duration(hours: 5, minutes: 30);
      expect(todayIn(plus530, DateTime.utc(2026, 11, 16, 18, 29)), '2026-11-16');
      expect(todayIn(plus530, DateTime.utc(2026, 11, 16, 18, 31)), '2026-11-17');
    });

    test('a negative zone is still on the previous day', () {
      expect(todayIn(zoneOffset('America/New_York'), DateTime.utc(2026, 11, 17, 4, 59)), '2026-11-16');
      expect(todayIn(zoneOffset('America/New_York'), DateTime.utc(2026, 11, 17, 5)), '2026-11-17');
    });

    test('without now it uses the current time', () {
      final ist = zoneOffset('Asia/Kolkata');
      final before = DateTime.now();
      final got = todayIn(ist);
      final after = DateTime.now();
      expect(got, anyOf(dayOf(before, ist(before)), dayOf(after, ist(after))));
    });

    test('a +14 and a -11 zone are never on the same day', () {
      final now = DateTime.now();
      expect(todayIn(zoneOffset('Pacific/Kiritimati'), now), isNot(todayIn(zoneOffset('Pacific/Pago_Pago'), now)));
    });
  });

  group('evidence days in the profile zone', () {
    late ProfileDb db;
    setUp(() async {
      db = memDb();
      await db.into(db.sources).insert(SourcesCompanion.insert(id: 'git', kind: SourceKind.gitRepo, name: 'git'));
    });
    tearDown(() => db.close());

    PayloadObservation obs(String id, DateTime t) => PayloadObservation(
      externalId: id,
      kind: PayloadKind.commit,
      content: {'sha': id, 'at': t.toIso8601String()},
      occurredStart: t,
      title: id,
      groupKey: id,
    );

    Future<String> dayOfExt(String id) async {
      final p = await (db.select(db.payloads)..where((p) => p.externalId.equals(id))).getSingle();
      return (await (db.select(db.evidences)..where((e) => e.id.equals(p.evidenceId))).getSingle()).day;
    }

    test('Ingestor with zoneOffset("Asia/Kolkata") puts 18:30Z on the next day', () async {
      final ing = Ingestor(db, utcOffset: zoneOffset('Asia/Kolkata'));
      await ing.ingest('git', [obs('a', DateTime.utc(2026, 11, 16, 18, 29)), obs('b', DateTime.utc(2026, 11, 16, 18, 30))]);
      expect(await dayOfExt('a'), '2026-11-16');
      expect(await dayOfExt('b'), '2026-11-17');
    });

    test('Ingestor with zoneOffset("Europe/London") follows DST per instant', () async {
      final ing = Ingestor(db, utcOffset: zoneOffset('Europe/London'));
      await ing.ingest('git', [
        obs('winter', DateTime.utc(2026, 1, 10, 23, 30)), // GMT: still the 10th
        obs('summer', DateTime.utc(2026, 7, 10, 23, 30)), // BST: 00:30 on the 11th
      ]);
      expect(await dayOfExt('winter'), '2026-01-10');
      expect(await dayOfExt('summer'), '2026-07-11');
    });

    test('Ingestor with zoneOffset("America/New_York") puts 03:00Z on the previous day', () async {
      final ing = Ingestor(db, utcOffset: zoneOffset('America/New_York'));
      await ing.ingest('git', [obs('a', DateTime.utc(2026, 11, 17, 3))]);
      expect(await dayOfExt('a'), '2026-11-16');
    });

    test('re-ingesting a payload moved across the profile-zone midnight moves its evidence day', () async {
      final ing = Ingestor(db, utcOffset: zoneOffset('Asia/Kolkata'));
      await ing.ingest('git', [obs('m', DateTime.utc(2026, 11, 16, 18))]); // 23:30 IST on the 16th
      expect(await dayOfExt('m'), '2026-11-16');
      await ing.ingest('git', [obs('m', DateTime.utc(2026, 11, 16, 19))]); // 00:30 IST on the 17th
      expect(await dayOfExt('m'), '2026-11-17');
    });

    test('AntEngine built with zoneOffset(profile zone): addNote and ingestor use that day', () async {
      final engine = AntEngine(
        db: db,
        profileId: 'p1',
        ports: EnginePorts(
          secrets: MemSecrets(),
          blobs: MemBlobs(),
          git: NoGit(),
          watcher: NoWatcher(),
          clock: MutableClock(DateTime.utc(2026, 11, 18, 12)),
        ),
        router: ScriptedRouter(ScriptedLlm([])),
        utcOffset: zoneOffset('Asia/Kolkata'),
      );
      final id = await engine.addNote(text: 'late note', at: DateTime.utc(2026, 11, 18, 19));
      final e = await (db.select(db.evidences)..where((x) => x.id.equals(id))).getSingle();
      expect(e.day, '2026-11-19');
      await engine.ingestor.ingest('git', [obs('c', DateTime.utc(2026, 11, 18, 18))]);
      expect(await dayOfExt('c'), '2026-11-18');
    });
  });
}
