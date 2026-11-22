import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/model.dart' show FFI;

/// One non-interactive status line for the strip above a laptop-pose picture.
class DuoStatusStrip extends StatefulWidget {
  const DuoStatusStrip({
    super.key,
    this.name,
    this.delay,
    this.changed,
    this.now = DateTime.now,
  });

  /// The peer's name, or null when unknown.
  final ValueGetter<String?>? name;

  /// The round-trip delay in ms, or null when the session has not reported it.
  final ValueGetter<String?>? delay;

  /// Notifies when [name] or [delay] may have changed.
  final Listenable? changed;

  final ValueGetter<DateTime> now;

  factory DuoStatusStrip.forSession(FFI ffi, String id) => DuoStatusStrip(
        name: () => ffi.ffiModel.pi.hostname.isNotEmpty
            ? ffi.ffiModel.pi.hostname
            : id,
        delay: () => ffi.qualityMonitorModel.data.delay,
        changed: ffi.qualityMonitorModel,
      );

  @override
  State<DuoStatusStrip> createState() => _DuoStatusStripState();
}

class _DuoStatusStripState extends State<DuoStatusStrip> {
  late String _text = _line();
  Timer? _timer;

  String _line() {
    final now = widget.now();
    final name = widget.name?.call();
    final delay = widget.delay?.call();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return [
      if (name != null && name.isNotEmpty) name,
      if (delay != null && delay.isNotEmpty) '$delay ms',
      '$hh:$mm',
    ].join('  ·  ');
  }

  void _refresh() {
    final text = _line();
    if (text != _text) setState(() => _text = text);
  }

  void _tick() {
    _refresh();
    _arm();
  }

  void _arm() =>
      _timer = Timer(Duration(seconds: 60 - widget.now().second), _tick);

  @override
  void initState() {
    super.initState();
    widget.changed?.addListener(_refresh);
    _arm();
  }

  @override
  void didUpdateWidget(DuoStatusStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changed != widget.changed) {
      oldWidget.changed?.removeListener(_refresh);
      widget.changed?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.changed?.removeListener(_refresh);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Center(
            child: Text(_text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ),
      );
}
