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
  tearDown(() => DuoFold.instance.update(const DuoGeometry(
      posture: DuoPosture.open,
      screen: DuoScreen.inner,
      hinge: null,
      hingeAngle: 180)));

  testWidgets('fold set: keyboard above trackpad, both below the band',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.book,
        screen: DuoScreen.inner,
        hinge: _band,
        hingeAngle: 90));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(below: _deck(), child: const SizedBox.expand()),
    ));
    final kb = tester.getRect(find.byKey(const Key('duo-keyboard')));
    final tp = tester.getRect(find.byKey(const Key('duo-trackpad')));
    expect(kb.top, greaterThanOrEqualTo(_band.bottom));
    expect(kb.bottom, lessThanOrEqualTo(tp.top));
    expect(tp.bottom, lessThanOrEqualTo(951));
  });

  testWidgets('no fold: no deck', (tester) async {
    _setView(tester, const Size(669, 951));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(below: _deck(), child: const SizedBox.expand()),
    ));
    expect(find.byType(DuoDeck), findsNothing);
  });

  for (final h in [250.0, 300.0, 380.0, 455.0]) {
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
}
