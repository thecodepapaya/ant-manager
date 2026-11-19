/// Report sharing (SPEC §7 Share): parse the rendered Markdown (#92) and convert it to Slack mrkdwn,
/// HTML (rich text) and PDF. Pure functions except [exportPdf].
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportItemLine {
  ReportItemLine(this.text, this.notes);
  final String text;

  /// Footnote numbers cited by this line.
  final List<int> notes;
}

class ReportSectionBlock {
  ReportSectionBlock(this.heading);
  final String heading;
  final items = <ReportItemLine>[];
}

class Footnote {
  Footnote(this.n, this.statement, this.factId);
  final int n;
  final String statement;
  final String factId;
}

/// A report snapshot's Markdown, parsed back into title / sections / items / footnotes.
class ParsedReport {
  ParsedReport(this.title, this.sections, this.footnotes, this.emptyNote);
  final String title;
  final List<ReportSectionBlock> sections;
  final Map<int, Footnote> footnotes;

  /// "_Nothing recorded for this period._" when there are no sections.
  final String? emptyNote;

  static final _marker = RegExp(r'\[\^f(\d+)\]');
  static final _footnote = RegExp(r'^\[\^f(\d+)\]: (.*) \(fact:([^)]+)\)$');

  factory ParsedReport.parse(String md) {
    var title = '';
    String? empty;
    final sections = <ReportSectionBlock>[];
    final notes = <int, Footnote>{};
    for (final raw in const LineSplitter().convert(md)) {
      final line = raw.trimRight();
      if (line.startsWith('# ')) {
        title = line.substring(2).trim();
      } else if (line.startsWith('## ')) {
        sections.add(ReportSectionBlock(line.substring(3).trim()));
      } else if (line.startsWith('- ')) {
        if (sections.isEmpty) sections.add(ReportSectionBlock(''));
        final body = line.substring(2);
        final nums = [for (final m in _marker.allMatches(body)) int.parse(m.group(1)!)];
        sections.last.items.add(ReportItemLine(body.replaceAll(_marker, '').trim(), nums));
      } else if (_footnote.hasMatch(line)) {
        final m = _footnote.firstMatch(line)!;
        final n = int.parse(m.group(1)!);
        notes[n] = Footnote(n, m.group(2)!, m.group(3)!);
      } else if (line.startsWith('_') && line.endsWith('_') && line.length > 2) {
        empty = line.substring(1, line.length - 1);
      }
    }
    return ParsedReport(title, sections, notes, empty);
  }

  /// Plain Markdown without fact ids (footnotes keep their statements).
  String toMarkdown() {
    final b = StringBuffer('# $title\n');
    if (emptyNote != null) b.write('\n_${emptyNote}_\n');
    for (final s in sections) {
      if (s.heading.isNotEmpty) b.write('\n## ${s.heading}\n');
      b.write('\n');
      for (final i in s.items) {
        b.write('- ${i.text} ${i.notes.map((n) => '[^$n]').join()}'.trimRight());
        b.write('\n');
      }
    }
    if (footnotes.isNotEmpty) {
      b.write('\n');
      for (final f in footnotes.values) {
        b.write('[^${f.n}]: ${f.statement}\n');
      }
    }
    return b.toString();
  }

  /// Slack mrkdwn: bold headings, bullets with [n] markers, sources at the end.
  String toSlack() {
    String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    final b = StringBuffer('*${esc(title)}*\n');
    if (emptyNote != null) b.write('_${esc(emptyNote!)}_\n');
    for (final s in sections) {
      if (s.heading.isNotEmpty) b.write('\n*${esc(s.heading)}*\n');
      for (final i in s.items) {
        b.write('• ${esc(i.text)}${i.notes.isEmpty ? '' : ' ${i.notes.map((n) => '[$n]').join()}'}\n');
      }
    }
    if (footnotes.isNotEmpty) {
      b.write('\n_Sources_\n');
      for (final f in footnotes.values) {
        b.write('[${f.n}] ${esc(f.statement)}\n');
      }
    }
    return b.toString();
  }

  /// HTML for rich-text paste into email or docs.
  String toHtml() {
    String esc(String s) =>
        s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
    final b = StringBuffer('<h1>${esc(title)}</h1>');
    if (emptyNote != null) b.write('<p><em>${esc(emptyNote!)}</em></p>');
    for (final s in sections) {
      if (s.heading.isNotEmpty) b.write('<h2>${esc(s.heading)}</h2>');
      b.write('<ul>');
      for (final i in s.items) {
        b.write('<li>${esc(i.text)}${i.notes.map((n) => '<sup>[$n]</sup>').join()}</li>');
      }
      b.write('</ul>');
    }
    if (footnotes.isNotEmpty) {
      b.write('<hr><ol>');
      for (final f in footnotes.values) {
        b.write('<li value="${f.n}">${esc(f.statement)}</li>');
      }
      b.write('</ol>');
    }
    return b.toString();
  }
}

/// PDF page scale (points). The PDF is a document format, not app UI, so it has its own sizes.
abstract final class _Pdf {
  static const margin = 48.0;
  static const title = 18.0;
  static const heading = 13.0;
  static const body = 11.0;
  static const note = 9.0;
  static const gapLg = 16.0;
  static const gap = 12.0;
  static const gapSm = 4.0;
  static const leading = 2.0;
  static const rule = 0.5;
}

/// Builds a PDF of [r] (Inter from the ui package, so non-Latin-1 text renders).
Future<List<int>> buildPdf(ParsedReport r) async {
  Future<pw.Font> font(String file) async =>
      pw.Font.ttf(await rootBundle.load('packages/ui/assets/fonts/inter/$file'));
  final regular = await font('Inter-Regular.ttf');
  final bold = await font('Inter-SemiBold.ttf');
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  final grey = PdfColor.fromHex('#6B665E');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(_Pdf.margin),
      build: (_) => [
        pw.Text(r.title, style: pw.TextStyle(font: bold, fontSize: _Pdf.title)),
        pw.SizedBox(height: _Pdf.gap),
        if (r.emptyNote != null) pw.Text(r.emptyNote!, style: pw.TextStyle(color: grey)),
        for (final s in r.sections) ...[
          if (s.heading.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: _Pdf.gap, bottom: _Pdf.gapSm),
              child: pw.Text(s.heading, style: pw.TextStyle(font: bold, fontSize: _Pdf.heading)),
            ),
          for (final i in s.items)
            pw.Bullet(
              text: '${i.text}${i.notes.isEmpty ? '' : ' ${i.notes.map((n) => '[$n]').join()}'}',
              style: const pw.TextStyle(fontSize: _Pdf.body, lineSpacing: _Pdf.leading),
            ),
        ],
        if (r.footnotes.isNotEmpty) ...[
          pw.SizedBox(height: _Pdf.gapLg),
          pw.Divider(color: grey, thickness: _Pdf.rule),
          for (final f in r.footnotes.values)
            pw.Text('[${f.n}] ${f.statement}', style: pw.TextStyle(fontSize: _Pdf.note, color: grey)),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Asks where to save, then writes the PDF. Returns the path, or null when cancelled.
Future<String?> exportPdf(ParsedReport r, String suggestedName) async {
  final loc = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
  );
  if (loc == null) return null;
  final path = loc.path.endsWith('.pdf') ? loc.path : '${loc.path}.pdf';
  await File(path).writeAsBytes(await buildPdf(r));
  return path;
}
