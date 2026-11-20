import 'dart:ui';

import 'package:duo_display/duo_display.dart';
import 'package:flutter_hbb/mobile/duo/duo_fold.dart';
import 'package:flutter_test/flutter_test.dart';

// Shapes measured on the iOS 27.1 iPhone Duo simulator (669x951 pt inner display upright,
// a 40 pt division band centred on the crease).
const _laptopBand = Rect.fromLTWH(0, 455.5, 669, 40);
const _bookBand = Rect.fromLTWH(455.5, 0, 40, 669);

DuoGeometry _geo({
  DuoPosture posture = DuoPosture.book,
  DuoScreen screen = DuoScreen.inner,
  Rect? hinge = _laptopBand,
  double? angle = 90,
}) =>
    DuoGeometry(
        posture: posture, screen: screen, hinge: hinge, hingeAngle: angle);

void main() {
  group('laptopFoldFrom', () {
    test('upright and half folded gives the fold', () {
      final fold = laptopFoldFrom(_geo());
      expect(fold, isNotNull);
      expect(fold!.topHeight, 455.5);
      expect(fold.bottomStart, 495.5);
      expect(fold.hingeAngle, 90);
    });

    test('sideways book pose is not the laptop pose', () {
      expect(laptopFoldFrom(_geo(hinge: _bookBand)), isNull);
    });

    test('open flat, closed, cover display or no band gives nothing', () {
      expect(laptopFoldFrom(_geo(posture: DuoPosture.open)), isNull);
      expect(laptopFoldFrom(_geo(posture: DuoPosture.closed)), isNull);
      expect(laptopFoldFrom(_geo(screen: DuoScreen.outer)), isNull);
      expect(laptopFoldFrom(_geo(hinge: null)), isNull);
      expect(laptopFoldFrom(_geo(hinge: Rect.zero)), isNull);
      expect(laptopFoldFrom(_geo(posture: DuoPosture.unsupported)), isNull);
    });
  });

  test('DuoFold.update tracks the pose', () {
    final duo = DuoFold.instance;
    duo.update(_geo());
    expect(duo.laptop.value, isNotNull);
    duo.update(_geo(posture: DuoPosture.open));
    expect(duo.laptop.value, isNull);
    expect(duo.geometry.value?.posture, DuoPosture.open);
  });
}
