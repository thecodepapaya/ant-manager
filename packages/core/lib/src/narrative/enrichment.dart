import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../ai/llm.dart';
import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../util/ids.dart';
import 'context.dart';
import 'interfaces.dart';

/// Text summary for one or more payloads of a kind in a single call (Extraction route).
class SummaryStrategy implements EnrichmentStrategy {
  SummaryStrategy(this.ctx, this.kind, this.focus);
  final NarrativeContext ctx;
  @override
  final PayloadKind kind;

  /// What the summary should capture for this kind.
  final String focus;

  static const excerptChars = 6000;

  @override
  LlmRoute get route => LlmRoute.extraction;

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'payload_id': {'type': 'string'},
            'summary': {'type': 'string'},
          },
          'required': ['payload_id', 'summary'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, String>> enrich(List<Payload> payloads) async {
    if (payloads.isEmpty) return {};
    final input = [
      for (final x in payloads) {'payload_id': x.id, 'content': excerpt(x, excerptChars)},
    ];
    final out = await ctx.structured(
      route,
      system:
          '''
You summarize raw work records for an engineer's work log. For each item write 1–3 plain sentences: $focus
Use only what the content says; don't guess motives or outcomes that aren't stated. No preamble.
Return one entry per payload_id given.''',
      user: 'Items (${kind.name}):\n${const JsonEncoder.withIndent(' ').convert(input)}',
      schema: schema,
      schemaName: 'enrichment',
    );
    final ids = payloads.map((x) => x.id).toSet();
    return {
      for (final i in (out['items'] as List? ?? const []).whereType<Map>())
        if (ids.contains(i['payload_id']) && i['summary'] is String) i['payload_id'] as String: i['summary'] as String,
    };
  }
}

/// Screenshot → description (Vision route). One call per payload: images are large.
class ImageDescriptionStrategy implements EnrichmentStrategy {
  ImageDescriptionStrategy(this.ctx);
  final NarrativeContext ctx;

  @override
  PayloadKind get kind => PayloadKind.image;
  @override
  LlmRoute get route => LlmRoute.vision;

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'description': {'type': 'string'},
    },
    'required': ['description'],
    'additionalProperties': false,
  };

  static const system = '''
You describe screenshots an engineer captured as evidence of their work. In 2–5 sentences state:
the visible text that matters (titles, messages, numbers, error text), who/what/where if visible (app, channel,
dashboard, people's names), and quote verbatim any praise, thanks or recognition. Don't speculate beyond the image.''';

  @override
  Future<Map<String, String>> enrich(List<Payload> payloads) async {
    final out = <String, String>{};
    for (final x in payloads) {
      final images = await _images(x);
      final c = contentOf(x);
      final note = [c['text'], c['link']].whereType<String>().where((s) => s.isNotEmpty).join('\n');
      if (images.isEmpty) {
        out[x.id] = note.isEmpty ? '(image unavailable)' : note;
        continue;
      }
      final r = await ctx.structured(
        route,
        system: system,
        user: note.isEmpty ? 'Describe the screenshot.' : 'Describe the screenshot. The user\'s note: $note',
        images: images,
        schema: schema,
        schemaName: 'image_description',
      );
      if (r['description'] is String) out[x.id] = r['description'] as String;
    }
    return out;
  }

  Future<List<LlmImage>> _images(Payload x) async {
    final paths = <String>{
      ...((contentOf(x)['attachments'] as List?) ?? const []).whereType<String>(),
      ...(await (ctx.db.select(ctx.db.attachments)..where((a) => a.payloadId.equals(x.id))).get()).map((a) => a.path),
    };
    final images = <LlmImage>[];
    for (final path in paths) {
      final mime = _mime(path);
      if (mime == null) continue;
      images.add(LlmImage(mime: mime, base64: base64Encode(await ctx.blobs.get(path))));
    }
    return images;
  }

  static String? _mime(String path) => switch (p.extension(path).toLowerCase()) {
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    _ => null,
  };
}

/// One strategy per payload kind (#91).
List<EnrichmentStrategy> defaultEnrichmentStrategies(NarrativeContext ctx) => [
  SummaryStrategy(ctx, PayloadKind.commit, 'what changed and why, from the message and patch.'),
  SummaryStrategy(
    ctx,
    PayloadKind.pullRequest,
    'the purpose, the outcome (merged/closed/open) and the author\'s role.',
  ),
  SummaryStrategy(ctx, PayloadKind.review, 'what was reviewed, the substance of the feedback, and the outcome.'),
  SummaryStrategy(ctx, PayloadKind.issue, 'the problem, its status, and the author\'s role.'),
  SummaryStrategy(
    ctx,
    PayloadKind.calendarEvent,
    'the purpose of the meeting and the user\'s likely role, from the title, description and attendees.',
  ),
  SummaryStrategy(ctx, PayloadKind.note, 'a normalized restatement of the note: what was done, decided or learned.'),
  SummaryStrategy(ctx, PayloadKind.transcript, 'decisions, action items, and who said what that matters.'),
  ImageDescriptionStrategy(ctx),
];

/// Enrichments row kind per payload kind.
String enrichmentKind(PayloadKind k) => switch (k) {
  PayloadKind.image => 'image_description',
  PayloadKind.transcript => 'transcript_summary',
  _ => 'summary',
};

/// Runs strategies over a day's payloads that have no enrichment or whose payload changed (LLD 04 §4.5).
class Enricher {
  Enricher(this.ctx, this.registry);
  final NarrativeContext ctx;
  final EnrichmentRegistry registry;
  ProfileDb get db => ctx.db;

  static const maxBatch = 8;
  static const maxBatchChars = 24000;

  Future<void> enrichDay(String day) async {
    final evidence = await (db.select(db.evidences)..where((e) => e.day.equals(day) & e.hidden.equals(false))).get();
    if (evidence.isEmpty) return;
    final payloads = await (db.select(
      db.payloads,
    )..where((x) => x.evidenceId.isIn(evidence.map((e) => e.id)) & x.tombstonedAt.isNull())).get();
    final existing = {
      for (final n in await (db.select(
        db.enrichments,
      )..where((n) => n.targetType.equalsValue(EntityType.payload) & n.targetId.isIn(payloads.map((x) => x.id)))).get())
        n.targetId: n,
    };
    final recorded = <String, int>{};
    if (existing.isNotEmpty) {
      for (final d
          in await (db.select(db.dependencies)..where(
                (d) =>
                    d.dependentType.equalsValue(EntityType.enrichment) &
                    d.dependentId.isIn(existing.values.map((n) => n.id)) &
                    d.inputType.equalsValue(EntityType.payload),
              ))
              .get()) {
        recorded[d.dependentId] = d.inputRevision;
      }
    }
    final todo = payloads.where((x) {
      final n = existing[x.id];
      return n == null || recorded[n.id] != x.revision;
    }).toList();

    final byKind = <PayloadKind, List<Payload>>{};
    for (final x in todo) {
      byKind.putIfAbsent(x.kind, () => []).add(x);
    }
    for (final MapEntry(key: kind, value: list) in byKind.entries) {
      final strategy = registry[kind];
      if (strategy == null) continue;
      final model = await ctx.modelName(strategy.route);
      for (final batch in _batches(list)) {
        final out = await strategy.enrich(batch);
        // Short write transaction after the model call; a payload that changed or went away
        // meanwhile is discarded and its day re-queued.
        await db.transaction(() async {
          final now = await db.payloadsById(batch.map((x) => x.id));
          for (final x in batch) {
            final text = out[x.id];
            if (text == null) continue;
            final cur = now[x.id];
            if (cur == null || cur.tombstonedAt != null || cur.revision != x.revision) {
              await ctx.enqueue(EntityType.day, day, 'payload changed during enrichment');
              continue;
            }
            final n = await (db.select(db.enrichments)
                  ..where((n) => n.targetType.equalsValue(EntityType.payload) & n.targetId.equals(x.id)))
                .getSingleOrNull();
            await _write(x, n, text, model);
          }
        });
      }
    }
  }

  Iterable<List<Payload>> _batches(List<Payload> list) sync* {
    var cur = <Payload>[];
    var chars = 0;
    for (final x in list) {
      final n = x.content.length.clamp(0, SummaryStrategy.excerptChars);
      if (cur.isNotEmpty && (cur.length >= maxBatch || chars + n > maxBatchChars)) {
        yield cur;
        cur = [];
        chars = 0;
      }
      cur.add(x);
      chars += n;
    }
    if (cur.isNotEmpty) yield cur;
  }

  Future<void> _write(Payload x, Enrichment? n, String output, String model) async {
    final String id;
    final int rev;
    if (n == null) {
      id = newId(ctx.clock.now());
      rev = 1;
      await db
          .into(db.enrichments)
          .insert(
            EnrichmentsCompanion.insert(
              id: id,
              targetType: EntityType.payload,
              targetId: x.id,
              kind: enrichmentKind(x.kind),
              output: output,
              modelId: model,
              createdAt: ctx.clock.now(),
            ),
          );
    } else {
      id = n.id;
      rev = n.output == output ? n.revision : n.revision + 1;
      if (rev != n.revision) {
        await (db.update(db.enrichments)..where((e) => e.id.equals(id))).write(
          EnrichmentsCompanion(
            output: Value(output),
            modelId: Value(model),
            revision: Value(rev),
            createdAt: Value(ctx.clock.now()),
          ),
        );
      }
    }
    await ctx.deps.record(
      (type: EntityType.enrichment, id: id),
      rev,
      [(type: EntityType.payload, id: x.id, revision: x.revision)],
    );
  }
}
