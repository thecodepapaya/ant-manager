// Deterministic OpenAI-compatible model server for the e2e flow: answers each request by its
// structured-output schema name, deriving ids from the prompt the engine built. Runs on localhost,
// so the real DbModelRouter → createClient → OpenAiCompatibleClient path is exercised end to end.
import 'dart:convert';
import 'dart:io';

class FakeLlmCall {
  FakeLlmCall(this.schema, this.system, this.user, this.imageCount);
  final String schema;
  final String system;
  final String user;
  final int imageCount;
}

class FakeLlmServer {
  FakeLlmServer._(this._server);
  final HttpServer _server;
  final calls = <FakeLlmCall>[];

  static const model = 'fake/e2e-model';

  static Future<FakeLlmServer> start() async {
    final s = FakeLlmServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen(s._handle);
    return s;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';
  List<FakeLlmCall> of(String schema) => calls.where((c) => c.schema == schema).toList();
  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    final res = req.response;
    if (req.method == 'GET' && req.uri.path.endsWith('/models')) {
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({
        'data': [
          {
            'id': model,
            'context_length': 32000,
            'architecture': {
              'input_modalities': ['text', 'image'],
            },
            'supported_parameters': ['response_format', 'structured_outputs'],
          },
        ],
      }));
      await res.close();
      return;
    }
    final json = jsonDecode(body) as Map<String, Object?>;
    final schema = ((json['response_format'] as Map)['json_schema'] as Map)['name'] as String;
    final messages = (json['messages'] as List).cast<Map<String, Object?>>();
    String textOf(Map<String, Object?> m) {
      final c = m['content'];
      if (c is String) return c;
      return [
        for (final part in (c as List).cast<Map<String, Object?>>())
          if (part['type'] == 'text') part['text'] as String,
      ].join('\n');
    }

    final last = messages.last;
    final images = last['content'] is List
        ? (last['content'] as List).cast<Map<String, Object?>>().where((p) => p['type'] == 'image_url').length
        : 0;
    final call = FakeLlmCall(schema, textOf(messages.first), textOf(last), images);
    calls.add(call);
    final text = jsonEncode(_answer(call));
    res.headers.contentType = ContentType('text', 'event-stream');
    final chunks = [
      {
        'choices': [
          {
            'delta': {'content': text},
            'finish_reason': null,
          },
        ],
      },
      {
        'choices': [
          {'delta': <String, Object?>{}, 'finish_reason': 'stop'},
        ],
        'usage': {'prompt_tokens': call.user.length ~/ 4, 'completion_tokens': text.length ~/ 4},
      },
    ];
    res.write([for (final c in chunks) 'data: ${jsonEncode(c)}', 'data: [DONE]'].join('\n\n'));
    res.write('\n\n');
    await res.close();
  }

  static List<Map<String, Object?>> _jsonAfter(String user, String marker) {
    final i = user.indexOf(marker);
    return (jsonDecode(user.substring(i + marker.length)) as List).cast<Map<String, Object?>>();
  }

  Map<String, Object?> _answer(FakeLlmCall c) {
    switch (c.schema) {
      case 'probe':
        return {'ok': true};
      case 'importance':
        return {
          'scores': [
            for (final i in _jsonAfter(c.user, 'Rate these evidence items:\n'))
              {'evidence_id': i['evidence_id'], 'score': 0.7, 'reason': 'normal feature work'},
          ],
        };
      case 'enrichment':
        return {
          'items': [
            for (final i in _jsonAfter(c.user, ':\n'))
              {'payload_id': i['payload_id'], 'summary': 'Summary of ${i['payload_id']}.'},
          ],
        };
      case 'image_description':
        return {'description': 'A striped test image showing a green CI status.'};
      case 'fact_ops':
        return {'ops': _factOps(c.user)};
      case 'workstreams':
        final input = jsonDecode(c.user) as Map<String, Object?>;
        final existing = (input['workstreams'] as List).cast<Map<String, Object?>>();
        return {
          'assignments': [
            for (final f in (input['facts'] as List).cast<Map<String, Object?>>())
              {
                'fact_id': f['fact_id'],
                'workstream_id': existing.isEmpty ? null : existing.first['id'],
                'new_title': existing.isEmpty ? 'Checkout reliability' : null,
                'new_summary': existing.isEmpty ? 'Retries and idempotency for checkout payments.' : null,
              },
          ],
        };
      case 'report':
        final lines = RegExp(r'^- \[([^\]]+)\] [^:]*: (.*)$', multiLine: true).allMatches(c.user);
        return {
          'sections': [
            {
              'heading': 'Highlights',
              'items': [
                for (final m in lines) {'text': m.group(2), 'fact_ids': [m.group(1)]},
              ],
            },
          ],
        };
      case 'win':
        return {
          'statement': 'Unblocked a teammate on the refund flow.',
          'citations': [for (final m in RegExp(r'payload_id=(\S+)').allMatches(c.user)) m.group(1)],
        };
    }
    throw StateError('unexpected schema ${c.schema}');
  }

  /// Creates one outcome (commits) and one invisible-work fact (notes/images) per day; on later passes
  /// updates the outcome to cite the day's current commits.
  static List<Map<String, Object?>> _factOps(String user) {
    final payloads = [
      for (final m in RegExp(r'^- payload_id=(\S+) kind=(\w+)', multiLine: true).allMatches(user))
        (id: m.group(1)!, kind: m.group(2)!),
    ];
    final commits = [for (final p in payloads) if (p.kind == 'commit') p.id];
    final notes = [for (final p in payloads) if (p.kind == 'note' || p.kind == 'image') p.id];
    final existing = [
      for (final m in RegExp(r'^- fact_id=(\S+) type=(\S+) model', multiLine: true).allMatches(user))
        (id: m.group(1)!, type: m.group(2)!),
    ];
    Map<String, Object?> op(String op, {String? id, String? type, String? statement, List<String> cites = const []}) =>
        {
          'op': op,
          'fact_id': id,
          'type': type,
          'statement': statement,
          'citations': cites,
          'project_id': null,
          'importance': op == 'create' ? 0.8 : null,
          'suggest_win': op == 'create' ? type == 'outcome' : null,
          'reason': op == 'create' ? null : 'evidence changed',
        };
    final ops = <Map<String, Object?>>[];
    final outcome = existing.where((f) => f.type == 'outcome').firstOrNull;
    if (commits.isNotEmpty) {
      final statement = 'Shipped checkout payment changes across ${commits.length} commits.';
      ops.add(outcome == null
          ? op('create', type: 'outcome', statement: statement, cites: commits)
          : op('update', id: outcome.id, statement: statement, cites: commits));
    }
    if (notes.isNotEmpty && !existing.any((f) => f.type == 'invisible_work')) {
      ops.add(op('create', type: 'invisible_work', statement: 'Paired with a teammate on refund edge cases.', cites: notes));
    }
    return ops;
  }
}
