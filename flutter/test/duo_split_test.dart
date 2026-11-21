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
  tearDown(() => DuoFold.instance.update(_flat()));

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
        const Rect.fromLTWH(0, 0, 669, 455.5));
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
    expect(tester.getSize(find.byKey(probeKey)).height, 455.5);
    expect(find.byType(DuoSplitPlaceholder), findsOneWidget);
    expect(changes, 1);

    DuoFold.instance.update(_geo(angle: 80));
    await tester.pump();
    expect(changes, 1);

    DuoFold.instance.update(_flat());
    await tester.pump();
    expect(tester.getSize(find.byKey(probeKey)).height, 951);
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
    expect(changes, 2);
    expect(probeKey.currentState, same(state));
  });

  testWidgets('body shorter than the fold: no overflow, no placeholder',
      (tester) async {
    _setView(tester, const Size(669, 480));
    DuoFold.instance.update(_geo());
    const childKey = Key('child');
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: DuoSplitBody(child: SizedBox.expand(key: childKey)),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
    expect(tester.getSize(find.byKey(childKey)).height, 455.5);

    _setView(tester, const Size(669, 400));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(DuoSplitPlaceholder), findsNothing);
    expect(tester.getSize(find.byKey(childKey)).height, 400);
  });

  test('duoCanvasHeight caps the height above the fold only', () {
    expect(duoCanvasHeight(900, 50), 900);
    DuoFold.instance.update(_geo());
    expect(duoCanvasHeight(900, 50), 405.5);
    expect(duoCanvasHeight(300, 50), 300);
    expect(duoCanvasHeight(900, 500), 0);
  });
}
