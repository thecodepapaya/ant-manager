import '../data/profile_db.dart';

/// Context passed to every tool call.
class ToolContext {
  const ToolContext({required this.db, required this.profileId});
  final ProfileDb db;
  final String profileId;
}

/// Typed query over Evidence and the Narrative (#53). Reports and Wins use these now;
/// chat and an MCP server will wrap the same tools later.
/// Inputs and outputs are JSON maps described by JSON schemas, so they are agent-callable as-is.
abstract interface class HarnessTool {
  String get name;
  String get description;
  Map<String, Object?> get inputSchema;
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx);
}

class ToolRegistry {
  final _tools = <String, HarnessTool>{};
  void register(HarnessTool tool) => _tools[tool.name] = tool;
  HarnessTool operator [](String name) => _tools[name] ?? (throw StateError('Unknown tool $name'));
  Iterable<HarnessTool> get all => _tools.values;
}
