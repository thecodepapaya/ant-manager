import 'dart:convert';
import 'dart:io';

typedef Handler = (int, Object?) Function(HttpRequest req);

/// Local JSON server: [routes] maps a path to a handler returning (status, body).
class FakeApi {
  FakeApi._(this._server, this.routes);
  final HttpServer _server;
  final Map<String, Handler> routes;
  final requests = <HttpRequest>[];

  static Future<FakeApi> start(Map<String, Handler> routes) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = FakeApi._(s, routes);
    s.listen((req) async {
      api.requests.add(req);
      final h = api.routes[req.uri.path];
      final (status, body) = h == null ? (404, {'message': 'Not Found'}) : h(req);
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    return api;
  }

  String get url => 'http://${_server.address.host}:${_server.port}';
  Future<void> close() => _server.close(force: true);
}

(int, Object?) ok(Object? body) => (200, body);
