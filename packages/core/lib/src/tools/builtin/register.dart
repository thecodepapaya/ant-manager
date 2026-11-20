import '../tool.dart';
import 'get_evidence.dart';
import 'get_facts.dart';
import 'list_wins.dart';
import 'search_evidence.dart';
import 'time_breakdown.dart';
import 'workstream_timeline.dart';

/// Registers the built-in harness tools (#53).
void registerBuiltinTools(ToolRegistry r) {
  r
    ..register(SearchEvidenceTool())
    ..register(GetEvidenceTool())
    ..register(GetFactsTool())
    ..register(TimeBreakdownTool())
    ..register(WorkstreamTimelineTool())
    ..register(ListWinsTool());
}
