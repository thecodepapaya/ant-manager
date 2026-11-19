// Independent tests (#99) for the core side of DECISIONS #115: attachment mime by extension (any case),
// workstreams reused by title refresh their summary unless user-touched, and an empty or
// whitespace-only commit author email counts as yours.

import 'package:core/core.dart';
import 'package:core/src/narrative/time_allocation.dart';
import 'package:core/src/narrative/workstreams.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    h = H();
    await h.setUp();
  });
  tearDown(() => h.close());

  group('attachment mime by extension', () {
    late AntEngine engine;
    setUp(() {
      final u = Unused();
      engine = AntEngine(
        db: h.db,
        profileId: 'p',
        ports: EnginePorts(secrets: u, blobs: h.blobs, git: u, watcher: u, clock: h.clock),
        router: h.router,
        utcOffset: (_) => Duration.zero,
      );
    });

    /// Adds one note with a blob per extension; returns extension → stored mime.
    Future<Map<String, String>> mimes(List<String> exts) async {
      final byPath = <String, String>{};
      for (final ext in exts) {
        byPath[await h.blobs.put(Uint8List.fromList([1, 2, 3]), extension: ext)] = ext;
      }
      final id = await engine.addNote(text: 'shots', at: at(10), attachmentPaths: byPath.keys.toList());
      final payload = (await h.payloadsOf(id)).single;
      final atts = await (h.db.select(h.db.attachments)..where((a) => a.payloadId.equals(payload.id))).get();
      expect(atts.map((a) => a.path).toSet(), byPath.keys.toSet());
      return {for (final a in atts) byPath[a.path]!: a.mime};
    }

    test('png / gif / webp / heic keep their own image type', () async {
      expect(await mimes(['png', 'gif', 'webp', 'heic']), {
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'heic': 'image/heic',
      });
    });

    test('jpg and jpeg (any case) are image/jpeg', () async {
      expect(await mimes(['jpg', 'JPG', 'jpeg', 'JPEG']), {
        'jpg': 'image/jpeg',
        'JPG': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'JPEG': 'image/jpeg',
      });
    });

    test('upper / mixed case of the other types map like lower case', () async {
      expect(await mimes(['PNG', 'Gif', 'WEBP', 'HEIC']), {
        'PNG': 'image/png',
        'Gif': 'image/gif',
        'WEBP': 'image/webp',
        'HEIC': 'image/heic',
      });
    });
  });

  group('workstreams reused by title', () {
    late WorkstreamAssigner ws;
    late String p;
    setUp(() async {
      ws = WorkstreamAssigner(h.ctx);
      p = await h.pid(await h.commit('a1', at(10)));
    });

    Future<Workstream> wsRow(String id) => (h.db.select(h.db.workstreams)..where((w) => w.id.equals(id))).getSingle();

    void answer(List<Map<String, Object?>> assignments) =>
        h.router.responders['workstreams'] = (_) => {'assignments': assignments};

    Map<String, Object?> byTitle(String fact, String title, String? summary) =>
        {'fact_id': fact, 'workstream_id': null, 'new_title': title, 'new_summary': summary};

    test('a user-touched workstream reused by title keeps its summary', () async {
      await h.db.into(h.db.workstreams).insert(WorkstreamsCompanion.insert(
            id: 'mine',
            title: 'Payments Retry',
            summary: const Value('My words.'),
            userTouched: const Value(true),
          ));
      await h.insertFact('new', [p]);
      answer([byTitle('new', 'payments retry', 'Model words.')]);
      await ws.assignDay(day);
      expect((await h.fact('new')).workstreamId, 'mine');
      expect((await wsRow('mine')).summary, 'My words.');
    });

    test('a non-touched workstream reused by title takes the trimmed new_summary', () async {
      await h.db.into(h.db.workstreams).insert(
            WorkstreamsCompanion.insert(id: 'auto', title: 'Payments Retry', summary: const Value('Old.')),
          );
      await h.insertFact('new', [p]);
      answer([byTitle('new', 'Payments Retry', '  New summary.  ')]);
      await ws.assignDay(day);
      expect((await h.fact('new')).workstreamId, 'auto');
      expect((await wsRow('auto')).summary, 'New summary.');
    });

    test('a non-touched workstream reused by title with a blank new_summary keeps its summary', () async {
      await h.db.into(h.db.workstreams).insert(
            WorkstreamsCompanion.insert(id: 'auto', title: 'Payments Retry', summary: const Value('Old.')),
          );
      await h.insertFact('a', [p]);
      await h.insertFact('b', [p]);
      answer([byTitle('a', 'Payments Retry', null), byTitle('b', 'Payments Retry', '   ')]);
      await ws.assignDay(day);
      expect((await h.fact('a')).workstreamId, 'auto');
      expect((await h.fact('b')).workstreamId, 'auto');
      expect((await wsRow('auto')).summary, 'Old.');
    });

    test('a brand-new title is created once with the summary from its first assignment', () async {
      await h.insertFact('a', [p]);
      await h.insertFact('b', [p]);
      answer([byTitle('a', 'Search Revamp', 'First summary.'), byTitle('b', 'search revamp', 'Second summary.')]);
      await ws.assignDay(day);
      final rows = await h.db.select(h.db.workstreams).get();
      expect(rows, hasLength(1));
      final w = rows.single;
      expect((w.title, w.summary, w.userTouched), ('Search Revamp', 'First summary.', false));
      expect((await h.fact('a')).workstreamId, w.id);
      expect((await h.fact('b')).workstreamId, w.id);
      expect((w.spanStart, w.spanEnd), (day, day));
    });
  });

  group('TimeAllocator.authoredByYou', () {
    Map<String, Object?> commit(Object? email) => {
          'author': {'name': 'Someone', 'email': email},
        };
    const me = {'me@acme.io'};

    test("'' and whitespace-only emails count as yours", () {
      expect(TimeAllocator.authoredByYou(commit(''), me), isTrue);
      expect(TimeAllocator.authoredByYou(commit('   '), me), isTrue);
      expect(TimeAllocator.authoredByYou(commit(' \t\n'), me), isTrue);
    });

    test('missing author / email / non-string email count as yours', () {
      expect(TimeAllocator.authoredByYou(const {}, me), isTrue);
      expect(TimeAllocator.authoredByYou({'author': 'not a map'}, me), isTrue);
      expect(TimeAllocator.authoredByYou(commit(null), me), isTrue);
      expect(TimeAllocator.authoredByYou(commit(42), me), isTrue);
    });

    test('a real email is yours only when it matches (trimmed, lower-cased)', () {
      expect(TimeAllocator.authoredByYou(commit(' ME@Acme.io '), me), isTrue);
      expect(TimeAllocator.authoredByYou(commit('other@acme.io'), me), isFalse);
    });

    test('a whitespace-only author email is kept in the time fact', () async {
      await h.db
          .into(h.db.identities)
          .insert(IdentitiesCompanion.insert(id: 'email:me', kind: 'email', value: 'me@acme.io'));
      final mine = await h.commit('a1', at(10), extra: commit('me@acme.io'));
      final blank = await h.commit('b1', at(14), extra: commit('  '));
      await h.commit('o1', at(16), extra: commit('other@acme.io'));
      await TimeAllocator(h.ctx).computeDay(day);
      final f = (await h.timeFacts()).single;
      expect((await h.citations(f.id)).map((c) => c.payloadId).toSet(), {await h.pid(mine), await h.pid(blank)});
    });
  });
}
