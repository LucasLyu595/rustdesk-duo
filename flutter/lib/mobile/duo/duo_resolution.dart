import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import 'duo_split.dart';

/// How much farther than the best aspect distance a mode may be and still tie.
const double kDuoAspectTolerance = 0.02;

/// macOS lists modes shorter than this but refuses to set them as the desktop
/// mode.
const int kDuoMinMacModeHeight = 540;

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

/// Among the modes at least as wide as [area] in aspect, the closest, then the
/// lowest; without such a mode, [chooseDuoResolution].
Resolution? chooseDuoResolutionFullWidth(List<Resolution> modes, Size area) {
  if (area.width <= 0 || area.height <= 0) return null;
  final target = area.width / area.height;
  final wide =
      modes.where((m) => m.height > 0 && m.width / m.height >= target);
  return chooseDuoResolution(wide.isEmpty ? modes : wide.toList(), area);
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
    bool fullWidth = false,
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
    final usable =
        modes.where((m) => m.height >= kDuoMinMacModeHeight).toList();
    final mode = (fullWidth
        ? chooseDuoResolutionFullWidth
        : chooseDuoResolution)(usable.isEmpty ? modes : usable, area);
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
      final pi = ffi.ffiModel.pi;
      final d = pi.isSet.isTrue
          ? pi.tryGetDisplayIfNotAllDisplay(display: pi.currentDisplay)
          : null;
      tryFit(
        area: currentDuoFitArea(media.size, paddingTop: media.padding.top),
        platform: pi.platform,
        keyboard: ffi.ffiModel.keyboard,
        viewOnly: ffi.ffiModel.viewOnly,
        modes: pi.resolutions,
        fullWidth: currentDuoFitFullWidth(media.size),
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
