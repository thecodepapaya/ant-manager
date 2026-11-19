import 'package:ant_manager/features/reports/share.dart';
import 'package:flutter_test/flutter_test.dart';

/// A snapshot as core renders it (`renderReportMarkdown`): footnote markers `[^fN]` and
/// definitions ending in `(fact:<id>)`.
const _md = '''
# Weekly review — Week of 2 Mar

## Shipped

- Fixed <script> & "quotes" in R&D > prod [^f1][^f2]
- Cleaned up docs [^f2]

## Next

- Plan Q2

[^f1]: Escaped <b>tags</b> & things (fact:01ABCDEF)
[^f2]: Wrote the docs (fact:01GHIJKL)
''';

void main() {
  final r = ParsedReport.parse(_md);

  test('parse: title, sections, items with footnote numbers, footnotes with fact ids', () {
    expect(r.title, 'Weekly review — Week of 2 Mar');
    expect(r.sections.map((s) => s.heading), ['Shipped', 'Next']);
    expect(r.sections.first.items.first.text, 'Fixed <script> & "quotes" in R&D > prod');
    expect(r.sections.first.items.first.notes, [1, 2]);
    expect(r.sections.last.items.single.notes, isEmpty);
    expect(r.footnotes[1]!.factId, '01ABCDEF');
    expect(r.footnotes[2]!.statement, 'Wrote the docs');
    expect(r.emptyNote, isNull);
  });

  test('Markdown drops the (fact:id) references but keeps statements and markers', () {
    final md = r.toMarkdown();
    expect(md, isNot(contains('fact:')));
    expect(md, isNot(contains('01ABCDEF')));
    expect(md, contains('[^1]: Escaped <b>tags</b> & things'));
    expect(md, contains('- Fixed <script> & "quotes" in R&D > prod [^1][^2]'));
    expect(md, contains('## Next'));
  });

  test('Slack escapes &, < and > everywhere', () {
    final s = r.toSlack();
    expect(s, startsWith('*Weekly review — Week of 2 Mar*'));
    expect(s, contains('• Fixed &lt;script&gt; &amp; "quotes" in R&amp;D &gt; prod [1][2]'));
    expect(s, contains('[1] Escaped &lt;b&gt;tags&lt;/b&gt; &amp; things'));
    expect(s, isNot(contains('<')));
    expect(s, isNot(contains('fact:')));
    // Only escape sequences use '&'.
    expect(s.replaceAll(RegExp('&(amp|lt|gt);'), ''), isNot(contains('&')));
  });

  test('HTML escapes text and quotes', () {
    final html = r.toHtml();
    expect(html, startsWith('<h1>Weekly review — Week of 2 Mar</h1>'));
    expect(html, contains('<li>Fixed &lt;script&gt; &amp; &quot;quotes&quot; in R&amp;D &gt; prod<sup>[1]</sup><sup>[2]</sup></li>'));
    expect(html, contains('<li value="1">Escaped &lt;b&gt;tags&lt;/b&gt; &amp; things</li>'));
    expect(html, isNot(contains('<script>')));
    expect(html, isNot(contains('<b>')));
    expect(html, isNot(contains('fact:')));
  });

  test('empty report keeps its "nothing recorded" note in every format', () {
    final e = ParsedReport.parse('# Daily — 3 Mar\n\n_Nothing recorded for this period._\n');
    expect(e.emptyNote, 'Nothing recorded for this period.');
    expect(e.sections, isEmpty);
    expect(e.toMarkdown(), contains('_Nothing recorded for this period._'));
    expect(e.toSlack(), contains('_Nothing recorded for this period._'));
    expect(e.toHtml(), contains('<em>Nothing recorded for this period.</em>'));
  });

  testWidgets('the PDF builds (Inter font, non-Latin-1 text)', (tester) async {
    final bytes = await tester.runAsync(() => buildPdf(ParsedReport.parse('$_md\n- Ünïcødé — “quotes” → ✓\n')));
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
