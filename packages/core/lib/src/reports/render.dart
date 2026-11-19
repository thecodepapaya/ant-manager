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
/// Whitespace in text and headings collapses to single spaces, so text can't forge bullets or headings.
Map<String, Object?> validateReport(Map<String, Object?> raw, Set<String> validIds) {
  final sections = <Map<String, Object?>>[];
  for (final s in _list(raw['sections'])) {
    if (s is! Map) continue;
    final heading = _oneLine(_string(s['heading']));
    final items = <Map<String, Object?>>[];
    for (final i in _list(s['items'])) {
      if (i is! Map) continue;
      final text = _oneLine(_string(i['text']));
      final ids = <String>[
        ...{
          for (final id in _list(i['fact_ids']))
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
    final heading = _oneLine(s['heading'] as String);
    if (heading.isNotEmpty) b.write('\n## $heading\n');
    b.write('\n');
    for (final i in (s['items'] as List).cast<Map<String, Object?>>()) {
      final markers = [
        for (final id in (i['fact_ids'] as List).cast<String>())
          '[^f${numbers.putIfAbsent(id, () => numbers.length + 1)}]',
      ];
      b.write('- ${_oneLine(i['text'] as String)} ${markers.join()}\n');
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
List<Object?> _list(Object? v) => v is List ? v : const [];
String _string(Object? v) => v is String ? v : '';

/// Ids cited by a validated report, in first-appearance order.
List<String> citedFactIds(Map<String, Object?> report) => [
  ...{
    for (final s in (report['sections'] as List).cast<Map<String, Object?>>())
      for (final i in (s['items'] as List).cast<Map<String, Object?>>()) ...(i['fact_ids'] as List).cast<String>(),
  },
];
