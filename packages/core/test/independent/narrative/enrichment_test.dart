import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:core/src/narrative/enrichment.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late Enricher enricher;
  setUp(() async {
    h = H();
    await h.setUp();
    final reg = EnrichmentRegistry();
    for (final s in defaultEnrichmentStrategies(h.ctx)) {
      reg.register(s);
    }
    enricher = Enricher(h.ctx, reg);
  });
  tearDown(() => h.close());

  test('every PayloadKind has a strategy; images use vision, the rest extraction', () {
    final byKind = {for (final s in defaultEnrichmentStrategies(h.ctx)) s.kind: s};
    expect(byKind.keys.toSet(), PayloadKind.values.toSet());
    for (final k in PayloadKind.values) {
      expect(byKind[k]!.route, k == PayloadKind.image ? LlmRoute.vision : LlmRoute.extraction, reason: k.name);
    }
  });

  test('each kind of payload gets an enrichment row of the right kind', () async {
    final ids = <PayloadKind, String>{};
    ids[PayloadKind.commit] = await h.pid(await h.commit('a1', at(9)));
    ids[PayloadKind.calendarEvent] = await h.pid(await h.meeting('m1', at(10), at(11)));
    ids[PayloadKind.pullRequest] = await h.pid(await h.pr('pr1', at(12)));
    ids[PayloadKind.note] = await h.pid(await h.note('n1', at(13), 'note'));
    ids[PayloadKind.transcript] = await h.pid(await h.note('t1', at(14), 'transcript', kind: PayloadKind.transcript));
    ids[PayloadKind.review] = await h.pid(await h.note('r1', at(15), 'review', kind: PayloadKind.review));
    ids[PayloadKind.issue] = await h.pid(await h.note('i1', at(16), 'issue', kind: PayloadKind.issue));
    await enricher.enrichDay(day);
    for (final MapEntry(key: k, value: p) in ids.entries) {
      final n = await h.enrichmentOf(p);
      expect(n, isNotNull, reason: k.name);
      expect(n!.output, 'summary of $p');
      expect(n.kind, k == PayloadKind.transcript ? 'transcript_summary' : 'summary');
      expect(n.targetType, EntityType.payload);
      expect(n.modelId, 'fake-extraction');
    }
    expect(h.router.calls.every((c) => c.route == LlmRoute.extraction), isTrue);
  });

  test('images go to the vision route with base64 bytes from the BlobStore', () async {
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));
    final path = await h.blobs.put(bytes, extension: 'png');
    final p = await h.pid(await h.note('img', at(9), 'praise from Bob', kind: PayloadKind.image, attachments: [path]));
    await enricher.enrichDay(day);
    final c = h.router.of('image_description').single;
    expect(c.route, LlmRoute.vision);
    expect(c.images.single.mime, 'image/png');
    expect(c.images.single.base64, base64Encode(bytes));
    final n = (await h.enrichmentOf(p))!;
    expect((n.kind, n.output, n.modelId), ('image_description', 'a screenshot', 'fake-vision'));
  });

  test('small payloads of a kind are batched into one call', () async {
    for (var i = 0; i < 5; i++) {
      await h.commit('c$i', at(9, i));
    }
    await enricher.enrichDay(day);
    expect(h.router.of('enrichment'), hasLength(1));
    expect(FakeRouter.jsonItems(h.router.calls.single.user, ':\n'), hasLength(5));
  });

  test('re-runs only when the payload revision changes', () async {
    final e = await h.commit('a1', at(9));
    await h.commit('a2', at(10));
    await enricher.enrichDay(day);
    expect(h.router.calls, hasLength(1));
    await enricher.enrichDay(day);
    expect(h.router.calls, hasLength(1), reason: 'cached');
    await h.commit('a1', at(9), extra: {'amended': true});
    await enricher.enrichDay(day);
    expect(h.router.calls, hasLength(2));
    expect(FakeRouter.jsonItems(h.router.calls.last.user, ':\n').map((i) => i['payload_id']), [await h.pid(e)]);
  });

  test('dependency rows pin the payload revision; enrichment revision bumps only when the text changes', () async {
    final p = await h.pid(await h.commit('a1', at(9)));
    await enricher.enrichDay(day);
    var n = (await h.enrichmentOf(p))!;
    expect(n.revision, 1);
    var deps = await h.depsOf(EntityType.enrichment, n.id);
    expect(deps.map((d) => (d.inputType, d.inputId, d.inputRevision, d.dependentRevision)), [
      (EntityType.payload, p, 1, 1),
    ]);

    // Payload changes, model writes the same text → no revision bump, dependency moves to payload r2.
    await h.commit('a1', at(9), extra: {'v': 2});
    await enricher.enrichDay(day);
    n = (await h.enrichmentOf(p))!;
    expect(n.revision, 1);
    deps = await h.depsOf(EntityType.enrichment, n.id);
    expect(deps.single.inputRevision, 2);
    expect(await h.ctx.isStale(EntityType.enrichment, n.id), isFalse);

    // Payload changes and the text changes → revision 2.
    h.router.responders['enrichment'] = (c) => {
      'items': [
        for (final i in FakeRouter.jsonItems(c.user, ':\n')) {'payload_id': i['payload_id'], 'summary': 'new text'},
      ],
    };
    await h.commit('a1', at(9), extra: {'v': 3});
    await enricher.enrichDay(day);
    n = (await h.enrichmentOf(p))!;
    expect((n.revision, n.output), (2, 'new text'));
    deps = await h.depsOf(EntityType.enrichment, n.id);
    expect((deps.single.inputRevision, deps.single.dependentRevision), (3, 2));
  });

  test('tombstoned payloads are not enriched', () async {
    await h.ingestor.ingest(H.git, [
      PayloadObservation(
        externalId: 'x',
        kind: PayloadKind.commit,
        content: const {'a': 1},
        occurredStart: at(9),
        title: 't',
      ),
    ]);
    await h.ingestor.ingest(H.git, [
      PayloadObservation(
        externalId: 'x',
        kind: PayloadKind.commit,
        content: const {'a': 1},
        occurredStart: at(9),
        title: 't',
        tombstone: true,
      ),
    ]);
    await enricher.enrichDay(day);
    expect(h.router.calls, isEmpty);
  });

  test('a summary the model omits is retried on the next run (no row written)', () async {
    final p = await h.pid(await h.commit('a1', at(9)));
    h.router.responders['enrichment'] = (_) => {'items': <Object?>[]};
    await enricher.enrichDay(day);
    expect(await h.enrichmentOf(p), isNull);
    h.router.responders.remove('enrichment');
    await enricher.enrichDay(day);
    expect(await h.enrichmentOf(p), isNotNull);
  });
}
