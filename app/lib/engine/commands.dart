/// Engine commands as top-level functions, so each closure captures only its plain arguments
/// (closures are copied into the engine isolate; see [EngineHandle.run]).
library;

import 'dart:io';
import 'dart:typed_data';

import 'messages.dart';

EngineCommand<void> setActiveProfileCmd(String id) => (rt) => rt.setActiveProfile(id);

EngineCommand<String> createProfileCmd(String name) => (rt) => rt.createProfile(name);

EngineCommand<void> setPausedCmd(bool paused) => (rt) => rt.setPaused(paused);

EngineCommand<bool> syncNowCmd() => (rt) => rt.syncNow();

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
