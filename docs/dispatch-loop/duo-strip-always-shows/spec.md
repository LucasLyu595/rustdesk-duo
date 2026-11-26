---
name: duo-strip-always-shows-spec
description: "The Duo's top status strip (status line and shortcut buttons) always shows on the inner screen in the portrait crease layout, through transient fold, metrics, keyboard, lifecycle and aspect changes; layout-branch changes are logged for field evidence."
metadata:
  node_type: spec
  type: project
  work_type: code
  status: stable
  work_unit: duo-strip-always-shows
  modified: 2026-11-26
generated:
  by: claude/claude-opus-5-5
  session: 57ba620c-e6db-421c-b4f9-84f591b5ede7
  at: 2026-11-26T02:42:19-08:00
---

# Spec: the strip always shows

Base: `duo-mode` at `db064f5f4`. Worktree: `/Users/lucas/rustdesk-duo/.dispatch-workspaces/duo-strip-always-shows`
(prepared with `duo/prep-worktree.sh`). Work type: `code` with an investigation step.

## Intent (Lucas, 2026-11-26)

"Sometimes" the whole top strip (status line and the eight buttons) disappears. No exact steps.
The Duo is offline now, so there is no field evidence.

## Known so far (from units 5 and the upside-down fix)

- The strip shows only when the picture offset above the crease is at least `kDuoStripMinExtent`
  (24 pt; the buttons need `kDuoShortcutMinExtent`, 56 pt). The offset is the picture top minus
  MediaQuery `padding.top`.
- A 4:3 peer mode makes the picture fill the height above the crease, so the offset is 0 and there is
  no strip (unit 5: seen after a cover-to-inner switch, before the refit).
- A visible iOS status bar adds about 60 pt of `padding.top` and squeezes the strip out (upside-down
  fix). `remote_page.dart` shows the status bar (`SystemUiOverlay.values`) while the soft keyboard
  is up (`onSoftKeyboardChanged`, the keyboard button path) and hides it again on keyboard hide.

## Investigation (planner, with file:line evidence)

I1. List every condition under which the strip is not shown or is pushed off screen, across
`duo_split.dart`, `duo_status_strip.dart`, `duo_deck.dart`, `duo_resolution.dart`, `duo_fold.dart`,
the duo_display plugin (Dart and iOS), and every `SystemChrome` / safe-area use on the remote page.
I2. For each, say whether it can be true in normal use (rotation, fold or pose change,
cover-to-inner switch, resume from background, soft keyboard or system UI, a dialog, the band being
briefly null or zero, a peer mode change), and whether the app recovers or can stay in the fallback.

## Required behavior

R1. On the inner screen in portrait (up or upside down) with the crease layout, the strip always
shows: the layout reserves room for it (at least the strip-with-buttons height) instead of hiding
it when the picture or the top padding would take that room. A picture that would be taller is
fitted below the strip (bars at the sides are acceptable; the refit then removes them).
R2. Transient glitches do not change the layout: keep the last good fold band and pose through a
short null or zero reading from duo_display; recompute on every metrics change, orientation change
and `AppLifecycleState.resumed`; never latch into a fallback.
R3. The iOS status bar stays hidden on the remote page whenever the soft keyboard is not up, also
after resume and after dialogs, so `padding.top` does not eat the strip (only if I1 shows a path
where it stays visible).
R4. A debug log line (`debugPrint` or the app's logger at a level that reaches the device log, not
the UI) whenever the layout branch changes: strip shown or hidden, buttons shown or hidden, and the
reason (offset, padding, band, pose, aspect). Throttled to branch changes only.
R5. Scope: the Duo files and at most thin hooks in `remote_page.dart`. Earlier behavior otherwise
unchanged (cover screen, landscape, non-Duo).

## Tests

Dart tests for each glitch found that can be reproduced: a band null for a moment then back
(layout unchanged); a resume; a rotation sequence; a 4:3 aspect (strip still shows, picture fitted
below it); a non-zero `padding.top` (strip still shows). No new test infrastructure.

## Done when

D1. The plan lists I1/I2 with evidence. D2. R1-R4 pinned by tests where reproducible. D3. Focused
gate green (`flutter test` on all duo tests; `flutter analyze` on changed files, no new issue).
D4. On the Duo (Lucas): the steps in the final report do not make the strip disappear; the log
shows the branch lines.
