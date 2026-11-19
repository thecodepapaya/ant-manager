import 'dart:convert';

import 'package:core/core.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  late ScriptSource src;
  late SyncService svc;

  setUp(() {
    h = Harness.create();
    src = ScriptSource(SourceKind.github, (_) => const Stream.empty());
    h.engine.sources.register(SourceKind.github, () => src);
    svc = h.service();
  });
  tearDown(() => h.db.close());

  Future<SourceRow> row(String id) => (h.db.select(h.db.sources)..where((s) => s.id.equals(id))).getSingle();

  group('addSource / updateSource (claim 8)', () {
    test('stores the secret so ctx.secret() returns it, and persists kind/name/config', () async {
      final id = await svc.addSource(SourceKind.github, 'GH', {'org': 'acme'}, secret: 'tok-1');
      final r = await row(id);
      expect(r.kind, SourceKind.github);
      expect(r.name, 'GH');
      expect(jsonDecode(r.config), {'org': 'acme'});
      expect(r.enabled, isTrue);
      expect(r.credentialRef, isNotNull);
      expect(h.secrets.map[r.credentialRef], 'tok-1');

      await svc.syncSource(id);
      expect(await src.contexts.last.secret(), 'tok-1');
      expect(src.contexts.last.config, {'org': 'acme'});
    });

    test('two sources get distinct ids and secrets', () async {
      final a = await svc.addSource(SourceKind.github, 'A', {}, secret: 'ta');
      final b = await svc.addSource(SourceKind.github, 'B', {}, secret: 'tb');
      expect(a, isNot(b));
      await svc.validateSource(a);
      expect(await src.contexts.last.secret(), 'ta');
      await svc.validateSource(b);
      expect(await src.contexts.last.secret(), 'tb');
    });

    test('no secret -> null credentialRef, nothing written, ctx.secret() null', () async {
      final id = await svc.addSource(SourceKind.github, 'GH', {});
      expect((await row(id)).credentialRef, isNull);
      expect(h.secrets.map, isEmpty);
      await svc.validateSource(id);
      expect(await src.contexts.last.secret(), isNull);
    });

    test('updateSource adds a secret to a source that had none', () async {
      final id = await svc.addSource(SourceKind.github, 'GH', {});
      await svc.updateSource(id, secret: 'new');
      expect((await row(id)).credentialRef, isNotNull);
      await svc.validateSource(id);
      expect(await src.contexts.last.secret(), 'new');
    });

    test('updateSource replaces the secret under the same ref', () async {
      final id = await svc.addSource(SourceKind.github, 'GH', {}, secret: 'old');
      final ref = (await row(id)).credentialRef;
      await svc.updateSource(id, secret: 'new');
      expect((await row(id)).credentialRef, ref);
      expect(h.secrets.map[ref], 'new');
      expect(h.secrets.map, hasLength(1));
    });

    test('updateSource changes only the given fields and keeps cursors', () async {
      h.engine.sources.register(SourceKind.github, () => ScriptSource(SourceKind.github, (ctx) async* {
            ctx.setCursor('since', 'c1');
          }));
      final id = await svc.addSource(SourceKind.github, 'GH', {'a': 1}, secret: 's');
      await svc.syncSource(id);

      await svc.updateSource(id, name: 'Renamed');
      var r = await row(id);
      expect(r.name, 'Renamed');
      expect(jsonDecode(r.config), {'a': 1});
      expect(r.credentialRef, isNotNull);
      expect(r.enabled, isTrue);

      await svc.updateSource(id, config: {'b': 2});
      r = await row(id);
      expect(r.name, 'Renamed');
      expect(jsonDecode(r.config), {'b': 2});

      expect((await h.cursorMap(id))['since'], 'c1');
      expect((await h.status(id))!.lastSuccessAt, isNotNull);
    });

    test('removeSource only disables: evidence, cursors and secret are kept; no longer synced', () async {
      h.engine.sources.register(SourceKind.github, () => ScriptSource(SourceKind.github, (ctx) async* {
            ctx.setCursor('since', 'c1');
            yield obs('a');
          }));
      final id = await svc.addSource(SourceKind.github, 'GH', {}, secret: 'tok');
      await svc.syncSource(id);
      final ref = (await row(id)).credentialRef;

      await svc.removeSource(id);
      final r = await row(id);
      expect(r.enabled, isFalse);
      expect(r.credentialRef, ref);
      expect(h.secrets.map[ref], 'tok');
      expect(await h.externalIds(id), ['a']);
      expect((await h.db.select(h.db.evidences).get()), hasLength(1));
      expect((await h.cursorMap(id))['since'], 'c1');
      expect(await svc.syncAll(), isEmpty);
      expect(await SyncScheduler(svc).tick(), isEmpty);
    });

    test('validateSource returns the source health', () async {
      src.onValidate = (ctx) async => SourceHealth.error('bad token for ${ctx.sourceId}');
      final id = await svc.addSource(SourceKind.github, 'GH', {});
      final health = await svc.validateSource(id);
      expect(health.ok, isFalse);
      expect(health.message, 'bad token for $id');
    });
  });

  group('importTranscript (claim 9)', () {
    const vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:05.000\n<v Ann>Hello team\n\n'
        '00:00:05.000 --> 00:30:00.000\n<v Bob>Shipped it\n';
    final at = DateTime.utc(2026, 11, 17, 9);

    test('returns the same evidence id on re-import of the same file', () async {
      final first = await svc.importTranscript('standup.vtt', vtt, at);
      final again = await svc.importTranscript('standup.vtt', vtt, at);
      expect(again, first);
      expect(await h.db.select(h.db.evidences).get(), hasLength(1));
      final payloads = await h.db.select(h.db.payloads).get();
      expect(payloads, hasLength(1));
      expect(payloads.single.kind, PayloadKind.transcript);
      expect(payloads.single.revision, 1);
      final ev = await h.db.select(h.db.evidences).getSingle();
      expect(ev.id, first);
      expect(ev.title, 'standup');
    });

    test('a different file gets a new evidence; all under one built-in transcript source', () async {
      final a = await svc.importTranscript('a.txt', 'one', at);
      final b = await svc.importTranscript('b.txt', 'two', at);
      expect(a, isNot(b));
      final sources = await (h.db.select(h.db.sources)..where((s) => s.kind.equalsValue(SourceKind.transcript))).get();
      expect(sources, hasLength(1));
      final ids = (await h.db.select(h.db.payloads).get()).map((p) => p.sourceId).toSet();
      expect(ids, {sources.single.id});
    });

    test('the transcript source is not synced (no connector registered)', () async {
      await svc.importTranscript('a.txt', 'one', at);
      expect(await svc.syncAll(), isEmpty);
    });
  });
}
