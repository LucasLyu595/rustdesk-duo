import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import 'duo_split.dart';

/// How much farther than the best aspect distance a mode may be and still tie.
const double kDuoAspectTolerance = 0.02;

/// The mode closest in aspect to [area], then the lowest, for the largest UI.
Resolution? chooseDuoResolution(List<Resolution> modes, Size area) {
  if (area.width <= 0 || area.height <= 0) return null;
  final target = area.width / area.height;
  final valid = modes.where((m) => m.width > 0 && m.height > 0).toList();
  if (valid.isEmpty) return null;
  double distance(Resolution m) => log(m.width / m.height / target).abs();
  final best = valid.map(distance).reduce(min);
  Resolution? pick;
  for (final m in valid) {
    if (distance(m) > best + kDuoAspectTolerance) continue;
    if (pick == null ||
        m.width < pick.width ||
        (m.width == pick.width && m.height < pick.height)) {
      pick = m;
    }
  }
  return pick;
}

typedef DuoResolutionSender = void Function(int width, int height);

/// Sets the peer's display mode once per session, when a Duo deck shows.
class DuoResolutionFit {
  bool _done = false;
  bool _scheduled = false;

  void tryFit({
    required Size? area,
    required String platform,
    required bool keyboard,
    required bool viewOnly,
    required List<Resolution> modes,
    required Size? current,
    required DuoResolutionSender send,
  }) {
    if (_done) return;
    if (area == null ||
        platform != kPeerPlatformMacOS ||
        !keyboard ||
        viewOnly ||
        modes.length <= 1 ||
        current == null) {
      return;
    }
    final mode = chooseDuoResolution(modes, area);
    if (mode == null) return;
    _done = true;
    if (mode.width != current.width.round() ||
        mode.height != current.height.round()) {
      send(mode.width, mode.height);
    }
  }

  void schedule(FFI ffi, BuildContext context) {
    if (_done || _scheduled) return;
    _scheduled = true;
    final view = View.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final media = MediaQueryData.fromView(view);
      final split = currentDuoSplit(media.size);
      final pi = ffi.ffiModel.pi;
      final d = pi.isSet.isTrue
          ? pi.tryGetDisplayIfNotAllDisplay(display: pi.currentDisplay)
          : null;
      tryFit(
        area: split == null
            ? null
            : Size(media.size.width, split.pictureBottom - media.padding.top),
        platform: pi.platform,
        keyboard: ffi.ffiModel.keyboard,
        viewOnly: ffi.ffiModel.viewOnly,
        modes: pi.resolutions,
        current: d == null ? null : Size(d.width / d.scale, d.height / d.scale),
        send: (w, h) => bind.sessionChangeResolution(
            sessionId: ffi.sessionId,
            display: pi.currentDisplay,
            width: w,
            height: h),
      );
    });
  }
}
