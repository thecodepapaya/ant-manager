/// Engine commands as top-level functions, so each closure captures only its plain arguments
/// (closures are copied into the engine isolate; see [EngineHandle.run]).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';

import 'messages.dart';

EngineCommand<void> setActiveProfileCmd(String id) => (rt) => rt.setActiveProfile(id);

EngineCommand<String> createProfileCmd(String name) => (rt) => rt.createProfile(name);

EngineCommand<void> setPausedCmd(bool paused) => (rt) => rt.setPaused(paused);

EngineCommand<bool> syncNowCmd() => (rt) => rt.syncNow();

// ---------- sources (core SyncService) ----------

EngineCommand<String> addSourceCmd(SourceKind kind, String name, Map<String, Object?> config, {String? secret}) =>
    (rt) => rt.sync.addSource(kind, name, config, secret: secret);

EngineCommand<void> updateSourceCmd(String id,
        {String? name, Map<String, Object?>? config, String? secret, bool? enabled}) =>
    (rt) => rt.sync.updateSource(id, name: name, config: config, secret: secret, enabled: enabled);

EngineCommand<void> removeSourceCmd(String id) => (rt) => rt.sync.removeSource(id);

/// Returns null when healthy, else the error message.
EngineCommand<String?> validateSourceCmd(String id) =>
    (rt) async => (await rt.sync.validateSource(id)).message;

EngineCommand<bool> syncSourceCmd(String id) => (rt) => rt.sync.enqueueSync(id);

/// Returns the transcript's evidence id.
EngineCommand<String> importTranscriptCmd(String fileName, String text, DateTime at) =>
    (rt) => rt.sync.importTranscript(fileName, text, at);

/// Quick capture (#83): a note on today, optionally with a screenshot. The screenshot temp file
/// is moved into the profile's BlobStore and deleted.
EngineCommand<String> addQuickNoteCmd({
  required String text,
  String? link,
  String? projectId,
  String? screenshotPath,
}) =>
    (rt) async {
      final attachments = <String>[];
      if (screenshotPath != null) {
        final file = File(screenshotPath);
        final bytes = await file.readAsBytes();
        attachments.add(await rt.engine.ports.blobs.put(Uint8List.fromList(bytes), extension: 'png'));
        await file.delete();
      }
      return rt.engine.addNote(
        text: text,
        at: DateTime.now(),
        link: link,
        projectId: projectId,
        attachmentPaths: attachments,
      );
    };
