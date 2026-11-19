/// Engine commands for setup screens: Settings (models, schedule, backup, templates, general),
/// identities, curation rules, repo scanning and onboarding. Top-level functions so each closure
/// captures only plain data (see `commands.dart`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'engine_runtime.dart';
import 'messages.dart';

// ---------- settings ----------

EngineCommand<void> setSettingCmd(String key, String value) => (rt) => rt.putSetting(key, value);

EngineCommand<void> renameProfileCmd(String id, String name) => (rt) =>
    (rt.appDb.update(rt.appDb.profiles)..where((p) => p.id.equals(id))).write(ProfilesCompanion(name: Value(name)));

// ---------- identities ----------

/// Identity kinds (Identities.kind) with their UI labels.
const identityKinds = <String, String>{
  'email': 'Email',
  'github_login': 'GitHub login',
  'gitlab_user': 'GitLab username',
  'jira_account': 'Jira account',
  'linear_user': 'Linear user',
};

/// Adds an identity unless an equal one (case-insensitive) exists.
EngineCommand<void> addIdentityCmd(String kind, String value) => (rt) async {
      final v = value.trim();
      if (v.isEmpty) return;
      final db = rt.db;
      final existing = await (db.select(db.identities)..where((i) => i.kind.equals(kind))).get();
      if (existing.any((i) => i.value.toLowerCase() == v.toLowerCase())) return;
      await db.into(db.identities).insert(IdentitiesCompanion.insert(id: newId(), kind: kind, value: v));
    };

EngineCommand<void> removeIdentityCmd(String id) =>
    (rt) => (rt.db.delete(rt.db.identities)..where((i) => i.id.equals(id))).go();

// ---------- calendar ----------

/// Asks macOS for calendar access through the port bridge (EventKit runs in the UI isolate).
EngineCommand<bool> appleCalendarAccessCmd() => (rt) async => await rt.engine.ports.calendar?.requestAccess() ?? false;

// ---------- git ----------

/// `git config --global user.email`, used to pre-tick "you" among scanned authors.
EngineCommand<String?> gitGlobalEmailCmd() => (rt) async {
      final path = GitDetector().detect();
      if (path == null) return null;
      try {
        final r = await Process.run(path, ['config', '--global', 'user.email']);
        final v = (r.stdout as String).trim();
        return v.isEmpty ? null : v.toLowerCase();
      } on ProcessException {
        return null;
      }
    };

/// System git: [path] null when it isn't installed (guided install screen).
class GitStatus {
  const GitStatus(this.path, this.version);
  final String? path;
  final String? version;
}

EngineCommand<GitStatus> gitStatusCmd() => (rt) async {
      final path = GitDetector().detect();
      if (path == null) return const GitStatus(null, null);
      try {
        final r = await Process.run(path, ['--version']);
        final v = (r.stdout as String).trim().replaceFirst('git version ', '');
        return GitStatus(path, v);
      } on ProcessException {
        return GitStatus(path, null);
      }
    };

/// A repo found by [scanReposCmd], with its last-30-days activity.
class RepoScan {
  const RepoScan({
    required this.path,
    required this.lastCommitAt,
    required this.myCommits,
    required this.authors,
  });
  final String path;
  final DateTime? lastCommitAt;

  /// Commits in the last 30 days by one of the profile's email identities.
  final int myCommits;

  /// email → (name, commits in the last 30 days).
  final Map<String, (String, int)> authors;

  String get name => p.basename(path);
}

/// Default roots offered for scanning (SPEC §5).
List<String> defaultScanRoots() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  return [
    for (final d in const ['Projects', 'projects', 'work', 'Work', 'code', 'src', 'dev', 'Developer', 'repos', 'git'])
      if (Directory(p.join(home, d)).existsSync()) p.join(home, d),
  ];
}

/// Scans [roots] for git repos and reads who committed there in the last 30 days.
/// Repos are sorted by your recent commits, then by last activity.
EngineCommand<List<RepoScan>> scanReposCmd(List<String> roots) => (rt) async {
      final git = rt.engine.ports.git;
      if (await git.locate() == null) return const [];
      final mine = {
        for (final i in await (rt.db.select(rt.db.identities)..where((i) => i.kind.equals('email'))).get())
          i.value.toLowerCase(),
      };
      final paths = await scanForRepos(roots);
      Future<RepoScan> one(String path) async {
        final authors = <String, (String, int)>{};
        DateTime? last;
        try {
          final out = await git.run(path, ['log', '--all', '--since=30.days', '--format=%ae%x1f%an%x1f%cI']);
          for (final line in const LineSplitter().convert(out)) {
            final f = line.split('\x1f');
            if (f.length < 3) continue;
            final email = f[0].toLowerCase();
            final prev = authors[email];
            authors[email] = (f[1], (prev?.$2 ?? 0) + 1);
            final at = DateTime.tryParse(f[2]);
            if (at != null && (last == null || at.isAfter(last))) last = at;
          }
          if (last == null) {
            final out = (await git.run(path, ['log', '-1', '--all', '--format=%cI'])).trim();
            last = DateTime.tryParse(out);
          }
        } catch (_) {
          // Empty or broken repo: listed without activity.
        }
        final my = authors.entries.where((e) => mine.contains(e.key)).fold<int>(0, (s, e) => s + e.value.$2);
        return RepoScan(path: path, lastCommitAt: last, myCommits: my, authors: authors);
      }

      final out = <RepoScan>[];
      for (var i = 0; i < paths.length; i += 8) {
        out.addAll(await Future.wait(paths.skip(i).take(8).map(one)));
      }
      out.sort((a, b) {
        final c = b.myCommits.compareTo(a.myCommits);
        if (c != 0) return c;
        return (b.lastCommitAt ?? DateTime(0)).compareTo(a.lastCommitAt ?? DateTime(0));
      });
      return out;
    };

// ---------- curation rules (#60) ----------

/// Saves a rule matching titles by [titlePattern] (and optionally a source kind).
EngineCommand<void> saveCurationRuleCmd({
  String? id,
  required String titlePattern,
  SourceKind? sourceKind,
  required CurationAction action,
  double value = 0,
  bool enabled = true,
}) =>
    (rt) => rt.db.into(rt.db.curationRules).insertOnConflictUpdate(CurationRulesCompanion.insert(
          id: id ?? newId(),
          match: jsonEncode({'titlePattern': titlePattern, 'sourceKind': ?sourceKind?.name}),
          action: action,
          value: Value(action == CurationAction.hide ? 0 : value),
          enabled: Value(enabled),
        ));

EngineCommand<void> setCurationRuleEnabledCmd(String id, bool enabled) =>
    (rt) => (rt.db.update(rt.db.curationRules)..where((r) => r.id.equals(id)))
        .write(CurationRulesCompanion(enabled: Value(enabled)));

EngineCommand<void> deleteCurationRuleCmd(String id) =>
    (rt) => (rt.db.delete(rt.db.curationRules)..where((r) => r.id.equals(id))).go();

// ---------- AI providers & models (#15, #70, #74, #75) ----------

String _keyRef(String providerId) => 'provider/$providerId/key';
String _headerRef(String providerId, String name) => 'provider/$providerId/header/$name';

/// Creates or updates a provider. [apiKey] / [headers] null = keep the stored values;
/// an empty [apiKey] removes the key. Returns (provider id, consent already given).
EngineCommand<(String, bool)> saveProviderCmd({
  String? id,
  required ProviderKind kind,
  required String name,
  required String baseUrl,
  required ProviderProtocol protocol,
  String? apiKey,
  Map<String, String>? headers,
  String? customCaPem,
  bool allowSelfSigned = false,
  int timeoutSeconds = 120,
}) =>
    (rt) async {
      final db = rt.appDb;
      final secrets = rt.engine.ports.secrets;
      final pid = id ?? newId();
      final old = await (db.select(db.providers)..where((x) => x.id.equals(pid))).getSingleOrNull();
      var keyRef = old?.credentialRef;
      if (apiKey != null) {
        if (apiKey.isEmpty) {
          if (keyRef != null) await secrets.delete(keyRef);
          keyRef = null;
        } else {
          keyRef = _keyRef(pid);
          await secrets.write(keyRef, apiKey);
        }
      }
      var headerJson = old?.headers ?? '{}';
      if (headers != null) {
        final oldRefs = (jsonDecode(headerJson) as Map).cast<String, String>();
        for (final ref in oldRefs.values) {
          await secrets.delete(ref);
        }
        final refs = <String, String>{};
        for (final e in headers.entries) {
          refs[e.key] = _headerRef(pid, e.key);
          await secrets.write(refs[e.key]!, e.value);
        }
        headerJson = jsonEncode(refs);
      }
      // Consent is per base URL: changing the URL asks again (#74).
      final consent = old != null && old.baseUrl == baseUrl && old.consentGiven;
      await db.into(db.providers).insertOnConflictUpdate(ProvidersCompanion.insert(
            id: pid,
            kind: kind,
            name: name,
            baseUrl: baseUrl,
            protocol: protocol,
            credentialRef: Value(keyRef),
            headers: Value(headerJson),
            customCaPem: Value(customCaPem == null || customCaPem.trim().isEmpty ? null : customCaPem),
            allowSelfSigned: Value(allowSelfSigned),
            timeoutSeconds: Value(timeoutSeconds),
            consentGiven: Value(consent),
          ));
      return (pid, consent);
    };

EngineCommand<void> setProviderConsentCmd(String id) => (rt) =>
    (rt.appDb.update(rt.appDb.providers)..where((x) => x.id.equals(id)))
        .write(const ProvidersCompanion(consentGiven: Value(true)));

Future<LlmClient> _client(EngineRuntime rt, String providerId) async {
  final db = rt.appDb;
  final secrets = rt.engine.ports.secrets;
  final row = await (db.select(db.providers)..where((x) => x.id.equals(providerId))).getSingle();
  final key = row.credentialRef == null ? null : await secrets.read(row.credentialRef!);
  final refs = (jsonDecode(row.headers) as Map).cast<String, String>();
  final headers = {for (final e in refs.entries) e.key: await secrets.read(e.value) ?? ''};
  return createClient(row, apiKey: key, headers: headers);
}

/// Test connection: lists the provider's models. Throws with the provider's error message.
EngineCommand<List<ModelInfo>> listProviderModelsCmd(String providerId) => (rt) async {
      final models = await (await _client(rt, providerId)).listModels();
      return models..sort((a, b) => a.name.compareTo(b.name));
    };

/// Adds a model only after the structured-output probe succeeds (#70). The first model becomes
/// the default when none is set. Returns the model id.
EngineCommand<String> addModelCmd(String providerId, String modelName, {ModelInfo? info}) => (rt) async {
      final probed = await probeModel(await _client(rt, providerId), modelName, info: info);
      final db = rt.appDb;
      final existing = await (db.select(db.models)
            ..where((m) => m.providerId.equals(providerId) & m.modelName.equals(modelName)))
          .getSingleOrNull();
      final id = existing?.id ?? newId();
      await db.into(db.models).insertOnConflictUpdate(ModelsCompanion.insert(
            id: id,
            providerId: providerId,
            modelName: modelName,
            vision: Value(probed.vision),
            contextLength: Value(probed.contextLength ?? 8192),
            inputPricePerMTok: Value(probed.inputPricePerMTok),
            outputPricePerMTok: Value(probed.outputPricePerMTok),
          ));
      final pdb = rt.db;
      final def = await (pdb.select(pdb.taskRoutes)..where((r) => r.route.equalsValue(LlmRoute.defaultRoute)))
          .getSingleOrNull();
      if (def?.modelId == null) {
        await pdb.into(pdb.taskRoutes).insertOnConflictUpdate(
              TaskRoutesCompanion.insert(route: LlmRoute.defaultRoute, modelId: Value(id)),
            );
      }
      return id;
    };

EngineCommand<void> removeModelCmd(String modelId) => (rt) async {
      await (rt.db.update(rt.db.taskRoutes)..where((r) => r.modelId.equals(modelId)))
          .write(const TaskRoutesCompanion(modelId: Value(null)));
      await (rt.appDb.delete(rt.appDb.models)..where((m) => m.id.equals(modelId))).go();
    };

EngineCommand<void> removeProviderCmd(String providerId) => (rt) async {
      final db = rt.appDb;
      final row = await (db.select(db.providers)..where((x) => x.id.equals(providerId))).getSingle();
      final secrets = rt.engine.ports.secrets;
      if (row.credentialRef != null) await secrets.delete(row.credentialRef!);
      for (final ref in (jsonDecode(row.headers) as Map).cast<String, String>().values) {
        await secrets.delete(ref);
      }
      final models = await (db.select(db.models)..where((m) => m.providerId.equals(providerId))).get();
      for (final m in models) {
        await (rt.db.update(rt.db.taskRoutes)..where((r) => r.modelId.equals(m.id)))
            .write(const TaskRoutesCompanion(modelId: Value(null)));
      }
      await db.transaction(() async {
        await (db.delete(db.models)..where((m) => m.providerId.equals(providerId))).go();
        await (db.delete(db.providers)..where((x) => x.id.equals(providerId))).go();
      });
    };

/// Sets a route's model; null = inherit Default (#75).
EngineCommand<void> setRouteCmd(LlmRoute route, String? modelId) => (rt) =>
    rt.db.into(rt.db.taskRoutes).insertOnConflictUpdate(TaskRoutesCompanion.insert(route: route, modelId: Value(modelId)));

/// A local model server answering on its default port (auto-detect convenience, SPEC §6).
class LocalServer {
  const LocalServer(this.name, this.baseUrl, this.protocol);
  final String name;
  final String baseUrl;
  final ProviderProtocol protocol;
}

EngineCommand<List<LocalServer>> detectLocalServersCmd() => (rt) async {
      const candidates = [
        LocalServer('Ollama', 'http://localhost:11434', ProviderProtocol.ollama),
        LocalServer('LM Studio', 'http://localhost:1234/v1', ProviderProtocol.openai),
      ];
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 1), receiveTimeout: const Duration(seconds: 2)));
      final found = <LocalServer>[];
      for (final c in candidates) {
        try {
          await dio.get<Object?>(c.protocol == ProviderProtocol.ollama ? '${c.baseUrl}/api/tags' : '${c.baseUrl}/models');
          found.add(c);
        } catch (_) {}
      }
      return found;
    };

// ---------- schedule ----------

/// Writes a schedule rule. lastRunAt = now, so changing the time never fires a "missed" run.
EngineCommand<void> setScheduleCmd(String id, ScheduleRule rule, bool enabled) => (rt) =>
    (rt.db.update(rt.db.schedules)..where((s) => s.id.equals(id))).write(SchedulesCompanion(
      rule: Value(jsonEncode(rule.toJson())),
      enabled: Value(enabled),
      lastRunAt: Value(DateTime.now().toUtc()),
    ));

// ---------- backup (SPEC §9) ----------

EngineCommand<String> backupNowCmd() => (rt) => rt.backupNow();

EngineCommand<String> defaultBackupFolderCmd() => (rt) async => rt.defaultBackupFolder;

EngineCommand<BackupManifest> inspectBackupCmd(String file) => (rt) => BackupService.inspect(file);

/// Restores [file] into a new profile (named "… (restored)") and returns its id; the UI then
/// switches to it. Existing profiles are never overwritten.
EngineCommand<String> restoreBackupCmd(String file) => (rt) async {
      final m = await BackupService.inspect(file);
      final id = await rt.createProfile('${m.profile} (restored)');
      try {
        await BackupService.restore(
          file,
          p.join(rt.config.dataDir, 'profiles', '$id.sqlite'),
          currentSchemaVersion: rt.db.schemaVersion,
          attachmentsDir: p.join(rt.config.dataDir, 'blobs', id),
        );
      } catch (_) {
        await (rt.appDb.delete(rt.appDb.profiles)..where((x) => x.id.equals(id))).go();
        rethrow;
      }
      return id;
    };

// ---------- templates (#86) ----------

EngineCommand<String> duplicateTemplateCmd(String id) => (rt) => TemplateService(rt.db).duplicate(id);

/// Returns the id actually changed (editing a built-in duplicates it).
EngineCommand<String> updateTemplateCmd(String id, {String? name, List<PeriodKind>? periodKinds, String? prompt}) =>
    (rt) => TemplateService(rt.db).update(id, name: name, periodKinds: periodKinds, prompt: prompt);

EngineCommand<void> resetTemplateCmd(String id) => (rt) => TemplateService(rt.db).resetToDefault(id);

EngineCommand<void> deleteTemplateCmd(String id) => (rt) => TemplateService(rt.db).delete(id);

/// Live preview (#86): renders [templateId] for the current [kind] period against real data,
/// saving nothing. Returns Markdown.
EngineCommand<String> previewTemplateCmd(String templateId, PeriodKind kind) => (rt) async {
      final today = dayOf(DateTime.now(), DateTime.now().timeZoneOffset);
      final period = kind == PeriodKind.custom
          ? Period.custom(formatDayString(DateTime.now().subtract(const Duration(days: 13))), today)
          : Period.containing(kind, today);
      final generator =
          ReportGenerator(db: rt.db, router: rt.engine.router, tools: rt.engine.tools, profileId: rt.profile.id);
      String? markdown;
      await for (final e in generator.preview(templateId, period)) {
        if (e is ReportDone) markdown = e.markdown;
      }
      return markdown ?? '';
    };

String formatDayString(DateTime d) => dayOf(d, d.timeZoneOffset);
