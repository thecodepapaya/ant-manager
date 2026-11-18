import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../tool.dart';
import 'common.dart';

/// Wins view (#63, LLD 04 §4.10): Outcome facts with win_status = accepted.
class ListWinsTool implements HarnessTool {
  @override
  String get name => 'list_wins';

  @override
  String get description =>
      'Accepted wins (Outcome facts marked as wins) overlapping start..end, most important first. '
      'Optionally filtered by project.';

  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': periodProperties,
    'required': ['start', 'end'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx) async {
    final db = ctx.db;
    final rows =
        await (db.select(db.facts)
              ..where(
                (f) =>
                    factInPeriod(
                      f,
                      reqString(input, 'start'),
                      reqString(input, 'end'),
                      projectId: optString(input, 'project_id'),
                    ) &
                    f.type.equalsValue(FactType.outcome) &
                    f.winStatus.equalsValue(WinStatus.accepted),
              )
              ..orderBy(factOrder))
            .get();
    return {
      'wins': [for (final f in rows) factJson(f)],
    };
  }
}
