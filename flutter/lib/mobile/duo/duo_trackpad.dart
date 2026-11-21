import 'dart:math';

import 'package:flutter/material.dart';

enum DuoButton { left, right }

abstract class DuoPointerSink {
  void move(Offset delta);
  void click(DuoButton button);
  void buttonDown();
  void buttonUp();
  void scroll(int step);
}

const double _slop = 8.0;
const Duration _tapTime = Duration(milliseconds: 250);
const Duration _dragWindow = Duration(milliseconds: 300);
const double _scrollDivisor = 4.0;

class DuoTrackpad extends StatefulWidget {
  const DuoTrackpad({Key? key, required this.sink}) : super(key: key);

  final DuoPointerSink sink;

  @override
  State<DuoTrackpad> createState() => _DuoTrackpadState();
}

class _DuoTrackpadState extends State<DuoTrackpad> {
  final Map<int, Offset> _down = {};
  final Set<int> _extra = {};
  int _maxFingers = 0;
  Duration _start = Duration.zero;
  Duration? _lastClickUp;
  bool _armed = false;
  bool _dragging = false;
  bool _pastSlop = false;
  bool _scrolled = false;
  double _integral = 0;

  void _onDown(PointerDownEvent e) {
    if (_down.isEmpty) {
      _maxFingers = 1;
      _start = e.timeStamp;
      final last = _lastClickUp;
      _armed = last != null && e.timeStamp - last <= _dragWindow;
      _dragging = false;
      _pastSlop = false;
      _scrolled = false;
      _integral = 0;
      _extra.clear();
    } else if (_dragging) {
      _extra.add(e.pointer);
    } else {
      _armed = false;
      _maxFingers = max(_maxFingers, _down.length + 1);
    }
    _down[e.pointer] = e.position;
  }

  void _onMove(PointerMoveEvent e) {
    final origin = _down[e.pointer];
    if (origin == null || _extra.contains(e.pointer) || _maxFingers > 2) {
      return;
    }
    final sink = widget.sink;
    if (_maxFingers == 1) {
      if (_pastSlop) {
        sink.move(e.delta);
      } else if ((e.position - origin).distance > _slop) {
        _pastSlop = true;
        if (_armed) {
          _dragging = true;
          sink.buttonDown();
        }
        sink.move(e.position - origin);
      }
      return;
    }
    if ((e.position - origin).distance > _slop) _scrolled = true;
    _integral += e.delta.dy / 2 / _scrollDivisor;
    if (_integral > 1) {
      sink.scroll(1);
      _integral = 0;
      _scrolled = true;
    } else if (_integral < -1) {
      sink.scroll(-1);
      _integral = 0;
      _scrolled = true;
    }
  }

  void _onUp(PointerUpEvent e) {
    _down.remove(e.pointer);
    _extra.remove(e.pointer);
    if (_down.isNotEmpty) return;
    final quick = e.timeStamp - _start <= _tapTime;
    if (_dragging) {
      widget.sink.buttonUp();
    } else if (_maxFingers == 1 && !_pastSlop && quick) {
      widget.sink.click(DuoButton.left);
      _lastClickUp = e.timeStamp;
    } else if (_maxFingers == 2 && !_scrolled && !_pastSlop && quick) {
      widget.sink.click(DuoButton.right);
    }
    _reset();
  }

  void _onCancel(PointerCancelEvent e) {
    _down.remove(e.pointer);
    _extra.remove(e.pointer);
    if (_down.isNotEmpty) return;
    _release();
  }

  void _release() {
    if (_dragging) widget.sink.buttonUp();
    _reset();
  }

  void _reset() {
    _down.clear();
    _extra.clear();
    _maxFingers = 0;
    _armed = false;
    _dragging = false;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: DecoratedBox(
          key: const Key('duo-trackpad'),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const SizedBox.expand(),
        ),
      );
}
