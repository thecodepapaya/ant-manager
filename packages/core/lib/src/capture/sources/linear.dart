/// Linear (cloud, API key from the secret store): issues you created, completed (assigned to you) or commented
/// on, updated since the cursor. One `issue` payload per issue.
library;

import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../source.dart';
import 'calendar_common.dart' show isoUtc;

class LinearSource implements Source {
  LinearSource({Uri? endpoint}) : endpoint = endpoint ?? Uri.parse('https://api.linear.app/graphql');
  final Uri endpoint;
  static const _scope = 'issues';

  @override
  SourceKind get kind => SourceKind.linear;

  @override
  Future<SourceHealth> validate(SourceContext ctx) async {
    try {
      final d = await _query(ctx, 'query { viewer { id } }', const {});
      return d['viewer'] == null ? const SourceHealth.error('Linear: invalid API key') : const SourceHealth.ok();
    } on DioException catch (e) {
      return SourceHealth.error('Linear: ${e.response?.statusCode ?? e.message}');
    } on StateError catch (e) {
      return SourceHealth.error(e.message);
    }
  }

  static const _issuesQuery = r'''
query Mine($since: DateTimeOrDuration!, $after: String) {
  issues(
    first: 50
    after: $after
    orderBy: updatedAt
    filter: {
      updatedAt: { gt: $since }
      or: [
        { creator: { isMe: { eq: true } } }
        { assignee: { isMe: { eq: true } } }
        { comments: { some: { user: { isMe: { eq: true } } } } }
      ]
    }
  ) {
    pageInfo { hasNextPage endCursor }
    nodes {
      id identifier title description url createdAt updatedAt completedAt
      state { name type }
      team { key }
      project { name }
      creator { isMe }
      assignee { isMe }
      comments(filter: { user: { isMe: { eq: true } } }) { nodes { id body createdAt } }
    }
  }
}''';

  @override
  Stream<PayloadObservation> sync(SourceContext ctx) async* {
    final since = DateTime.tryParse(await ctx.cursor(_scope) ?? '') ?? ctx.initialImportFrom;
    var maxUpdated = since;
    String? after;
    do {
      final d = await _query(ctx, _issuesQuery, {'since': isoUtc(since), 'after': after});
      final issues = d['issues'] as Map<String, Object?>;
      for (final n in (issues['nodes'] as List).cast<Map<String, Object?>>()) {
        final updated = DateTime.parse(n['updatedAt'] as String).toUtc();
        if (updated.isAfter(maxUpdated)) maxUpdated = updated;
        final o = _observation(n);
        if (o != null) yield o;
      }
      final page = issues['pageInfo'] as Map<String, Object?>;
      after = page['hasNextPage'] == true ? page['endCursor'] as String? : null;
    } while (after != null);
    ctx.setCursor(_scope, isoUtc(maxUpdated));
  }

  PayloadObservation? _observation(Map<String, Object?> n) {
    bool isMe(String k) => (n[k] as Map?)?['isMe'] == true;
    final created = isMe('creator');
    final assigned = isMe('assignee');
    final comments = ((n['comments'] as Map?)?['nodes'] as List? ?? const []).cast<Map<String, Object?>>();
    final completedAt = n['completedAt'] as String?;
    final completedByMe = assigned && completedAt != null;
    // My activity times: creation, completion, my comments.
    final times = [
      if (created) DateTime.parse(n['createdAt'] as String),
      if (completedByMe) DateTime.parse(completedAt),
      for (final c in comments) DateTime.parse(c['createdAt'] as String),
    ].map((t) => t.toUtc()).toList()..sort();
    if (times.isEmpty && !assigned) return null; // matched the filter but nothing of mine
    final start = times.isEmpty ? DateTime.parse(n['updatedAt'] as String).toUtc() : times.first;
    final title = '${n['identifier']} ${n['title']}';
    return PayloadObservation(
      externalId: n['id'] as String,
      kind: PayloadKind.issue,
      title: title,
      occurredStart: start,
      occurredEnd: times.length > 1 ? times.last : null,
      content: {
        'tracker': 'linear',
        'key': n['identifier'],
        'title': n['title'],
        'description': ?n['description'],
        'url': n['url'],
        'team': (n['team'] as Map?)?['key'],
        'project': ?(n['project'] as Map?)?['name'],
        'state': (n['state'] as Map?)?['name'],
        'stateType': (n['state'] as Map?)?['type'],
        'createdAt': n['createdAt'],
        'completedAt': ?completedAt,
        'createdByMe': created,
        'assignedToMe': assigned,
        'completedByMe': completedByMe,
        'myComments': [
          for (final c in comments) {'id': c['id'], 'body': c['body'], 'at': c['createdAt']},
        ],
      },
    );
  }

  Future<Map<String, Object?>> _query(SourceContext ctx, String query, Map<String, Object?> vars) async {
    final key = await ctx.secret();
    if (key == null || key.isEmpty) throw StateError('Linear API key missing');
    final r = await ctx.http.postUri<Map<String, Object?>>(
      endpoint,
      data: {'query': query, 'variables': vars},
      options: Options(
        headers: {'Authorization': key}, // personal API keys are sent without "Bearer"
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    final body = r.data ?? const {};
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) throw StateError('Linear: ${(errors.first as Map)['message']}');
    return (body['data'] as Map<String, Object?>?) ?? const {};
  }
}
