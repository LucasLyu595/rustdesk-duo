import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/duo/duo_keyboard.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSink implements DuoKeySink {
  final armed = <DuoModifier>{};
  final sent = <String>[];
  final armedAtSend = <Set<DuoModifier>>[];

  @override
  bool isArmed(DuoModifier m) => armed.contains(m);

  @override
  void setArmed(DuoModifier m, bool a) => a ? armed.add(m) : armed.remove(m);

  @override
  void sendKey(String name) {
    sent.add(name);
    armedAtSend.add({...armed});
  }
}

Future<_FakeSink> _pump(WidgetTester tester) async {
  final sink = _FakeSink();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(width: 669, height: 300, child: DuoKeyboard(sink: sink)),
    ),
  ));
  return sink;
}

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('duo-key-$id')));
  await tester.pump();
}

void main() {
  testWidgets('character keys send themselves', (tester) async {
    final sink = await _pump(tester);
    for (final c in ['c', '1', ';', '`', '\\']) {
      await _tap(tester, c);
    }
    expect(sink.sent, ['c', '1', ';', '`', '\\']);
  });

  testWidgets('named keys send their VK names', (tester) async {
    final sink = await _pump(tester);
    final ids = {
      'esc': 'VK_ESCAPE',
      'delete': 'VK_BACK',
      'return': 'VK_RETURN',
      'tab': 'VK_TAB',
      'space': 'VK_SPACE',
      'left': 'VK_LEFT',
      'up': 'VK_UP',
      'down': 'VK_DOWN',
      'right': 'VK_RIGHT',
      for (var i = 1; i <= 12; i++) 'f$i': 'VK_F$i',
    };
    for (final id in ids.keys) {
      await _tap(tester, id);
    }
    expect(sink.sent, ids.values.toList());
  });

  testWidgets('Cmd, Ctrl and Option arm for one key then disarm',
      (tester) async {
    final sink = await _pump(tester);
    const mods = {
      'cmd-l': DuoModifier.command,
      'ctrl': DuoModifier.ctrl,
      'option-r': DuoModifier.alt,
    };
    for (final e in mods.entries) {
      await _tap(tester, e.key);
      expect(sink.isArmed(e.value), isTrue);
      await _tap(tester, 'c');
      expect(sink.sent.last, 'c');
      expect(sink.armedAtSend.last, {e.value});
      expect(sink.armed, isEmpty);
    }
  });

  testWidgets('Shift sends the shifted glyph, Shift with Cmd does not',
      (tester) async {
    final sink = await _pump(tester);
    await _tap(tester, 'shift-l');
    await _tap(tester, 'a');
    expect(sink.sent, ['A']);
    expect(sink.armedAtSend.last, {DuoModifier.shift});
    expect(sink.armed, isEmpty);

    await _tap(tester, 'shift-r');
    await _tap(tester, '1');
    await _tap(tester, 'shift-r');
    await _tap(tester, '`');
    await _tap(tester, 'shift-r');
    await _tap(tester, '\\');
    expect(sink.sent.sublist(1), ['!', '~', '|']);

    await _tap(tester, 'shift-l');
    await _tap(tester, 'cmd-l');
    await _tap(tester, 'z');
    expect(sink.sent.last, 'z');
    expect(sink.armedAtSend.last, {DuoModifier.shift, DuoModifier.command});
    expect(sink.armed, isEmpty);
  });

  testWidgets('tapping an armed modifier again disarms it without a key',
      (tester) async {
    final sink = await _pump(tester);
    const mods = {
      'shift-l': DuoModifier.shift,
      'ctrl': DuoModifier.ctrl,
      'option-l': DuoModifier.alt,
      'cmd-r': DuoModifier.command,
    };
    for (final e in mods.entries) {
      await _tap(tester, e.key);
      expect(sink.isArmed(e.value), isTrue);
      await _tap(tester, e.key);
      expect(sink.isArmed(e.value), isFalse);
    }
    expect(sink.sent, isEmpty);
  });

  testWidgets('keycaps carry MacBook labels', (tester) async {
    await _pump(tester);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('c'), findsNothing);
    for (final a in ['\u2190', '\u2191', '\u2193', '\u2192']) {
      expect(find.text(a), findsOneWidget);
    }
    for (final l in 'esc delete tab return F1 F12'.split(' ')) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('caps lock'), findsOneWidget);
    expect(find.text('⌃\ncontrol'), findsOneWidget);
    for (final l in ['⇧\nshift', '⌥\noption', '⌘\ncommand']) {
      expect(find.text(l), findsNWidgets(2));
    }
  });

  testWidgets('rows follow the MacBook table and line up', (tester) async {
    await _pump(tester);
    List<String> chars(String c) => c.split('');
    final rows = <Map<String, double>>[
      {'esc': 1.5, for (var i = 1; i <= 12; i++) 'f$i': 13 / 12},
      {for (final c in chars('`1234567890-=')) c: 1, 'delete': 1.5},
      {'tab': 1.5, for (final c in chars('qwertyuiop[]\\')) c: 1},
      {
        'caps': 1.75,
        for (final c in chars('asdfghjkl;\'')) c: 1,
        'return': 1.75
      },
      {
        'shift-l': 2.25,
        for (final c in chars('zxcvbnm,./')) c: 1,
        'shift-r': 2.25
      },
      {
        'ctrl': 1.25,
        'option-l': 1.25,
        'cmd-l': 1.5,
        'space': 3.75,
        'cmd-r': 1.5,
        'option-r': 1.25,
        for (final a in ['left', 'up', 'down', 'right']) a: 1,
      },
    ];
    final board = tester.getRect(find.byType(DuoKeyboard));
    Rect rect(String id) => tester.getRect(find.byKey(Key('duo-key-$id')));
    for (final row in rows) {
      var left = double.negativeInfinity;
      for (final k in row.entries) {
        final r = rect(k.key);
        expect(r.top, rect(row.keys.first).top);
        expect(r.left, greaterThan(left));
        expect(r.width + 4, closeTo(k.value * 669 / 14.5, 0.01));
        left = r.left;
      }
      expect(rect(row.keys.last).right, closeTo(board.right - 2, 0.01));
    }
    expect(rect('1').top - rect('esc').top, closeTo(300 / 11, 0.01));
    expect(rect('q').top - rect('1').top, closeTo(600 / 11, 0.01));
    expect(find.byKey(const Key('duo-key-fn')), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('duo-key-')),
        findsNWidgets(76));
  });

  testWidgets('caps lock latches, capitalises letters only and is never sent',
      (tester) async {
    final sink = await _pump(tester);
    Color? capColor() => (tester
            .widget<Container>(find.descendant(
                of: find.byKey(const Key('duo-key-caps')),
                matching: find.byType(Container)))
            .decoration as BoxDecoration)
        .color;
    await _tap(tester, 'caps');
    expect(sink.sent, isEmpty);
    expect(capColor(), const Color(0xFF3D6FE0));

    for (final c in ['a', '1', ';', 'a']) {
      await _tap(tester, c);
    }
    expect(sink.sent, ['A', '1', ';', 'A']);
    expect(sink.armedAtSend.every((s) => s.isEmpty), isTrue);

    await _tap(tester, 'cmd-l');
    await _tap(tester, 'c');
    expect(sink.sent.last, 'c');
    expect(sink.armedAtSend.last, {DuoModifier.command});
    await _tap(tester, 'ctrl');
    await _tap(tester, 'c');
    expect(sink.sent.last, 'c');
    expect(sink.armedAtSend.last, {DuoModifier.ctrl});

    final before = sink.sent.length;
    await _tap(tester, 'caps');
    expect(sink.sent.length, before);
    expect(capColor(), isNot(const Color(0xFF3D6FE0)));
    await _tap(tester, 'a');
    expect(sink.sent.last, 'a');
  });

  testWidgets('removing the keyboard disarms armed modifiers', (tester) async {
    final sink = await _pump(tester);
    await _tap(tester, 'cmd-l');
    expect(sink.isArmed(DuoModifier.command), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(sink.armed, isEmpty);
  });
}
