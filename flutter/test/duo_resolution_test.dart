import 'dart:ui';

import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/mobile/duo/duo_resolution.dart';
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
}
