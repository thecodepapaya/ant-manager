import 'package:dio/dio.dart';

import '../domain/enums.dart';
import '../ports/ports.dart';

/// What a source saw. The Ingestor turns it into Evidence/Payload/PayloadRevision rows.
final class PayloadObservation {
  const PayloadObservation({
    required this.externalId,
    required this.kind,
    required this.content,
    required this.occurredStart,
    required this.title,
    this.occurredEnd,
    this.groupKey,
    this.tombstone = false,
  });

  final String externalId; // unique per source
  final PayloadKind kind;
  final Map<String, Object?> content; // no volatile fields (fetched_at etc.)
  final DateTime occurredStart;
  final DateTime? occurredEnd;
  final String title;
  final String? groupKey; // exact identity: iCal UID, commit SHA (#57)
  final bool tombstone; // upstream deletion
}

class SourceHealth {
  const SourceHealth.ok() : ok = true, message = null;
  const SourceHealth.error(this.message) : ok = false;
  final bool ok;
  final String? message;
}

/// Everything a source may use. Cursor writes are committed only after ingest succeeds.
abstract interface class SourceContext {
  String get sourceId;
  Map<String, Object?> get config;
  List<String> identities(String kind); // e.g. identities('email')
  Future<String?> cursor(String scope);
  void setCursor(String scope, String value); // staged; committed after ingest
  Future<String?> secret();
  Dio get http;
  Clock get clock;
  GitExecutable get git;
  CalendarBridge? get calendar;
  FileWatcher get watcher;
  DateTime get initialImportFrom; // now - 30 days (#88)
}

/// A connector instance (LLD 03 §3.4). Pull-based, idempotent, resumable (#69).
abstract interface class Source {
  SourceKind get kind;
  Future<SourceHealth> validate(SourceContext ctx);
  Stream<PayloadObservation> sync(SourceContext ctx);
}

/// Optional: change events that only trigger a debounced sync (#69, #73).
abstract interface class WatchableSource implements Source {
  Stream<void> changes(SourceContext ctx);
}

/// kind → factory. Adding a connector = one class + one registration (N7).
class SourceRegistry {
  final _factories = <SourceKind, Source Function()>{};
  void register(SourceKind kind, Source Function() factory) => _factories[kind] = factory;
  Source create(SourceKind kind) {
    final f = _factories[kind];
    if (f == null) throw StateError('No source registered for $kind');
    return f();
  }

  Iterable<SourceKind> get kinds => _factories.keys;
}
