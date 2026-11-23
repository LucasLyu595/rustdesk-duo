import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../common.dart' show isIOS;
import '../../consts.dart';
import '../../models/model.dart' show FFI;
import '../../models/platform_model.dart';

/// Sends one press of [name] with exactly these modifiers.
typedef DuoShortcutSender = void Function(String name,
    {required bool alt,
    required bool ctrl,
    required bool shift,
    required bool command});

@immutable
class DuoShortcut {
  const DuoShortcut(this.id, this.label, this.icon, this.name,
      {this.ctrl = false,
      this.shift = false,
      this.command = false,
      this.hold = false});
  final String id;
  final String label;
  final IconData icon;
  final String name;
  final bool ctrl;
  final bool shift;
  final bool command;

  /// Sent on a long press only.
  final bool hold;
}

/// Character names are lowercase: an uppercase name has no keycode and is
/// typed as text instead.
const List<DuoShortcut> kDuoShortcuts = [
  DuoShortcut('mission', 'Mission', Icons.grid_view, 'VK_UP', ctrl: true),
  DuoShortcut('spotlight', 'Spotlight', Icons.search, 'VK_SPACE',
      command: true),
  DuoShortcut('desktop', 'Desktop', Icons.desktop_windows_outlined, 'VK_F11'),
  DuoShortcut('switcher', 'Switch', Icons.swap_horiz, 'VK_TAB', command: true),
  DuoShortcut('window', 'Window', Icons.web_asset, '5',
      command: true, shift: true),
  DuoShortcut('copy', 'Copy', Icons.copy, 'c', command: true),
  DuoShortcut('paste', 'Paste', Icons.content_paste, 'v', command: true),
  DuoShortcut('quit', 'Hold Quit', Icons.power_settings_new, 'q',
      command: true, hold: true),
];

/// How many of [kDuoShortcuts] a narrow row keeps.
const int kDuoShortcutCore = 5;

/// The least strip height that shows the row.
const double kDuoShortcutMinExtent = 56;

/// The least slot width; a narrower row keeps [kDuoShortcutCore] buttons.
const double kDuoShortcutSlotMin = 52;

const double _kSlotMax = 72;

DuoShortcutSender _legacySender(FFI ffi) => (name,
    {required alt, required ctrl, required shift, required command}) {
  final input = ffi.inputModel;
  if (!input.keyboardInputAllowed ||
      !input.keyboardPerm ||
      input.isViewCamera) {
    return;
  }
  bind.sessionInputKey(
      sessionId: ffi.sessionId,
      name: name,
      down: false,
      press: true,
      alt: alt,
      ctrl: ctrl,
      shift: shift,
      command: command);
};

bool _canSendKeys(FFI ffi) {
  final input = ffi.inputModel;
  return input.keyboardInputAllowed &&
      input.keyboardPerm &&
      !input.isViewCamera;
}

/// One map-mode key: the peer's keycode, and whether it goes down.
typedef DuoMapKey = (int code, bool down);

typedef DuoMapKeySender = Future<void> Function(int code, bool down);

/// kVK_Control and kVK_UpArrow as real key events: a legacy Ctrl+Up reaches
/// the Mac without the arrow's own flags and misses the Mission Control hotkey.
const List<DuoMapKey> kDuoMacMissionKeys = [
  (59, true),
  (126, true),
  (126, false),
  (59, false),
];

/// kVK_F11 as a real key event: a legacy F11 misses the Show Desktop hotkey.
const List<DuoMapKey> kDuoMacDesktopKeys = [
  (103, true),
  (103, false),
];

/// The map-mode keys a Mac peer needs for this combo, or null for a legacy one.
List<DuoMapKey>? _macMapKeys(String name,
    {required bool alt,
    required bool ctrl,
    required bool shift,
    required bool command}) {
  if (alt || shift || command) return null;
  if (name == 'VK_UP' && ctrl) return kDuoMacMissionKeys;
  if (name == 'VK_F11' && !ctrl) return kDuoMacDesktopKeys;
  return null;
}

/// Sends a combo that has Mac map keys through [mapKey] when [useMapKeys], and
/// everything else through [legacy].
DuoShortcutSender duoPeerAwareSender(
        {required bool Function() useMapKeys,
        required DuoShortcutSender legacy,
        required DuoMapKeySender mapKey}) =>
    (name, {required alt, required ctrl, required shift, required command}) {
      final keys = _macMapKeys(name,
          alt: alt, ctrl: ctrl, shift: shift, command: command);
      if (keys == null || !useMapKeys()) {
        legacy(name, alt: alt, ctrl: ctrl, shift: shift, command: command);
        return;
      }
      unawaited(_sendInOrder(keys, mapKey));
    };

/// The bridge runs each call on a pool thread, so each is awaited to keep the order.
Future<void> _sendInOrder(List<DuoMapKey> keys, DuoMapKeySender mapKey) async {
  for (final (code, down) in keys) {
    // Keep going, so a failed press still gets its releases.
    try {
      await mapKey(code, down);
    } catch (e) {
      debugPrint('duo map key $code ${down ? 'down' : 'up'}: $e');
    }
  }
}

DuoShortcutSender duoShortcutSender(FFI ffi) => duoPeerAwareSender(
    useMapKeys: () =>
        isIOS &&
        _canSendKeys(ffi) &&
        ffi.ffiModel.pi.platform == kPeerPlatformMacOS,
    legacy: _legacySender(ffi),
    mapKey: (code, down) => bind.sessionHandleFlutterRawKeyEvent(
        sessionId: ffi.sessionId,
        name: 'duo_map_key',
        platformCode: code,
        positionCode: 0,
        lockModes: 0,
        downOrUp: down));

class DuoShortcutRow extends StatelessWidget {
  const DuoShortcutRow({super.key, required this.send, required this.height});
  final DuoShortcutSender send;
  final double height;

  void _fire(DuoShortcut s) => send(s.name,
      alt: false, ctrl: s.ctrl, shift: s.shift, command: s.command);

  Widget _button(DuoShortcut s, double slot) => SizedBox(
        key: Key('duo-shortcut-${s.id}'),
        width: slot,
        height: height,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: s.hold ? null : () => _fire(s),
          onLongPress: s.hold ? () => _fire(s) : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s.icon, size: 18, color: Colors.white70),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(s.label,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final count = c.maxWidth >= kDuoShortcuts.length * kDuoShortcutSlotMin
            ? kDuoShortcuts.length
            : kDuoShortcutCore;
        final slot = min(_kSlotMax, c.maxWidth / count);
        return Material(
          type: MaterialType.transparency,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in kDuoShortcuts.take(count)) _button(s, slot),
            ],
          ),
        );
      });
}
