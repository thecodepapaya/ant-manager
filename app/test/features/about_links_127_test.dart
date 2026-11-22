/// Independent tests (#99) for DECISIONS #127: Settings → General → About (version, licence, GitHub / Report a
/// bug / Request a feature opened in the browser), the GitHub issue forms and the website's issue links.
library;

import 'dart:io';

import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/features/settings/general_tab.dart';
import 'package:ant_manager/features/settings/kit.dart' show PanelRow;
import 'package:ant_manager/features/settings/project_links.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';
// Transitive deps of url_launcher; imported only to fake the platform and parse the forms (no new deps).
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:yaml/yaml.dart';

import 'support.dart';

const _repo = 'https://github.com/thecodepapaya/ant-manager';
const _bug = '$_repo/issues/new?template=bug_report.yml';
const _feature = '$_repo/issues/new?template=feature_request.yml';

/// Records every launch; answers [result].
class _FakeLauncher extends UrlLauncherPlatform {
  final launches = <(String, PreferredLaunchMode)>[];
  bool result = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url, options.mode));
    return result;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launches.add((url, PreferredLaunchMode.platformDefault));
    return result;
  }
}

/// [bootPage] with a known app version.
Future<(ProviderContainer, EngineHandle)> _boot(WidgetTester tester, Directory dir, {String version = '9.8.7-test'}) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    engineConfigProvider.overrideWithValue(EngineConfig(
      dataDir: dir.path,
      timeZone: 'UTC',
      inMemory: true,
      startLoops: false,
      appVersion: version,
    )),
    uiPortHostProvider.overrideWithValue(fakeHost()),
  ]);
  addTearDown(container.dispose);
  final h = (await tester.runAsync(() => container.read(engineProvider.future)))!;
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: pageApp(const GeneralTab())));
  await settle(tester);
  return (container, h);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.widgetWithText(AntButton, label);
  expect(f, findsOneWidget, reason: label);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

String _root() => Directory.current.parent.path; // flutter test runs in app/

void main() {
  group('About section', () {
    late Directory dir;
    late _FakeLauncher launcher;
    late UrlLauncherPlatform original;
    setUp(() {
      dir = tempDir();
      original = UrlLauncherPlatform.instance;
      launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
    });
    tearDown(() {
      UrlLauncherPlatform.instance = original;
      dir.deleteSync(recursive: true);
    });

    testWidgets('comes after Diagnostics and shows the configured version and the licence', (tester) async {
      final (_, h) = await _boot(tester, dir);
      final diagnostics = find.text('DIAGNOSTICS');
      final about = find.text('ABOUT');
      expect(diagnostics, findsOneWidget);
      expect(about, findsOneWidget);
      expect(tester.getTopLeft(about).dy, greaterThan(tester.getTopLeft(diagnostics).dy));
      // About is the last section: its rows sit below the Logs row.
      expect(tester.getTopLeft(about).dy, greaterThan(tester.getTopLeft(find.text('Logs')).dy));

      expect(find.text('Ant Manager 9.8.7-test'), findsOneWidget);
      expect(find.text('Open source · Apache 2.0'), findsOneWidget);
      final row = find.ancestor(of: find.text('Ant Manager 9.8.7-test'), matching: find.byType(PanelRow));
      expect(tester.widget<PanelRow>(row).hint, 'Open source · Apache 2.0');
      expect(find.descendant(of: row, matching: find.widgetWithText(AntButton, 'GitHub')), findsOneWidget);
      expect(tester.getTopLeft(find.text('Ant Manager 9.8.7-test')).dy, greaterThan(tester.getTopLeft(about).dy));
      expect(tester.getTopLeft(find.text('Feedback')).dy, greaterThan(tester.getTopLeft(about).dy));
      final feedback = find.ancestor(of: find.text('Feedback'), matching: find.byType(PanelRow));
      expect(tester.widget<PanelRow>(feedback).hint, allOf(contains('GitHub issues'), contains('copy diagnostics')));
      expect(launcher.launches, isEmpty, reason: 'nothing opens until a button is pressed');
      await killEngine(tester, h);
    });

    for (final (label, url) in [('GitHub', _repo), ('Report a bug', _bug), ('Request a feature', _feature)]) {
      testWidgets('$label opens $url in the external browser', (tester) async {
        final (_, h) = await _boot(tester, dir);
        await _tap(tester, label);
        expect(launcher.launches, [(url, PreferredLaunchMode.externalApplication)]);
        expect(find.text('Couldn’t open the browser'), findsNothing);
        await killEngine(tester, h);
      });
    }

    testWidgets('a failed launch shows "Couldn’t open the browser" for each button', (tester) async {
      final (_, h) = await _boot(tester, dir);
      launcher.result = false;
      for (final label in ['GitHub', 'Report a bug', 'Request a feature']) {
        await _tap(tester, label);
        expect(find.text('Couldn’t open the browser'), findsOneWidget, reason: label);
        await tester.pump(const Duration(seconds: 10)); // let the toast expire
        await settle(tester);
        expect(find.text('Couldn’t open the browser'), findsNothing);
      }
      expect(launcher.launches.map((l) => l.$1), [_repo, _bug, _feature]);
      await killEngine(tester, h);
    });
  });

  group('ProjectLinks', () {
    test('constants are the public repo and its two issue forms', () {
      expect(ProjectLinks.repo.toString(), _repo);
      expect(ProjectLinks.bugReport.toString(), _bug);
      expect(ProjectLinks.featureRequest.toString(), _feature);
      for (final u in [ProjectLinks.repo, ProjectLinks.bugReport, ProjectLinks.featureRequest]) {
        expect(u.scheme, 'https');
        expect(u.host, 'github.com');
      }
      expect(ProjectLinks.bugReport.path, '/thecodepapaya/ant-manager/issues/new');
      expect(ProjectLinks.bugReport.queryParameters, {'template': 'bug_report.yml'});
      expect(ProjectLinks.featureRequest.queryParameters, {'template': 'feature_request.yml'});
    });

    test('every ?template= names a form in .github/ISSUE_TEMPLATE/', () {
      for (final u in [ProjectLinks.bugReport, ProjectLinks.featureRequest]) {
        final name = u.queryParameters['template']!;
        expect(File('${_root()}/.github/ISSUE_TEMPLATE/$name').existsSync(), isTrue, reason: name);
      }
    });
  });

  group('issue forms', () {
    final templates = Directory('${_root()}/.github/ISSUE_TEMPLATE');

    test('the folder has the two forms and config.yml', () {
      final names = [for (final f in templates.listSync()) f.uri.pathSegments.last]..sort();
      expect(names, ['bug_report.yml', 'config.yml', 'feature_request.yml']);
    });

    for (final (file, label, ids) in [
      ('bug_report.yml', 'bug', ['what', 'steps', 'expected', 'diagnostics', 'os', 'version']),
      ('feature_request.yml', 'enhancement', ['problem', 'proposal']),
    ]) {
      test('$file parses as a form with unique ids', () {
        final doc = loadYaml(File('${templates.path}/$file').readAsStringSync()) as YamlMap;
        expect(doc['name'], isA<String>());
        expect(doc['description'], isA<String>());
        expect((doc['labels'] as YamlList).toList(), [label]);
        final body = doc['body'] as YamlList;
        final got = [for (final b in body) (b as YamlMap)['id'] as String];
        expect(got.toSet().length, got.length, reason: 'ids must be unique');
        expect(got, ids);
        for (final b in body.cast<YamlMap>()) {
          expect(['textarea', 'input', 'markdown', 'dropdown', 'checkboxes'], contains(b['type']));
          expect((b['attributes'] as YamlMap)['label'], isA<String>(), reason: b['id'] as String);
        }
      });
    }

    test('bug report: Diagnostics is optional plain text, the rest are required', () {
      final body = (loadYaml(File('${templates.path}/bug_report.yml').readAsStringSync()) as YamlMap)['body'] as YamlList;
      for (final b in body.cast<YamlMap>()) {
        final required = (b['validations'] as YamlMap?)?['required'] == true;
        expect(required, b['id'] != 'diagnostics', reason: b['id'] as String);
      }
      final diag = body.cast<YamlMap>().firstWhere((b) => b['id'] == 'diagnostics');
      expect((diag['attributes'] as YamlMap)['render'], 'text');
      final how = (diag['attributes'] as YamlMap)['description'] as String;
      expect(how, allOf(contains('Diagnostics'), contains('Copy')));
    });

    test('config.yml disables blank issues and links the privacy notes', () {
      final doc = loadYaml(File('${templates.path}/config.yml').readAsStringSync()) as YamlMap;
      expect(doc['blank_issues_enabled'], isFalse);
      final links = (doc['contact_links'] as YamlList).cast<YamlMap>();
      expect(links, hasLength(1));
      expect(links.single['url'], '$_repo/blob/main/PRIVACY.md');
      expect(File('${_root()}/PRIVACY.md').existsSync(), isTrue);
    });
  });

  group('website', () {
    late String html;
    setUpAll(() => html = File('${_root()}/web/index.html').readAsStringSync());

    String section(String start, String end) {
      final i = html.indexOf(start);
      expect(i, greaterThanOrEqualTo(0), reason: start);
      final j = html.indexOf(end, i);
      expect(j, greaterThan(i), reason: end);
      return html.substring(i, j);
    }

    test('the Open source section (after Download) links both issue forms and the repo', () {
      final s = section('<section id="open-source"', '</section>');
      expect(s, contains('href="$_bug"'));
      expect(s, contains('href="$_feature"'));
      expect(s, contains('href="$_repo"'));
      final download = html.indexOf('<section id="download"');
      expect(download, greaterThanOrEqualTo(0));
      expect(html.indexOf('<section id="open-source"'), greaterThan(download));
    });

    test('the footer links both issue forms', () {
      final f = section('<footer', '</footer>');
      expect(f, contains('<a href="$_bug">Report a bug</a>'));
      expect(f, contains('<a href="$_feature">Request a feature</a>'));
    });

    test('no inline scripts or style attributes (CSP unchanged)', () {
      expect(RegExp(r'<script(?![^>]*\bsrc=)[^>]*>', caseSensitive: false).hasMatch(html), isFalse);
      expect(RegExp(r'\son\w+\s*=', caseSensitive: false).hasMatch(html), isFalse, reason: 'inline handlers');
      expect(RegExp(r'\sstyle\s*=', caseSensitive: false).hasMatch(html), isFalse);
      expect(RegExp(r'<style', caseSensitive: false).hasMatch(html), isFalse);
    });

    test('the CSP still allows no scripts and no inline styles', () {
      final csp = File('${_root()}/web/_headers')
          .readAsLinesSync()
          .firstWhere((l) => l.trim().startsWith('Content-Security-Policy:'));
      expect(csp, contains("default-src 'none'"));
      expect(csp, contains("style-src 'self'"));
      expect(csp, isNot(contains('script-src')));
      expect(csp, isNot(contains('unsafe-inline')));
    });
  });
}
