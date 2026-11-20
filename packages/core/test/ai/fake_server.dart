import 'dart:convert';
import 'dart:io';

class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}

class FakeResponse {
  const FakeResponse(this.body, {this.status = 200, this.contentType = 'application/json'});
  FakeResponse.json(Object? value, {int status = 200}) : this(jsonEncode(value), status: status);
  FakeResponse.sse(List<Object> events)
    : this(
        [for (final e in events) e is String ? e : 'data: ${jsonEncode(e)}'].join('\n\n'),
        contentType: 'text/event-stream',
      );
  FakeResponse.ndjson(List<Object> lines)
    : this([for (final l in lines) jsonEncode(l)].join('\n'), contentType: 'application/x-ndjson');
  final String body;
  final int status;
  final String contentType;
}

/// Localhost HTTP server answering each path with a canned response and recording requests.
class FakeServer {
  FakeServer._(this._server);
  final HttpServer _server;
  final Map<String, FakeResponse> routes = {};
  final List<RecordedRequest> requests = [];

  static Future<FakeServer> start() async {
    final s = FakeServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen(s._handle);
    return s;
  }

  String get url => 'http://127.0.0.1:${_server.port}';
  RecordedRequest get last => requests.last;

  Future<void> _handle(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    requests.add(RecordedRequest(req.method, req.uri, req.headers, body));
    final r = routes[req.uri.path] ?? const FakeResponse('{"error":"not found"}', status: 404);
    req.response
      ..statusCode = r.status
      ..headers.contentType = ContentType.parse(r.contentType)
      ..write(r.body);
    await req.response.close();
  }

  Future<void> close() => _server.close(force: true);
}
