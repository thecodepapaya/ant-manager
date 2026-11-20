/// Platform services: interfaces in core, adapters in app (LLD 03 §3.1).
library;

import 'dart:typed_data';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class BlobStore {
  /// Stores bytes, returns a path relative to the store root.
  Future<String> put(Uint8List bytes, {required String extension});
  Future<Uint8List> get(String path);
  Future<void> delete(String path);
}

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

abstract interface class Notifier {
  Future<void> show({required String title, required String body, String? actionId});
}

/// macOS EventKit bridge (Swift platform channel in app).
abstract interface class CalendarBridge {
  Future<bool> requestAccess();
  Future<List<Map<String, Object?>>> events(DateTime from, DateTime to);
  Stream<void> changes();
}

/// The detected system git executable.
abstract interface class GitExecutable {
  /// Null when git isn't installed (UI shows the guided install screen).
  Future<String?> locate();
  Future<String> run(String repoPath, List<String> args);
}

abstract interface class FileWatcher {
  Stream<void> watch(List<String> paths);
}

/// Where `Log` lines go (adapter in app: size-capped rotating files under `<dataDir>/logs`).
abstract interface class LogSink {
  void write(String line);
}
