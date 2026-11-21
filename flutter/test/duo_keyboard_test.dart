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
    const ids = {
      'esc': 'VK_ESCAPE',
      'delete': 'VK_BACK',
      'return': 'VK_RETURN',
      'tab': 'VK_TAB',
      'space': 'VK_SPACE',
      'left': 'VK_LEFT',
      'up': 'VK_UP',
      'down': 'VK_DOWN',
      'right': 'VK_RIGHT',
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

  testWidgets('letters are labelled in capitals and arrows use arrow glyphs',
      (tester) async {
    await _pump(tester);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('c'), findsNothing);
    for (final a in ['\u2190', '\u2191', '\u2193', '\u2192']) {
      expect(find.text(a), findsOneWidget);
    }
  });

  testWidgets('removing the keyboard disarms armed modifiers', (tester) async {
    final sink = await _pump(tester);
    await _tap(tester, 'cmd-l');
    expect(sink.isArmed(DuoModifier.command), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(sink.armed, isEmpty);
  });
}
