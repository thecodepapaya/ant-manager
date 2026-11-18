import '../../domain/enums.dart';
import '../source.dart';
import 'apple_calendar.dart';
import 'google_calendar.dart';
import 'ics.dart';
import 'jira.dart';
import 'linear.dart';

/// Registers the calendar and issue-tracker sources. Transcripts aren't synced (see transcript.dart).
void registerOtherSources(SourceRegistry r) {
  r.register(SourceKind.googleCalendar, GoogleCalendarSource.new);
  r.register(SourceKind.appleCalendar, AppleCalendarSource.new);
  r.register(SourceKind.ics, IcsSource.new);
  r.register(SourceKind.linear, LinearSource.new);
  r.register(SourceKind.jira, JiraSource.new);
}
