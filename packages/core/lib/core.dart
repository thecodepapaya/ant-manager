/// Ant Manager engine (pure Dart). Public API per LLD 03 §3.2:
/// AntEngine (writes), drift data classes (reads), ports, tools, and extension interfaces.
library;

export 'src/ai/llm.dart';
export 'src/ai/consent.dart' show requiresConsent;
export 'src/ai/probe.dart' show probeModel;
export 'src/ai/register.dart' show createClient;
export 'src/ai/router.dart' show DbModelRouter;
export 'src/ai/structured.dart' show StructuredOutput;
export 'src/capture/source.dart';
export 'src/capture/sources/git_detect.dart' show GitDetector, ProcessGitExecutable;
export 'src/capture/sources/git_repo.dart' show scanForRepos, parseRemote, GitRemote;
export 'src/capture/sources/register.dart' show registerCodeSources;
export 'src/capture/sources/other_register.dart' show registerOtherSources;
export 'src/capture/sources/transcript.dart' show transcriptObservation;
export 'src/capture/sources/google_oauth.dart' show GoogleOAuth, GoogleTokens;
export 'src/backup/backup.dart' show BackupService, BackupManifest, BackupException;
export 'src/data/app_db.dart';
export 'src/data/profile_db.dart';
export 'src/domain/enums.dart';
export 'src/engine/engine.dart';
export 'src/jobs/job_queue.dart' show JobQueue, JobHandler;
export 'src/jobs/scheduler.dart' show Scheduler, ScheduleRule;
export 'src/narrative/context.dart' show NarrativeContext;
export 'src/narrative/delete.dart' show EvidenceDeleter;
export 'src/narrative/interfaces.dart';
export 'src/narrative/pipeline.dart' show registerNarrativePipeline, NarrativePipeline;
export 'src/narrative/wins.dart' show WinService;
export 'src/ports/ports.dart';
export 'src/reports/generator.dart';
export 'src/reports/periods.dart' show Period, parseDay, formatDay;
export 'src/reports/scheduled.dart';
export 'src/reports/templates.dart' show TemplateService, BuiltinTemplate, defaultTemplateFor;
export 'src/staleness/staleness.dart' show EntityRef, InputRef, StalenessService;
export 'src/tools/builtin/register.dart' show registerBuiltinTools;
export 'src/tools/tool.dart';
export 'src/util/ids.dart' show newId, dayOf;
