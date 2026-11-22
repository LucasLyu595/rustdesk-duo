import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/input_model.dart';
import '../../models/model.dart';
import 'duo_keyboard.dart';
import 'duo_trackpad.dart';

class DuoDeck extends StatelessWidget {
  final DuoKeySink keys;
  final DuoPointerSink pointer;
  final List<Widget> actions;

  /// The height of the strip at the deck's top that holds the session row; null
  /// lays the row out above the keyboard as usual.
  final double? rowExtent;

  const DuoDeck(
      {Key? key,
      required this.keys,
      required this.pointer,
      this.actions = const [],
      this.rowExtent})
      : super(key: key);

  factory DuoDeck.forSession(FFI ffi,
      {List<Widget> actions = const [], double? rowExtent}) {
    final input = DuoDeckInput(ffi);
    return DuoDeck(
        keys: input,
        pointer: input,
        actions: actions,
        rowExtent: rowExtent);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, rowExtent == null ? 6 : 0, 6, 6),
        child: LayoutBuilder(builder: (context, constraints) {
          final showRow = actions.isNotEmpty && constraints.maxHeight >= 60;
          final strip =
              rowExtent != null && constraints.maxHeight >= rowExtent! + 22
                  ? rowExtent
                  : null;
          final top =
              strip ?? (rowExtent != null ? 6.0 : (showRow ? 32.0 + 6 : 0.0));
          final gap = strip == null ? 6.0 : max(0.0, (strip - 32) / 2);
          final rowH = (((constraints.maxHeight - top) * 0.6 - 16) / 5)
              .clamp(0.0, 46.0);
          return Column(
            children: [
              if (rowExtent != null)
                SizedBox(height: strip == null ? 6 : (showRow ? gap : strip)),
              if (showRow) ...[
                SizedBox(
                  key: const Key('duo-session-row'),
                  height: 32,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: actions),
                  ),
                ),
                SizedBox(height: gap),
              ],
              SizedBox(
                height: 5 * rowH + 16,
                child: DuoKeyboard(key: const Key('duo-keyboard'), sink: keys),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: DuoTrackpad(sink: pointer),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// One button of the deck's session row.
class DuoDeckAction extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;

  const DuoDeckAction({Key? key, required this.icon, required this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) => IconButton(
        color: Colors.white,
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 32),
        icon: icon,
        onPressed: onPressed,
      );
}

class DuoDeckInput implements DuoKeySink, DuoPointerSink {
  final FFI _ffi;

  DuoDeckInput(this._ffi);

  InputModel get _input => _ffi.inputModel;

  @override
  bool isArmed(DuoModifier m) {
    switch (m) {
      case DuoModifier.shift:
        return _input.shift;
      case DuoModifier.ctrl:
        return _input.ctrl;
      case DuoModifier.alt:
        return _input.alt;
      case DuoModifier.command:
        return _input.command;
    }
  }

  @override
  void setArmed(DuoModifier m, bool armed) {
    switch (m) {
      case DuoModifier.shift:
        _input.shift = armed;
        break;
      case DuoModifier.ctrl:
        _input.ctrl = armed;
        break;
      case DuoModifier.alt:
        _input.alt = armed;
        break;
      case DuoModifier.command:
        _input.command = armed;
        break;
    }
  }

  @override
  void sendKey(String name) {
    if (!_input.keyboardInputAllowed) return;
    _input.inputKey(name);
  }

  @override
  void move(Offset delta) =>
      _ffi.cursorModel.updatePan(delta, Offset.zero, false);

  @override
  void click(DuoButton button) => _input
      .tap(button == DuoButton.left ? MouseButtons.left : MouseButtons.right);

  @override
  void buttonDown() => _input.sendMouse('down', MouseButtons.left);

  @override
  void buttonUp() => _input.sendMouse('up', MouseButtons.left);

  @override
  void scroll(int step) => _input.scroll(step);
}
