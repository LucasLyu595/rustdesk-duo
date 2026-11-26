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
        const Rect.fromLTWH(0, 56, 669, 399.5));
    expect(tester.getRect(find.byType(DuoSplitPlaceholder)),
        const Rect.fromLTRB(0, 455.5, 669, 951));
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
        const Rect.fromLTRB(0, 455.5, 669, 951));
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
    expect(tester.getSize(find.byKey(probeKey)).height, 399.5);
    expect(find.byType(DuoSplitPlaceholder), findsOneWidget);
    expect(changes, 1);

    DuoFold.instance.update(_geo(angle: 80));
    await tester.pump();
    expect(changes, 1);

    DuoFold.instance.update(_flat());
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, 399.5);
    expect(find.byType(DuoSplitPlaceholder), findsOneWidget);
    expect(changes, 1);

    _setView(tester, const Size(951, 669));
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, 669);
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
    expect(changes, 2);
    expect(probeKey.currentState, same(state));
  });

  testWidgets('body shorter than the split: no overflow, no placeholder',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_geo());
    const childKey = Key('child');
    for (final h in [450.0, 400.0]) {
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
      expect(tester.getSize(find.byKey(childKey)).height, h - 56);
    }
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

  testWidgets('flat without a band: strip, picture and deck stack from the top',
      (tester) async {
    _setView(tester, const Size(669, 951));
    DuoFold.instance.update(_flat());
    final above = GlobalKey();
    final below = GlobalKey();
    final child = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(
        aspect: () => 4 / 3,
        above: SizedBox.expand(key: above),
        below: SizedBox.expand(key: below),
        child: SizedBox.expand(key: child),
      ),
    ));
    expect(tester.getRect(find.byKey(child)),
        const Rect.fromLTWH(0, 60, 669, 501.75));
    expect(
        tester.getRect(find.byKey(above)), const Rect.fromLTWH(0, 0, 669, 60));
    expect(tester.getTopLeft(find.byKey(below)).dy, closeTo(561.75, 0.001));
  });

  group('duoSplitFrom', () {
    const portrait = Size(669, 951);
    const cover = Size(466, 678);

    test('laptop: the picture ends at the band top, whatever the aspect', () {
      for (final a in <double?>[4 / 3, 16 / 9, null]) {
        final split = duoSplitFrom(_geo(), portrait, isDuo: true, aspect: a)!;
        expect(split.pictureBottom, 455.5, reason: '$a');
        expect(split.deckTop, 455.5, reason: '$a');
      }
    });

    test('flat with a band is the laptop split; without one the picture starts'
        ' 60 pt down', () {
      const openBand = DuoGeometry(
          posture: DuoPosture.open,
          screen: DuoScreen.inner,
          hinge: _band,
          hingeAngle: 180);
      for (final a in <double?>[4 / 3, 16 / 9, null]) {
        expect(duoSplitFrom(openBand, portrait, isDuo: true, aspect: a),
            duoSplitFrom(_geo(), portrait, isDuo: true, aspect: a),
            reason: '$a');
      }
      final split =
          duoSplitFrom(_flat(), portrait, isDuo: true, aspect: 4 / 3)!;
      expect(split.pictureTop, 60);
      expect(split.pictureBottom, closeTo(561.75, 0.001));
      expect(split.deckTop, split.pictureBottom);
      expect(
          duoSplitFrom(_flat(), portrait, isDuo: true, aspect: 1.0)!
              .pictureBottom,
          closeTo(570.6, 0.01));
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

  group('the strip always shows', () {
    const childKey = Key('child');
    const aboveKey = Key('above');
    const belowKey = Key('below');

    Widget body({double? aspect, VoidCallback? onFoldChanged}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: DuoSplitBody(
            aspect: aspect == null ? null : () => aspect,
            onFoldChanged: onFoldChanged,
            above: const SizedBox.expand(key: aboveKey),
            below: const SizedBox.expand(key: belowKey),
            child: const SizedBox.expand(key: childKey),
          ),
        );

    List<Rect> rects(WidgetTester tester) => [
          tester.getRect(find.byKey(childKey)),
          tester.getRect(find.byKey(aboveKey)),
          tester.getRect(find.byKey(belowKey)),
        ];

    testWidgets('4:3: the strip shows and the picture box starts below it',
        (tester) async {
      _setView(tester, const Size(669, 951));
      DuoFold.instance.update(_geo());
      await tester.pumpWidget(body(aspect: 4 / 3));
      expect(tester.getRect(find.byKey(aboveKey)),
          const Rect.fromLTWH(0, 0, 669, 56));
      expect(tester.getRect(find.byKey(childKey)),
          const Rect.fromLTWH(0, 56, 669, 399.5));
    });

    testWidgets('a top padding of 60: the strip still shows', (tester) async {
      _setView(tester, const Size(669, 951));
      tester.view.padding = const FakeViewPadding(top: 60);
      DuoFold.instance.update(_geo());
      await tester.pumpWidget(body(aspect: 16 / 9));
      expect(tester.getRect(find.byKey(aboveKey)),
          const Rect.fromLTWH(0, 60, 669, 56));
    });

    testWidgets('a report without the crease leaves the layout unchanged',
        (tester) async {
      _setView(tester, const Size(669, 951));
      var changes = 0;
      DuoFold.instance.update(_geo());
      await tester
          .pumpWidget(body(aspect: 16 / 9, onFoldChanged: () => changes++));
      final before = rects(tester);
      DuoFold.instance.update(const DuoGeometry(
          posture: DuoPosture.open,
          screen: DuoScreen.unknown,
          hinge: null,
          hingeAngle: null));
      await tester.pump();
      expect(rects(tester), before);
      DuoFold.instance.update(_geo());
      await tester.pump();
      expect(rects(tester), before);
      expect(changes, 0);
    });

    testWidgets('rotation to landscape and back keeps the strip',
        (tester) async {
      _setView(tester, const Size(669, 951));
      DuoFold.instance.update(_geo());
      await tester.pumpWidget(body(aspect: 16 / 9));
      _setView(tester, const Size(951, 669));
      DuoFold.instance
          .update(_geo(hinge: const Rect.fromLTWH(455.5, 0, 40, 669)));
      await tester.pump();
      expect(find.byKey(aboveKey), findsNothing);
      _setView(tester, const Size(669, 951));
      await tester.pump();
      expect(tester.getRect(find.byKey(belowKey)).top, 455.5);
      expect(find.byKey(aboveKey), findsOneWidget);
      DuoFold.instance.update(_geo());
      await tester.pump();
      expect(tester.getRect(find.byKey(belowKey)).top, 455.5);
      expect(find.byKey(aboveKey), findsOneWidget);
    });

    test('the held crease stays with its view size', () {
      const portrait = Size(669, 951);
      const cover = Size(466, 678);
      DuoFold.instance.update(_geo());
      expect(currentDuoSplit(portrait)!.rowBand, _band);
      currentDuoSplit(cover);
      expect(DuoFold.instance.heldBand(cover), isNull);
      DuoFold.instance.update(const DuoGeometry(
          posture: DuoPosture.closed,
          screen: DuoScreen.outer,
          hinge: null,
          hingeAngle: null));
      final split = currentDuoSplit(cover)!;
      expect(split.rowBand, isNull);
      expect(split.pictureBottom, closeTo(305.1, 0.01));
      expect(currentDuoSplit(portrait)!.rowBand, _band);
    });

    testWidgets('a branch change prints one line', (tester) async {
      _setView(tester, const Size(669, 951));
      final lines = <String>[];
      final saved = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => lines.add(m ?? '');
      try {
        DuoFold.instance.update(_geo());
        await tester.pumpWidget(body(aspect: 16 / 9));
        final mount = lines.where((l) => l.startsWith('DuoSplit:')).toList();
        expect(mount, hasLength(1));
        expect(mount.single, contains('layout=crease strip=true'));
        await tester.pumpWidget(body(aspect: 16 / 9));
        expect(lines.where((l) => l.startsWith('DuoSplit:')), hasLength(1));
        _setView(tester, const Size(951, 669));
        await tester.pump();
        final all = lines.where((l) => l.startsWith('DuoSplit:')).toList();
        expect(all, hasLength(2));
        expect(all.last, contains('layout=none'));
      } finally {
        debugPrint = saved;
      }
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
    DuoFold.instance.update(_flat());
    expect(duoCanvasHeight(900, 0, view, aspect: 4 / 3), closeTo(501.75, 0.01));
    DuoFold.instance.update(_geo());
    expect(duoCanvasHeight(900, 50, view), 349.5);
    expect(
        duoCanvasHeight(900, 0, view, aspect: 16 / 9), closeTo(376.31, 0.01));
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
