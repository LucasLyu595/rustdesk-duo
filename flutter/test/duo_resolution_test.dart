import 'dart:ui';

import 'package:duo_display/duo_display.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/mobile/duo/duo_resolution.dart';
import 'package:flutter_hbb/mobile/duo/duo_split.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_test/flutter_test.dart';

List<Resolution> modes(List<List<int>> sizes) =>
    [for (final s in sizes) Resolution(s[0], s[1])];

final k4k = modes([
  [3840, 2160],
  [3360, 1890],
  [3008, 1692],
  [2560, 1440],
  [1920, 1080],
  [1600, 900],
  [1280, 720],
  [1024, 768],
  [800, 600],
]);

String? pick(List<Resolution> m, Size area) {
  final r = chooseDuoResolution(m, area);
  return r == null ? null : '${r.width}x${r.height}';
}

void main() {
  test('laptop area picks the lowest mode of the closest aspect', () {
    expect(pick(k4k, const Size(669, 456)), '800x600');
  });

  test('cover area picks the lowest 16:9 mode', () {
    expect(pick(k4k, const Size(466, 251)), '1280x720');
  });

  test('the mode closest in size is not chosen', () {
    expect(pick(k4k, const Size(1338, 912)), '800x600');
  });

  test('aspect tolerance lets a lower mode beat an exact one; empty is null',
      () {
    final m = modes([
      [1366, 768],
      [1360, 768],
      [1280, 720],
      [1024, 768]
    ]);
    expect(pick(m, const Size(683, 384)), '1280x720');
    expect(pick([], const Size(669, 456)), isNull);
  });

  List<String> run(
    DuoResolutionFit f,
    List<String> sent, {
    Size? area = const Size(669, 456),
    String platform = kPeerPlatformMacOS,
    bool keyboard = true,
    bool viewOnly = false,
    List<Resolution>? modes,
    Size? current = const Size(3840, 2160),
  }) {
    f.tryFit(
      area: area,
      platform: platform,
      keyboard: keyboard,
      viewOnly: viewOnly,
      modes: modes ?? k4k,
      current: current,
      send: (w, h) => sent.add('${w}x$h'),
    );
    return sent;
  }

  test('conditions met send exactly one request per session', () {
    final f = DuoResolutionFit();
    final sent = <String>[];
    run(f, sent);
    run(f, sent);
    run(f, sent, area: const Size(466, 251));
    expect(sent, ['800x600']);
  });

  test('already at the chosen size sends nothing and uses up the session', () {
    final f = DuoResolutionFit();
    final sent = <String>[];
    run(f, sent, current: const Size(800, 600));
    run(f, sent);
    expect(sent, isEmpty);
  });

  test('unmet conditions send nothing until all hold', () {
    final f = DuoResolutionFit();
    final sent = <String>[];
    run(f, sent, platform: 'Windows');
    run(f, sent, keyboard: false);
    run(f, sent, viewOnly: true);
    run(f, sent, modes: modes([[800, 600]]));
    run(f, sent, area: null);
    run(f, sent, current: null);
    expect(sent, isEmpty);
    run(f, sent);
    expect(sent, ['800x600']);
  });

  test('a full-width fit sends the lowest mode at least as wide as the area',
      () {
    final sent = <String>[];
    DuoResolutionFit().tryFit(
      area: const Size(669, 455.5),
      platform: kPeerPlatformMacOS,
      keyboard: true,
      viewOnly: false,
      modes: k4k,
      current: const Size(3840, 2160),
      send: (w, h) => sent.add('${w}x$h'),
      fullWidth: true,
    );
    expect(sent, ['1280x720']);
    final r = chooseDuoResolutionFullWidth(
        modes([
          [1024, 768],
          [800, 600]
        ]),
        const Size(669, 455.5));
    expect('${r!.width}x${r.height}', '800x600');
  });

  test('the laptop fit area ends at the band top and picks 16:9, the rest 4:3',
      () {
    const view = Size(669, 951);
    const band = Rect.fromLTWH(0, 455.5, 669, 40);
    for (final posture in [DuoPosture.book, DuoPosture.open]) {
      final area = duoFitAreaFrom(
          DuoGeometry(
              posture: posture,
              screen: DuoScreen.inner,
              hinge: band,
              hingeAngle: 90),
          view,
          isDuo: true)!;
      expect(area, Size(669, posture == DuoPosture.book ? 455.5 : 495.5));
      if (posture == DuoPosture.book) {
        final r = chooseDuoResolutionFullWidth(k4k, area)!;
        expect('${r.width}x${r.height}', '1280x720');
      } else {
        expect(pick(k4k, area), '800x600');
      }
    }
    final flat = duoFitAreaFrom(
        const DuoGeometry(
            posture: DuoPosture.open,
            screen: DuoScreen.inner,
            hinge: null,
            hingeAngle: 180),
        view,
        isDuo: true)!;
    expect(flat.height, closeTo(570.6, 0.01));
    expect(pick(k4k, flat), '800x600');
    final cover = duoFitAreaFrom(null, const Size(466, 678), isDuo: true)!;
    expect(cover.height, closeTo(305.1, 0.01));
    expect(pick(k4k, cover), '800x600');
    expect(duoFitAreaFrom(null, view, isDuo: false), isNull);
  });
}
