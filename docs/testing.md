# Testing without a human

Axshot is a hotkey, an overlay and a screenshot — all of which sound like they need someone at the
keyboard. They do not. What follows is enough to exercise every path from a shell.

[The `test` skill](../.github/skills/test/SKILL.md) is the procedure, including the mutex over the
installed app; this is the mechanics it calls for.

## The paths that need no interaction

- `axshot --dump` walks and filters and prints, without drawing anything and without touching the
  installed app. This is how the region filter is tuned, it needs no lock, and it is the only path
  that does not touch Screen Recording.
- The outcome line is the assertion for anything that changes *which* region a session ends on.
  `rect=` is printed on the capture line, so a driven run can be checked against the region list
  from a `--dump` of the same window without looking at a pixel; photograph the overlay only for
  questions about how it is drawn.
- A session ending in a copy rather than a capture reads no pixels at all, so it needs neither
  Screen Recording nor the target window in front — the walk works on a window that is behind the
  overlay, and `--bundle` is enough to aim it. Driving one costs the keyboard for a couple of
  seconds and nothing else, which is the cheapest way to exercise the tap end to end. Its outcome
  line carries `chars=` and `lines=`, and `pbpaste` is the rest of the assertion.
- Where a shot *landed* is a shell question too, and the one the app's own hotkey cannot answer:
  a driven run through the menu bar app prints no outcome line anywhere. Put a sentinel string on
  the clipboard before the run, and afterwards `osascript -e 'clipboard info'` names the classes on
  it — a sentinel still there is proof the run did not touch the clipboard, and `«class PNGf»` is
  proof it did. Counting the save folder before and after is the other half; a run that copies must
  leave it unchanged. To check *which* region a clipboard shot holds, write it out and measure it:

      osascript -e 'set f to open for access POSIX file "/tmp/clip.png" with write permission' \
                -e 'set eof f to 0' \
                -e 'write (the clipboard as «class PNGf») to f' -e 'close access f'
      sips -g pixelWidth -g pixelHeight /tmp/clip.png

- `axshot --pid 1` runs the permission checks and exits at "no target app". Useful as a permission
  probe precisely because it draws no overlay — polling with a real capture would flash a
  full-screen overlay every few seconds and swallow the user's keystrokes while it was up.

## Driving the overlay

The hint overlay reads keys through a `CGEventTap`, which sees posted events, so AppleScript can
drive it:

    axshot --out /tmp/x.png &
    sleep 3
    osascript -e 'tell application "System Events" to keystroke "s"'

The hotkey works the same way — `key code 21 using {option down, command down}` — which exercises
the real path through the running app rather than the CLI.

`key code` and `keystroke` are not interchangeable for anything matched on the *letter* rather than
the key. A `key code 38 using {shift down}` arrives with no unicode string on it, so the tap reads no
letter at all and a letter-matched key — the join key — does nothing, while the arrows and Return,
which are matched on the code, are unaffected. Drive those with `keystroke "J"`, which carries the
character. A run where one key of a sequence silently did nothing and the rest worked is this, not a
missed keystroke.

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

Guard every posted key on the session still being alive. A driver that sleeps and then sends is
sending to whatever is frontmost the moment the session has already ended — which is the user's
window, where the hint letter, the arrow and the Return all land and submit. A `kill -0` on the
backgrounded run before each key costs nothing, and is the difference between a test that reports
nothing happened and one that types into someone's editor.

The driver's own failures are invisible in the outcome line, which reports only that nothing was
typed. The shell is zsh, where an unquoted parameter is *not* word-split, so a `for k in $keys` over
a list of key codes passes the whole list as one argument and osascript rejects it — every key of
every case silently unsent, and every run ending on its deadline exactly as it would if the tap were
broken. Split explicitly (`${=keys}`) and read osascript's stderr rather than only the run's last
line; a case that ends `cancelled=true` is a claim about the driver until the keys are known to have
been posted.

A run that ends `cancelled=true` well before its deadline was Escaped by a person; the deadline is
what an unattended run ends on. Once that has happened twice, and especially once `total_ms` shrinks
from one run to the next — they are reacting faster each time to a full-screen overlay they did not
ask for — stop driving and hand the build over. It is an answer, not a flake to retry through.

Take the labels from a `--dump` run immediately before, and drive a window whose content is not
moving. Labels are assigned over the candidates that run found, so a window that gains or loses
regions between the dump and the drive re-letters everything — and once the count crosses the
alphabet the labels grow a character, so a label read from the earlier dump is now a prefix. The
hint never completes, nothing is ever held, and the session ends `cancelled=true` on the deadline,
which reads as a keystroke that never arrived rather than one that arrived and was ignored. A list
view that refreshes itself is the worst case; a settings window is the easy one.

A hotkey press that does not land is silent: no overlay appears and the session never starts. Look
for the overlay before sending hints rather than assuming the chord arrived, and send it again if it
did not. A capture that lands is not proof of the press that started it either — a chord swallowed
while an overlay was already up leaves the *next* press to do the work, and the file appears all the
same. When which press did what is the question, have the app answer it: a couple of lines appended
to a file from the Carbon hotkey handler and from the tap callback separate "the event never
arrived" from "the session started and stopped", which nothing on screen can.

AppleScript can send a chord but cannot *hold* one. `key code` posts its down and its up a
millisecond apart, and System Events' `key down` does not carry a modifier that a separate `key down
option` is holding — option plus `key down "4"` types `4`, not `¢`. So anything that turns on how
long a key is down never happens under osascript, and the overlay is exactly such a thing: its tap
is not created until the walk finishes, which is after a posted press has been released and before a
real one has. A posted chord's key-up misses the tap entirely; a held one does not.

Post the events yourself for those, from a process that already holds Accessibility — which means
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

Address that window's controls by name or subrole, never by index. `button 1 of window 1` is
`Choose…`, not the close box, so a script meaning to close the window opens the folder picker
instead — and unlike a hint that misses, a misfire here is in front of the user and one Return away
from rewriting the save folder. Close it with `first button of window "Axshot" whose subrole is
"AXCloseButton"`, and name the window rather than numbering it: an open panel becomes `window 1`, so
a retry aimed there reopens the picker it was meant to dismiss.

Stage what the window should be *showing* from the shell; drive only the buttons. It is built once
and kept, so a `defaults write` does not appear by reopening it — quit the app, write the key, and
relaunch, and the window comes up on the state you wanted:

    defaults write com.raine.axshot saveDirectory -string /private/var/tmp

Getting there by driving `Choose…` instead is the worst of both. The panel is modal, it holds the
keyboard for as long as it is up, and typing into it obeys the rule above about keys going wherever
is frontmost — which, since an open panel does not pin the machine's focus, can be the user's own
window. Stage the state, then click the named button to test the *action*.

What a control is showing is a shell question too, and a cheaper one than a screenshot:

    osascript -e 'tell application "System Events" to tell process "Axshot" to get {name, enabled, position, size} of buttons of window "Axshot"'

`enabled` is the assertion for a control that dims itself rather than hiding. `position` and `size`
are the assertion that a row of them still fits: the stack's insets leave the window width less
44pt, and a row that overruns that is not something a screenshot makes obvious.

An empty window list is how "the install put no settings window on screen" gets asserted — the app
opens one only when a permission is missing or a hotkey was refused. It is also what a locked screen
reports for a window that is there, so it is a pass only on a machine that is awake.

## Seeing the overlay

Axshot keeps its own marks out of its own screenshots — the shutter orders the overlay out, and the
transcription key leaves it up and draws it bare — so no capture it takes ever contains them. To look
at the overlay itself, trigger it and capture the screen from a *different* process — a shell with
its own Screen Recording grant — then send Escape:

    osascript -e 'tell application "System Events" to key code 21 using {option down, command down}'
    sleep 3
    screencapture -x -o -R 0,34,1470,922 /tmp/overlay.png
    osascript -e 'tell application "System Events" to key code 53'

This is the only way to check hint placement and density, and it is worth doing after any change to
the filter. It is also the only way to check anything the overlay *draws*, and the trap is that a
capture looks like evidence: the overlay is ordered out before every shot, so the PNG is identical
whether the drawing under test appeared or not, and a run that ends in a file proves the session
reached the shutter and nothing more. The outcome line is the same kind of claim — it says which
region the session ended on, not what was on top of it.

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

A still cannot show a transition, and a transition is what most overlay complaints are about — a
flash, a gap, a thing that redraws twice. When the user sends a screen recording, read it frame by
frame rather than scrubbing it: extract every frame and tile them into one contact sheet, and the
frame where the mask is missing is visible at a glance where playback is too fast to catch it.

    ffmpeg -v error -i rec.mov -vf "scale=760:-1" frames/f%03d.png
    ffmpeg -v error -i frames/f%03d.png -vf "tile=6x4,scale=1400:-1" grid.png

Such a clip is often under a second, so ask for every frame and not a sampled `fps=`. And the file
name will not be the one you were given: macOS writes a narrow no-break space (U+202F) before AM/PM
in screenshot and recording names, so a path that `ls` prints and the user pastes still fails `stat`
and `ffmpeg` with "No such file or directory". Match it with a glob rather than retyping it.

The shell running the tests generally has no Screen Recording grant of its own — `screencapture`
fails with "could not create image from rect" — so a probe image for anything that reads pixels has
to be rendered rather than photographed. `qlmanage -t -s 900 -o . file.txt` turns a text file into a
PNG of that text, which is enough to prove a reader reads.

## Asking what the tree actually says

`--dump` prints one label per element, already collapsed to a line, so it answers which regions
would be hinted and not where any of their words came from. When the question is about the text a
copy would give — why a name nobody can see is in it, which attribute supplied it, which elements
were recursed into — nothing exposes that, and reading the walk instead of the tree is how a
heuristic gets built against a guess. Print it: a throwaway option that walks one candidate and
dumps each element's role, child count and every text attribute it carries answers in one run what
a dozen driven copies only hint at. It comes back out with the same commit that used it.

## Failures that are the environment, not the code

Each of these cost time in the session that built the tool.

- **A black screenshot means the display is asleep**, not that the window is missing. Anything
  visual is unverifiable until someone wakes it.
- **Window queries go quiet while the session is locked.** `--dump` reporting `windows=0` for every
  app on the machine — not one app, all of them — is the signature, and it reads exactly like a
  tree that is never exposed. Nothing visual can be driven or captured until someone unlocks it, so
  check before concluding anything about the walk:

      ioreg -n Root -d1 -r | grep -o 'CGSSessionScreenIsLocked"=[A-Za-z]*'

  An absent key is an unlocked session; `=Yes` means stop and hand the build over.
- **Capturing a window's rect captures whatever is on top of it.** `--bundle` aims the walk and not
  the camera, so the outcome line names the region it meant while the pixels are of whatever was in
  front. Front the target again before *each* run, not once per test: a run that ends gives the
  foreground back, and the next one then photographs a different app at the same coordinates and
  says nothing about it.
- **`security dump-keychain` does not list keys**, only passwords. There is no convenient shell
  route to a private key's label; the dialog that asks about it is the readout.
- **A GUI dialog can block a build indefinitely.** `codesign` waiting on a keychain prompt looks
  exactly like a slow compile. If a build has not returned, check for a `SecurityAgent` process
  before assuming it is working.

## Leaving the machine as you found it

AGENTS.md's "Driving the app on a live machine" is the rule this closes out: hold the foreground for
the keystrokes and no longer. What follows is what a run has to undo afterwards.

A capture session takes the keyboard while its overlay is up, and a permission request can leave a
system modal on screen. Both are fine when someone is watching and rude when they are not: quit any
instance you started, and do not leave a dialog waiting on a person who has walked away.
