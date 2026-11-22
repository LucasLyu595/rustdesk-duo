import 'dart:math';

import 'package:duo_display/duo_display.dart';
import 'package:flutter/material.dart';

import '../../models/model.dart' show PeerInfo;
import 'duo_fold.dart';

/// Where the remote picture ends and the deck starts, from the top of the view.
@immutable
class DuoSplit {
  const DuoSplit(
      {required this.pictureBottom, required this.deckTop, this.crease});

  final double pictureBottom;
  final double deckTop;

  /// The strip of the picture that takes no touches, in the laptop pose.
  final Rect? crease;

  @override
  bool operator ==(Object other) =>
      other is DuoSplit &&
      other.pictureBottom == pictureBottom &&
      other.deckTop == deckTop &&
      other.crease == crease;

  @override
  int get hashCode => Object.hash(pictureBottom, deckTop, crease);
}

/// The share of a portrait view given to the picture when the fold reports no
/// usable band.
const double kDuoPictureFraction = 0.45;

/// How far the deck may give way so a laptop-pose picture fills the width.
const double kDuoDeckGive = 12;

/// The largest share of a flat inner view the picture may take.
const double kDuoFlatPictureFraction = 0.6;

Rect? _usableBand(DuoGeometry? geometry, Size viewSize) {
  final band = geometry?.hinge;
  if (band != null &&
      !band.isEmpty &&
      band.width > band.height &&
      band.top > 0 &&
      band.bottom < viewSize.height) {
    return band;
  }
  return null;
}

/// The peer's current display width / height, or null when unknown.
double? duoPeerAspect(PeerInfo? pi) {
  final d = pi?.tryGetDisplayIfNotAllDisplay();
  if (d == null || d.width <= 0 || d.height <= 0) return null;
  return d.width / d.height;
}

/// The split for a Duo in portrait, or null (not a Duo, or a landscape view).
DuoSplit? duoSplitFrom(DuoGeometry? geometry, Size viewSize,
    {required bool isDuo, double paddingTop = 0, double? aspect}) {
  if (!isDuo || viewSize.width >= viewSize.height) return null;
  final band = _usableBand(geometry, viewSize);
  final full = aspect == null ? null : paddingTop + viewSize.width / aspect;
  final laptop = geometry != null && laptopFoldFrom(geometry) != null;
  if (band != null && laptop) {
    final y =
        full != null && full > band.bottom && full <= band.bottom + kDuoDeckGive
            ? full
            : band.bottom;
    return DuoSplit(pictureBottom: y, deckTop: y, crease: band);
  }
  if (geometry?.screen == DuoScreen.inner && !laptop && full != null) {
    final y = min(full, kDuoFlatPictureFraction * viewSize.height);
    return DuoSplit(pictureBottom: y, deckTop: y);
  }
  if (band != null) {
    return DuoSplit(pictureBottom: band.top, deckTop: band.bottom);
  }
  final y = kDuoPictureFraction * viewSize.height;
  return DuoSplit(pictureBottom: y, deckTop: y);
}

DuoSplit? currentDuoSplit(Size viewSize,
        {double paddingTop = 0, double? aspect}) =>
    duoSplitFrom(DuoFold.instance.geometry.value, viewSize,
        isDuo: DuoFold.instance.isDuo, paddingTop: paddingTop, aspect: aspect);

/// The picture area auto-fit aims at; it does not depend on the peer's picture.
Size? duoFitAreaFrom(DuoGeometry? geometry, Size viewSize,
    {required bool isDuo, double paddingTop = 0}) {
  final split = duoSplitFrom(geometry, viewSize, isDuo: isDuo);
  if (split == null) return null;
  if (geometry?.screen == DuoScreen.inner) {
    final band = _usableBand(geometry, viewSize);
    if (band != null) return Size(viewSize.width, band.bottom - paddingTop);
    if (laptopFoldFrom(geometry!) == null) {
      return Size(viewSize.width,
          kDuoFlatPictureFraction * viewSize.height - paddingTop);
    }
  }
  return Size(viewSize.width, split.pictureBottom - paddingTop);
}

Size? currentDuoFitArea(Size viewSize, {double paddingTop = 0}) =>
    duoFitAreaFrom(DuoFold.instance.geometry.value, viewSize,
        isDuo: DuoFold.instance.isDuo, paddingTop: paddingTop);

/// Lays [child] above the iPhone Duo's split and a plain area below it.
/// Without a split, [child] fills the whole body. [child] keeps its State across
/// changes.
class DuoSplitBody extends StatefulWidget {
  const DuoSplitBody({
    super.key,
    required this.child,
    this.below,
    this.onFoldChanged,
    this.aspect,
    this.aspectChanged,
  });

  final Widget child;

  /// Shown below the split; defaults to [DuoSplitPlaceholder].
  final Widget? below;

  /// Called when the split changes, not at mount.
  final VoidCallback? onFoldChanged;

  /// The peer picture's width / height, or null when unknown.
  final ValueGetter<double?>? aspect;

  /// Notifies when [aspect] may have changed.
  final Listenable? aspectChanged;

  @override
  State<DuoSplitBody> createState() => _DuoSplitBodyState();
}

class _DuoSplitBodyState extends State<DuoSplitBody> {
  DuoSplit? _split;
  Size? _view;
  double _top = 0;

  DuoSplit? _current() =>
      currentDuoSplit(_view!, paddingTop: _top, aspect: widget.aspect?.call());

  @override
  void initState() {
    super.initState();
    DuoFold.instance.geometry.addListener(_onFold);
    widget.aspectChanged?.addListener(_onAspect);
  }

  @override
  void didUpdateWidget(DuoSplitBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aspectChanged != widget.aspectChanged) {
      oldWidget.aspectChanged?.removeListener(_onAspect);
      widget.aspectChanged?.addListener(_onAspect);
    }
  }

  @override
  void dispose() {
    DuoFold.instance.geometry.removeListener(_onFold);
    widget.aspectChanged?.removeListener(_onAspect);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final first = _view == null;
    _view = MediaQuery.sizeOf(context);
    _top = MediaQuery.paddingOf(context).top;
    final split = _current();
    final changed = split != _split;
    _split = split;
    if (!first && changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFoldChanged?.call();
      });
    }
  }

  void _onFold() {
    final split = _current();
    if (split == _split) return;
    setState(() => _split = split);
    widget.onFoldChanged?.call();
  }

  void _onAspect() {
    final split = _current();
    if (split != _split) setState(() => _split = split);
  }

  @override
  Widget build(BuildContext context) {
    final split = _split;
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: split == null ? height : min(split.pictureBottom, height),
            child: widget.child,
          ),
          if (split?.crease != null)
            Positioned.fromRect(
                rect: split!.crease!, child: const AbsorbPointer()),
          if (split != null && height > split.deckTop)
            Positioned(
              top: split.deckTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: widget.below ?? const DuoSplitPlaceholder(),
            ),
        ]);
      }),
    );
  }
}

/// Empty, non-interactive stand-in for the area below the fold.
class DuoSplitPlaceholder extends StatelessWidget {
  const DuoSplitPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

/// The canvas height to use: [h] without a split, else capped to the picture
/// area.
double duoCanvasHeight(double h, double paddingTop, Size viewSize,
    {double? aspect}) {
  final split =
      currentDuoSplit(viewSize, paddingTop: paddingTop, aspect: aspect);
  if (split == null) return h;
  return max(0, min(h, split.pictureBottom - paddingTop));
}
