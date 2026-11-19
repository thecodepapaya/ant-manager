import 'dart:io';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  test('secrets write then read from the engine go through the UI port host', () async {
    final secrets = FakeSecrets();
    final h = await EngineHandle.start(testConfig(dir.path), host: fakeHost(secrets: secrets));
    addTearDown(h.shutdown);
    await h.runtime(writeSecretCmd('github.token', 's3cret'));
    expect(secrets.values, {'github.token': 's3cret'});
    expect(await h.runtime(readSecretCmd('github.token')), 's3cret');
    expect(await h.runtime(readSecretCmd('missing')), isNull);
  });

  test('notifier.show reaches the UI notifier', () async {
    final notifier = FakeNotifier();
    final h = await EngineHandle.start(testConfig(dir.path), host: fakeHost(notifier: notifier));
    addTearDown(h.shutdown);
    await h.runtime(notifyCmd('Daily nudge'));
    expect(notifier.shown, [('Daily nudge', 'b', null)]);
  });

  test('without a host, port calls fail clearly', () async {
    final h = await EngineHandle.start(testConfig(dir.path));
    addTearDown(h.shutdown);
    await expectLater(
      h.runtime(readSecretCmd('k')).timeout(const Duration(seconds: 5)),
      throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('no UI port host'))),
    );
  });

  test('calendar events and changes round-trip through a fake CalendarBridge', () async {
    final cal = FakeCalendar();
    final h = await EngineHandle.start(testConfig(dir.path, calendar: true), host: fakeHost(calendar: cal));
    addTearDown(h.shutdown);
    final from = DateTime.utc(2026, 11, 1);
    final to = DateTime.utc(2026, 11, 2);
    expect(await h.runtime(calendarEventsCmd(from, to)), 1);
    expect(cal.eventCalls, [(from, to)]);
    expect(await h.runtime(calendarChangeCmd()), isTrue);
  });

  test('a calendar call on a host without a calendar fails with the host error', () async {
    final h = await EngineHandle.start(testConfig(dir.path, calendar: true), host: fakeHost());
    addTearDown(h.shutdown);
    await expectLater(
      h.runtime(calendarEventsCmd(DateTime.utc(2026), DateTime.utc(2027))).timeout(const Duration(seconds: 5)),
      throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('not available'))),
    );
  });
}
