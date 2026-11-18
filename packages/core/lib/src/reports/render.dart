/// Pure validation + deterministic Markdown rendering of structured reports (#92, LLD 04 §4.9 steps 4–5).
library;

/// JSON schema the Reports model must fill.
const reportSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'sections': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'heading': {'type': 'string'},
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'text': {'type': 'string'},
                'fact_ids': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
              'required': ['text', 'fact_ids'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['heading', 'items'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['sections'],
  'additionalProperties': false,
};

/// Keeps only fact ids in [validIds] (de-duplicated, in order); drops items left with none and
/// sections left empty (no uncited claims, N9). Unexpected shapes are skipped, not repaired.
Map<String, Object?> validateReport(Map<String, Object?> raw, Set<String> validIds) {
  final sections = <Map<String, Object?>>[];
  for (final s in (raw['sections'] as List?) ?? const []) {
    if (s is! Map) continue;
    final heading = (s['heading'] as String?)?.trim() ?? '';
    final items = <Map<String, Object?>>[];
    for (final i in (s['items'] as List?) ?? const []) {
      if (i is! Map) continue;
      final text = (i['text'] as String?)?.trim() ?? '';
      final ids = <String>[
        ...{
          for (final id in (i['fact_ids'] as List?) ?? const [])
            if (id is String && validIds.contains(id)) id,
        },
      ];
      if (text.isEmpty || ids.isEmpty) continue;
      items.add({'text': text, 'fact_ids': ids});
    }
    if (items.isNotEmpty) sections.add({'heading': heading, 'items': items});
  }
  return {'sections': sections};
}

/// Renders validated report JSON to Markdown. Citation markers `[^fN]` are numbered by first
/// appearance; the footnote list names each fact's statement and id (`fact:<id>`) so the UI can link it.
String renderReportMarkdown({
  required String title,
  required Map<String, Object?> report,
  required Map<String, String> factStatements,
}) {
  final b = StringBuffer('# $title\n');
  final numbers = <String, int>{};
  final sections = report['sections'] as List;
  if (sections.isEmpty) b.write('\n_Nothing recorded for this period._\n');
  for (final s in sections.cast<Map<String, Object?>>()) {
    final heading = s['heading'] as String;
    if (heading.isNotEmpty) b.write('\n## $heading\n');
    b.write('\n');
    for (final i in (s['items'] as List).cast<Map<String, Object?>>()) {
      final markers = [
        for (final id in (i['fact_ids'] as List).cast<String>())
          '[^f${numbers.putIfAbsent(id, () => numbers.length + 1)}]',
      ];
      b.write('- ${i['text']} ${markers.join()}\n');
    }
  }
  if (numbers.isNotEmpty) {
    b.write('\n');
    for (final MapEntry(key: id, value: n) in numbers.entries) {
      b.write('[^f$n]: ${_oneLine(factStatements[id] ?? '')} (fact:$id)\n');
    }
  }
  return b.toString();
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Ids cited by a validated report, in first-appearance order.
List<String> citedFactIds(Map<String, Object?> report) => [
  ...{
    for (final s in (report['sections'] as List).cast<Map<String, Object?>>())
      for (final i in (s['items'] as List).cast<Map<String, Object?>>()) ...(i['fact_ids'] as List).cast<String>(),
  },
];
