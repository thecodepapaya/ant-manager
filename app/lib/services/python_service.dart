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
  PythonService({String? pythonExecutable})
    : _pythonExecutable = pythonExecutable;

  final String? _pythonExecutable;

  Future<String> _getPythonPath() async {
    if (_pythonExecutable != null) return _pythonExecutable;

    final entry = await _resolveCoreEntry();
    final coreDir = p.dirname(entry);

    // Use Application Support for the venv to avoid read-only bundle issues on macOS
    final supportDir = await getApplicationSupportDirectory();
    final venvDir = p.normalize(
      p.join(supportDir.path, 'ant_manager_python_venv'),
    );
    final setupMarker = p.join(venvDir, '.setup_done');

    final pythonExec = Platform.isWindows
        ? p.join(venvDir, 'Scripts', 'python.exe')
        : p.join(venvDir, 'bin', 'python3');

    final pipExec = Platform.isWindows
        ? p.join(venvDir, 'Scripts', 'pip.exe')
        : p.join(venvDir, 'bin', 'pip');

    // 1. If venv doesn't exist or setup isn't finished, set it up
    final reqFile = p.join(coreDir, 'requirements.txt');
    final reqFileExists = File(reqFile).existsSync();
    final reqFileModified = reqFileExists
        ? await File(reqFile).lastModified()
        : DateTime.fromMillisecondsSinceEpoch(0);

    // Check if setup marker exists and if requirements.txt is newer
    final setupMarkerExists = File(setupMarker).existsSync();
    final setupMarkerModified = setupMarkerExists
        ? await File(setupMarker).lastModified()
        : DateTime.fromMillisecondsSinceEpoch(0);

    final needsSetup =
        !Directory(venvDir).existsSync() ||
        !setupMarkerExists ||
        (reqFileExists && reqFileModified.isAfter(setupMarkerModified));

    if (needsSetup) {
      print('Setting up Python virtual environment in $venvDir...');

      if (!Directory(venvDir).existsSync()) {
        await Directory(venvDir).create(recursive: true);
      }

      // Create venv - note we don't use coreDir as workingDirectory
      // because it might be read-only in the app bundle.
      if (!File(pythonExec).existsSync()) {
        final venvResult = await Process.run('python3', [
          '-m',
          'venv',
          venvDir,
        ], workingDirectory: supportDir.path);

        if (venvResult.exitCode != 0) {
          throw PythonServiceError(
            'Failed to create venv: ${venvResult.stderr}',
          );
        }
      }

      // Install/upgrade requirements
      if (reqFileExists) {
        print('Installing requirements from $reqFile...');
        final pipResult = await Process.run(pipExec, [
          'install',
          '--upgrade',
          '-r',
          reqFile,
        ], workingDirectory: venvDir);
        if (pipResult.exitCode != 0) {
          throw PythonServiceError(
            'Failed to install requirements: ${pipResult.stderr}',
          );
        }
        print('Requirements installed successfully.');
      }

      // Create/update marker file
      await File(setupMarker).writeAsString(reqFileModified.toIso8601String());
      print('Python environment ready.');
    }

    if (File(pythonExec).existsSync()) return pythonExec;

    // 2. Fallback to system python3 if venv logic fails for some reason
    return 'python3';
  }

  Future<String> _resolveCoreEntry() async {
    // dev defaults: now that core is inside app/
    final cwd = Directory.current.path;
    final candidates = <String>[
      p.normalize(p.join(cwd, 'core', 'main.py')),
      p.normalize(p.join(cwd, 'app', 'core', 'main.py')),
      p.normalize(p.join(cwd, '..', 'core', 'main.py')),
      // macOS bundle fallback (Flutter assets in a built app)
      p.normalize(
        p.join(
          p.dirname(Platform.resolvedExecutable),
          '..',
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          'core',
          'main.py',
        ),
      ),
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }

    final env = Platform.environment['ANT_MANAGER_PY_ENTRY'];
    if (env != null && env.isNotEmpty && File(env).existsSync()) return env;

    throw PythonServiceError(
      'Could not find core/main.py. Tried: ${candidates.join(', ')}',
    );
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
    final pythonPath = await _getPythonPath();
    final env = await _buildEnv();

    // Add the parent of the 'core' directory to PYTHONPATH so 'import core' works
    final coreParentDir = p.dirname(p.dirname(entry));
    final existingPythonPath = env['PYTHONPATH'];
    env['PYTHONPATH'] = existingPythonPath == null
        ? coreParentDir
        : '$coreParentDir${Platform.isWindows ? ';' : ':'}$existingPythonPath';

    final result = await Process.run(
      pythonPath,
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
    final stderrStr = (result.stderr as String).trim();

    // Print Python's debug output to the Dart console
    if (stderrStr.isNotEmpty) {
      print('Python stderr:\n$stderrStr');
    }
    if (stdoutStr.isEmpty) {
      throw PythonServiceError(
        'Python returned empty stdout for args: ${args.join(' ')}',
      );
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

  Future<Map<String, dynamic>> getDailySummary({
    String? date,
    bool regenerate = false,
    int days = 1,
    String period = 'daily',
    String? startDate,
    String? endDate,
  }) {
    final args = ['daily-summary'];
    if (date != null) args.add('--date=$date');
    if (regenerate) args.add('--regenerate');
    args.add('--days=$days');
    args.add('--period=$period');
    if (startDate != null) args.add('--start-date=$startDate');
    if (endDate != null) args.add('--end-date=$endDate');
    return runJson(args);
  }

  Future<Map<String, dynamic>> getTimeline({
    int days = 7,
    String? date,
    String? startDate,
    String? endDate,
  }) {
    final args = ['timeline', '--days=$days'];
    if (date != null) args.add('--date=$date');
    if (startDate != null) args.add('--start-date=$startDate');
    if (endDate != null) args.add('--end-date=$endDate');
    return runJson(args);
  }

  Future<Map<String, dynamic>> getEventDetails(
    String eventId, {
    String? source,
    String? timestamp,
    bool regenerate = false,
    bool skipLlm = false,
  }) {
    final args = ['event-details', eventId];
    if (source != null) args.add('--source=$source');
    if (timestamp != null) args.add('--timestamp=$timestamp');
    if (regenerate) args.add('--regenerate');
    if (skipLlm) args.add('--skip-llm');
    return runJson(args);
  }

  Future<Map<String, dynamic>> getWins({
    String period = 'weekly',
    String? date,
    String? startDate,
    String? endDate,
  }) {
    final args = ['wins', '--period=$period'];
    if (date != null) args.add('--date=$date');
    if (startDate != null) args.add('--start-date=$startDate');
    if (endDate != null) args.add('--end-date=$endDate');
    return runJson(args);
  }

  Future<void> updateNarrative({
    required String narrativeId,
    required String text,
  }) async {
    await runJson(['update-narrative', narrativeId, text]);
  }

  Future<Map<String, dynamic>> addEventArtifact({
    required String eventId,
    required String kind,
    required String content,
  }) async {
    return runJson(['add-event-artifact', eventId, kind, content]);
  }

  Future<Map<String, dynamic>> updateEventArtifact({
    required String eventId,
    required String kind,
    required String content,
  }) async {
    return runJson(['update-event-artifact', eventId, kind, content]);
  }

  Future<void> lockNarrative(String narrativeId) async {
    await runJson(['lock-narrative', narrativeId]);
  }

  Future<void> addNote(String content) async {
    await runJson(['add-note', content]);
  }

  Future<Map<String, dynamic>> listNotes({
    int days = 30,
    String? date,
    String? startDate,
    String? endDate,
  }) {
    final args = ['notes', '--days=$days'];
    if (date != null) args.add('--date=$date');
    if (startDate != null) args.add('--start-date=$startDate');
    if (endDate != null) args.add('--end-date=$endDate');
    return runJson(args);
  }

  Future<Map<String, dynamic>> getConfig() => runJson(['config-get']);

  Future<Map<String, dynamic>> addRepo(String path) =>
      runJson(['config-add-repo', path]);

  Future<Map<String, dynamic>> removeRepo(String path) =>
      runJson(['config-remove-repo', path]);

  Future<Map<String, dynamic>> setModel(String model) =>
      runJson(['config-set-model', model]);

  Future<Map<String, dynamic>> setUserName(String name) =>
      runJson(['config-set-user-name', name]);

  Future<String?> detectGitUser(String path) async {
    final res = await runJson(['detect-git-user', path]);
    return res['name'] as String?;
  }

  Future<String?> getGoogleAuthUrl() async {
    final res = await runJson(['google-calendar-auth-url']);
    if (res['ok'] == true) return res['url'] as String?;
    throw PythonServiceError(res['error'] ?? 'Failed to get auth URL');
  }

  Future<void> setGoogleToken(String code) async {
    final res = await runJson(['google-calendar-set-token', code]);
    if (res['ok'] != true) {
      throw PythonServiceError(res['error'] ?? 'Failed to set token');
    }
  }

  Future<void> setGoogleSecrets(String clientId, String clientSecret) async {
    final res = await runJson([
      'google-calendar-set-secrets',
      clientId,
      clientSecret,
    ]);
    if (res['ok'] != true) {
      throw PythonServiceError(res['error'] ?? 'Failed to set secrets');
    }
  }

  Future<Map<String, dynamic>> ingestGit({int days = 7}) =>
      runJson(['ingest-git', '--days=$days']);
}
