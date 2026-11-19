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
  void register(HarnessTool tool) => _tools[tool.name] = _StrictInput(tool);
  HarnessTool operator [](String name) => _tools[name] ?? (throw StateError('Unknown tool $name'));
  Iterable<HarnessTool> get all => _tools.values;
}

/// Enforces `additionalProperties: false`: an unknown input key (an agent typo) is a tool error.
class _StrictInput implements HarnessTool {
  _StrictInput(this._tool);
  final HarnessTool _tool;
  @override
  String get name => _tool.name;
  @override
  String get description => _tool.description;
  @override
  Map<String, Object?> get inputSchema => _tool.inputSchema;

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx) {
    if (inputSchema['additionalProperties'] == false) {
      final known = (inputSchema['properties'] as Map? ?? const {}).keys.toSet();
      final unknown = input.keys.where((k) => !known.contains(k)).toList();
      if (unknown.isNotEmpty) return Future.error(ArgumentError('Unknown input keys: ${unknown.join(', ')}'));
    }
    return _tool.call(input, ctx);
  }
}
