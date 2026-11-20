/// Enums shared across core. Stored in the DB by `name`.
library;

enum SourceKind {
  gitRepo,
  github,
  githubEnterprise,
  gitlab,
  googleCalendar,
  appleCalendar,
  ics,
  linear,
  jira,
  transcript,
  screenshotCapture,
  manualNote,
}

enum PayloadKind { commit, pullRequest, review, issue, calendarEvent, note, image, transcript }

enum ImportanceSetBy { model, user, rule }

enum RevisionCause { sync, user, merge, split }

enum FactType { outcome, problemSolved, invisibleWork, hiccup, decision, timeAllocation }

enum FactOrigin { inferred, confirmed, userEdited, userCreated }

extension FactOriginX on FactOrigin {
  /// User-touched facts are never overwritten by the model (#50, #62).
  bool get isUserTouched => this != FactOrigin.inferred;
}

enum ReviewState { ok, needsReview }

enum WinStatus { none, suggested, accepted, rejected }

enum PeriodKind { daily, weekly, monthly, quarterly, custom }

enum CurationAction { hide, setImportance }

enum JobState { queued, running, done, failed }

enum JobLane { io, llm }

/// Model routes (#75). Unset routes inherit [defaultRoute].
enum LlmRoute { defaultRoute, vision, extraction, reports }

enum ProviderKind { openrouter, openai, anthropic, gemini, custom }

enum ProviderProtocol { openai, ollama, native }

/// Entity types used by Dependency / RecomputeQueue (polymorphic refs).
enum EntityType { payload, evidence, enrichment, fact, day, workstream, report, reportSnapshot }
