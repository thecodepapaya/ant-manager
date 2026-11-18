import 'package:core/core.dart';
import 'package:dio/dio.dart';

class FixedClock implements Clock {
  FixedClock(this.t);
  final DateTime t;
  @override
  DateTime now() => t;
}

class NoopWatcher implements FileWatcher {
  final watched = <List<String>>[];
  @override
  Stream<void> watch(List<String> paths) {
    watched.add(paths);
    return const Stream.empty();
  }
}

class UnusedGit implements GitExecutable {
  @override
  Future<String?> locate() async => null;
  @override
  Future<String> run(String repoPath, List<String> args) => throw UnimplementedError();
}

/// In-memory [SourceContext]; [commit] applies staged cursors like the engine does after ingest.
class FakeContext implements SourceContext {
  FakeContext({
    this.sourceId = 's1',
    this.config = const {},
    this.ids = const {},
    this.token,
    GitExecutable? git,
    DateTime? now,
  })  : git = git ?? UnusedGit(),
        clock = FixedClock(now ?? DateTime.now().toUtc());

  @override
  final String sourceId;
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
  final NoopWatcher watcher = NoopWatcher();

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
  CalendarBridge? get calendar => null;
  @override
  DateTime get initialImportFrom => clock.now().subtract(const Duration(days: 30));
}
