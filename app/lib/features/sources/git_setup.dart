/// Local git setup (SPEC §5, #14): git detection with a guided install screen, scanning watched
/// roots for repos with recent activity, tick to include, manual add.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart' hide Provider;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/commands.dart';
import '../../engine/setup_commands.dart';
import '../../state/providers.dart';
import '../settings/kit.dart';
import '../settings/setup_providers.dart';

/// `~/…` for paths under the home folder.
String tildePath(String path) {
  final home = Platform.environment['HOME'];
  return home != null && path.startsWith(home) ? '~${path.substring(home.length)}' : path;
}

/// Scan state shared by the git dialog and onboarding (identities are suggested from it).
class RepoScanController extends ChangeNotifier {
  RepoScanController(this._ref);
  final WidgetRef _ref;

  GitStatus? git;
  bool checking = true;
  bool scanning = false;
  // Real paths: on a case-insensitive disk ~/Projects and ~/projects are one folder.
  List<String> roots = {for (final r in defaultScanRoots()) _realPath(r)}.toList();

  static String _realPath(String path) {
    try {
      return Directory(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path;
    }
  }
  List<RepoScan> repos = const [];
  final selected = <String>{};
  bool _disposed = false;

  // Scans outlive the page that started them: drop updates after dispose.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> checkGit() async {
    checking = true;
    notifyListeners();
    final h = await _ref.read(engineProvider.future);
    final status = await h.runtime(gitStatusCmd());
    if (_disposed) return;
    git = status;
    checking = false;
    notifyListeners();
  }

  Future<void> scan() async {
    if (_disposed || git?.path == null) return;
    scanning = true;
    notifyListeners();
    final h = await _ref.read(engineProvider.future);
    final manual = repos.where((r) => !roots.any((root) => p.isWithin(root, r.path))).toList();
    final found = await h.runtime(scanReposCmd(roots));
    if (_disposed) return;
    repos = [...found, for (final m in manual) if (!found.any((f) => f.path == m.path)) m];
    scanning = false;
    notifyListeners();
  }

  /// Ticks repos with commits by [emails] in the last 30 days (or by anyone, when [emails] is empty).
  void autoSelect(Set<String> emails) {
    selected
      ..clear()
      ..addAll([
        for (final r in repos)
          if (emails.isEmpty ? r.authors.isNotEmpty : r.authors.keys.any(emails.contains)) r.path,
      ]);
    notifyListeners();
  }

  void toggle(String path) {
    selected.contains(path) ? selected.remove(path) : selected.add(path);
    notifyListeners();
  }

  Future<void> addRoot(String dir) async {
    if (!roots.contains(dir)) roots = [...roots, dir];
    await scan();
  }

  /// Manual add: one repo folder, ticked.
  Future<String?> addRepo(String dir) async {
    if (!Directory(p.join(dir, '.git')).existsSync() && !File(p.join(dir, '.git')).existsSync()) {
      return '${tildePath(dir)} is not a git repository';
    }
    if (!repos.any((r) => r.path == dir)) {
      final h = await _ref.read(engineProvider.future);
      final one = await h.runtime(scanReposCmd([dir]));
      repos = [...one, ...repos];
    }
    selected.add(dir);
    notifyListeners();
    return null;
  }

  /// email → (name, repos it committed to) across the scan, most repos first.
  List<(String, String, int)> authors() {
    final byEmail = <String, (String, int)>{};
    for (final r in repos) {
      for (final e in r.authors.entries) {
        final prev = byEmail[e.key];
        byEmail[e.key] = (e.value.$1, (prev?.$2 ?? 0) + 1);
      }
    }
    final out = [for (final e in byEmail.entries) (e.key, e.value.$1, e.value.$2)];
    out.sort((a, b) => b.$3.compareTo(a.$3));
    return out;
  }

  /// Adds the ticked repos that aren't sources yet. Returns how many were added.
  Future<int> addSelected(Set<String> existing) async {
    final h = await _ref.read(engineProvider.future);
    var n = 0;
    for (final path in selected) {
      if (existing.contains(path)) continue;
      final id = await h.runtime(addSourceCmd(SourceKind.gitRepo, p.basename(path), {'path': path}));
      await h.runtime(syncSourceCmd(id));
      n++;
    }
    return n;
  }
}

/// Paths of the git repos already added.
Set<String> existingRepoPaths(List<SourceStatus> sources) => {
      for (final s in sources)
        if (s.row.kind == SourceKind.gitRepo && s.row.enabled) ?(jsonDecode(s.row.config) as Map)['path'] as String?,
    };

/// Friendly install screen when git is missing (SPEC §5).
class GitInstallGuide extends StatelessWidget {
  const GitInstallGuide({super.key, required this.onRecheck, this.checking = false});
  final VoidCallback onRecheck;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget step(String n, String title, String detail, {String? command}) => PanelRow(
          leading: Glyph(n),
          title: title,
          hint: detail,
          trailing: [
            if (command != null)
              AntButton(
                label: 'Copy',
                size: AntSize.sm,
                icon: Icons.copy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: command));
                  if (context.mounted) toast(context, 'Copied “$command”');
                },
              ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Callout(
          child: Text('Git isn’t installed yet. Ant Manager uses your system git to read commits; it never '
              'installs anything by itself.'),
        ),
        Gap(t.space.xl),
        ListPanel(children: [
          if (Platform.isMacOS) ...[
            step('1', 'Install the Command Line Tools', 'Open Terminal and run: xcode-select --install',
                command: 'xcode-select --install'),
            step('2', 'Or use Homebrew', 'If you use Homebrew: brew install git', command: 'brew install git'),
          ] else
            step('1', 'Install Git for Windows', 'Download the installer from git-scm.com and keep the defaults.'),
          step(Platform.isMacOS ? '3' : '2', 'Come back here', 'Ant Manager checks again when you press the button.'),
        ]),
        Gap(t.space.lg),
        Row(
          children: [
            AntButton.primary(label: checking ? 'Checking…' : 'Check again', onPressed: checking ? null : onRecheck),
            SizedBox(width: t.space.md),
            AntButton.ghost(
              label: 'git-scm.com/downloads',
              icon: Icons.open_in_new,
              onPressed: () => launchUrl(Uri.parse('https://git-scm.com/downloads')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chips + repo checklist (mockup onboarding "Pick the repos to watch").
class RepoPicker extends StatelessWidget {
  const RepoPicker({super.key, required this.c, this.existing = const {}});
  final RepoScanController c;
  final Set<String> existing;

  Future<void> _addFolder(BuildContext context, {required bool root}) async {
    final dir = await getDirectoryPath(confirmButtonText: root ? 'Scan folder' : 'Add repo');
    if (dir == null) return;
    if (root) {
      await c.addRoot(dir);
    } else {
      final err = await c.addRepo(dir);
      if (err != null && context.mounted) toast(context, err, tone: AntTone.err);
    }
  }

  String _activity(RepoScan r) {
    if (r.myCommits > 0) return '${r.myCommits} of your commits · 30 days';
    final total = r.authors.values.fold<int>(0, (s, a) => s + a.$2);
    if (total > 0) return '$total commits · 30 days';
    final last = r.lastCommitAt;
    if (last == null) return 'No commits yet';
    final days = DateTime.now().difference(last).inDays;
    return days > 365 ? 'No activity in over a year' : 'No activity in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.checking) return const _Loading('Looking for git…');
        if (c.git?.path == null) return GitInstallGuide(onRecheck: c.checkGit, checking: c.checking);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: t.space.md,
              runSpacing: t.space.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AntChip(label: 'git ${c.git!.version ?? ''} found', tone: AntTone.ok, icon: Icons.check),
                AntChip(label: c.scanning ? 'Scanning…' : '${c.repos.length} repos found'),
                for (final r in c.roots) AntChip(label: tildePath(r), icon: Icons.folder_outlined),
                AntButton.ghost(
                    label: 'Add folder', icon: Icons.add, size: AntSize.sm, onPressed: () => _addFolder(context, root: true)),
                AntButton.ghost(
                    label: 'Add repo manually',
                    icon: Icons.create_new_folder_outlined,
                    size: AntSize.sm,
                    onPressed: () => _addFolder(context, root: false)),
              ],
            ),
            Gap(t.space.lg),
            if (c.scanning && c.repos.isEmpty)
              const _Loading('Scanning for repositories…')
            else if (c.repos.isEmpty)
              ListPanel(children: [
                PanelRow(
                  title: 'No repositories found',
                  hint: c.roots.isEmpty
                      ? 'Add the folder where you keep your code, or add a repo manually.'
                      : 'Nothing under ${c.roots.map(tildePath).join(', ')}. Add another folder or a repo manually.',
                ),
              ])
            else
              ListPanel(children: [
                for (final r in c.repos)
                  PanelRow(
                    dense: true,
                    onTap: existing.contains(r.path) ? null : () => c.toggle(r.path),
                    leading: AntCheckbox(
                      value: existing.contains(r.path) || c.selected.contains(r.path),
                      onChanged: existing.contains(r.path) ? null : (_) => c.toggle(r.path),
                    ),
                    title: r.name,
                    hint: tildePath(r.path),
                    hintMono: true,
                    trailing: [
                      if (existing.contains(r.path))
                        const AntChip(label: 'Added', tone: AntTone.ok)
                      else
                        Text(_activity(r), style: t.typo.small.copyWith(color: t.muted)),
                    ],
                  ),
              ]),
          ],
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.xl),
      child: Row(children: [
        SizedBox(
          width: t.icon.md,
          height: t.icon.md,
          child: CircularProgressIndicator(strokeWidth: t.stroke.focus, color: t.muted),
        ),
        SizedBox(width: t.space.md),
        Text(text, style: t.typo.body.copyWith(color: t.muted)),
      ]),
    );
  }
}

/// "Local git" in Add source / Manage repos.
class GitSetupDialog extends ConsumerStatefulWidget {
  const GitSetupDialog({super.key});
  @override
  ConsumerState<GitSetupDialog> createState() => _GitSetupDialogState();
}

class _GitSetupDialogState extends ConsumerState<GitSetupDialog> {
  late final c = RepoScanController(ref);
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    Future(() async {
      await c.checkGit();
      await c.scan();
      final emails = {
        for (final i in ref.read(identitiesProvider).value ?? const <Identity>[])
          if (i.kind == 'email') i.value.toLowerCase(),
      };
      c.autoSelect(emails);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = existingRepoPaths(ref.watch(sourcesProvider).value ?? const []);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final count = c.selected.where((s) => !existing.contains(s)).length;
        return WideDialog(
          title: 'Local git repositories',
          subtitle: 'Commits on every branch by your identities. New repos under these folders are suggested.',
          body: RepoPicker(c: c, existing: existing),
          actions: [
            AntButton.ghost(label: 'Close', onPressed: () => Navigator.of(context).pop()),
            AntButton.primary(
              label: _adding ? 'Adding…' : (count == 0 ? 'Add repos' : 'Add $count repo${count == 1 ? '' : 's'}'),
              onPressed: count == 0 || _adding
                  ? null
                  : () async {
                      setState(() => _adding = true);
                      try {
                        final n = await c.addSelected(existing);
                        if (context.mounted) {
                          toast(context, 'Added $n repo${n == 1 ? '' : 's'} · importing the last 30 days', tone: AntTone.ok);
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) toast(context, errorText(e), tone: AntTone.err);
                      } finally {
                        if (mounted) setState(() => _adding = false);
                      }
                    },
            ),
          ],
        );
      },
    );
  }
}
