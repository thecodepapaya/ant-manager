import 'dart:convert';
import 'dart:io';

/// A request seen by [StubHttp].
class Seen {
  Seen(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}

typedef Reply = Future<void> Function(HttpRequest req);

/// Local server: [on] maps a path to a reply function. Unknown paths → 404.
class StubHttp {
  StubHttp._(this._server);
  final HttpServer _server;
  final Map<String, Reply> on = {};
  final List<Seen> seen = [];

  static Future<StubHttp> start() async {
    final s = StubHttp._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      s.seen.add(Seen(req.method, req.uri, req.headers, body));
      final r = s.on[req.uri.path];
      if (r == null) {
        req.response.statusCode = 404;
        req.response.write('{"error":"no route"}');
        await req.response.close();
        return;
      }
      await r(req);
    });
    return s;
  }

  String get url => 'http://127.0.0.1:${_server.port}';
  Seen get last => seen.last;
  Future<void> close() => _server.close(force: true);
}

/// Plain body with a status.
Reply text(String body, {int status = 200, String type = 'application/json'}) => (req) async {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.parse(type)
    ..write(body);
  await req.response.close();
};

Reply json(Object? v, {int status = 200}) => text(jsonEncode(v), status: status);

/// SSE: maps are encoded as `data: {json}`; strings are written verbatim as one event.
Reply sse(List<Object> events) =>
    text([for (final e in events) e is String ? e : 'data: ${jsonEncode(e)}'].join('\n\n'), type: 'text/event-stream');

Reply ndjson(List<Object> lines) =>
    text([for (final l in lines) l is String ? l : jsonEncode(l)].join('\n'), type: 'application/x-ndjson');

/// Writes [raw] as a chunked response, then kills the socket without the terminating chunk.
Reply dropAfter(String raw) => (req) async {
  final socket = await req.response.detachSocket(writeHeaders: false);
  final bytes = utf8.encode(raw);
  socket.write('HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\ntransfer-encoding: chunked\r\n\r\n');
  socket.write('${bytes.length.toRadixString(16)}\r\n');
  socket.add(bytes);
  socket.write('\r\n');
  await socket.flush();
  await Future<void>.delayed(const Duration(milliseconds: 50));
  socket.destroy();
};
