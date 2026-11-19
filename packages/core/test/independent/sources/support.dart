import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dio/dio.dart';

class Clock0 implements Clock {
  Clock0(this.t);
  final DateTime t;
  @override
  DateTime now() => t;
}

class NoWatch implements FileWatcher {
  @override
  Stream<void> watch(List<String> paths) => const Stream.empty();
}

class NoGit implements GitExecutable {
  @override
  Future<String?> locate() async => null;
  @override
  Future<String> run(String repoPath, List<String> args) => throw UnimplementedError();
}

class Bridge implements CalendarBridge {
  List<Map<String, Object?>> items = [];
  final calls = <(DateTime, DateTime)>[];
  @override
  Future<bool> requestAccess() async => true;
  @override
  Stream<void> changes() => const Stream.empty();
  @override
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to) async {
    calls.add((from, to));
    return items;
  }
}

/// In-memory context; [commit] applies staged cursors (as the engine does after ingest).
class Ctx implements SourceContext {
  Ctx({this.config = const {}, this.ids = const {}, this.token, GitExecutable? git, DateTime? now, this.calendar})
    : git = git ?? NoGit(),
      clock = Clock0(now ?? DateTime.now().toUtc());

  @override
  String get sourceId => 's1';
  @override
  final Map<String, Object?> config;
  final Map<String, List<String>> ids;
  final String? token;
  final cursors = <String, String>{};
  final staged = <String, String>{};
  @override
  final GitExecutable git;
  @override
  final Clock clock;
  @override
  final Dio http = Dio();
  @override
  final FileWatcher watcher = NoWatch();
  @override
  final CalendarBridge? calendar;

  void commit() {
    cursors.addAll(staged);
    staged.clear();
  }

  @override
  List<String> identities(String kind) => ids[kind] ?? const [];
  @override
  Future<String?> cursor(String scope) async => cursors[scope];
  @override
  void setCursor(String scope, String value) => staged[scope] = value;
  @override
  Future<String?> secret() async => token;
  @override
  DateTime get initialImportFrom => clock.now().subtract(const Duration(days: 30));
}

class Res {
  const Res(this.body, {this.status = 200, this.headers = const {}});
  final Object? body;
  final int status;
  final Map<String, String> headers;
}

class Hit {
  Hit(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}

/// Local JSON API. [handler] gets every request; null → 404.
class Api {
  Api._(this._server);
  final HttpServer _server;
  Res? Function(Hit hit) handler = (_) => null;
  final hits = <Hit>[];

  static Future<Api> start() async {
    final api = Api._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    api._server.listen((req) async {
      final hit = Hit(req.method, req.uri, req.headers, await utf8.decoder.bind(req).join());
      api.hits.add(hit);
      final r = api.handler(hit) ?? const Res({'message': 'Not Found'}, status: 404);
      req.response.statusCode = r.status;
      r.headers.forEach(req.response.headers.set);
      final body = r.body;
      if (body is String) {
        req.response.write(body);
      } else {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(body));
      }
      await req.response.close();
    });
    return api;
  }

  String get url => 'http://127.0.0.1:${_server.port}';
  Iterable<Hit> to(String path) => hits.where((h) => h.uri.path == path);
  Future<void> close() => _server.close(force: true);
}
