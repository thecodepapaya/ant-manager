import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PythonServiceError implements Exception {
  PythonServiceError(this.message);
  final String message;

  @override
  String toString() => 'PythonServiceError: $message';
}

class PythonService {
  PythonService({String? pythonExecutable}) : _pythonExecutable = pythonExecutable ?? 'python3';

  final String _pythonExecutable;

  Future<String> _resolveCoreEntry() async {
    // dev defaults: now that core is inside app/
    final cwd = Directory.current.path;
    final candidates = <String>[
      p.normalize(p.join(cwd, 'core', 'main.py')),
      p.normalize(p.join(cwd, '..', 'core', 'main.py')),
      // macOS bundle fallback (Flutter assets in a built app)
      p.normalize(p.join(p.dirname(Platform.resolvedExecutable), '..', 'Frameworks', 'App.framework', 'Resources', 'flutter_assets', 'core', 'main.py')),
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }

    final env = Platform.environment['ANT_MANAGER_PY_ENTRY'];
    if (env != null && env.isNotEmpty && File(env).existsSync()) return env;

    throw PythonServiceError('Could not find core/main.py. Tried: ${candidates.join(', ')}');
  }

  Future<Map<String, String>> _buildEnv() async {
    final supportDir = await getApplicationSupportDirectory();
    final dataDir = Directory(p.join(supportDir.path, 'ant_manager_data'));
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }
    return {
      ...Platform.environment,
      // Route the python DB+files to a stable per-user location.
      'ANT_MANAGER_DATA_DIR': dataDir.path,
    };
  }

  Future<Map<String, dynamic>> runJson(List<String> args) async {
    final entry = await _resolveCoreEntry();
    final env = await _buildEnv();

    final result = await Process.run(
      _pythonExecutable,
      [entry, ...args],
      environment: env,
      runInShell: false,
    );

    if (result.exitCode != 0) {
      throw PythonServiceError(
        'Python exited ${result.exitCode}. stderr: ${result.stderr}\nstdout: ${result.stdout}',
      );
    }

    final stdoutStr = (result.stdout as String).trim();
    if (stdoutStr.isEmpty) {
      throw PythonServiceError('Python returned empty stdout for args: ${args.join(' ')}');
    }

    final decoded = jsonDecode(stdoutStr);
    if (decoded is! Map<String, dynamic>) {
      throw PythonServiceError('Expected JSON object. Got: $decoded');
    }
    return decoded;
  }

  Future<void> initDb() async {
    await runJson(['init-db']);
  }

  Future<Map<String, dynamic>> getDailySummary() => runJson(['daily-summary']);

  Future<Map<String, dynamic>> getTimeline({int days = 7}) => runJson(['timeline', '--days=$days']);

  Future<Map<String, dynamic>> getEventDetails(String eventId) => runJson(['event-details', eventId]);

  Future<Map<String, dynamic>> getWins({String period = 'weekly'}) =>
      runJson(['wins', '--period=$period']);

  Future<void> updateNarrative({required String narrativeId, required String text}) async {
    await runJson(['update-narrative', narrativeId, text]);
  }

  Future<void> lockNarrative(String narrativeId) async {
    await runJson(['lock-narrative', narrativeId]);
  }

  Future<void> addNote(String content) async {
    await runJson(['add-note', content]);
  }

  Future<Map<String, dynamic>> listNotes({int days = 30}) => runJson(['notes', '--days=$days']);

  Future<Map<String, dynamic>> getConfig() => runJson(['config-get']);

  Future<Map<String, dynamic>> addRepo(String path) => runJson(['config-add-repo', path]);

  Future<Map<String, dynamic>> removeRepo(String path) => runJson(['config-remove-repo', path]);

  Future<Map<String, dynamic>> setModel(String model) => runJson(['config-set-model', model]);

  Future<Map<String, dynamic>> ingestGit({int days = 7}) => runJson(['ingest-git', '--days=$days']);
}


