# Testing without a human

Axshot is a hotkey, an overlay and a screenshot — all of which sound like they need someone at the
keyboard. They do not. What follows is enough to exercise every path from a shell.

The `test` skill is the procedure, including the mutex over the installed app; this is the mechanics
it calls for.

## The paths that need no interaction

- `axshot --dump` walks and filters and prints, without drawing anything and without touching the
  installed app. This is how the region filter is tuned, it needs no lock, and it is the only path
  that does not touch Screen Recording.
- The outcome line is the assertion for anything that changes *which* region a session ends on.
  `rect=` is printed on the capture line, so a driven run can be checked against the region list
  from a `--dump` of the same window without looking at a pixel; photograph the overlay only for
  questions about how it is drawn.
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

Background the run itself, not just the line after it: a CLI run left in the foreground blocks the
osascript that was meant to drive it, and the session then ends on its own deadline. That looks
exactly like a real Escape — `cancelled=true` — and the only thing telling them apart is
`total_ms`, which lands on the deadline rather than on when the key was sent.

Then `wait` for it before starting the next one. A backgrounded run outlives the keys sent to it —
by its deadline if nothing ends it — and a second run started meanwhile puts two overlays and two
taps up at once, after which no key reaches the one being watched. A loop over several cases has to
be serial even though each case is only a few seconds of keystrokes.

Take the labels from a `--dump` run immediately before, and drive a window whose content is not
moving. Labels are assigned over the candidates that run found, so a window that gains or loses
regions between the dump and the drive re-letters everything — and once the count crosses the
alphabet the labels grow a character, so a label read from the earlier dump is now a prefix. The
hint never completes, nothing is ever held, and the session ends `cancelled=true` on the deadline,
which reads as a keystroke that never arrived rather than one that arrived and was ignored. A list
view that refreshes itself is the worst case; a settings window is the easy one.

A hotkey press that does not land is silent: no overlay appears and the session never starts. Look
for the overlay before sending hints rather than assuming the chord arrived, and send it again if it
did not. A capture that lands is not proof of the press that started it either -- a chord swallowed
while an overlay was already up leaves the *next* press to do the work, and the file appears all the
same. When which press did what is the question, have the app answer it: a couple of lines appended
to a file from the Carbon hotkey handler and from the tap callback separate "the event never
arrived" from "the session started and stopped", which nothing on screen can.

AppleScript can send a chord but cannot *hold* one. `key code` posts its down and its up a
millisecond apart, and System Events' `key down` does not carry a modifier that a separate `key down
option` is holding -- option plus `key down "4"` types `4`, not `¢`. So anything that turns on how
long a key is down never happens under osascript, and the overlay is exactly such a thing: its tap
is not created until the walk finishes, which is after a posted press has been released and before a
real one has. A posted chord's key-up misses the tap entirely; a held one does not.

Post the events yourself for those, from a process that already holds Accessibility -- which means
axshot behind a throwaway option rather than a scratch binary, which would need a grant of its own:

    let down = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState),
                       virtualKey: 21, keyDown: true)!
    down.flags = [.maskCommand, .maskAlternate]
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 1.2)  // past the walk, so the tap is up before the release
    // ... then the matching keyDown: false

Run any such reproduction against a build *without* the fix before trusting it. One that passes
either way is measuring something other than what it was written for, and it will go on passing
after the fix for the same wrong reason.

## Driving the menu bar item and the settings window

The status item and its menu are reachable as `menu bar 2` — `menu bar 1` is the app's own menu bar,
which exists only while the app is regular:

    osascript -e 'tell application "System Events" to tell process "Axshot" to click menu bar item 1 of menu bar 2' \
              -e 'delay 0.5' \
              -e 'tell application "System Events" to tell process "Axshot" to click menu item "Settings…" of menu 1 of menu bar item 1 of menu bar 2'

Whether the app is currently an accessory is a shell question, not a visual one:

    lsappinfo info -only ApplicationType "Axshot"

`"UIElement"` is accessory, `"Foreground"` is regular — which is what decides whether it is in the
App Switcher and the Dock. Reading it before and after opening the window is the whole test for a
policy change.

`keystroke` and `key code` go to whatever is frontmost *at that moment*, not to the process the
previous line addressed — a window can be open and not focused, and the key then lands in the user's
editor. Front the app in the same script and confirm it took:

    osascript -e 'tell application "System Events" to tell process "Axshot" to set frontmost to true' \
              -e 'delay 0.5' \
              -e 'tell application "System Events" to keystroke "w" using {command down}'

Clicking the menu item instead (`click menu item "Close" of menu 1 of menu bar item "File" of menu
bar 1`) tests the action but not the key equivalent, so it is a diagnostic, not the test.

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

Anything smaller than the overlay — the corner thumbnail, a badge, a bracket — does not survive a
whole screen shrunk to fit. Capture the screen whole and crop afterwards rather than guessing a
`-R` rectangle, and remember the crop is in *pixels* while the app draws in points, so on a Retina
display the offsets are twice the coordinates the code uses:

    screencapture -x -o /tmp/screen.png
    magick /tmp/screen.png -crop 700x520+2240+1392 +repage -resize 200% /tmp/corner.png

Timing is the other half of it. Something that shows for a few seconds and then animates away has to
be photographed at three moments — up, mid-animation, gone — and appending the crops side by side
(`magick a.png b.png c.png +append`) is what makes the sequence one thing to look at rather than
three.

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
