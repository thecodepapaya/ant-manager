import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/profile_db.dart';
import '../../domain/enums.dart';

/// Shared JSON-schema fragments and helpers for the built-in tools.
/// Days are local dates (YYYY-MM-DD) in the profile time zone (#87).
const _dayPattern = r'^\d{4}-\d{2}-\d{2}$';

const periodProperties = <String, Object?>{
  'start': {'type': 'string', 'pattern': _dayPattern, 'description': 'First day (inclusive), YYYY-MM-DD.'},
  'end': {'type': 'string', 'pattern': _dayPattern, 'description': 'Last day (inclusive), YYYY-MM-DD.'},
  'project_id': {'type': 'string', 'description': 'Only this project.'},
};

String reqString(Map<String, Object?> input, String key) {
  final v = input[key];
  if (v is! String || v.isEmpty) throw ArgumentError('Missing "$key"');
  return v;
}

String? optString(Map<String, Object?> input, String key) {
  final v = input[key];
  return v is String && v.isNotEmpty ? v : null;
}

/// A real calendar day in YYYY-MM-DD form (the schema pattern, enforced).
String reqDay(Map<String, Object?> input, String key) => _day(key, reqString(input, key));

String? optDay(Map<String, Object?> input, String key) {
  final v = input[key];
  return v == null ? null : _day(key, v is String ? v : '');
}

String _day(String key, String v) {
  final d = RegExp(_dayPattern).hasMatch(v) ? DateTime.tryParse(v) : null;
  if (d == null || d.toIso8601String().substring(0, 10) != v) throw ArgumentError('"$key" must be a YYYY-MM-DD day');
  return v;
}

int optInt(Map<String, Object?> input, String key, int fallback) {
  final v = input[key];
  return v is num ? v.toInt() : fallback;
}

/// Facts overlapping [start]..[end], not retired. A rejected fact is a retired one (AntEngine.rejectFact).
Expression<bool> factInPeriod($FactsTable f, String start, String end, {String? projectId}) {
  Expression<bool> e =
      f.retired.equals(false) & f.periodStart.isSmallerOrEqualValue(end) & f.periodEnd.isBiggerOrEqualValue(start);
  if (projectId != null) e = e & f.projectId.equals(projectId);
  return e;
}

Map<String, Object?> factJson(Fact f) => {
  'fact_id': f.id,
  'type': f.type.name,
  'statement': f.statement,
  'details': jsonDecode(f.details),
  'period_start': f.periodStart,
  'period_end': f.periodEnd,
  'project_id': f.projectId,
  'workstream_id': f.workstreamId,
  'importance': f.importance,
  'origin': f.origin.name,
  'user_confirmed': f.origin.isUserTouched,
  'win_status': f.winStatus.name,
  'revision': f.revision,
};

/// Orders facts by importance (highest first), then by period start and id for determinism.
List<OrderingTerm Function($FactsTable)> get factOrder => [
  (f) => OrderingTerm.desc(f.importance),
  (f) => OrderingTerm.asc(f.periodStart),
  (f) => OrderingTerm.asc(f.id),
];
