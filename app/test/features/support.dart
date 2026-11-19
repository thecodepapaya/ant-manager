/// Shared helpers for the feature-screen tests: a loopback fake LLM server, engine-side setup
/// commands (top-level so closures capture plain data only) and a widget-test page harness.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import '../support/fakes.dart';

export '../support/fakes.dart';

// ---------------------------------------------------------------------------
// Fake OpenAI-compatible server on 127.0.0.1 (never a real network).
// ---------------------------------------------------------------------------

class FakeLlm {
  FakeLlm._(this._server);
  final HttpServer _server;

  /// Every request as (path, decoded JSON body or null).
  final requests = <(String, Map<String, Object?>?)>[];

  /// Request headers, parallel to [requests] (lower-cased names).
  final headers = <Map<String, String>>[];

  /// Chat completions answer 500.
  bool fail = false;

  /// The structured-output probe gets plain text back (model "doesn't support" JSON).
  bool probeFails = false;

  /// Win statement returned for the `win` schema.
  String winStatement = 'Shipped the thing';

  static Future<FakeLlm> start() async {
    final s = FakeLlm._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen(s._handle);
    return s;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';

  int get chatCalls => requests.where((r) => r.$1.endsWith('/chat/completions')).length;

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final raw = await utf8.decoder.bind(req).join();
    final body = raw.isEmpty ? null : jsonDecode(raw) as Map<String, Object?>;
    requests.add((req.uri.path, body));
    final h = <String, String>{};
    req.headers.forEach((name, values) => h[name.toLowerCase()] = values.join(','));
    headers.add(h);
    final res = req.response;
    if (req.uri.path.endsWith('/models')) {
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({
        'data': [
          {'id': 'm-text'},
          {
            'id': 'm-vision',
            'architecture': {
              'input_modalities': ['text', 'image'],
            },
          },
        ],
      }));
    } else if (req.uri.path.endsWith('/chat/completions')) {
      final name = ((body!['response_format'] as Map)['json_schema'] as Map)['name'] as String;
      if (fail) {
        res.statusCode = 500;
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({
          'error': {'message': 'fake model is down'},
        }));
      } else {
        final user = ((body['messages'] as List).last as Map)['content'];
        final text = switch (name) {
          'probe' => probeFails ? 'sorry, plain text only' : jsonEncode({'ok': true}),
          'win' => jsonEncode({'statement': winStatement, 'citations': <String>[]}),
          'report' => jsonEncode(_report('$user')),
          _ => '{}',
        };
        res.headers.contentType = ContentType('text', 'event-stream');
        res.write('data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': text},
            },
          ],
        })}\n\n');
        res.write('data: ${jsonEncode({
          'choices': [
            {'delta': <String, Object?>{}, 'finish_reason': 'stop'},
          ],
        })}\n\n');
        res.write('data: [DONE]\n\n');
      }
    } else {
      res.statusCode = 404;
    }
    await res.close();
  }

  /// One section citing every fact id listed in the prompt (`- [id] type | …`).
  static Map<String, Object?> _report(String user) {
    final ids = [for (final m in RegExp(r'^- \[([^\]]+)\] ', multiLine: true).allMatches(user)) m.group(1)!];
    return {
      'sections': [
        {
          'heading': 'Highlights',
          'items': [
            for (final id in ids)
              {
                'text': 'Item for $id',
                'fact_ids': [id],
              },
          ],
        },
      ],
    };
  }
}

/// Saves a loopback provider for [llm] and adds [model] (probe passes). Returns (providerId, modelId).
Future<(String, String)> addFakeModel(EngineHandle h, FakeLlm llm, {String model = 'm-text', ModelInfo? info}) async {
  final (pid, _) = await h.runtime(saveProviderCmd(
    kind: ProviderKind.custom,
    name: 'Fake',
    baseUrl: llm.baseUrl,
    protocol: ProviderProtocol.openai,
  ));
  final mid = await h.runtime(addModelCmd(pid, model, info: info));
  return (pid, mid);
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

Future<EngineHandle> startEngine(Directory dir, {FakeSecrets? secrets, FakeNotifier? notifier, bool inMemory = true}) =>
    EngineHandle.start(testConfig(dir.path, inMemory: inMemory), host: fakeHost(secrets: secrets, notifier: notifier));

/// A fact citing every payload of [evidenceIds], written like core's FactWriter.create: fact row,
/// revision 1 in history, citations pinned to current payload revisions, Dependency rows.
EngineCommand<String> createFactCmd(
  List<String> evidenceIds, {
  String statement = 'A fact',
  FactType type = FactType.outcome,
  String? day,
  FactOrigin origin = FactOrigin.inferred,
  WinStatus winStatus = WinStatus.none,
  String? workstreamId,
  String? projectId,
}) =>
    (rt) async {
      final db = rt.db;
      final payloads = await (db.select(db.payloads)..where((p) => p.evidenceId.isIn(evidenceIds))).get();
      final ev = await (db.select(db.evidences)..where((e) => e.id.isIn(evidenceIds))).get();
      final d = day ?? ev.first.day;
      final now = DateTime.now().toUtc();
      final id = newId(now);
      return db.transaction(() async {
        await db.into(db.facts).insert(FactsCompanion.insert(
              id: id,
              type: type,
              statement: statement,
              periodStart: d,
              periodEnd: d,
              projectId: Value(projectId),
              workstreamId: Value(workstreamId),
              origin: origin,
              winStatus: Value(winStatus),
              createdAt: now,
              updatedAt: now,
            ));
        await db.into(db.factRevisions).insert(FactRevisionsCompanion.insert(
              factId: id,
              revision: 1,
              statement: statement,
              details: '{}',
              origin: origin,
              changedBy: 'model',
              changedAt: now,
            ));
        for (final p in payloads) {
          await db
              .into(db.citations)
              .insert(CitationsCompanion.insert(factId: id, payloadId: p.id, payloadRevision: p.revision));
        }
        await rt.engine.deps.record((type: EntityType.fact, id: id), 1, [
          for (final p in payloads) (type: EntityType.payload, id: p.id, revision: p.revision),
        ]);
        return id;
      });
    };

EngineCommand<void> insertWorkstreamCmd(String id, String title) => (rt) => rt.db
    .into(rt.db.workstreams)
    .insert(WorkstreamsCompanion.insert(id: id, title: title));

/// Puts a model proposal on [factId] (review queue).
EngineCommand<void> proposeCmd(String factId, Map<String, Object?> proposal) => (rt) =>
    (rt.db.update(rt.db.facts)..where((x) => x.id.equals(factId))).write(FactsCompanion(
      reviewState: const Value(ReviewState.needsReview),
      reviewProposal: Value(jsonEncode(proposal)),
    ));

EngineCommand<void> clearRecomputeCmd() => (rt) => rt.db.delete(rt.db.recomputeQueue).go();

EngineCommand<bool> runJobCmd(JobLane lane) => (rt) => rt.engine.jobs.runOne(lane);

EngineCommand<String> enqueueJobCmd(String kind, {Map<String, Object?> args = const {}}) =>
    (rt) => rt.engine.jobs.enqueue(kind, args: args);

EngineCommand<void> setEvidenceDayCmd(String id, String day, DateTime at) => (rt) =>
    (rt.db.update(rt.db.evidences)..where((e) => e.id.equals(id)))
        .write(EvidencesCompanion(day: Value(day), occurredStart: Value(at.toUtc())));

/// Recompute-queue entries as (type, id).
Future<List<(EntityType, String)>> recomputeEntries(EngineHandle h) async =>
    [for (final q in await h.db.select(h.db.recomputeQueue).get()) (q.entityType, q.entityId)];

Future<Fact> factOf(EngineHandle h, String id) =>
    (h.db.select(h.db.facts)..where((f) => f.id.equals(id))).getSingle();

Future<Evidence> evidenceOf(EngineHandle h, String id) =>
    (h.db.select(h.db.evidences)..where((e) => e.id.equals(id))).getSingle();

Future<String?> settingOf(EngineHandle h, String key) async =>
    (await (h.db.select(h.db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

// ---------------------------------------------------------------------------
// Widget harness
// ---------------------------------------------------------------------------

/// Starts the engine via [engineProvider] on the real event loop and pumps [page] in an app
/// with the Ant theme and toast host. Set [onboarded] false to keep the onboarding gate.
Future<(ProviderContainer, EngineHandle)> bootPage(
  WidgetTester tester,
  Directory dir,
  Widget page, {
  FakeSecrets? secrets,
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    engineConfigProvider.overrideWithValue(testConfig(dir.path)),
    uiPortHostProvider.overrideWithValue(fakeHost(secrets: secrets)),
  ]);
  addTearDown(container.dispose);
  final h = (await tester.runAsync(() => container.read(engineProvider.future)))!;
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: pageApp(page)));
  await settle(tester);
  return (container, h);
}

Widget pageApp(Widget page) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: antTheme(AntTokens.light()),
      builder: (context, child) => AntToastHost(child: child!),
      home: Material(child: page),
    );

/// Kills the engine isolate (EngineHandle.shutdown hangs under the widget binding).
Future<void> killEngine(WidgetTester tester, EngineHandle h) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
  await tester.runAsync(() async {
    final iso = await h.runtime((rt) async => Isolate.current);
    final exited = ReceivePort();
    iso.addOnExitListener(exited.sendPort);
    iso.kill(priority: Isolate.immediate);
    await exited.first.timeout(const Duration(seconds: 5));
    exited.close();
  });
}

/// Pumps with real time passing (engine isolate + drift streams need the real event loop).
Future<void> settle(WidgetTester tester, {bool Function()? until, int max = 150}) async {
  for (var i = 0; i < max; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 30));
    if (until == null ? i >= 5 : until()) return;
  }
}

/// Runs [cmd] from a widget test on the real event loop.
Future<T> cmd<T>(WidgetTester tester, EngineHandle h, EngineCommand<T> c) async =>
    (await tester.runAsync(() => h.runtime(c))) as T;

/// Reads from the UI-side DB from a widget test.
Future<T> read<T>(WidgetTester tester, Future<T> Function() q) async => (await tester.runAsync(q)) as T;
