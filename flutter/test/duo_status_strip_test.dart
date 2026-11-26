import 'dart:async';

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
    expect(find.text('Win Shot'), findsOneWidget);
    expect(kDuoShortcuts[kDuoShortcutCore - 1].id, 'window');
    const table = <String, Sent>{
      'mission': ('VK_UP', false, true, false, false),
      'spotlight': ('VK_SPACE', false, false, false, true),
      'desktop': ('VK_F11', false, false, false, false),
      'switcher': ('VK_TAB', false, false, false, true),
      'window': ('5', false, false, true, true),
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

  Future<(List<Sent>, List<(int, bool)>, List<Completer<void>>)> pumpPeer(
      WidgetTester tester,
      {required bool mac, bool hold = false, bool fail = false}) async {
    final legacy = <Sent>[];
    final map = <(int, bool)>[];
    final gates = <Completer<void>>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: const Size(669, 79),
          child: DuoStatusStrip(
            now: () => DateTime(2026, 11, 22, 9, 5),
            send: duoPeerAwareSender(
                useMapKeys: () => mac,
                legacy: (name,
                        {required alt,
                        required ctrl,
                        required shift,
                        required command}) =>
                    legacy.add((name, alt, ctrl, shift, command)),
                mapKey: (code, down) {
                  map.add((code, down));
                  if (fail && map.length == 1) return Future.error('refused');
                  if (!hold || map.length > 1) return Future.value();
                  final gate = Completer<void>();
                  gates.add(gate);
                  return gate.future;
                }),
          ),
        ),
      ),
    ));
    return (legacy, map, gates);
  }

  testWidgets('Mission on a Mac peer sends the four map keys in order and no '
      'legacy combo', (tester) async {
    final (legacy, map, gates) = await pumpPeer(tester, mac: true, hold: true);
    await tester.tap(find.byKey(const Key('duo-shortcut-mission')));
    await tester.pump();
    expect(map, [(59, true)]);
    gates.single.complete();
    await tester.pump();
    expect(map, [(59, true), (126, true), (126, false), (59, false)]);
    expect(legacy, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Mission on another peer sends today\'s legacy Ctrl+Up',
      (tester) async {
    final (legacy, map, _) = await pumpPeer(tester, mac: false);
    await tester.tap(find.byKey(const Key('duo-shortcut-mission')));
    await tester.pump();
    expect(legacy, [('VK_UP', false, true, false, false)]);
    expect(map, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Desktop on a Mac peer sends F11, then after the pause Ctrl+F3, '
      'as map keys and no legacy key', (tester) async {
    final (legacy, map, gates) = await pumpPeer(tester, mac: true, hold: true);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    expect(map, [(103, true)]);
    gates.single.complete();
    await tester.pump();
    expect(map, [(103, true), (103, false)]);
    await tester.pump(kDuoMacDockDelay - const Duration(milliseconds: 1));
    expect(map, [(103, true), (103, false)]);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(map, [
      (103, true),
      (103, false),
      (59, true),
      (99, true),
      (99, false),
      (59, false),
    ]);
    expect(legacy, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Desktop on another peer sends today\'s legacy F11',
      (tester) async {
    final (legacy, map, _) = await pumpPeer(tester, mac: false);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    expect(legacy, [('VK_F11', false, false, false, false)]);
    expect(map, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another button on a Mac peer keeps its legacy combo',
      (tester) async {
    final (legacy, map, _) = await pumpPeer(tester, mac: true);
    await tester.tap(find.byKey(const Key('duo-shortcut-spotlight')));
    await tester.pump();
    expect(legacy, [('VK_SPACE', false, false, false, true)]);
    expect(map, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tap during a running Desktop sequence on a Mac peer sends '
      'nothing, and the next one after it sends again', (tester) async {
    final (legacy, map, gates) = await pumpPeer(tester, mac: true, hold: true);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    expect(map, [(103, true)]);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.tap(find.byKey(const Key('duo-shortcut-spotlight')));
    await tester.pump();
    expect(map, [(103, true)]);
    expect(legacy, [('VK_SPACE', false, false, false, true)]);
    gates.single.complete();
    await tester.pump();
    await tester.pump(kDuoMacDockDelay ~/ 2);
    await tester.tap(find.byKey(const Key('duo-shortcut-mission')));
    await tester.pump();
    expect(map, [(103, true), (103, false)]);
    await tester.pump(kDuoMacDockDelay ~/ 2);
    await tester.pump();
    const sequence = [
      (103, true),
      (103, false),
      (59, true),
      (99, true),
      (99, false),
      (59, false),
    ];
    expect(map, sequence);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    await tester.pump(kDuoMacDockDelay);
    await tester.pump();
    expect(map, [...sequence, ...sequence]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a Desktop sequence whose first key fails still lets the next '
      'tap send', (tester) async {
    final (_, map, _) = await pumpPeer(tester, mac: true, fail: true);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    await tester.pump(kDuoMacDockDelay);
    await tester.pump();
    expect(map.length, 6);
    await tester.tap(find.byKey(const Key('duo-shortcut-desktop')));
    await tester.pump();
    await tester.pump(kDuoMacDockDelay);
    await tester.pump();
    expect(map.length, 12);
    await tester.pumpWidget(const SizedBox());
  });
}
