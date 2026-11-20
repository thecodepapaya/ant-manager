// promptText (widgets/common.dart): the dialog owns its TextEditingController, so closing it and
// running the exit animation must not use a disposed controller.
import 'package:ant_manager/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  /// Pumps a button that opens promptText; returns a getter for the result once it completes.
  Future<({bool done, String? value}) Function()> open(
    WidgetTester tester, {
    String initial = '',
    int maxLines = 1,
  }) async {
    var done = false;
    String? value;
    await tester.pumpWidget(MaterialApp(
      theme: antTheme(AntTokens.dark()),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              value = await promptText(context, title: 'Rename', initial: initial, action: 'Save', maxLines: maxLines);
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    return () => (done: done, value: value);
  }

  /// Runs the route's exit animation to completion and checks nothing threw on the way.
  Future<void> closeFully(WidgetTester tester) async {
    await tester.pump(); // route starts popping
    await tester.pump(const Duration(milliseconds: 16)); // mid-animation frame: dialog still built
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Rename'), findsNothing);
  }

  testWidgets('Save returns the trimmed value; no use-after-dispose during exit', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(EditableText), '  New name  ');
    await tester.tap(find.text('Save'));
    await closeFully(tester);
    expect(result(), (done: true, value: 'New name'));
  });

  testWidgets('Enter submits a single-line prompt with the trimmed value', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(EditableText), ' typed ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await closeFully(tester);
    expect(result(), (done: true, value: 'typed'));
  });

  testWidgets('Cancel returns null even with text entered', (tester) async {
    final result = await open(tester, initial: 'keep');
    await tester.enterText(find.byType(EditableText), 'changed');
    await tester.tap(find.text('Cancel'));
    await closeFully(tester);
    expect(result(), (done: true, value: null));
  });

  testWidgets('whitespace-only value returns null', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(EditableText), '   ');
    await tester.tap(find.text('Save'));
    await closeFully(tester);
    expect(result(), (done: true, value: null));
  });

  testWidgets('initial text is pre-filled and returned unchanged on Save', (tester) async {
    final result = await open(tester, initial: 'Payments');
    expect(find.text('Payments'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await closeFully(tester);
    expect(result(), (done: true, value: 'Payments'));
  });

  testWidgets('multi-line prompt: Enter does not submit; Save returns the text', (tester) async {
    final result = await open(tester, maxLines: 3);
    await tester.enterText(find.byType(EditableText), 'line one\nline two ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget, reason: 'still open');
    expect(result().done, isFalse);
    await tester.tap(find.text('Save'));
    await closeFully(tester);
    expect(result(), (done: true, value: 'line one\nline two'));
  });

  testWidgets('barrier dismiss returns null without errors', (tester) async {
    final result = await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await closeFully(tester);
    expect(result(), (done: true, value: null));
  });

  testWidgets('the dialog can be opened again after closing', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await closeFully(tester);
    expect(result().done, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'again');
    await tester.tap(find.text('Save'));
    await closeFully(tester);
    expect(result().value, 'again');
  });
}
