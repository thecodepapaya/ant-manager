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

// ---------- Notes & curation (Today, Timeline) ----------

/// A note (#83) on [at]'s day, standalone or attached to [attachTo] evidence (annotate).
/// [images] are (bytes, extension) pairs, e.g. a pasted or dropped screenshot.
EngineCommand<String> addNoteCmd({
  required String text,
  required DateTime at,
  String? link,
  String? projectId,
  String? attachTo,
  List<(Uint8List, String)> images = const [],
}) =>
    (rt) async {
      final paths = [for (final (bytes, ext) in images) await rt.engine.ports.blobs.put(bytes, extension: ext)];
      return rt.engine.addNote(
        text: text,
        at: at,
        link: link,
        projectId: projectId,
        attachTo: attachTo,
        attachmentPaths: paths,
      );
    };

/// Star goes through WinService (#63): stars the evidence, then makes sure an accepted Outcome
/// fact covers it (one model call when none exists). The evidence stays starred if the call fails.
/// Returns the win's fact id.
EngineCommand<String> starEvidenceCmd(String evidenceId) =>
    (rt) => WinService(NarrativeContext.of(rt.engine)).starEvidence(evidenceId);

EngineCommand<void> unstarEvidenceCmd(String evidenceId) => (rt) => rt.engine.setStarred(evidenceId, false);

EngineCommand<void> setHiddenCmd(String evidenceId, bool hidden) => (rt) => rt.engine.setHidden(evidenceId, hidden);

EngineCommand<void> setEvidenceProjectCmd(String evidenceId, String? projectId) =>
    (rt) => rt.engine.setEvidenceProject(evidenceId, projectId);

/// "Delete permanently" (#85): purges the evidence in one transaction, then its blobs.
EngineCommand<void> deleteEvidenceCmd(String evidenceId) => (rt) async {
      final paths = await EvidenceDeleter(NarrativeContext.of(rt.engine)).permanentDelete(evidenceId);
      for (final p in paths) {
        await rt.engine.ports.blobs.delete(p);
      }
    };

// ---------- Facts (#50) ----------

EngineCommand<void> confirmFactCmd(String factId) => (rt) => rt.engine.confirmFact(factId);

EngineCommand<void> editFactCmd(String factId, String statement) => (rt) => rt.engine.editFact(factId, statement);

EngineCommand<void> rejectFactCmd(String factId) => (rt) => rt.engine.rejectFact(factId);

EngineCommand<void> setWinStatusCmd(String factId, WinStatus status) => (rt) => rt.engine.setWinStatus(factId, status);

EngineCommand<void> resolveReviewCmd(String factId, {required bool accept}) =>
    (rt) => rt.engine.resolveReview(factId, accept: accept);

// ---------- Workstreams ----------

EngineCommand<void> renameWorkstreamCmd(String id, String title) => (rt) => rt.engine.renameWorkstream(id, title);

EngineCommand<void> mergeWorkstreamsCmd(String fromId, String intoId) =>
    (rt) => rt.engine.mergeWorkstreams(fromId, intoId);

EngineCommand<void> moveFactToWorkstreamCmd(String factId, String? workstreamId) =>
    (rt) => rt.engine.moveFactToWorkstream(factId, workstreamId);

// ---------- Projects ----------

EngineCommand<String> createProjectCmd(String name, {String? colour}) =>
    (rt) => rt.engine.createProject(name, colour: colour);

EngineCommand<void> updateProjectCmd(String id, {String? name, String? colour, bool? archived}) =>
    (rt) => rt.engine.updateProject(id, name: name, colour: colour, archived: archived);

// ---------- Reports (#49, #66) ----------

/// Finds or creates the report for a period + template. Returns its id.
EngineCommand<String> ensureReportCmd(PeriodKind kind, String start, String end, String templateId) =>
    (rt) async => (await rt.reports.ensureReport(kind, start, end, templateId)).id;

/// Generates a new snapshot (runs the Reports model to completion). Returns the snapshot id.
EngineCommand<String> generateReportCmd(String reportId, {String? styleInstruction}) => (rt) async {
      String? id;
      await for (final e in rt.reports.generate(reportId, styleInstruction: styleInstruction)) {
        if (e is ReportDone) id = e.snapshot?.id;
      }
      if (id == null) throw StateError('Report generation produced no snapshot');
      return id;
    };

EngineCommand<void> lockReportCmd(String reportId) => (rt) => rt.engine.lockReport(reportId);

EngineCommand<void> unlockReportCmd(String reportId) => (rt) => rt.engine.unlockReport(reportId);
