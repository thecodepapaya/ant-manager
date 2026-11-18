import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/util/ids.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Shared test data for tools, reports and backup tests.
class Fixture {
  Fixture([ProfileDb? db]) : db = db ?? ProfileDb(NativeDatabase.memory());
  final ProfileDb db;
  final _now = DateTime.utc(2026, 11, 18);
  var _n = 0;

  Future<void> base() async {
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.gitRepo, name: 'repo'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'pay', name: 'Payments'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'web', name: 'Website'));
  }

  Future<String> evidence(
    String day,
    String title,
    Map<String, Object?> content, {
    String? project,
    bool hidden = false,
    PayloadKind kind = PayloadKind.commit,
  }) async {
    final id = 'e${++_n}';
    await db
        .into(db.evidences)
        .insert(
          EvidencesCompanion.insert(
            id: id,
            occurredStart: DateTime.parse('${day}T10:00:00Z'),
            day: day,
            title: title,
            projectId: Value(project),
            hidden: Value(hidden),
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    final c = canonicalJson(content);
    await db
        .into(db.payloads)
        .insert(
          PayloadsCompanion.insert(
            id: 'p$_n',
            evidenceId: id,
            sourceId: 's1',
            kind: kind,
            externalId: 'x$_n',
            content: c,
            contentHash: sha256Hex(c),
          ),
        );
    return id;
  }

  Future<String> fact(
    FactType type,
    String statement,
    String start, {
    String? end,
    String? project,
    double importance = 0.5,
    WinStatus win = WinStatus.none,
    bool retired = false,
    String? workstream,
    Map<String, Object?> details = const {},
    String? id,
  }) async {
    final fid = id ?? 'f${++_n}';
    await db
        .into(db.facts)
        .insert(
          FactsCompanion.insert(
            id: fid,
            type: type,
            statement: statement,
            details: Value(jsonEncode(details)),
            periodStart: start,
            periodEnd: end ?? start,
            projectId: Value(project),
            workstreamId: Value(workstream),
            importance: Value(importance),
            origin: FactOrigin.inferred,
            winStatus: Value(win),
            retired: Value(retired),
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    return fid;
  }
}

/// Model client that returns canned JSON and records requests.
class FakeClient implements LlmClient {
  FakeClient(this.responses);
  final List<Map<String, Object?>> responses;
  final requests = <LlmRequest>[];

  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;
  @override
  Future<List<ModelInfo>> listModels() async => const [];
  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    requests.add(request);
    final text = jsonEncode(responses[(requests.length - 1).clamp(0, responses.length - 1)]);
    yield LlmDelta(text);
    yield LlmDone(text: text);
  }
}

class FakeModelRouter implements ModelRouter {
  FakeModelRouter(List<Map<String, Object?>> responses, {this.contextLength = 32000}) : client = FakeClient(responses);
  final FakeClient client;
  final int contextLength;
  final routes = <LlmRoute>[];

  @override
  Future<ResolvedModel> resolve(LlmRoute route) async {
    routes.add(route);
    return ResolvedModel(
      client: client,
      modelName: 'fake-model',
      info: ModelInfo(name: 'fake-model', contextLength: contextLength),
    );
  }
}

class FixedClock implements Clock {
  FixedClock(this.t);
  DateTime t;
  @override
  DateTime now() => t;
}
