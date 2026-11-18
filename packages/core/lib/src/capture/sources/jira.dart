/// Jira Cloud only (#81). Config: `{siteUrl, email}`; secret: API token (basic auth).
/// Issues assigned to / reported by / watched by you (commenting auto-watches), updated since the cursor, with your
/// status transitions (changelog) and comments. One `issue` payload per issue.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../source.dart';
import 'calendar_common.dart' show isoUtc;

class JiraSource implements Source {
  static const _scope = 'issues';

  @override
  SourceKind get kind => SourceKind.jira;

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    try {
      final me = await _req(ctx, 'GET', 'rest/api/3/myself');
      return me['accountId'] == null ? const SourceHealth.error('Jira: not signed in') : const SourceHealth.ok();
    } on DioException catch (e) {
      return SourceHealth.error('Jira: ${e.response?.statusCode ?? e.message}');
    } on StateError catch (e) {
      return SourceHealth.error(e.message);
    }
  }

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final me = (await _req(ctx, 'GET', 'rest/api/3/myself'))['accountId'] as String;
    final since = DateTime.tryParse(await ctx.cursor(_scope) ?? '') ?? ctx.initialImportFrom;
    // JQL dates are in the user's Jira time zone; a day of overlap is free (unchanged content is a no-op).
    final d = since.subtract(const Duration(days: 1));
    final day = '${d.year}-${_two(d.month)}-${_two(d.day)}';
    final jql =
        '(assignee = currentUser() OR reporter = currentUser() OR watcher = currentUser() '
        'OR status changed BY currentUser()) AND updated >= "$day" ORDER BY updated ASC';
    var maxUpdated = since;
    String? next;
    do {
      final page = await _req(ctx, 'POST', 'rest/api/3/search/jql', {
        'jql': jql,
        'maxResults': 50,
        'fields': [
          'summary',
          'status',
          'issuetype',
          'project',
          'created',
          'updated',
          'reporter',
          'assignee',
          'comment',
        ],
        'expand': 'changelog',
        'nextPageToken': ?next,
      });
      for (final issue in (page['issues'] as List? ?? const []).cast<Map<String, Object?>>()) {
        final fields = issue['fields'] as Map<String, Object?>;
        final updated = _date(fields['updated']);
        if (updated != null && updated.isAfter(maxUpdated)) maxUpdated = updated;
        final o = _observation(ctx, me, issue);
        if (o != null) yield o;
      }
      next = page['nextPageToken'] as String?;
    } while (next != null);
    ctx.setCursor(_scope, isoUtc(maxUpdated));
  }

  PayloadObservation? _observation(SourceContext ctx, String me, Map<String, Object?> issue) {
    final f = issue['fields'] as Map<String, Object?>;
    bool mine(Object? user) => user is Map && user['accountId'] == me;
    final reporter = mine(f['reporter']);
    final assignee = mine(f['assignee']);
    final transitions = <Map<String, Object?>>[];
    for (final h in ((issue['changelog'] as Map?)?['histories'] as List? ?? const []).cast<Map<String, Object?>>()) {
      if (!mine(h['author'])) continue;
      for (final item in (h['items'] as List? ?? const []).cast<Map<String, Object?>>()) {
        if (item['field'] != 'status') continue;
        transitions.add({'from': item['fromString'], 'to': item['toString'], 'at': h['created']});
      }
    }
    final comments = [
      for (final c in ((f['comment'] as Map?)?['comments'] as List? ?? const []).cast<Map<String, Object?>>())
        if (mine(c['author'])) {'id': c['id'], 'body': adfText(c['body']).trim(), 'at': c['created']},
    ];
    final times = [
      if (reporter) ?_date(f['created']),
      for (final t in transitions) ?_date(t['at']),
      for (final c in comments) ?_date(c['at']),
    ]..sort();
    if (times.isEmpty && !assignee) return null; // only watching
    final key = issue['key'] as String;
    final summary = f['summary'] as String? ?? '';
    final site = (ctx.config['siteUrl'] as String).replaceAll(RegExp(r'/+$'), '');
    return PayloadObservation(
      externalId: issue['id'] as String,
      kind: PayloadKind.issue,
      title: '$key $summary',
      occurredStart: times.isEmpty ? _date(f['updated']) ?? ctx.clock.now() : times.first,
      occurredEnd: times.length > 1 ? times.last : null,
      content: {
        'tracker': 'jira',
        'key': key,
        'title': summary,
        'url': '$site/browse/$key',
        'project': (f['project'] as Map?)?['key'],
        'type': (f['issuetype'] as Map?)?['name'],
        'state': (f['status'] as Map?)?['name'],
        'createdAt': f['created'],
        'createdByMe': reporter,
        'assignedToMe': assignee,
        'myTransitions': transitions,
        'myComments': comments,
      },
    );
  }

  Future<Map<String, Object?>> _req(SourceContext ctx, String method, String path, [Object? body]) async {
    final site = ctx.config['siteUrl'] as String?;
    final email = ctx.config['email'] as String?;
    final token = await ctx.secret();
    if (site == null || email == null || token == null) throw StateError('Jira site, email or API token missing');
    final base = Uri.parse(site.endsWith('/') ? site : '$site/');
    final r = await ctx.http.requestUri<Map<String, Object?>>(
      base.resolve(path),
      data: body,
      options: Options(
        method: method,
        headers: {'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$token'))}', 'Accept': 'application/json'},
        contentType: body == null ? null : Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    return r.data ?? const {};
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Jira timestamps look like 2026-11-17T10:00:00.000+0000 (no colon in the offset).
  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final fixed = v.replaceFirstMapped(RegExp(r'([+-]\d{2})(\d{2})$'), (m) => '${m[1]}:${m[2]}');
    return DateTime.tryParse(fixed)?.toUtc();
  }
}

/// Plain text of an Atlassian Document Format node (v3 comment bodies). Strings pass through.
String adfText(Object? node) {
  if (node is String) return node;
  if (node is! Map) return '';
  if (node['type'] == 'text') return node['text'] as String? ?? '';
  if (node['type'] == 'hardBreak') return '\n';
  final inner = (node['content'] as List? ?? const []).map(adfText).join();
  return const {'paragraph', 'heading', 'listItem', 'codeBlock', 'blockquote'}.contains(node['type'])
      ? '$inner\n'
      : inner;
}
