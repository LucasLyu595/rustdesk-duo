import 'package:flutter/material.dart';

import 'duo_fold.dart';

/// Debug only (`--dart-define=DUO_DEBUG=true`): shades the fold band and prints what the
/// device reports, so a real iPhone Duo can show whether the fold is detected. Ignores touches.
class DuoFoldDebugOverlay extends StatelessWidget {
  const DuoFoldDebugOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder(
        valueListenable: DuoFold.instance.geometry,
        builder: (context, geometry, _) {
          final fold = DuoFold.instance.laptop.value;
          final label = geometry == null
              ? 'Duo: no geometry reported'
              : 'Duo: ${geometry.screen.name}, ${geometry.posture.name}, '
                  '${geometry.hingeAngle?.toStringAsFixed(0) ?? '?'}°, '
                  'band ${_rect(geometry.hinge)}, '
                  'laptop ${fold == null ? 'no' : 'yes'}';
          return Stack(
            children: [
              if (geometry?.hinge != null)
                Positioned.fromRect(
                  rect: geometry!.hinge!,
                  child: Container(color: const Color(0x55FF9800)),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: const Color(0xAA000000),
                  child: Text(
                    label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        decoration: TextDecoration.none),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "left,top widthxheight" in logical pixels. Rect.toString() is stripped in release builds.
String _rect(Rect? r) => r == null
    ? 'none'
    : '${r.left.toStringAsFixed(0)},${r.top.toStringAsFixed(0)} '
        '${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}';
