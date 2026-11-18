import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';

import 'fake_context.dart';

/// [FakeContext] plus an EventKit bridge.
class CalContext extends FakeContext {
  CalContext({super.config, super.token, super.now, this.bridge});
  final CalendarBridge? bridge;
  @override
  CalendarBridge? get calendar => bridge;
}

class FakeBridge implements CalendarBridge {
  List<Map<String, Object?>> items = [];
  final calls = <(DateTime, DateTime)>[];
  final changeCtl = StreamController<void>.broadcast();
  bool granted = true;

  @override
  Future<bool> requestAccess() async => granted;
  @override
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to) async {
    calls.add((from, to));
    return items;
  }

  @override
  Stream<void> changes() => changeCtl.stream;
}

/// Local server with a free-form async handler (headers, status, plain bodies).
class RawServer {
  RawServer._(this._s);
  final HttpServer _s;
  final requests = <HttpRequest>[];

  static Future<RawServer> start(Future<void> Function(HttpRequest req, HttpResponse res) handler) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final r = RawServer._(s);
    s.listen((req) async {
      r.requests.add(req);
      await handler(req, req.response);
      await req.response.close();
    });
    return r;
  }

  String get url => 'http://${_s.address.host}:${_s.port}';
  Future<void> close() => _s.close(force: true);
}
