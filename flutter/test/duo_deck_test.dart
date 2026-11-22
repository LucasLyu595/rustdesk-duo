import 'package:duo_display/duo_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/duo/duo_deck.dart';
import 'package:flutter_hbb/mobile/duo/duo_fold.dart';
import 'package:flutter_hbb/mobile/duo/duo_keyboard.dart';
import 'package:flutter_hbb/mobile/duo/duo_split.dart';
import 'package:flutter_hbb/mobile/duo/duo_trackpad.dart';
import 'package:flutter_test/flutter_test.dart';

const _band = Rect.fromLTWH(0, 455.5, 669, 40);

class _Keys implements DuoKeySink {
  @override
  bool isArmed(DuoModifier m) => false;
  @override
  void setArmed(DuoModifier m, bool armed) {}
  @override
  void sendKey(String name) {}
}

class _RecordingKeys implements DuoKeySink {
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

class _Pointer implements DuoPointerSink {
  @override
  void move(Offset delta) {}
  @override
  void click(DuoButton button) {}
  @override
  void buttonDown() {}
  @override
  void buttonUp() {}
  @override
  void scroll(int step) {}
}

DuoDeck _deck() => DuoDeck(keys: _Keys(), pointer: _Pointer());

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  tearDown(DuoFold.instance.reset);

  testWidgets('laptop: the session row sits in the band, keyboard right below',
      (tester) async {
    var a = 0;
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.book,
        screen: DuoScreen.inner,
        hinge: _band,
        hingeAngle: 90));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
          below: DuoDeck(
              keys: _Keys(),
              pointer: _Pointer(),
              rowExtent:
                  currentDuoSplit(const Size(669, 951))!.rowBand!.height,
              actions: [
                DuoDeckAction(
                    icon: const Icon(Icons.clear), onPressed: () => a++),
                DuoDeckAction(icon: const Icon(Icons.tv), onPressed: () {}),
              ]),
          child: const SizedBox.expand()),
    ));
    final row = tester.getRect(find.byKey(const Key('duo-session-row')));
    final kb = tester.getRect(find.byKey(const Key('duo-keyboard')));
    final tp = tester.getRect(find.byKey(const Key('duo-trackpad')));
    expect(row.top, greaterThanOrEqualTo(_band.top));
    expect(row.bottom, lessThanOrEqualTo(_band.bottom));
    await tester.tap(find.byIcon(Icons.clear));
    expect(a, 1);
    expect(kb.top, closeTo(_band.bottom, 1));
    expect(kb.bottom, lessThanOrEqualTo(tp.top));
    expect(tp.bottom, lessThanOrEqualTo(951));
    expect(kb.height, closeTo(246 * 10 / 11, 0.01));
    expect(tp.top, closeTo(kb.bottom + 6, 0.01));
    expect(tp.bottom, closeTo(945, 0.01));
  });

  testWidgets('laptop, 16:9: the picture rests on the crease under the strip',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.book,
        screen: DuoScreen.inner,
        hinge: _band,
        hingeAngle: 90));
    double a = 16 / 9;
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);
    const pictureKey = Key('picture');
    const stripKey = Key('strip');
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
          aspect: () => a,
          aspectChanged: notifier,
          above: const SizedBox.expand(key: stripKey),
          below: DuoDeck(
              keys: _Keys(),
              pointer: _Pointer(),
              rowExtent: _band.height,
              actions: [
                DuoDeckAction(icon: const Icon(Icons.clear), onPressed: () {}),
              ]),
          child: const SizedBox.expand(key: pictureKey)),
    ));
    final picture = tester.getRect(find.byKey(pictureKey));
    expect(picture.left, 0);
    expect(picture.top, closeTo(79.19, 0.01));
    expect(picture.width, 669);
    expect(picture.height, closeTo(376.31, 0.01));
    final strip = tester.getRect(find.byKey(stripKey));
    expect(strip.top, 0);
    expect(strip.bottom, closeTo(79.19, 0.01));
    final row = tester.getRect(find.byKey(const Key('duo-session-row')));
    expect(row.top, greaterThanOrEqualTo(_band.top));
    expect(row.bottom, lessThanOrEqualTo(_band.bottom));
    expect(tester.getRect(find.byKey(const Key('duo-keyboard'))).top,
        closeTo(495.5, 1));
    a = 4 / 3;
    notifier.notifyListeners();
    await tester.pump();
    expect(tester.getRect(find.byKey(pictureKey)),
        const Rect.fromLTWH(0, 0, 669, 455.5));
    expect(find.byKey(stripKey), findsNothing);
  });

  testWidgets('no fold: no deck', (tester) async {
    _setView(tester, const Size(669, 951));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(below: _deck(), child: const SizedBox.expand()),
    ));
    expect(find.byType(DuoDeck), findsNothing);
  });

  for (final h in [250.0, 300.0, 373.0, 380.0, 455.0]) {
    testWidgets('deck at height $h does not overflow', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 669, height: h, child: _deck()),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('session actions: row above the keyboard, actions fire',
      (tester) async {
    var a = 0, b = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 466,
          height: 373,
          child: DuoDeck(keys: _Keys(), pointer: _Pointer(), actions: [
            DuoDeckAction(icon: const Icon(Icons.clear), onPressed: () => a++),
            DuoDeckAction(icon: const Icon(Icons.tv), onPressed: () => b++),
          ]),
        ),
      ),
    ));
    final row = tester.getRect(find.byKey(const Key('duo-session-row')));
    final kb = tester.getRect(find.byKey(const Key('duo-keyboard')));
    expect(row.bottom, lessThanOrEqualTo(kb.top));
    await tester.tap(find.byIcon(Icons.clear));
    await tester.tap(find.byIcon(Icons.tv));
    expect([a, b], [1, 1]);
  });

  testWidgets('no actions: no session row', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 466, height: 373, child: _deck()),
      ),
    ));
    expect(find.byKey(const Key('duo-session-row')), findsNothing);
    expect(find.byKey(const Key('duo-deck-esc')), findsNothing);
    expect(
        tester.getRect(find.byKey(const Key('duo-keyboard'))).top, 6);
  });

  testWidgets(
      "esc sits at the row's left, sends Escape with the armed modifier, then disarms it",
      (tester) async {
    final keys = _RecordingKeys();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 466,
          height: 373,
          child: DuoDeck(keys: keys, pointer: _Pointer(), actions: [
            DuoDeckAction(icon: const Icon(Icons.clear), onPressed: () {}),
          ]),
        ),
      ),
    ));
    final esc = find.byKey(const Key('duo-deck-esc'));
    expect(
        find.descendant(
            of: find.byKey(const Key('duo-session-row')), matching: esc),
        findsOneWidget);
    expect(find.descendant(of: esc, matching: find.text('esc')),
        findsOneWidget);
    expect(tester.getRect(esc).right,
        lessThanOrEqualTo(tester.getRect(find.byIcon(Icons.clear)).left));

    Color? capColor() => (tester
            .widget<Container>(find.descendant(
                of: find.byKey(const Key('duo-key-cmd-l')),
                matching: find.byType(Container)))
            .decoration as BoxDecoration)
        .color;
    await tester.tap(find.byKey(const Key('duo-key-cmd-l')));
    await tester.pump();
    expect(capColor(), const Color(0xFF3D6FE0));

    await tester.tap(esc);
    await tester.pump();
    expect(keys.sent, ['VK_ESCAPE']);
    expect(keys.armedAtSend.single, {DuoModifier.command});
    expect(keys.armed, isEmpty);
    expect(capColor(), isNot(const Color(0xFF3D6FE0)));
  });

  for (final h in [72.0, 80.0, 373.0, 455.0]) {
    testWidgets('deck with actions at height $h does not overflow',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 466,
            height: h,
            child: DuoDeck(keys: _Keys(), pointer: _Pointer(), actions: [
              for (final i in _icons)
                DuoDeckAction(icon: Icon(i), onPressed: () {}),
            ]),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('duo-session-row')), findsOneWidget);
    });
  }
}

const _icons = [
  Icons.clear,
  Icons.tv,
  Icons.keyboard,
  Icons.build,
  Icons.message,
  Icons.more_vert,
];
