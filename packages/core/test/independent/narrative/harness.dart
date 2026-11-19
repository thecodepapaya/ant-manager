// Independent test harness for the narrative pipeline: in-memory ProfileDb, the real Ingestor,
// and a fake model router that answers per schema and records every call.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';

/// One recorded model call.
class Call {
  Call(this.route, this.request);
  final LlmRoute route;
  final LlmRequest request;
  String get schema => request.schemaName;
  String get user => request.messages.last.text;
  List<LlmImage> get images => request.messages.last.images;
}

typedef Responder = Map<String, Object?> Function(Call call);

/// Model router whose client answers by schema name. Unhandled schemas get sensible defaults that
/// echo the ids found in the prompt, so every stage produces something unless a test overrides it.
class FakeRouter implements ModelRouter {
  FakeRouter({this.contextLength = 32000});
  final int contextLength;
  final calls = <Call>[];
  final responders = <String, Responder>{};

  /// Awaited before each answer (to simulate user actions while the model is thinking).
  Future<void> Function(Call call)? onCall;

  List<Call> of(String schema) => calls.where((c) => c.schema == schema).toList();

  @override
  Future<ResolvedModel> resolve(LlmRoute route) async => ResolvedModel(
    client: _RouteClient(this, route),
    modelName: 'fake-${route.name}',
    info: ModelInfo(name: 'fake-${route.name}', contextLength: contextLength, vision: true),
  );

  Map<String, Object?> answer(Call c) {
    final r = responders[c.schema];
    if (r != null) return r(c);
    return switch (c.schema) {
      'importance' => {
        'scores': [
          for (final i in jsonItems(c.user, 'Rate these evidence items:\n'))
            {'evidence_id': i['evidence_id'], 'score': 0.7, 'reason': 'fake'},
        ],
      },
      'enrichment' => {
        'items': [
          for (final i in jsonItems(c.user, ':\n'))
            {'payload_id': i['payload_id'], 'summary': 'summary of ${i['payload_id']}'},
        ],
      },
      'image_description' => {'description': 'a screenshot'},
      'fact_ops' => {'ops': <Object?>[]},
      'workstreams' => {'assignments': <Object?>[]},
      'win' => {'statement': 'Shipped the thing.', 'citations': <Object?>[]},
      _ => throw StateError('unexpected schema ${c.schema}'),
    };
  }

  /// Parses the JSON array that follows [marker] in a prompt.
  static List<Map<String, Object?>> jsonItems(String user, String marker) {
    final i = user.indexOf(marker);
    final list = jsonDecode(user.substring(i + marker.length)) as List;
    return list.cast<Map<String, Object?>>();
  }

  /// All `payload_id=…` ids in a fact-extraction prompt.
  static List<String> payloadIds(String user) =>
      RegExp(r'payload_id=(\S+)').allMatches(user).map((m) => m.group(1)!).toList();
}

class _RouteClient implements LlmClient {
  _RouteClient(this.router, this.route);
  final FakeRouter router;
  final LlmRoute route;
  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;
  @override
  Future<List<ModelInfo>> listModels() async => const [];
  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    final c = Call(route, request);
    router.calls.add(c);
    await router.onCall?.call(c);
    final text = jsonEncode(router.answer(c));
    yield LlmDone(text: text);
  }
}

class FakeBlobs implements BlobStore {
  final files = <String, Uint8List>{};
  final deleted = <String>[];
  var _n = 0;
  @override
  Future<String> put(Uint8List bytes, {required String extension}) async {
    final p = 'blob${++_n}.$extension';
    files[p] = bytes;
    return p;
  }

  @override
  Future<Uint8List> get(String path) async => files[path] ?? (throw StateError('no blob $path'));
  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
  }
}

class TestClock implements Clock {
  TestClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}

class Unused implements SecretStore, GitExecutable, FileWatcher {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

const day = '2026-11-17';
DateTime at(int h, [int m = 0, String d = day]) => DateTime.parse('${d}T00:00:00Z').add(Duration(hours: h, minutes: m));

class H {
  H({Duration offset = Duration.zero})
    : db = ProfileDb(NativeDatabase.memory()),
      router = FakeRouter(),
      blobs = FakeBlobs(),
      clock = TestClock(DateTime.utc(2026, 11, 18, 12)) {
    ingestor = Ingestor(db, utcOffset: (_) => offset);
    ctx = NarrativeContext(db: db, router: router, blobs: blobs, clock: clock);
  }

  final ProfileDb db;
  final FakeRouter router;
  final FakeBlobs blobs;
  final TestClock clock;
  late final Ingestor ingestor;
  late final NarrativeContext ctx;

  static const git = 'src-git', cal = 'src-cal', gh = 'src-gh', notes = 'src-notes';

  Future<void> setUp() async {
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: git,
            kind: SourceKind.gitRepo,
            name: 'git',
            config: const Value('{"path":"/Users/me/code/acme/api"}'),
          ),
        );
    await db.into(db.sources).insert(SourcesCompanion.insert(id: cal, kind: SourceKind.googleCalendar, name: 'cal'));
    await db.into(db.sources).insert(SourcesCompanion.insert(id: gh, kind: SourceKind.github, name: 'gh'));
    await db.into(db.sources).insert(SourcesCompanion.insert(id: notes, kind: SourceKind.manualNote, name: 'notes'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'pay', name: 'Payments'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'web', name: 'Website'));
  }

  Future<void> close() => db.close();

  // ---------- ingest helpers (return the evidence id) ----------

  Future<String> ingest(String source, PayloadObservation o) async {
    await ingestor.ingest(source, [o]);
    return (await payloadByExt(source, o.externalId)).evidenceId;
  }

  Future<String> commit(String sha, DateTime t, {String msg = 'commit', Map<String, Object?> extra = const {}}) =>
      ingest(
        git,
        PayloadObservation(
          externalId: sha,
          kind: PayloadKind.commit,
          content: {'sha': sha, 'message': msg, ...extra},
          occurredStart: t,
          title: msg,
          groupKey: sha,
        ),
      );

  Future<String> meeting(
    String id,
    DateTime start,
    DateTime end, {
    String title = 'Meeting',
    int attendees = 3,
    bool allDay = false,
    Map<String, Object?> extra = const {},
  }) => ingest(
    cal,
    PayloadObservation(
      externalId: id,
      kind: PayloadKind.calendarEvent,
      content: {
        'title': title,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'allDay': allDay,
        'attendeesCount': attendees,
        ...extra,
      },
      occurredStart: start,
      occurredEnd: end,
      title: title,
    ),
  );

  Future<String> pr(String id, DateTime t, {String title = 'PR', String repo = 'acme/api'}) => ingest(
    gh,
    PayloadObservation(
      externalId: id,
      kind: PayloadKind.pullRequest,
      content: {'title': title, 'repo': repo, 'state': 'merged'},
      occurredStart: t,
      title: title,
    ),
  );

  Future<String> note(
    String id,
    DateTime t,
    String text, {
    PayloadKind kind = PayloadKind.note,
    List<String> attachments = const [],
  }) => ingest(
    notes,
    PayloadObservation(
      externalId: id,
      kind: kind,
      content: {'text': text, if (attachments.isNotEmpty) 'attachments': attachments},
      occurredStart: t,
      title: text,
    ),
  );

  // ---------- queries ----------

  Future<Payload> payloadByExt(String source, String ext) =>
      (db.select(db.payloads)..where((p) => p.sourceId.equals(source) & p.externalId.equals(ext))).getSingle();

  Future<List<Payload>> payloadsOf(String evidenceId) =>
      (db.select(db.payloads)..where((p) => p.evidenceId.equals(evidenceId))).get();

  Future<String> pid(String evidenceId) async => (await payloadsOf(evidenceId)).first.id;

  Future<Evidence> evidence(String id) => (db.select(db.evidences)..where((e) => e.id.equals(id))).getSingle();

  Future<Fact> fact(String id) => (db.select(db.facts)..where((f) => f.id.equals(id))).getSingle();

  Future<List<Fact>> facts({FactType? type, bool includeRetired = true}) async {
    final all = await db.select(db.facts).get();
    return all.where((f) => (type == null || f.type == type) && (includeRetired || !f.retired)).toList();
  }

  Future<List<Fact>> timeFacts({bool live = true}) async =>
      (await facts(type: FactType.timeAllocation)).where((f) => !live || !f.retired).toList();

  Future<List<Citation>> citations(String factId) =>
      (db.select(db.citations)..where((c) => c.factId.equals(factId))).get();

  Future<List<FactRevision>> history(String factId) =>
      (db.select(db.factRevisions)..where((r) => r.factId.equals(factId))).get();

  Future<List<Dependency>> depsOf(EntityType type, String id) =>
      (db.select(db.dependencies)..where((d) => d.dependentType.equalsValue(type) & d.dependentId.equals(id))).get();

  Future<Enrichment?> enrichmentOf(String payloadId) =>
      (db.select(db.enrichments)..where((n) => n.targetId.equals(payloadId))).getSingleOrNull();

  Future<void> clearQueue() => db.delete(db.recomputeQueue).go();

  /// Inserts a fact directly (for reconciler tests), with citations pinned to current revisions.
  Future<String> insertFact(
    String id,
    List<String> payloadIds, {
    FactType type = FactType.outcome,
    String statement = 'Did a thing.',
    FactOrigin origin = FactOrigin.inferred,
    WinStatus win = WinStatus.none,
    bool retired = false,
    String d = day,
    String? workstream,
    String? project,
  }) async {
    final now = clock.now();
    await db
        .into(db.facts)
        .insert(
          FactsCompanion.insert(
            id: id,
            type: type,
            statement: statement,
            periodStart: d,
            periodEnd: d,
            origin: origin,
            winStatus: Value(win),
            retired: Value(retired),
            workstreamId: Value(workstream),
            projectId: Value(project),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.factRevisions)
        .insert(
          FactRevisionsCompanion.insert(
            factId: id,
            revision: 1,
            statement: statement,
            details: '{}',
            origin: origin,
            changedBy: 'model',
            changedAt: now,
          ),
        );
    for (final p in payloadIds) {
      final row = await (db.select(db.payloads)..where((x) => x.id.equals(p))).getSingle();
      await db
          .into(db.citations)
          .insert(CitationsCompanion.insert(factId: id, payloadId: p, payloadRevision: row.revision));
    }
    return id;
  }

  Future<void> setProject(String evidenceId, String? project) => (db.update(
    db.evidences,
  )..where((e) => e.id.equals(evidenceId))).write(EvidencesCompanion(projectId: Value(project)));

  Future<void> setHidden(String evidenceId, bool hidden) =>
      (db.update(db.evidences)..where((e) => e.id.equals(evidenceId))).write(EvidencesCompanion(hidden: Value(hidden)));

  Future<void> rule(
    String id,
    Map<String, Object?> match,
    CurationAction action, {
    double value = 0,
    int priority = 0,
    bool enabled = true,
  }) => db
      .into(db.curationRules)
      .insert(
        CurationRulesCompanion.insert(
          id: id,
          match: jsonEncode(match),
          action: action,
          value: Value(value),
          priority: Value(priority),
          enabled: Value(enabled),
        ),
      );
}

/// fact_ops responder helpers.
Map<String, Object?> createOp(
  List<String> cites, {
  String type = 'outcome',
  String statement = 'Shipped the payments retry.',
  bool suggestWin = false,
  String? project,
  double importance = 0.6,
}) => {
  'op': 'create',
  'fact_id': null,
  'type': type,
  'statement': statement,
  'citations': cites,
  'project_id': project,
  'importance': importance,
  'suggest_win': suggestWin,
  'reason': null,
};

Map<String, Object?> updateOp(String factId, String statement, List<String> cites) => {
  'op': 'update',
  'fact_id': factId,
  'type': null,
  'statement': statement,
  'citations': cites,
  'project_id': null,
  'importance': null,
  'suggest_win': null,
  'reason': 'changed',
};

Map<String, Object?> retireOp(String factId) => {
  'op': 'retire',
  'fact_id': factId,
  'type': null,
  'statement': null,
  'citations': <String>[],
  'project_id': null,
  'importance': null,
  'suggest_win': null,
  'reason': 'gone',
};
