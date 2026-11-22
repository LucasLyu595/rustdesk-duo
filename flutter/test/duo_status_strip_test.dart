import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/duo/duo_status_strip.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
