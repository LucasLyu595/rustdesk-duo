import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/model.dart' show FFI;
import 'duo_shortcuts.dart';

/// The status line, plus shortcut buttons when it can send keys.
class DuoStatusStrip extends StatefulWidget {
  const DuoStatusStrip({
    super.key,
    this.name,
    this.delay,
    this.changed,
    this.now = DateTime.now,
    this.send,
  });

  /// The peer's name, or null when unknown.
  final ValueGetter<String?>? name;

  /// The round-trip delay in ms, or null when the session has not reported it.
  final ValueGetter<String?>? delay;

  /// Notifies when [name] or [delay] may have changed.
  final Listenable? changed;

  final ValueGetter<DateTime> now;

  /// Sends the shortcut buttons' keys; null shows no buttons.
  final DuoShortcutSender? send;

  factory DuoStatusStrip.forSession(FFI ffi, String id) => DuoStatusStrip(
        name: () => ffi.ffiModel.pi.hostname.isNotEmpty
            ? ffi.ffiModel.pi.hostname
            : id,
        delay: () => ffi.qualityMonitorModel.data.delay,
        changed: ffi.qualityMonitorModel,
        send: duoShortcutSender(ffi),
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

  Widget _status(double fontSize) => IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Center(
            child: Text(_text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: fontSize)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final send = widget.send;
    if (send == null) return _status(12);
    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      if (h < kDuoShortcutMinExtent) return _status(12);
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 16, child: _status(11)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: DuoShortcutRow(send: send, height: (h - 16).clamp(40.0, 48.0)),
        ),
      ]);
    });
  }
}
