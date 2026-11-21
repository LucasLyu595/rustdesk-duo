import 'dart:math';

import 'package:duo_display/duo_display.dart';
import 'package:flutter/material.dart';

import 'duo_fold.dart';

/// Where the remote picture ends and the deck starts, from the top of the view.
@immutable
class DuoSplit {
  const DuoSplit({required this.pictureBottom, required this.deckTop});

  final double pictureBottom;
  final double deckTop;

  @override
  bool operator ==(Object other) =>
      other is DuoSplit &&
      other.pictureBottom == pictureBottom &&
      other.deckTop == deckTop;

  @override
  int get hashCode => Object.hash(pictureBottom, deckTop);
}

/// The share of a portrait view given to the picture when the fold reports no
/// usable band.
const double kDuoPictureFraction = 0.45;

/// The split for a Duo in portrait, or null (not a Duo, or a landscape view).
DuoSplit? duoSplitFrom(DuoGeometry? geometry, Size viewSize,
    {required bool isDuo}) {
  if (!isDuo || viewSize.width >= viewSize.height) return null;
  final band = geometry?.hinge;
  if (band != null &&
      !band.isEmpty &&
      band.width > band.height &&
      band.top > 0 &&
      band.bottom < viewSize.height) {
    return DuoSplit(pictureBottom: band.top, deckTop: band.bottom);
  }
  final y = kDuoPictureFraction * viewSize.height;
  return DuoSplit(pictureBottom: y, deckTop: y);
}

DuoSplit? currentDuoSplit(Size viewSize) => duoSplitFrom(
    DuoFold.instance.geometry.value, viewSize,
    isDuo: DuoFold.instance.isDuo);

/// Lays [child] above the iPhone Duo's split and a plain area below it.
/// Without a split, [child] fills the whole body. [child] keeps its State across
/// changes.
class DuoSplitBody extends StatefulWidget {
  const DuoSplitBody({
    super.key,
    required this.child,
    this.below,
    this.onFoldChanged,
  });

  final Widget child;

  /// Shown below the split; defaults to [DuoSplitPlaceholder].
  final Widget? below;

  /// Called when the split changes, not at mount.
  final VoidCallback? onFoldChanged;

  @override
  State<DuoSplitBody> createState() => _DuoSplitBodyState();
}

class _DuoSplitBodyState extends State<DuoSplitBody> {
  DuoSplit? _split;
  Size? _view;

  @override
  void initState() {
    super.initState();
    DuoFold.instance.geometry.addListener(_onFold);
  }

  @override
  void dispose() {
    DuoFold.instance.geometry.removeListener(_onFold);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = MediaQuery.sizeOf(context);
    final split = currentDuoSplit(view);
    final changed = split != _split;
    final first = _view == null;
    _view = view;
    _split = split;
    if (!first && changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFoldChanged?.call();
      });
    }
  }

  void _onFold() {
    final split = currentDuoSplit(_view!);
    if (split == _split) return;
    setState(() => _split = split);
    widget.onFoldChanged?.call();
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
double duoCanvasHeight(double h, double paddingTop, Size viewSize) {
  final split = currentDuoSplit(viewSize);
  if (split == null) return h;
  return max(0, min(h, split.pictureBottom - paddingTop));
}
