import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/duo/duo_shortcuts.dart';
import 'package:flutter_hbb/mobile/duo/duo_status_strip.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Sent = (String, bool, bool, bool, bool);

void main() {
  testWidgets('the strip shows name, delay and time, and leaves out what is '
      'missing', (tester) async {
    String? name;
    String? delay;
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoStatusStrip(
          name: () => name,
          delay: () => delay,
          changed: notifier,
          now: () => DateTime(2026, 11, 22, 9, 5)),
    ));
    expect(find.text('09:05'), findsOneWidget);
    name = 'm6';
    delay = '23';
    notifier.notifyListeners();
    await tester.pump();
    expect(find.text('m6  ·  23 ms  ·  09:05'), findsOneWidget);
    delay = null;
    notifier.notifyListeners();
    await tester.pump();
    expect(find.text('m6  ·  09:05'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  Future<List<Sent>> pump(WidgetTester tester, Size size,
      {bool withSender = true}) async {
    final sent = <Sent>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: size,
          child: DuoStatusStrip(
            now: () => DateTime(2026, 11, 22, 9, 5),
            send: withSender
                ? (name,
                        {required alt,
                        required ctrl,
                        required shift,
                        required command}) =>
                    sent.add((name, alt, ctrl, shift, command))
                : null,
          ),
        ),
      ),
    ));
    return sent;
  }

  testWidgets('each tap button sends its one combo and no other modifiers',
      (tester) async {
    final sent = await pump(tester, const Size(669, 79));
    const table = <String, Sent>{
      'mission': ('VK_UP', false, true, false, false),
      'spotlight': ('VK_SPACE', false, false, false, true),
      'desktop': ('VK_F11', false, false, false, false),
      'switcher': ('VK_TAB', false, false, false, true),
      'screenshot': ('4', false, false, true, true),
      'copy': ('c', false, false, false, true),
      'paste': ('v', false, false, false, true),
    };
    for (final e in table.entries) {
      await tester.tap(find.byKey(Key('duo-shortcut-${e.key}')));
      await tester.pump();
      expect(sent, [e.value], reason: e.key);
      sent.clear();
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Quit sends Cmd+Q on a long press only', (tester) async {
    final sent = await pump(tester, const Size(669, 79));
    await tester.tap(find.byKey(const Key('duo-shortcut-quit')));
    await tester.pump(const Duration(seconds: 1));
    expect(sent, isEmpty);
    await tester.longPress(find.byKey(const Key('duo-shortcut-quit')));
    expect(sent, [('q', false, false, false, true)]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the row shows eight buttons in a tall strip, none in a low one '
      'or without a sender', (tester) async {
    await pump(tester, const Size(669, 79));
    expect(find.text('09:05'), findsOneWidget);
    final keys = [for (final s in kDuoShortcuts) Key('duo-shortcut-${s.id}')];
    expect(keys.length, 8);
    for (final k in keys) {
      final r = tester.getRect(find.byKey(k));
      expect(r.width, greaterThanOrEqualTo(36), reason: '$k');
      expect(r.height, greaterThanOrEqualTo(36), reason: '$k');
      expect(r.left, greaterThanOrEqualTo(40), reason: '$k');
      expect(r.right, lessThanOrEqualTo(629), reason: '$k');
    }
    await pump(tester, const Size(669, 60));
    for (final k in keys) {
      expect(find.byKey(k), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await pump(tester, const Size(669, 40));
    expect(find.text('09:05'), findsOneWidget);
    expect(find.byKey(keys.first), findsNothing);
    await pump(tester, const Size(669, 79), withSender: false);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.byKey(keys.first), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
