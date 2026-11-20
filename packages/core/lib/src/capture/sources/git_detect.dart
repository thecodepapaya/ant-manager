import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ports/ports.dart';

/// Finds the system git (#3) without ever running the macOS `/usr/bin/git` stub,
/// which would pop the "install Command Line Tools" dialog.
class GitDetector {
  GitDetector({
    String? os,
    Map<String, String>? env,
    bool Function(String path)? fileExists,
    bool Function(String path)? dirExists,
    String? Function()? xcodeSelectPath,
  })  : os = os ?? Platform.operatingSystem,
        env = env ?? Platform.environment,
        _fileExists = fileExists ?? ((path) => File(path).existsSync()),
        _dirExists = dirExists ?? ((path) => Directory(path).existsSync()),
        _xcodeSelectPath = xcodeSelectPath ?? _runXcodeSelect;

  final String os;
  final Map<String, String> env;
  final bool Function(String) _fileExists;
  final bool Function(String) _dirExists;
  final String? Function() _xcodeSelectPath;

  static const macCltDir = '/Library/Developer/CommandLineTools';
  static const macStub = '/usr/bin/git';

  bool get _windows => os == 'windows';

  /// Candidate paths in priority order: PATH entries, then well-known install locations.
  List<String> candidates() {
    final exe = _windows ? 'git.exe' : 'git';
    final ctx = _windows ? p.windows : p.posix;
    final pathVar = env['PATH'] ?? env['Path'] ?? '';
    final out = <String>[
      for (final dir in pathVar.split(_windows ? ';' : ':'))
        if (dir.trim().isNotEmpty) ctx.join(dir.trim(), exe),
    ];
    switch (os) {
      case 'macos':
        out.addAll(const ['/opt/homebrew/bin/git', '/usr/local/bin/git', '$macCltDir/usr/bin/git']);
      case 'windows':
        for (final root in [env['ProgramFiles'], env['ProgramW6432'], env['ProgramFiles(x86)']]) {
          if (root != null) {
            out.add(p.windows.join(root, 'Git', 'cmd', 'git.exe'));
            out.add(p.windows.join(root, 'Git', 'bin', 'git.exe'));
          }
        }
        out.addAll(const [r'C:\Program Files\Git\cmd\git.exe', r'C:\Program Files\Git\bin\git.exe']);
        final local = env['LOCALAPPDATA'];
        if (local != null) out.add(p.windows.join(local, 'Programs', 'Git', 'cmd', 'git.exe'));
      default:
        out.addAll(const ['/usr/bin/git', '/usr/local/bin/git']);
    }
    return {...out}.toList();
  }

  /// True when [path] is the macOS shim that only offers to install the CLT.
  /// Decided from the filesystem and `xcode-select -p` (which never prompts).
  bool isMacStub(String path) {
    if (os != 'macos' || p.posix.normalize(path) != macStub) return false;
    if (_dirExists(macCltDir)) return false;
    final dev = _xcodeSelectPath();
    return dev == null || !_dirExists(dev);
  }

  /// The first existing, non-stub candidate, or null when git isn't installed.
  String? detect() {
    for (final c in candidates()) {
      if (_fileExists(c) && !isMacStub(c)) return c;
    }
    return null;
  }

  static String? _runXcodeSelect() {
    try {
      final r = Process.runSync('/usr/bin/xcode-select', ['-p']);
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } on ProcessException {
      return null;
    }
  }
}

class GitException implements Exception {
  GitException(this.args, this.exitCode, this.stderr);
  final List<String> args;
  final int exitCode;
  final String stderr;
  @override
  String toString() => 'git ${args.join(' ')} failed ($exitCode): ${stderr.trim()}';
}

/// [GitExecutable] backed by `dart:io` [Process].
class ProcessGitExecutable implements GitExecutable {
  ProcessGitExecutable({GitDetector? detector}) : _detector = detector ?? GitDetector();
  final GitDetector _detector;
  String? _path;
  bool _located = false;

  @override
  Future<String?> locate() async {
    if (!_located) {
      _path = _detector.detect();
      _located = true;
    }
    return _path;
  }

  @override
  Future<String> run(String repoPath, List<String> args) async {
    final git = await locate();
    if (git == null) throw StateError('git is not installed');
    // log.showSignature would make `git log` run the repo's gpg.program (#NEXT).
    final full = ['-C', repoPath, '-c', 'log.showSignature=false', ...args];
    final r = await Process.run(
      git,
      full,
      environment: const {'GIT_TERMINAL_PROMPT': '0', 'GIT_PAGER': 'cat', 'LC_ALL': 'C'},
      stdoutEncoding: const Utf8Codec(allowMalformed: true),
      stderrEncoding: const Utf8Codec(allowMalformed: true),
    );
    if (r.exitCode != 0) throw GitException(full, r.exitCode, r.stderr as String);
    return r.stdout as String;
  }
}
