import 'dart:math';

import 'package:flutter/material.dart';

import 'duo_fold.dart';

/// Lays [child] above the iPhone Duo's fold in the laptop pose and a plain area below it.
/// Without a fold, [child] fills the whole body. [child] keeps its State across changes.
class DuoSplitBody extends StatefulWidget {
  const DuoSplitBody({
    super.key,
    required this.child,
    this.below,
    this.onFoldChanged,
  });

  final Widget child;

  /// Shown below the fold; defaults to [DuoSplitPlaceholder].
  final Widget? below;

  /// Called when the fold's band changes, not at mount.
  final VoidCallback? onFoldChanged;

  @override
  State<DuoSplitBody> createState() => _DuoSplitBodyState();
}

class _DuoSplitBodyState extends State<DuoSplitBody> {
  Rect? _band = DuoFold.instance.laptop.value?.band;

  @override
  void initState() {
    super.initState();
    DuoFold.instance.laptop.addListener(_onFold);
  }

  @override
  void dispose() {
    DuoFold.instance.laptop.removeListener(_onFold);
    super.dispose();
  }

  void _onFold() {
    final band = DuoFold.instance.laptop.value?.band;
    if (band == _band) return;
    setState(() => _band = band);
    widget.onFoldChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final band = _band;
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: band == null ? height : min(band.top, height),
            child: widget.child,
          ),
          if (band != null && height > band.bottom)
            Positioned(
              top: band.bottom,
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

/// The canvas height to use: [h] without a fold, else capped to the area above it.
double duoCanvasHeight(double h, double paddingTop) {
  final fold = DuoFold.instance.laptop.value;
  if (fold == null) return h;
  return max(0, min(h, fold.topHeight - paddingTop));
}
