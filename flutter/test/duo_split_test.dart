import 'package:duo_display/duo_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/duo/duo_fold.dart';
import 'package:flutter_hbb/mobile/duo/duo_split.dart';
import 'package:flutter_test/flutter_test.dart';

const _band = Rect.fromLTWH(0, 455.5, 669, 40);

DuoGeometry _geo({double? angle = 90, Rect hinge = _band}) => DuoGeometry(
    posture: DuoPosture.book,
    screen: DuoScreen.inner,
    hinge: hinge,
    hingeAngle: angle);

DuoGeometry _flat() => const DuoGeometry(
    posture: DuoPosture.open,
    screen: DuoScreen.inner,
    hinge: null,
    hingeAngle: 180);

class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  tearDown(DuoFold.instance.reset);

  testWidgets('fold set: child above the fold, placeholder below it',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_geo());
    const childKey = Key('child');
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(child: SizedBox.expand(key: childKey)),
    ));
    expect(tester.getRect(find.byKey(childKey)),
        const Rect.fromLTWH(0, 0, 669, 495.5));
    expect(tester.getRect(find.byType(DuoSplitPlaceholder)),
        const Rect.fromLTRB(0, 495.5, 669, 951));
  });

  testWidgets('fold set with below: that widget replaces the placeholder',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_geo());
    const belowKey = Key('below');
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
        below: SizedBox.expand(key: belowKey),
        child: SizedBox.expand(),
      ),
    ));
    expect(tester.getRect(find.byKey(belowKey)),
        const Rect.fromLTRB(0, 495.5, 669, 951));
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
  });

  testWidgets('no fold: child fills the body, no placeholder', (tester) async {
    _setView(tester, const Size(669, 951));
    const childKey = Key('child');
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(child: SizedBox.expand(key: childKey)),
    ));
    expect(tester.getRect(find.byKey(childKey)),
        const Rect.fromLTWH(0, 0, 669, 951));
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
  });

  testWidgets('switching the fold relayouts live and keeps the child state',
      (tester) async {
    _setView(tester, const Size(669, 951));
    var changes = 0;
    final probeKey = GlobalKey<State<_Probe>>();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
        onFoldChanged: () => changes++,
        child: _Probe(key: probeKey),
      ),
    ));
    final state = probeKey.currentState;
    expect(tester.getSize(find.byKey(probeKey)).height, 951);
    expect(changes, 0);

    DuoFold.instance.update(_geo());
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, 495.5);
    expect(find.byType(DuoSplitPlaceholder), findsOneWidget);
    expect(changes, 1);

    DuoFold.instance.update(_geo(angle: 80));
    await tester.pump();
    expect(changes, 1);

    DuoFold.instance.update(_flat());
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, closeTo(427.95, 0.01));
    expect(find.byType(DuoSplitPlaceholder), findsOneWidget);
    expect(changes, 2);

    _setView(tester, const Size(951, 669));
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, 669);
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
    expect(changes, 3);
    expect(probeKey.currentState, same(state));
  });

  testWidgets('body shorter than the split: no overflow, no placeholder',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_geo());
    const childKey = Key('child');
    for (final h in [480.0, 400.0]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
              width: 669,
              height: h,
              child: const DuoSplitBody(child: SizedBox.expand(key: childKey))),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(DuoSplitPlaceholder), findsNothing);
      expect(tester.getSize(find.byKey(childKey)).height, h);
    }
  });

  testWidgets('laptop: a touch in the crease band does not reach the picture',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_geo());
    var taps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
        aspect: () => 4 / 3,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand()),
      ),
    ));
    await tester.tapAt(const Offset(300, 475));
    expect(taps, 0);
    await tester.tapAt(const Offset(300, 450));
    expect(taps, 1);
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.open,
        screen: DuoScreen.inner,
        hinge: _band,
        hingeAngle: 180));
    await tester.pump();
    await tester.tapAt(const Offset(300, 475));
    expect(taps, 2);
  });

  testWidgets('a changed peer aspect relayouts the picture', (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_flat());
    double? a;
    var changes = 0;
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);
    final probeKey = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
        onFoldChanged: () => changes++,
        aspect: () => a,
        aspectChanged: notifier,
        child: SizedBox.expand(key: probeKey),
      ),
    ));
    expect(tester.getSize(find.byKey(probeKey)).height, closeTo(427.95, 0.01));
    a = 4 / 3;
    notifier.notifyListeners();
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, closeTo(501.75, 0.01));
    a = 16 / 9;
    notifier.notifyListeners();
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, closeTo(376.31, 0.01));
    expect(changes, 0);
  });

  group('duoSplitFrom', () {
    const portrait = Size(669, 951);
    const cover = Size(466, 678);

    test(
        'laptop: the picture runs to the band, or to full width within the deck give',
        () {
      for (final c in <(double?, double)>[
        (4 / 3, 501.75),
        (16 / 9, 495.5),
        (null, 495.5),
        (1.3, 495.5),
      ]) {
        final split =
            duoSplitFrom(_geo(), portrait, isDuo: true, aspect: c.$1)!;
        expect(split.pictureBottom, closeTo(c.$2, 0.001), reason: '${c.$1}');
        expect(split.deckTop, split.pictureBottom);
      }
    });

    test('flat: the picture takes its aspect height, capped at 0.6 of the view',
        () {
      const openBand = DuoGeometry(
          posture: DuoPosture.open,
          screen: DuoScreen.inner,
          hinge: _band,
          hingeAngle: 180);
      for (final g in [_flat(), openBand]) {
        final split = duoSplitFrom(g, portrait, isDuo: true, aspect: 4 / 3)!;
        expect(split.pictureBottom, closeTo(501.75, 0.001));
        expect(split.deckTop, split.pictureBottom);
        expect(
            duoSplitFrom(g, portrait, isDuo: true, aspect: 1.0)!.pictureBottom,
            closeTo(570.6, 0.01));
      }
      expect(duoSplitFrom(openBand, portrait, isDuo: true),
          const DuoSplit(pictureBottom: 455.5, deckTop: 495.5));
      expect(duoSplitFrom(_flat(), portrait, isDuo: true)!.pictureBottom,
          closeTo(427.95, 0.01));
    });

    test('no usable band falls back to 0.45 of the view', () {
      final unusable = [
        null,
        _flat(),
        _geo(hinge: Rect.zero),
        _geo(hinge: const Rect.fromLTWH(455.5, 0, 40, 669)),
        _geo(hinge: const Rect.fromLTWH(0, 940, 669, 40)),
      ];
      for (final g in unusable) {
        final split = duoSplitFrom(g, portrait, isDuo: true)!;
        expect(split.pictureBottom, closeTo(427.95, 0.01));
        expect(split.deckTop, split.pictureBottom);
      }
      final shut = duoSplitFrom(null, cover, isDuo: true)!;
      expect(shut.pictureBottom, closeTo(305.1, 0.01));
    });

    test('landscape and non-Duo give none', () {
      expect(duoSplitFrom(_geo(), const Size(951, 669), isDuo: true), isNull);
      expect(duoSplitFrom(_geo(), portrait, isDuo: false), isNull);
    });
  });

  test('the latch keeps the cover split', () {
    const cover = Size(466, 678);
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.open,
        screen: DuoScreen.unknown,
        hinge: null,
        hingeAngle: null));
    expect(currentDuoSplit(cover), isNull);
    DuoFold.instance.update(_flat());
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.closed,
        screen: DuoScreen.outer,
        hinge: null,
        hingeAngle: null));
    expect(currentDuoSplit(cover)!.pictureBottom, closeTo(305.1, 0.01));
  });

  test('duoCanvasHeight caps the height above the split only', () {
    const view = Size(669, 951);
    expect(duoCanvasHeight(900, 50, view), 900);
    DuoFold.instance.update(_geo());
    expect(duoCanvasHeight(900, 50, view), 445.5);
    expect(duoCanvasHeight(300, 50, view), 300);
    expect(duoCanvasHeight(900, 500, view), 0);
    DuoFold.instance.update(const DuoGeometry(
        posture: DuoPosture.closed,
        screen: DuoScreen.outer,
        hinge: null,
        hingeAngle: null));
    expect(duoCanvasHeight(900, 50, const Size(466, 678)),
        closeTo(255.1, 0.01));
    expect(duoCanvasHeight(900, 50, const Size(678, 466)), 900);
  });
}
