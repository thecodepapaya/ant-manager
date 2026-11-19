// Independent test fakes (#99): written without reference to the code author's test helpers.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/util/ids.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

ProfileDb memDb() => ProfileDb(NativeDatabase.memory());

class MutableClock implements Clock {
  MutableClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
}

class MemSecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class MemBlobs implements BlobStore {
  final files = <String, Uint8List>{};
  var _n = 0;
  @override
  Future<void> delete(String path) async => files.remove(path);
  @override
  Future<Uint8List> get(String path) async => files[path] ?? (throw StateError('no blob $path'));
  @override
  Future<String> put(Uint8List bytes, {required String extension}) async {
    final path = 'blobs/${++_n}.$extension';
    files[path] = bytes;
    return path;
  }
}

class NoGit implements GitExecutable {
  @override
  Future<String?> locate() async => null;
  @override
  Future<String> run(String repoPath, List<String> args) => throw UnimplementedError();
}

class NoWatcher implements FileWatcher {
  @override
  Stream<void> watch(List<String> paths) => const Stream.empty();
}

/// Scripted LLM: each call pops the next response (a JSON-able map or a raw string).
class ScriptedLlm implements LlmClient {
  ScriptedLlm(this.responses);
  final List<Object> responses;
  final requests = <LlmRequest>[];

  /// Runs before the response is returned (e.g. to simulate a concurrent user action).
  Future<void> Function()? during;

  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;
  @override
  Future<List<ModelInfo>> listModels() async => const [];
  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    requests.add(request);
    if (during != null) await during!();
    final r = responses.removeAt(0);
    final text = r is String ? r : jsonEncode(r);
    yield LlmDelta(text);
    yield LlmDone(text: text);
  }
}

class ScriptedRouter implements ModelRouter {
  ScriptedRouter(this.client, {this.contextLength = 100000, this.modelName = 'fake-model'});
  final LlmClient client;
  final int? contextLength;
  final String modelName;
  @override
  Future<ResolvedModel> resolve(LlmRoute route) async => ResolvedModel(
    client: client,
    modelName: modelName,
    info: ModelInfo(name: modelName, contextLength: contextLength),
  );
}

/// Minimal seeding helpers that go straight to tables (derived rows have no engine writer yet).
class Seed {
  Seed(this.db);
  final ProfileDb db;
  final now = DateTime.utc(2026, 11, 18, 12);
  var _n = 0;

  Future<String> source([SourceKind kind = SourceKind.gitRepo]) async {
    final id = 'src${++_n}';
    await db.into(db.sources).insert(SourcesCompanion.insert(id: id, kind: kind, name: id));
    return id;
  }

  Future<({String evidence, String payload})> evidence(
    String sourceId,
    String day,
    Map<String, Object?> content, {
    String? project,
    bool hidden = false,
    String title = 'title',
  }) async {
    final e = 'ev${++_n}';
    await db
        .into(db.evidences)
        .insert(
          EvidencesCompanion.insert(
            id: e,
            occurredStart: DateTime.parse('${day}T10:00:00Z'),
            day: day,
            title: title,
            projectId: Value(project),
            hidden: Value(hidden),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final p = 'pl${++_n}';
    final c = canonicalJson(content);
    await db
        .into(db.payloads)
        .insert(
          PayloadsCompanion.insert(
            id: p,
            evidenceId: e,
            sourceId: sourceId,
            kind: PayloadKind.note,
            externalId: p,
            content: c,
            contentHash: sha256Hex(c),
          ),
        );
    return (evidence: e, payload: p);
  }

  Future<String> fact(
    String statement,
    String start, {
    String? end,
    FactType type = FactType.outcome,
    double importance = 0.5,
    WinStatus win = WinStatus.none,
    FactOrigin origin = FactOrigin.inferred,
    String? project,
    String? workstream,
    bool retired = false,
    Map<String, Object?> details = const {},
    List<String> cites = const [],
  }) async {
    final id = 'fa${++_n}';
    await db
        .into(db.facts)
        .insert(
          FactsCompanion.insert(
            id: id,
            type: type,
            statement: statement,
            details: Value(jsonEncode(details)),
            periodStart: start,
            periodEnd: end ?? start,
            projectId: Value(project),
            workstreamId: Value(workstream),
            importance: Value(importance),
            origin: origin,
            winStatus: Value(win),
            retired: Value(retired),
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final p in cites) {
      await db.into(db.citations).insert(CitationsCompanion.insert(factId: id, payloadId: p, payloadRevision: 1));
    }
    return id;
  }

  Future<int> queueCount([EntityType? type, String? id]) async {
    final rows = await db.select(db.recomputeQueue).get();
    return rows.where((r) => (type == null || r.entityType == type) && (id == null || r.entityId == id)).length;
  }
}
