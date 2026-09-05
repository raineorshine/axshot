# Testing without a human

Axshot is a hotkey, an overlay and a screenshot — all of which sound like they need someone at the
keyboard. They do not. What follows is enough to exercise every path from a shell.

## The paths that need no interaction

- `axshot --dump` walks and filters and prints, without drawing anything. This is how the region
  filter is tuned, and it is the only path that does not touch Screen Recording.
- `axshot --pid 1` runs the permission checks and exits at "no target app". Useful as a permission
  probe precisely because it draws no overlay — polling with a real capture would flash a
  full-screen overlay every few seconds and swallow the user's keystrokes while it was up.

## Driving the overlay

The hint overlay reads keys through a `CGEventTap`, which sees posted events, so AppleScript can
drive it:

    axshot --out /tmp/x.png &
    sleep 3
    osascript -e 'tell application "System Events" to keystroke "s"'

The hotkeys work the same way — `key code 21 using {option down, command down}` — which exercises
the real path through the running app rather than the CLI.

Give the walk a few seconds before sending the hint. The overlay is not up until the walk finishes,
and a key sent early is delivered to the target app instead.

## Seeing the overlay

Axshot orders its overlay out before capturing, so its own screenshots never contain it. To look at
the overlay itself, trigger it and capture the screen from a *different* process — a shell with its
own Screen Recording grant — then send Escape:

    osascript -e 'tell application "System Events" to key code 21 using {option down, command down}'
    sleep 3
    screencapture -x -o -R 0,34,1470,922 /tmp/overlay.png
    osascript -e 'tell application "System Events" to key code 53'

This is the only way to check hint placement and density, and it is worth doing after any change to
the filter.

## Failures that are the environment, not the code

Each of these cost time in the session that built the tool.

- **A black screenshot means the display is asleep**, not that the window is missing. Anything
  visual is unverifiable until someone wakes it.
- **Window queries go quiet while the session is locked.** System Events reporting zero windows for
  a running app is not evidence the app failed to open one; ask the app instead, or check again
  when the screen is awake.
- **Capturing a window's rect captures whatever is on top of it.** Front the window first, or the
  screenshot is of the app that happens to overlap it.
- **`security dump-keychain` does not list keys**, only passwords. There is no convenient shell
  route to a private key's label; the dialog that asks about it is the readout.
- **A GUI dialog can block a build indefinitely.** `codesign` waiting on a keychain prompt looks
  exactly like a slow compile. If a build has not returned, check for a `SecurityAgent` process
  before assuming it is working.

## Leaving the machine as you found it

A capture session takes the keyboard while its overlay is up, and a permission request can leave a
system modal on screen. Both are fine when someone is watching and rude when they are not: quit any
instance you started, and do not leave a dialog waiting on a person who has walked away.
