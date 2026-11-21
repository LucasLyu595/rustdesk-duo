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
    const _KeySpec('esc', 'Esc', 1, name: 'VK_ESCAPE'),
    ..._chars('`1234567890-='),
    const _KeySpec('delete', 'Delete', 1.5, name: 'VK_BACK'),
  ],
  [
    const _KeySpec('tab', 'Tab', 1.5, name: 'VK_TAB'),
    ..._chars('qwertyuiop[]\\'),
  ],
  [
    ..._chars('asdfghjkl;\''),
    const _KeySpec('return', 'Return', 2, name: 'VK_RETURN'),
  ],
  [
    const _KeySpec('shift-l', 'Shift', 1.5, modifier: DuoModifier.shift),
    ..._chars('zxcvbnm,./'),
    const _KeySpec('shift-r', 'Shift', 1.5, modifier: DuoModifier.shift),
  ],
  [
    const _KeySpec('ctrl', 'Ctrl', 1.2, modifier: DuoModifier.ctrl),
    const _KeySpec('option-l', 'Option', 1.2, modifier: DuoModifier.alt),
    const _KeySpec('cmd-l', 'Cmd', 1.4, modifier: DuoModifier.command),
    const _KeySpec('space', '', 4.6, name: 'VK_SPACE'),
    const _KeySpec('cmd-r', 'Cmd', 1.4, modifier: DuoModifier.command),
    const _KeySpec('option-r', 'Option', 1.2, modifier: DuoModifier.alt),
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

  bool get _useShifted =>
      widget.sink.isArmed(DuoModifier.shift) &&
      !widget.sink.isArmed(DuoModifier.ctrl) &&
      !widget.sink.isArmed(DuoModifier.command);

  String _glyph(String c) {
    if (!_useShifted) return c;
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
      flex: (k.units * 10).round(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
        child: _KeyCap(
          key: Key('duo-key-${k.id}'),
          label: label,
          armed: m != null && widget.sink.isArmed(m),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
