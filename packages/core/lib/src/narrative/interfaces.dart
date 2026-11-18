import '../data/profile_db.dart';
import '../domain/enums.dart';

/// Per-payload-kind enrichment (LLD 04 §4.5, #91: every kind). Registered by kind.
abstract interface class EnrichmentStrategy {
  PayloadKind get kind;
  LlmRoute get route; // vision for images, extraction otherwise
  /// Returns the enrichment text for a batch of payloads of this kind (keyed by payload id).
  Future<Map<String, String>> enrich(List<Payload> payloads);
}

class EnrichmentRegistry {
  final _byKind = <PayloadKind, EnrichmentStrategy>{};
  void register(EnrichmentStrategy s) => _byKind[s.kind] = s;
  EnrichmentStrategy? operator [](PayloadKind k) => _byKind[k];
}

/// One proposed change from fact extraction (LLD 04 §4.6).
sealed class FactOp {}

class CreateFact extends FactOp {
  CreateFact({
    required this.type,
    required this.statement,
    required this.citations,
    this.details = const {},
    this.projectId,
    this.importance = 0.5,
    this.suggestWin = false,
  });
  final FactType type;
  final String statement;
  final List<String> citations; // payload ids
  final Map<String, Object?> details;
  final String? projectId;
  final double importance;
  final bool suggestWin;
}

class UpdateFact extends FactOp {
  UpdateFact({required this.factId, required this.statement, required this.citations, this.details});
  final String factId;
  final String statement;
  final List<String> citations;
  final Map<String, Object?>? details;
}

class RetireFact extends FactOp {
  RetireFact({required this.factId, required this.reason});
  final String factId;
  final String reason;
}

class FactChangeSet {
  FactChangeSet(this.day, this.ops);
  final String day;
  final List<FactOp> ops;
}

abstract interface class FactExtractor {
  Future<FactChangeSet> extract(String day);
}
