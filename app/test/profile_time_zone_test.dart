// Independent tests (#99) for #109 UI day/time labels in the active profile's zone
// (app/lib/platform/time_zone.dart `profileUtcOffset`), and the note composer's past-day time.
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/engine_runtime.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/platform/time_zone.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:ant_manager/widgets/common.dart';
import 'package:ant_manager/widgets/note_composer.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  late UtcOffset saved;
  setUp(() => saved = profileUtcOffset);
  tearDown(() => profileUtcOffset = saved);

  group('labels follow profileUtcOffset', () {
    test('hhmm shows the profile wall clock, not the system one', () {
      profileUtcOffset = zoneOffset('Asia/Kolkata');
      expect(hhmm(DateTime.utc(2026, 11, 16, 18, 30)), '00:00');
      expect(hhmm(DateTime.utc(2026, 11, 16, 18, 30).toLocal()), '00:00', reason: 'same instant, local DateTime');
      profileUtcOffset = zoneOffset('Europe/London');
      expect(hhmm(DateTime.utc(2026, 7, 1, 12, 5)), '13:05');
      expect(hhmm(DateTime.utc(2026, 1, 1, 12, 5)), '12:05');
      profileUtcOffset = zoneOffset('America/New_York');
      expect(hhmm(DateTime.utc(2026, 11, 17, 3, 7)), '22:07');
    });

    test('todayDay / profileToday use the profile zone', () {
      profileUtcOffset = zoneOffset('Pacific/Kiritimati'); // +14
      final ahead = todayDay();
      expect(ahead, todayIn(zoneOffset('Pacific/Kiritimati')));
      expect(profileToday(), ahead);
      profileUtcOffset = zoneOffset('Pacific/Pago_Pago'); // -11: always a different day
      final behind = todayDay();
      expect(behind, todayIn(zoneOffset('Pacific/Pago_Pago')));
      expect(behind, isNot(ahead));
    });

    test('profileDayOf uses the profile zone', () {
      profileUtcOffset = zoneOffset('Asia/Kolkata');
      expect(profileDayOf(DateTime.utc(2026, 11, 16, 18, 29)), '2026-11-16');
      expect(profileDayOf(DateTime.utc(2026, 11, 16, 18, 30)), '2026-11-17');
    });

    test('shortDayLabel drops the year only for the profile-zone current year', () {
      profileUtcOffset = (_) => Duration.zero;
      final thisYear = parseDay(todayIn((_) => Duration.zero)).year;
      expect(shortDayLabel('$thisYear-11-19'), 'Nov 19');
      expect(shortDayLabel('${thisYear - 1}-03-02'), 'Mar 2, ${thisYear - 1}');
      // A profile "today" in mid-next-year: this UTC year is no longer the current one.
      final now = DateTime.now().toUtc();
      final ahead = DateTime.utc(now.year + 1, 7, 1).difference(now);
      profileUtcOffset = (_) => ahead;
      expect(shortDayLabel('$thisYear-11-19'), 'Nov 19, $thisYear');
      expect(shortDayLabel('${thisYear + 1}-11-19'), 'Nov 19');
    });
  });

  group('note composer', () {
    Future<DateTime> savedAt(WidgetTester tester, String day) async {
      final engine = _RecordingEngine();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          engineProvider.overrideWith(() => _FakeController(_FakeHandle(_FakeRuntime(engine)))),
          projectsProvider.overrideWith((ref) => Stream.value(const <Project>[])),
        ],
        child: MaterialApp(
          theme: antTheme(AntTokens.light()),
          builder: (context, child) => AntToastHost(child: child!),
          home: Scaffold(body: NoteComposer(day: day)),
        ),
      ));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, 'Offline work');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(engine.ats, hasLength(1), reason: 'the note was saved once');
      return engine.ats.single;
    }

    testWidgets("a past day's note is at noon in the profile zone (+5:30)", (tester) async {
      profileUtcOffset = zoneOffset('Asia/Kolkata');
      final at = await savedAt(tester, '2026-11-10');
      expect(at.toUtc(), DateTime.utc(2026, 11, 10, 6, 30));
    });

    testWidgets("a past day's note is at noon in the profile zone (-5, New York winter)", (tester) async {
      profileUtcOffset = zoneOffset('America/New_York');
      final at = await savedAt(tester, '2026-11-10');
      expect(at.toUtc(), DateTime.utc(2026, 11, 10, 17));
    });

    testWidgets("a past day's note respects DST in the profile zone (London summer)", (tester) async {
      profileUtcOffset = zoneOffset('Europe/London');
      final at = await savedAt(tester, '2026-07-10');
      expect(at.toUtc(), DateTime.utc(2026, 7, 10, 11));
    });

    testWidgets("today's note (profile today) is now", (tester) async {
      profileUtcOffset = zoneOffset('Pacific/Kiritimati');
      final before = DateTime.now();
      final at = await savedAt(tester, todayIn(zoneOffset('Pacific/Kiritimati')));
      expect(at.difference(before).inMinutes.abs(), lessThan(2));
    });
  });
}

class _RecordingEngine implements AntEngine {
  final ats = <DateTime>[];
  @override
  Future<String> addNote({
    required String text,
    required DateTime at,
    String? link,
    String? projectId,
    String? attachTo,
    List<String> attachmentPaths = const [],
  }) async {
    ats.add(at);
    return 'ev1';
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _FakeRuntime implements EngineRuntime {
  _FakeRuntime(this.engine);
  @override
  final AntEngine engine;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

/// Runs runtime commands in-process against [_FakeRuntime].
class _FakeHandle implements EngineHandle {
  _FakeHandle(this.rt);
  final _FakeRuntime rt;
  @override
  Future<T> runtime<T>(EngineCommand<T> cmd) async => cmd(rt);
  @override
  Future<void> shutdown() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _FakeController extends EngineController {
  _FakeController(this.h);
  final EngineHandle h;
  @override
  Future<EngineHandle> build() async => h;
}
