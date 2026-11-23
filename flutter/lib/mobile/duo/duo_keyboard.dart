import 'package:flutter/material.dart';

enum DuoModifier { shift, ctrl, alt, command }

abstract class DuoKeySink {
  bool isArmed(DuoModifier m);
  void setArmed(DuoModifier m, bool armed);
  void sendKey(String name);
}

const _shifted = <String, String>{
  '1': '!',
  '2': '@',
  '3': '#',
  '4': '\$',
  '5': '%',
  '6': '^',
  '7': '&',
  '8': '*',
  '9': '(',
  '0': ')',
  '-': '_',
  '=': '+',
  '[': '{',
  ']': '}',
  '\\': '|',
  ';': ':',
  '\'': '"',
  ',': '<',
  '.': '>',
  '/': '?',
  '`': '~',
};

class _KeySpec {
  final String id;
  final String label;
  final double units;
  final DuoModifier? modifier;
  final String? name;
  final String? char;

  const _KeySpec(this.id, this.label, this.units,
      {this.modifier, this.name, this.char});

  factory _KeySpec.char(String c) => _KeySpec(c, c.toUpperCase(), 1, char: c);
}

List<_KeySpec> _chars(String s) => s.split('').map(_KeySpec.char).toList();

final _rows = <List<_KeySpec>>[
  [
    ..._chars('`1234567890-='),
    const _KeySpec('delete', 'delete', 1.5, name: 'VK_BACK'),
  ],
  [
    const _KeySpec('tab', 'tab', 1.5, name: 'VK_TAB'),
    ..._chars('qwertyuiop[]\\'),
  ],
  [
    const _KeySpec('ctrl', '⌃\ncontrol', 1.75, modifier: DuoModifier.ctrl),
    ..._chars('asdfghjkl;\''),
    const _KeySpec('return', 'return', 1.75, name: 'VK_RETURN'),
  ],
  [
    const _KeySpec('shift-l', '⇧\nshift', 2.25, modifier: DuoModifier.shift),
    ..._chars('zxcvbnm,./'),
    const _KeySpec('shift-r', '⇧\nshift', 2.25, modifier: DuoModifier.shift),
  ],
  [
    const _KeySpec('caps', 'caps lock', 1.25),
    const _KeySpec('option-l', '⌥\noption', 1.25, modifier: DuoModifier.alt),
    const _KeySpec('cmd-l', '⌘\ncommand', 1.5, modifier: DuoModifier.command),
    const _KeySpec('space', '', 6.5, name: 'VK_SPACE'),
    const _KeySpec('left', '\u2190', 1, name: 'VK_LEFT'),
    const _KeySpec('up', '\u2191', 1, name: 'VK_UP'),
    const _KeySpec('down', '\u2193', 1, name: 'VK_DOWN'),
    const _KeySpec('right', '\u2192', 1, name: 'VK_RIGHT'),
  ],
];

class DuoKeyboard extends StatefulWidget {
  final DuoKeySink sink;

  const DuoKeyboard({Key? key, required this.sink}) : super(key: key);

  @override
  State<DuoKeyboard> createState() => _DuoKeyboardState();
}

class _DuoKeyboardState extends State<DuoKeyboard> {
  static const _gap = 4.0;
  bool _capsLock = false;

  bool get _useShifted =>
      widget.sink.isArmed(DuoModifier.shift) &&
      !widget.sink.isArmed(DuoModifier.ctrl) &&
      !widget.sink.isArmed(DuoModifier.command);

  bool get _capsLetters =>
      _capsLock &&
      !widget.sink.isArmed(DuoModifier.ctrl) &&
      !widget.sink.isArmed(DuoModifier.command);

  String _glyph(String c) {
    if (!_useShifted) {
      return _capsLetters && RegExp(r'[a-z]').hasMatch(c) ? c.toUpperCase() : c;
    }
    return _shifted[c] ?? c.toUpperCase();
  }

  String _label(String c) {
    if (_useShifted) return _glyph(c);
    return RegExp(r'[a-z]').hasMatch(c) ? c.toUpperCase() : c;
  }

  @override
  void dispose() {
    for (final m in DuoModifier.values) {
      if (widget.sink.isArmed(m)) widget.sink.setArmed(m, false);
    }
    super.dispose();
  }

  void _tap(_KeySpec k) {
    final sink = widget.sink;
    final m = k.modifier;
    if (k.id == 'caps') {
      setState(() => _capsLock = !_capsLock);
      return;
    }
    if (m != null) {
      sink.setArmed(m, !sink.isArmed(m));
    } else {
      final c = k.char;
      sink.sendKey(c != null ? _glyph(c) : k.name!);
      for (final a in DuoModifier.values) {
        if (sink.isArmed(a)) sink.setArmed(a, false);
      }
    }
    setState(() {});
  }

  Widget _key(_KeySpec k) {
    final m = k.modifier;
    final c = k.char;
    final label = c != null ? _label(c) : k.label;
    return Expanded(
      flex: (k.units * 120).round(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
        child: _KeyCap(
          key: Key('duo-key-${k.id}'),
          label: label,
          armed: m != null && widget.sink.isArmed(m) ||
              k.id == 'caps' && _capsLock,
          onTap: () => _tap(k),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _gap / 2),
              child: Row(children: [for (final k in row) _key(k)]),
            ),
          ),
      ],
    );
  }
}

class _KeyCap extends StatefulWidget {
  final String label;
  final bool armed;
  final VoidCallback onTap;

  const _KeyCap(
      {Key? key, required this.label, required this.armed, required this.onTap})
      : super(key: key);

  @override
  State<_KeyCap> createState() => _KeyCapState();
}

class _KeyCapState extends State<_KeyCap> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    final Color fill;
    if (widget.armed) {
      fill = const Color(0xFF3D6FE0);
    } else if (_down) {
      fill = const Color(0xFF5A5A5E);
    } else {
      fill = const Color(0xFF3A3A3C);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
