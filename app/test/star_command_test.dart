// starEvidenceCmd (engine/commands.dart) end to end through the engine isolate, with the model
// served by a local stub OpenAI-compatible endpoint.
import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Stub `/chat/completions`: records request bodies; answers the `win` schema.
class StubModel {
  StubModel._(this._server);
  final HttpServer _server;
  final bodies = <Map<String, Object?>>[];
  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<StubModel> start() async {
    final s = StubModel._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, Object?>;
      s.bodies.add(body);
      final content = jsonEncode({'statement': 'Shipped the retry queue.', 'citations': <String>[]});
      final chunk = {
        'choices': [
          {
            'delta': {'content': content},
            'finish_reason': 'stop',
          },
        ],
      };
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.parse('text/event-stream')
        ..write('data: ${jsonEncode(chunk)}\n\ndata: [DONE]\n\n');
      await req.response.close();
    });
    return s;
  }

  List<String> get schemas => [
        for (final b in bodies) (((b['response_format'] as Map?)?['json_schema'] as Map?)?['name'] as String?) ?? '?',
      ];

  Future<void> close() => _server.close(force: true);
}

// ---------- engine commands (top-level: plain captures only) ----------

EngineCommand<void> _routeModelCmd(String baseUrl) => (rt) async {
      await rt.appDb.into(rt.appDb.providers).insert(ProvidersCompanion.insert(
            id: 'stub',
            kind: ProviderKind.custom,
            name: 'Stub',
            baseUrl: baseUrl,
            protocol: ProviderProtocol.openai,
          ));
      await rt.appDb
          .into(rt.appDb.models)
          .insert(ModelsCompanion.insert(id: 'm', providerId: 'stub', modelName: 'stub-model'));
      await rt.db
          .into(rt.db.taskRoutes)
          .insertOnConflictUpdate(TaskRoutesCompanion.insert(route: LlmRoute.defaultRoute, modelId: const Value('m')));
    };

EngineCommand<String> _noteCmd(String text) => (rt) => rt.engine.addNote(text: text, at: DateTime.now());

/// An inferred Outcome fact citing the evidence's payload.
EngineCommand<void> _outcomeCmd(String factId, String evidenceId) => (rt) async {
      final db = rt.db;
      final p = await (db.select(db.payloads)..where((x) => x.evidenceId.equals(evidenceId))).getSingle();
      final e = await (db.select(db.evidences)..where((x) => x.id.equals(evidenceId))).getSingle();
      final now = DateTime.now().toUtc();
      await db.into(db.facts).insert(FactsCompanion.insert(
            id: factId,
            type: FactType.outcome,
            statement: 'Did it.',
            periodStart: e.day,
            periodEnd: e.day,
            origin: FactOrigin.inferred,
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.factRevisions).insert(FactRevisionsCompanion.insert(
            factId: factId,
            revision: 1,
            statement: 'Did it.',
            details: '{}',
            origin: FactOrigin.inferred,
            changedBy: 'model',
            changedAt: now,
          ));
      await db
          .into(db.citations)
          .insert(CitationsCompanion.insert(factId: factId, payloadId: p.id, payloadRevision: p.revision));
    };

/// What a hide rule leaves behind (ImportanceScorer): hidden, importance 0, set by rule.
EngineCommand<void> _ruleHideCmd(String evidenceId) => (rt) => (rt.db.update(rt.db.evidences)
      ..where((x) => x.id.equals(evidenceId)))
    .write(const EvidencesCompanion(
        hidden: Value(true), importance: Value(0.0), importanceSetBy: Value(ImportanceSetBy.rule)));

EngineCommand<void> _userHideCmd(String evidenceId) => (rt) => rt.engine.setHidden(evidenceId, true);

void main() {
  late Directory dir;
  late StubModel model;
  late EngineHandle h;
  setUp(() async {
    dir = tempDir();
    model = await StubModel.start();
    h = await EngineHandle.start(testConfig(dir.path));
    await h.runtime(_routeModelCmd(model.url));
  });
  tearDown(() async {
    await h.shutdown();
    await model.close();
    dir.deleteSync(recursive: true);
  });

  Future<Evidence> evidence(String id) => (h.db.select(h.db.evidences)..where((e) => e.id.equals(id))).getSingle();
  Future<Fact> fact(String id) => (h.db.select(h.db.facts)..where((f) => f.id.equals(id))).getSingle();

  test('no Outcome → exactly one model call; accepted userCreated Outcome citing its payloads', () async {
    final e = await h.runtime(_noteCmd('Shipped the retry queue'));
    final id = await h.runtime(starEvidenceCmd(e));
    expect(model.schemas, ['win']);
    final f = await fact(id);
    expect(
      (f.type, f.origin, f.winStatus, f.statement),
      (FactType.outcome, FactOrigin.userCreated, WinStatus.accepted, 'Shipped the retry queue.'),
    );
    final payloads = await (h.db.select(h.db.payloads)..where((p) => p.evidenceId.equals(e))).get();
    final cites = await (h.db.select(h.db.citations)..where((c) => c.factId.equals(id))).get();
    expect(cites.map((c) => c.payloadId).toSet(), payloads.map((p) => p.id).toSet());
    final ev = await evidence(e);
    expect((ev.starred, ev.hidden, ev.importance, ev.importanceSetBy), (true, false, 1.0, ImportanceSetBy.user));
  });

  test('starring unknown evidence surfaces as EngineCommandException; engine stays usable', () async {
    await expectLater(
      h.runtime(starEvidenceCmd('missing')).timeout(const Duration(seconds: 5)),
      throwsA(isA<EngineCommandException>()),
    );
    expect(model.bodies, isEmpty);
    expect(await h.runtime(_noteCmd('still works')), isNotEmpty);
  });

  test('existing Outcome → upgraded to accepted, no model call', () async {
    final e = await h.runtime(_noteCmd('Shipped'));
    await h.runtime(_outcomeCmd('f1', e));
    expect(await h.runtime(starEvidenceCmd(e)), 'f1');
    expect(model.bodies, isEmpty);
    final f = await fact('f1');
    expect((f.winStatus, f.origin), (WinStatus.accepted, FactOrigin.confirmed));
    expect(await h.db.select(h.db.facts).get(), hasLength(1));
  });

  test('starring rule-hidden evidence → visible, importance 1.0', () async {
    final e = await h.runtime(_noteCmd('Shipped'));
    await h.runtime(_outcomeCmd('f1', e));
    await h.runtime(_ruleHideCmd(e));
    await h.runtime(starEvidenceCmd(e));
    final ev = await evidence(e);
    expect((ev.hidden, ev.starred, ev.importance, ev.importanceSetBy), (false, true, 1.0, ImportanceSetBy.user));
  });

  test('starring user-hidden evidence keeps it hidden, importance 0', () async {
    final e = await h.runtime(_noteCmd('Shipped'));
    await h.runtime(_outcomeCmd('f1', e));
    await h.runtime(_userHideCmd(e));
    await h.runtime(starEvidenceCmd(e));
    final ev = await evidence(e);
    expect((ev.hidden, ev.starred, ev.importance), (true, true, 0.0));
  });
}
