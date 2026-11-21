import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/duo/duo_trackpad.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements DuoPointerSink {
  final List<String> log = [];

  @override
  void move(Offset delta) => log.add('move ${delta.dx},${delta.dy}');
  @override
  void click(DuoButton button) => log.add('click ${button.name}');
  @override
  void buttonDown() => log.add('down');
  @override
  void buttonUp() => log.add('up');
  @override
  void scroll(int step) => log.add('scroll $step');

  Offset get movedSum {
    var sum = Offset.zero;
    for (final e in log.where((e) => e.startsWith('move '))) {
      final p = e.substring(5).split(',');
      sum += Offset(double.parse(p[0]), double.parse(p[1]));
    }
    return sum;
  }
}

Duration _ms(int v) => Duration(milliseconds: v);

Future<_Sink> _pump(WidgetTester tester) async {
  final sink = _Sink();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(width: 300, height: 200, child: DuoTrackpad(sink: sink)),
    ),
  ));
  return sink;
}

void main() {
  const a = Offset(300, 300);
  const b = Offset(360, 300);

  testWidgets('one-finger drag moves the cursor and does not click',
      (tester) async {
    final sink = await _pump(tester);
    final g = await tester.createGesture(pointer: 1);
    await g.down(a, timeStamp: _ms(0));
    await g.moveBy(const Offset(10, 4), timeStamp: _ms(16));
    await g.moveBy(const Offset(10, 4), timeStamp: _ms(32));
    await g.moveBy(const Offset(10, 4), timeStamp: _ms(48));
    await g.up(timeStamp: _ms(64));
    expect(sink.movedSum, const Offset(30, 12));
    expect(sink.log.where((e) => !e.startsWith('move ')), isEmpty);
  });

  testWidgets('one-finger tap is a left click with no move', (tester) async {
    final sink = await _pump(tester);
    final g = await tester.createGesture(pointer: 1);
    await g.down(a, timeStamp: _ms(0));
    await g.up(timeStamp: _ms(80));
    expect(sink.log, ['click left']);
  });

  testWidgets('two-finger tap is a right click', (tester) async {
    final sink = await _pump(tester);
    final g1 = await tester.createGesture(pointer: 1);
    final g2 = await tester.createGesture(pointer: 2);
    await g1.down(a, timeStamp: _ms(0));
    await g2.down(b, timeStamp: _ms(10));
    await g2.up(timeStamp: _ms(90));
    await g1.up(timeStamp: _ms(100));
    expect(sink.log, ['click right']);
  });

  testWidgets('two-finger drag scrolls by steps only', (tester) async {
    final sink = await _pump(tester);
    final g1 = await tester.createGesture(pointer: 1);
    final g2 = await tester.createGesture(pointer: 2);
    await g1.down(a, timeStamp: _ms(0));
    await g2.down(b, timeStamp: _ms(10));
    var t = 20;
    for (var i = 0; i < 4; i++) {
      await g1.moveBy(const Offset(0, 10), timeStamp: _ms(t += 16));
      await g2.moveBy(const Offset(0, 10), timeStamp: _ms(t += 16));
    }
    await g2.up(timeStamp: _ms(400));
    await g1.up(timeStamp: _ms(410));
    expect(sink.log, isNotEmpty);
    expect(sink.log.toSet(), {'scroll 1'});

    sink.log.clear();
    await g1.down(a, timeStamp: _ms(1000));
    await g2.down(b, timeStamp: _ms(1010));
    t = 1020;
    for (var i = 0; i < 4; i++) {
      await g1.moveBy(const Offset(0, -10), timeStamp: _ms(t += 16));
      await g2.moveBy(const Offset(0, -10), timeStamp: _ms(t += 16));
    }
    await g2.up(timeStamp: _ms(1400));
    await g1.up(timeStamp: _ms(1410));
    expect(sink.log, isNotEmpty);
    expect(sink.log.toSet(), {'scroll -1'});
  });

  testWidgets('tap then touch again and drag holds the button', (tester) async {
    final sink = await _pump(tester);
    final g = await tester.createGesture(pointer: 1);
    await g.down(a, timeStamp: _ms(0));
    await g.up(timeStamp: _ms(60));
    await g.down(a, timeStamp: _ms(200));
    await g.moveBy(const Offset(20, 0), timeStamp: _ms(216));
    await g.moveBy(const Offset(10, 6), timeStamp: _ms(232));
    await g.up(timeStamp: _ms(248));
    expect(sink.log,
        ['click left', 'down', 'move 20.0,0.0', 'move 10.0,6.0', 'up']);
  });

  testWidgets('tap then two-finger scroll within the drag window only scrolls',
      (tester) async {
    final sink = await _pump(tester);
    final g1 = await tester.createGesture(pointer: 1);
    final g2 = await tester.createGesture(pointer: 2);
    await g1.down(a, timeStamp: _ms(0));
    await g1.up(timeStamp: _ms(60));
    sink.log.clear();
    await g1.down(a, timeStamp: _ms(200));
    await g2.down(b, timeStamp: _ms(210));
    var t = 220;
    for (var i = 0; i < 4; i++) {
      await g1.moveBy(const Offset(0, 10), timeStamp: _ms(t += 16));
      await g2.moveBy(const Offset(0, 10), timeStamp: _ms(t += 16));
    }
    await g2.up(timeStamp: _ms(400));
    await g1.up(timeStamp: _ms(410));
    expect(sink.log, isNotEmpty);
    expect(sink.log.toSet(), {'scroll 1'});
  });

  testWidgets('tap then two-finger tap within the drag window right-clicks',
      (tester) async {
    final sink = await _pump(tester);
    final g1 = await tester.createGesture(pointer: 1);
    final g2 = await tester.createGesture(pointer: 2);
    await g1.down(a, timeStamp: _ms(0));
    await g1.up(timeStamp: _ms(60));
    await g1.down(a, timeStamp: _ms(200));
    await g2.down(b, timeStamp: _ms(210));
    await g2.up(timeStamp: _ms(260));
    await g1.up(timeStamp: _ms(270));
    expect(sink.log, ['click left', 'click right']);
  });
}
