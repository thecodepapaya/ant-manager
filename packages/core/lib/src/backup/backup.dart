import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../data/profile_db.dart';
import '../ports/ports.dart';
import 'readable_export.dart';

/// `manifest.json` inside an `.antbackup` (SPEC §9).
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.appVersion,
    required this.schemaVersion,
    required this.profile,
    required this.createdAt,
    required this.firstDay,
    required this.lastDay,
    required this.counts,
    required this.dbSha256,
  });

  static const currentFormat = 1;

  final int format;
  final String appVersion;
  final int schemaVersion;
  final String profile;
  final DateTime createdAt;
  final String? firstDay, lastDay;
  final Map<String, int> counts;

  /// sha256 of `db.sqlite` in the bundle.
  final String dbSha256;

  Map<String, Object?> toJson() => {
    'format': format,
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'profile': profile,
    'created_at': createdAt.toUtc().toIso8601String(),
    'first_day': firstDay,
    'last_day': lastDay,
    'counts': counts,
    'db_sha256': dbSha256,
  };

  factory BackupManifest.fromJson(Map<String, Object?> j) => BackupManifest(
    format: (j['format'] as num).toInt(),
    appVersion: j['app_version'] as String,
    schemaVersion: (j['schema_version'] as num).toInt(),
    profile: j['profile'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    firstDay: j['first_day'] as String?,
    lastDay: j['last_day'] as String?,
    counts: {for (final e in (j['counts'] as Map).entries) e.key as String: (e.value as num).toInt()},
    dbSha256: j['db_sha256'] as String,
  );
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => 'BackupException: $message';
}

/// Restorable `.antbackup` bundles + optional readable export (SPEC §9, #34 #78 #80).
///
/// A bundle is a zip: `manifest.json`, `db.sqlite` (from `VACUUM INTO`, a consistent snapshot) and
/// `attachments/<blob path>`. Secrets are never included: they live in the OS keychain (SecretStore),
/// and the profile DB only holds references to them.
class BackupService {
  BackupService(
    this.db, {
    required this.profileName,
    required this.appVersion,
    this.blobs,
    this.keep = 14,
    this.clock = const SystemClock(),
  });

  final ProfileDb db;
  final String profileName;
  final String appVersion;

  /// Source of attachment files; null = attachments are skipped.
  final BlobStore? blobs;

  /// Backups kept per profile in the destination folder (#78).
  final int keep;
  final Clock clock;

  static const extension = '.antbackup';

  /// Writes `<profile>-<timestamp>.antbackup` into [folder], prunes to the last [keep], and
  /// optionally refreshes the readable export in `<folder>/<profile>-export/`.
  Future<File> createBackup(String folder, {bool readableExport = false}) async {
    await Directory(folder).create(recursive: true);
    final now = clock.now().toUtc();
    final tmp = await Directory.systemTemp.createTemp('antbackup');
    try {
      final dbFile = p.join(tmp.path, 'db.sqlite');
      await db.customStatement('VACUUM INTO ?', [dbFile]);
      final dbBytes = await File(dbFile).readAsBytes();
      final archive = Archive();
      final attachments = await db.select(db.attachments).get();
      var attachmentCount = 0;
      if (blobs != null) {
        for (final a in attachments) {
          archive.addFile(ArchiveFile.bytes('attachments/${a.path}', await blobs!.get(a.path)));
          attachmentCount++;
        }
      }
      final manifest = BackupManifest(
        format: BackupManifest.currentFormat,
        appVersion: appVersion,
        schemaVersion: db.schemaVersion,
        profile: profileName,
        createdAt: now,
        firstDay: await _scalar('SELECT MIN(day) AS v FROM evidences'),
        lastDay: await _scalar('SELECT MAX(day) AS v FROM evidences'),
        counts: {...await _counts(), 'attachment_files': attachmentCount},
        dbSha256: sha256.convert(dbBytes).toString(),
      );
      archive
        ..addFile(ArchiveFile.string('manifest.json', const JsonEncoder.withIndent('  ').convert(manifest.toJson())))
        ..addFile(ArchiveFile.bytes('db.sqlite', dbBytes));
      final out = File(p.join(folder, '${_safe(profileName)}-${_stamp(now)}$extension'));
      await out.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
      await _prune(folder);
      if (readableExport) await ReadableExporter(db).export(p.join(folder, '${_safe(profileName)}-export'));
      return out;
    } finally {
      await tmp.delete(recursive: true);
    }
  }

  /// Backups of this profile in [folder], newest first.
  Future<List<File>> list(String folder) async {
    final dir = Directory(folder);
    if (!await dir.exists()) return [];
    // Exact `<profile>-<stamp>.antbackup`, so "Work" never matches "Work-old" backups.
    final name = RegExp('^${RegExp.escape(_safe(profileName))}-\\d{8}T\\d{6}Z${RegExp.escape(extension)}\$');
    final files = [
      await for (final f in dir.list())
        if (f is File && name.hasMatch(p.basename(f.path))) f,
    ]..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  /// Reads the manifest only (restore preview).
  static Future<BackupManifest> inspect(String file) async {
    final archive = ZipDecoder().decodeBytes(await File(file).readAsBytes());
    return _manifest(archive);
  }

  /// Restores [file] into a new database file at [targetDbPath] (and attachments into [attachmentsDir]).
  /// Sources lose their secret references and those that had one are disabled until signed in again.
  /// Refuses bundles from a newer schema than [currentSchemaVersion]; older ones are migrated by drift
  /// when the restored DB is opened. Close any DB open at [targetDbPath] before passing [overwrite].
  static Future<BackupManifest> restore(
    String file,
    String targetDbPath, {
    required int currentSchemaVersion,
    String? attachmentsDir,
    bool overwrite = false,
  }) async {
    final archive = ZipDecoder().decodeBytes(await File(file).readAsBytes());
    final m = _manifest(archive);
    if (m.schemaVersion > currentSchemaVersion) {
      throw BackupException(
        'This backup was made by a newer version of Ant Manager (schema ${m.schemaVersion}). '
        'Update the app to restore it.',
      );
    }
    final dbBytes = archive.findFile('db.sqlite')?.readBytes() ?? (throw BackupException('Backup has no database'));
    if (sha256.convert(dbBytes).toString() != m.dbSha256) throw BackupException('Backup checksum does not match');
    final target = File(targetDbPath);
    if (await target.exists() && !overwrite) throw BackupException('$targetDbPath already exists');
    await target.parent.create(recursive: true);
    for (final suffix in ['-wal', '-shm']) {
      final f = File('$targetDbPath$suffix');
      if (await f.exists()) await f.delete();
    }
    await target.writeAsBytes(dbBytes, flush: true);
    // After a restore you sign in again (SPEC §9, #118): a restored source must not reuse a token in this
    // machine's secret store, which an edited backup could point at another URL. Sources that had one are
    // disabled so they don't fail every sync; saving the source with a new secret re-enables it.
    final restored = sqlite3.open(targetDbPath);
    try {
      restored.execute('UPDATE sources SET enabled = 0, credential_ref = NULL WHERE credential_ref IS NOT NULL');
    } finally {
      restored.close();
    }
    if (attachmentsDir != null) {
      final root = p.normalize(p.absolute(attachmentsDir));
      for (final f in archive.files) {
        if (!f.isFile || !f.name.startsWith('attachments/')) continue;
        final dest = p.normalize(p.join(root, f.name.substring('attachments/'.length)));
        if (!p.isWithin(root, dest)) throw BackupException('Unsafe path in backup: ${f.name}');
        await File(dest).parent.create(recursive: true);
        await File(dest).writeAsBytes(f.readBytes() ?? Uint8List(0));
      }
    }
    return m;
  }

  // ---------- internals ----------

  static BackupManifest _manifest(Archive archive) {
    final bytes =
        archive.findFile('manifest.json')?.readBytes() ?? (throw BackupException('Not an Ant Manager backup'));
    return BackupManifest.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>);
  }

  Future<void> _prune(String folder) async {
    final files = await list(folder);
    for (final f in files.skip(keep)) {
      await f.delete();
    }
  }

  Future<String?> _scalar(String sql) => db.customSelect(sql).map((r) => r.read<String?>('v')).getSingle();

  Future<Map<String, int>> _counts() async {
    const tables = {
      'evidences': 'evidences',
      'payloads': 'payloads',
      'facts': 'facts',
      'workstreams': 'workstreams',
      'projects': 'projects',
      'reports': 'reports',
      'report_snapshots': 'report_snapshots',
      'templates': 'templates',
      'attachments': 'attachments',
    };
    return {
      for (final MapEntry(:key, :value) in tables.entries)
        key: await db.customSelect('SELECT COUNT(*) AS c FROM $value').map((r) => r.read<int>('c')).getSingle(),
    };
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}T${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }
}
