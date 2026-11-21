// iPhone Duo support: where the fold is, so the remote picture can sit above it and the
// keyboard and trackpad below it ("laptop pose": inner display upright, half folded).
//
// The fold comes from the duo_display plugin, which reads iOS 27.1's reserved regions and
// hinge. On every other device, and before iOS 27.1, nothing is reported and [DuoFold.laptop]
// stays null, so RustDesk behaves exactly as upstream.

import 'dart:async';
import 'dart:ui' show Rect;

import 'package:duo_display/duo_display.dart';
import 'package:flutter/foundation.dart';

/// Builds with `--dart-define=DUO_DEBUG=true` draw the fold over the remote page.
const bool kDuoDebug = bool.fromEnvironment('DUO_DEBUG');

/// The fold of an iPhone Duo held like a laptop, in the Flutter view's logical pixels
/// (the same space as `MediaQuery`).
@immutable
class DuoLaptopFold {
  const DuoLaptopFold({required this.band, required this.hingeAngle});

  /// The strip to keep interactive content out of: the crease plus its margins.
  final Rect band;

  /// Degrees, 0 closed to 180 flat, when known.
  final double? hingeAngle;

  /// Height of the area above the fold, from the top of the view.
  double get topHeight => band.top;

  /// Where the area below the fold starts, from the top of the view.
  double get bottomStart => band.bottom;

  @override
  bool operator ==(Object other) =>
      other is DuoLaptopFold &&
      other.band == band &&
      other.hingeAngle == hingeAngle;

  @override
  int get hashCode => Object.hash(band, hingeAngle);

  @override
  String toString() => 'DuoLaptopFold(band: $band, hingeAngle: $hingeAngle)';
}

/// The laptop pose's fold, or null when the device is not held that way: not a Duo, closed
/// (the cover display), open flat, or half folded sideways like a book (a vertical band).
DuoLaptopFold? laptopFoldFrom(DuoGeometry geometry) {
  final band = geometry.hinge;
  if (geometry.screen != DuoScreen.inner ||
      geometry.posture != DuoPosture.book ||
      band == null ||
      band.isEmpty) {
    return null;
  }
  // Upright, the fold runs across the screen: wider than tall.
  if (band.width < band.height) return null;
  return DuoLaptopFold(band: band, hingeAngle: geometry.hingeAngle);
}

/// App-wide view of the Duo's fold. Call [start] once; listen to [laptop].
class DuoFold {
  DuoFold._();

  static final DuoFold instance = DuoFold._();

  /// The current laptop-pose fold, or null.
  final ValueNotifier<DuoLaptopFold?> laptop = ValueNotifier(null);

  /// The last geometry the device reported, for the debug overlay.
  final ValueNotifier<DuoGeometry?> geometry = ValueNotifier(null);

  /// True once any report showed the inner screen or a hinge angle; never
  /// cleared in an app run.
  bool get isDuo => _isDuo;
  bool _isDuo = false;

  StreamSubscription<DuoGeometry>? _subscription;

  /// Starts listening on iOS. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _subscription = DuoDisplay.geometry.listen(
      update,
      onError: (Object error) => debugPrint('DuoFold: $error'),
    );
  }

  /// Applies one geometry report. Public for tests.
  @visibleForTesting
  void update(DuoGeometry next) {
    if (next.screen == DuoScreen.inner || next.hingeAngle != null) {
      _isDuo = true;
    }
    geometry.value = next;
    laptop.value = laptopFoldFrom(next);
  }

  @visibleForTesting
  void reset() {
    _isDuo = false;
    geometry.value = null;
    laptop.value = null;
  }
}
