---
name: top-strip-sends-mac-shortcuts-results
description: "Results of adding the centred row of eight Mac shortcut buttons to the Duo's top status strip."
metadata:
  node_type: results
  type: project
  work_type: code
  status: stable
  work_unit: top-strip-sends-mac-shortcuts
  modified: 2026-11-22
generated:
  by: claude/sonnet
  session: ae02121d614f43068
  at: 2026-11-22T02:59:43-08:00
verified:
  by: claude/claude-opus-5-5
  at: 2026-11-22T03:01:46-08:00
---

# Results: the top strip sends Mac shortcuts

Candidate commit: d21836568 (unit/top-strip-sends-mac-shortcuts, base 5ae9f7593; captain commit of the implementer's working tree; results doc committed after)

All eight buttons are kept at 669 pt (nothing dropped). The row has a 72 pt slot, so buttons are 72 x 48 in the 79 pt strip.

## Acceptance → tests

| Done-when | Proven by |
|---|---|
| D1 | `flutter/test/duo_status_strip_test.dart` "each tap button sends its one combo and no other modifiers" (run, green); the sender is the only call path (`_fire` in `duo_shortcuts.dart`, inspection) |
| D2 | `flutter/test/duo_status_strip_test.dart` "Quit sends Cmd+Q on a long press only" (run, green) |
| D3 | `flutter/test/duo_status_strip_test.dart` "the row shows eight buttons in a tall strip, none in a low one or without a sender" (run, green); existing "the strip shows name, delay and time, and leaves out what is missing" (run, green) |
| D4 | Inspection: diff touches only `flutter/lib/mobile/duo/duo_shortcuts.dart`, `duo_status_strip.dart`, the test file and the unit docs |
| D5 | Gate below (run, green) |
| D6 | MISSING: captain's on-device check (manual) |

## Gate

| Command | Exit status | Result |
|---|---|---|
| `flutter test test/duo_*_test.dart` (from `flutter/`) | exit 0 | 63 passed, 0 failed (includes 4 in the strip file) |
| `flutter analyze lib/mobile/duo/duo_shortcuts.dart lib/mobile/duo/duo_status_strip.dart test/duo_status_strip_test.dart` | exit 0 | No issues found; base analyze of the strip and its test in the main checkout: no issues |
| Red-first: `flutter test test/duo_status_strip_test.dart` with the three new tests against the base strip (no `send`, no `duo_shortcuts.dart`) | exit 1 | compile failure (`send` and `kDuoShortcuts` undefined), then restored |

Test-run exit status for the full duo run was taken from the runner's "All tests passed!" line.

## Deviations

- The combo test omits the plan's `armed` fake check (the plan itself calls it documentation only, since the sender type cannot reach armed state); R2 is enforced by the sender signature.
- The red-first run was a compile failure, not an assertion failure, because the new test file imports the new lib file.
- `Sent` is a file-level record typedef in the test (a typedef cannot sit inside `main`).

## Regression surface

| Existing file | Existing path whose behaviour changes | Why it is unavoidable |
|---|---|---|
| `flutter/lib/mobile/duo/duo_status_strip.dart` `build` | With a sender and a strip of 56 pt or more, the status text is 11 pt in the upper row and the lower row takes taps. Without a sender, or below 56 pt, the tree is the base one (now via `_status(12)`, same widgets) | The row has to live in the strip |
| `flutter/lib/mobile/duo/duo_status_strip.dart` `forSession` | Passes the session sender | R5, without editing `remote_page.dart` |
| Remote session touch input | Taps on the button rectangles no longer fall through below the strip | Buttons must take their taps |

Not changed: `remote_page.dart`, `input_model.dart`, `duo_split.dart`, deck, keyboard, trackpad, resolution, Rust, `src/lang/*`. `pubspec.lock` unchanged by `pub get`.

Cleanup: none beyond the two copied gitignored bridge files `flutter/lib/generated_bridge.dart` and `flutter/lib/generated_bridge.freezed.dart` (untracked/ignored, not staged).

## Review

Reviewer: loop-reviewer on Fable (rung 1/3), verdict APPROVE-WITH-NITS, no blocking findings.

| Nit | Disposition |
|---|---|
| Class doc comment 111 columns (`duo_status_strip.dart:8`) | fixed: shortened to one line; re-gated |
| No armed-state assertion in the combo test | accepted: the sender type has no path to `InputModel`'s armed flags (Deviations) |
| No test of the five-button fall-back | accepted: unreachable at base (no strip narrower than 416 pt inner width); AGENTS.md: no test per corner case |
| Large system text scale clips the label | known limit, below |

## Known limitations

- At a system text scale of about 2x, icon plus label exceed a 40-44 pt button in a 56-60 pt strip and the label clips. Default text size fits.
- Cmd+Tab is one press, so it switches to the previous app; it does not hold the switcher open.

## Verify

Captain gate after the fix, from `flutter/`: `flutter test` on the seven duo test files plus `cursor_size_test.dart` and `floating_mouse_cursor_offset_test.dart`: exit 0, 74 passed; `flutter analyze` on the two lib files and the test file: exit 0, no issues.
