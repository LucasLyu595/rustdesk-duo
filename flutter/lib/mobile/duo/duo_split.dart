import 'dart:math';

import 'package:duo_display/duo_display.dart';
import 'package:flutter/material.dart';

import '../../models/model.dart' show PeerInfo;
import 'duo_fold.dart';

/// Where the remote picture ends and the deck starts, from the top of the view.
@immutable
class DuoSplit {
  const DuoSplit(
      {required this.pictureBottom,
      required this.deckTop,
      this.rowBand,
      this.pictureTop = 0});

  final double pictureBottom;
  final double deckTop;

  /// The band the deck's session row sits in, when the picture rests on it.
  final Rect? rowBand;

  /// Where the picture starts when it sits below a top strip; 0 when it starts
  /// at the view's top inset.
  final double pictureTop;

  @override
  bool operator ==(Object other) =>
      other is DuoSplit &&
      other.pictureBottom == pictureBottom &&
      other.deckTop == deckTop &&
      other.rowBand == rowBand &&
      other.pictureTop == pictureTop;

  @override
  int get hashCode => Object.hash(pictureBottom, deckTop, rowBand, pictureTop);
}

/// The share of a portrait view given to the picture when the fold reports no
/// usable band.
const double kDuoPictureFraction = 0.45;

/// The least height above a picture that shows [DuoSplitBody.above].
const double kDuoStripMinExtent = 24;

/// The largest share of a flat inner view the picture may take.
const double kDuoFlatPictureFraction = 0.6;

/// The strip above a flat picture without a band, clear of the inner screen's
/// rounded top corners.
const double kDuoTopClear = 60;

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
  if (band != null && geometry?.screen == DuoScreen.inner) {
    return DuoSplit(
        pictureBottom: band.top,
        deckTop: band.top,
        rowBand: band,
        pictureTop: full != null && full < band.top
            ? band.top - (full - paddingTop)
            : 0);
  }
  if (geometry?.screen == DuoScreen.inner && !laptop && full != null) {
    final top = paddingTop + kDuoTopClear;
    final y = min(top + viewSize.width / aspect!,
        kDuoFlatPictureFraction * viewSize.height);
    return DuoSplit(pictureBottom: y, deckTop: y, pictureTop: top);
  }
  if (band != null) {
    return DuoSplit(pictureBottom: band.top, deckTop: band.bottom);
  }
  final y = kDuoPictureFraction * viewSize.height;
  return DuoSplit(pictureBottom: y, deckTop: y);
}

/// How far below the view's top the picture child starts.
double duoPictureOffset(DuoSplit? split, double paddingTop) =>
    split == null ? 0 : max(0, split.pictureTop - paddingTop);

DuoSplit? currentDuoSplit(Size viewSize,
        {double paddingTop = 0, double? aspect}) =>
    duoSplitFrom(DuoFold.instance.geometry.value, viewSize,
        isDuo: DuoFold.instance.isDuo, paddingTop: paddingTop, aspect: aspect);

/// The picture area auto-fit aims at; it does not depend on the peer's picture.
Size? duoFitAreaFrom(DuoGeometry? geometry, Size viewSize,
    {required bool isDuo, double paddingTop = 0}) {
  final split = duoSplitFrom(geometry, viewSize, isDuo: isDuo);
  if (split == null) return null;
  if (_flatWithoutBand(geometry, viewSize)) {
    return Size(viewSize.width,
        kDuoFlatPictureFraction * viewSize.height - paddingTop - kDuoTopClear);
  }
  return Size(viewSize.width, split.pictureBottom - paddingTop);
}

bool _flatWithoutBand(DuoGeometry? geometry, Size viewSize) =>
    geometry?.screen == DuoScreen.inner &&
    _usableBand(geometry, viewSize) == null &&
    laptopFoldFrom(geometry!) == null;

/// Whether auto-fit wants a mode at least as wide as the picture area: the
/// picture rests on the crease or fills the width below the top strip.
bool duoFitFullWidthFrom(DuoGeometry? geometry, Size viewSize,
        {required bool isDuo}) =>
    duoSplitFrom(geometry, viewSize, isDuo: isDuo)?.rowBand != null ||
    (isDuo &&
        viewSize.width < viewSize.height &&
        _flatWithoutBand(geometry, viewSize));

bool currentDuoFitFullWidth(Size viewSize) => duoFitFullWidthFrom(
    DuoFold.instance.geometry.value, viewSize,
    isDuo: DuoFold.instance.isDuo);

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
    this.above,
    this.onFoldChanged,
    this.aspect,
    this.aspectChanged,
  });

  final Widget child;

  /// Shown below the split; defaults to [DuoSplitPlaceholder].
  final Widget? below;

  /// Shown above the picture when there is room.
  final Widget? above;

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
        final top = duoPictureOffset(split, _top);
        return Stack(children: [
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: max(0.0,
                (split == null ? height : min(split.pictureBottom, height)) -
                    top),
            child: widget.child,
          ),
          if (widget.above != null && top >= kDuoStripMinExtent)
            Positioned(
                top: _top,
                left: 0,
                right: 0,
                height: top,
                child: widget.above!),
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
  return max(
      0, min(h, split.pictureBottom - max(split.pictureTop, paddingTop)));
}
