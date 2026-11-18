/// Ant Manager engine (pure Dart). Public API per LLD 03 §3.2:
/// AntEngine (writes), drift data classes (reads), ports, tools, and extension interfaces.
library;

export 'src/ai/llm.dart';
export 'src/ai/structured.dart' show StructuredOutput;
export 'src/capture/source.dart';
export 'src/data/app_db.dart';
export 'src/data/profile_db.dart';
export 'src/domain/enums.dart';
export 'src/engine/engine.dart';
export 'src/jobs/job_queue.dart' show JobQueue, JobHandler;
export 'src/narrative/interfaces.dart';
export 'src/ports/ports.dart';
export 'src/staleness/staleness.dart' show EntityRef, InputRef, StalenessService;
export 'src/tools/tool.dart';
export 'src/util/ids.dart' show newId, dayOf;
