# Driving the live app

The user is at their own keyboard while a test runs, and every drive of the installed app takes some of
what they are using: the foreground, the keyboard, the clipboard, the save folder. AGENTS.md's "Driving
the app on a live machine" is the rule; this is why it is shaped that way, how to drive the overlay and
the settings window from a shell, and how a driver produces results that look like the app's.
[The `test` skill](../.github/skills/test/SKILL.md) is the procedure and the lock.

## Sharing the machine

### Waiting for the keyboard

    ./scripts/wait-idle.sh          # returns once nobody has typed for three seconds

It returns silently when the keyboard was already quiet and says so when it had to wait. Exit 1 is
"still typing after two minutes": the user is working, which is a result to report and park on, not a
wait to lengthen. Exit 2 is "could not tell", which is never a licence to proceed as though it had
passed.

What it reads is `CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)` —
seconds since the last hardware keypress. The other ways to ask are all wrong for this, and each is
wrong quietly:

| | |
|---|---|
| `.hidSystemState` with `.keyDown` | what the gate uses: real typing, plus keys posted to `.cghidEventTap` |
| `.combinedSessionState` | counts keys posted to the *session* tap as well — osascript's among them — so a test driving the app spends its time resetting its own gate |
| any-input instead of `.keyDown` | ambient cursor movement resets it faster than any threshold clears, and the gate never opens |
| `ioreg -c IOHIDSystem`'s `HIDIdleTime` | any input again — and it prints nothing at all without `-d1 -r`, so the one-liner that reads it looks like a machine that has never been touched |

No source separates a person's keypress from one this session posted to `.cghidEventTap` — the route
[a held chord](#what-osascript-cannot-post) takes: both move the hid clock by exactly the same amount.
So the gate belongs at the *start* of a burst and not between the keys inside one. Run straight after
your own drive, it spends the whole threshold waiting on its own echo.

Nobody typing is not the same as somebody there. A locked screen is the quietest keyboard on the
machine and passes the gate in three seconds, after which everything visual fails without saying why —
so a burst whose result is a picture also asks
[whether there is a screen to take it on](environment.md#the-screen-is-locked-or-asleep).

### Saying an agent has the foreground

`bin/axshot --driving on` and `--driving off` bracket every burst, immediately inside the gate. `on`
makes the running app border every screen in the pink hint style; `off` takes it down and re-activates
whatever application had the foreground when `on` was issued. Neither draws anything in the process it
is typed in — the border belongs to the running app, and these two runs are the wire to it — so both
report `app=none` and exit 3 when no app is running, the only sign that the burst was marking nothing.

- **The border is out of every screenshot, including the one being tested.** Its sharing type excludes
  it, so a capture that runs while it is up photographs whatever it was drawn over. Do not read a
  missing pink edge in a PNG as the border having failed; look at the screen. Judging how it *looks*
  means building with `sharingType = .readOnly` for the shot and reverting after. Whether it is *there*
  takes no picture at all: `CGWindowListCopyWindowInfo` reports owner, layer, bounds and sharing state
  for it like any other window, so the assertion is a window owned by `Axshot` at the border's layer
  while a burst runs and none after — the only way a removed mark is shown to be gone. Both ends animate
  and the window server answers mid-flight: a probe fired straight after `--driving off` still lists the
  border, inset a little on every side as it scales away. Read the second answer.
- **It expires after two minutes** and gives the foreground back on the way out, because the session
  that would have run `off` is the one that can die mid-burst. A drive longer than that re-issues
  `--driving on`, which pushes the deadline out rather than drawing a second border.
- **`off` restores the application, not the window.** macOS brings that app's own front window, which
  is the right one unless the user had a second window of the same app in front.

The burst ends at the last posted key, not at the end of the script. End the session and take the
border down on the next two lines, and leave everything the run wants to *know* — waiting on a
backgrounded run, reading its outcome line, measuring the PNGs it left — until after them. None of that
needs the screen, and it is routinely longer than the drive:

    # ... last capture
    osascript -e 'tell application "System Events" to key code 53'
    bin/axshot --driving off
    trap - EXIT
    wait $PID   # and the reading, and the measuring

Ending the session is the more urgent half of that pair: the border is a mark the user can work around,
and a session left up swallows every key they type at it. A trap is the net for paths that never reach
those lines, not how a burst normally ends — on the last line it fires *after* the bookkeeping:

    trap 'bin/axshot --driving off' EXIT

### Leaving the machine as you found it

- **Quit any instance you started, and leave no dialog up.** A capture session holds the keyboard while
  its overlay is up, and a permission request can leave a system modal on screen, waiting on a person
  who has walked away.
- **The clipboard is the user's, and releasing the lock does not restore it.** Ask what is on it before
  planning a drive that writes it: `osascript -e 'clipboard info'` names the classes and touches
  nothing. Plain text is put back with `pbpaste` before and `pbcopy` after. Anything else is not — a
  copied image arrives in a dozen flavours, and nothing on the command line writes them all back — so no
  build that writes the clipboard is driven until the user has moved on. Everything short of the write
  still can be: a scratch copy of the source with the pasteboard call redirected to a file, signed into
  a bundle like [the comparison build](testing.md#a-filter-change-is-a-diff-of-region-lists) and put in
  the live slot with `axshot-test-lock.sh install <bundle>` under the held lock, drives the key, the
  session and anything the path draws; `./build.sh` puts the real build back for the hand-off. Report
  the write itself as untested.
- **A driven capture's file goes to the Trash once it has been measured.** It lands in the save folder
  under the same timestamped name as the user's own shots, where it reads as theirs. List the folder
  before the run and move what the run added afterwards — to the Trash rather than `rm`, since a
  timestamp alone does not prove a file was the run's.

## Driving the overlay

The overlay reads keys through a `CGEventTap`, which sees posted events, so AppleScript can drive it:

    bin/axshot --out /tmp/x.png &
    # wait for the overlay window, below
    osascript -e 'tell application "System Events" to keystroke "s"'

The hotkey works the same way — `key code 21 using {option down, command down}` — and exercises the
real path through the running app rather than the CLI. Drive `bin/axshot --out` whenever the question
is *which* region was captured: its outcome line names the app, the role and the rect actually held,
and the instance running from the menu bar prints that nowhere.

### Driver hygiene

The driver's own failures come back looking like the app's.

- **Background the run itself, not just the line after it.** A CLI run left in the foreground blocks
  the osascript meant to drive it, and the session ends on its own deadline — `cancelled=true`, exactly
  like a real Escape. Only `total_ms` tells them apart, landing on the deadline rather than on when the
  key was sent.
- **`wait` for it before starting the next one.** A backgrounded run outlives the keys sent to it, by
  its deadline if nothing ends it, and a second run started meanwhile puts two overlays and two taps up
  at once, after which no key reaches the one being watched. A loop over cases is serial even though
  each case is a few seconds of keystrokes.
- **Guard every posted key on the session still being alive.** A driver that sleeps and then sends is
  sending to whatever is frontmost once the session has ended — the user's window, where the hint
  letter, the arrow and the Return all land and submit. A `kill -0` on the backgrounded run before each
  key costs nothing.
- **Split a list of keys explicitly.** zsh does not word-split an unquoted parameter, so a
  `for k in $keys` over key codes passes the whole list as one argument and osascript rejects it — every
  key of every case silently unsent, every run ending on its deadline exactly as a broken tap would.
  Split with `${=keys}`, and read osascript's stderr rather than only the run's last line: a case that
  ends `cancelled=true` is a claim about the driver until its keys are known to have been posted.
- **A `cancelled=true` well before the deadline was a person pressing Escape.** The deadline is what an
  unattended run ends on. Once that has happened twice — especially with `total_ms` shrinking as they
  react faster to a full-screen overlay they did not ask for — stop driving and hand the build over. It
  is an answer, not a flake to retry through.

### Waiting for a window, not a clock

The overlay is not up until the walk finishes, a key sent before that goes to the target app, and how
long the walk takes belongs to the window it was pointed at. Ask the window server instead of sleeping:
`CGWindowListCopyWindowInfo` lists an on-screen window owned by the app at `kCGWindowLayer` 1000 for
exactly as long as a session is up. Poll for it, and send nothing if it never appears. It is the half of
the `kill -0` guard that driving the installed app through its hotkey needs, having no process of its
own to test.

- **The layer is the whole test, not the owner.** The driving border is a window of the same app one
  level above the overlay, so a poll for "a window owned by Axshot" is satisfied the instant the burst
  opens. Nor is the owner a fixed string: it is the process name, `Axshot` for the installed bundle and
  `axshot` for a `bin/axshot` run, and a probe comparing it exactly never fires for the other one.
- **The corner thumbnail is layer 25,** listed from just after a shot to a file lands until it has slid
  off. Anything meant to happen while one is up — the next press, a click on it — polls for it rather
  than sleeping into its few seconds. `⌘⇧3` on the overlay is the cheapest shot that puts one there: a
  capture to a file with no label in it to be renumbered.
- **A hotkey press that does not land is silent.** No overlay appears and no session starts, so look
  for the overlay before sending hints, and send the chord again if it is not there. A capture that
  lands does not prove the press that started it either: a chord swallowed while an overlay was already
  up leaves the *next* press to do the work, and the file appears all the same. When which press did
  what is the question, a couple of lines appended to a file from the Carbon hotkey handler and from the
  tap callback separate "the event never arrived" from "the session started and stopped".

### What a posted key carries

- **`key code` and `keystroke` differ for anything matched on the letter rather than the key.** A
  `key code 38 using {shift down}` arrives with no unicode string, so the tap reads no letter and a
  letter-matched key — the join key — does nothing, while the arrows and Return, matched on the code,
  work. Drive those with `keystroke "J"`. One key of a sequence silently doing nothing while the rest
  work is this, not a missed keystroke.
- **A posted key carries the letter its key sits on, and leaves Shift in the flags.** `typedString`
  uppercases under Shift for exactly this, so `keystroke "ABC"` inserts `ABC` — but uppercasing is the
  whole repair, and a shifted punctuation key is not a case change: `keystroke "<<"` inserts `,,` and
  `keystroke "!"` inserts `1`. Neither is a bug in the app, since a real press carries the shifted
  character. Assert an edit with letters, and read a stray comma as the driver rather than the caret.
- **A key *matched* on a shifted character is unreachable by `keystroke`.** `keystroke "+"` arrives as
  `=` with the flag, so a run that passes has exercised the unshifted character and says nothing about
  the shifted one — and looks like a pass. [Post it yourself](#what-osascript-cannot-post) and overwrite
  what the event says with `keyboardSetUnicodeString`, the only route that puts a character the layout
  needs Shift for in front of the tap.

### What osascript cannot post

AppleScript can send a chord but cannot *hold* one. `key code` posts its down and its up a millisecond
apart, and System Events' `key down` does not carry a modifier that a separate `key down option` is
holding — option plus `key down "4"` types `4`, not `¢`. The overlay turns on exactly that: its tap is
not created until the walk finishes, which is after a posted press has been released and before a real
one has, so a posted chord's key-up misses the tap entirely. Post the events from a process that
already holds Accessibility — axshot behind a throwaway option, not a scratch binary, which would need a
grant of its own:

    let down = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState),
                       virtualKey: 21, keyDown: true)!
    down.flags = [.maskCommand, .maskAlternate]
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 1.2)  // past the walk, so the tap is up before the release
    // ... then the matching keyDown: false

- **Nothing on a stock machine posts a real click.** System Events' `click at {x, y}` resolves the
  element under the point and presses it through the accessibility API — returning the element it hit,
  which reads like proof — and posts no CGEvent, so the tap never sees it and the click lands in the
  window under the overlay. There is no `cliclick`, and the system `python3` has no PyObjC. A click, a
  double click and a drag are posted like a held chord: `leftMouseDown`, `leftMouseDragged` and
  `leftMouseUp` with `mouseEventClickState` set, from a second invocation while the first holds the
  overlay. A session behaving as though the click never happened — an arrow that steps the region rather
  than the caret — is this, not the handler.
- **A modifier held across a drag is posted the same way**, a bare `keyDown` with the release sent
  later, and asking whether it worked is the trap. The overlay's tap eats that key-down, so
  `.combinedSessionState` answers false for a key that is genuinely down while `.hidSystemState` answers
  true ([decisions.md](decisions.md#how-keys-reach-the-app)). A feature reading the wrong one fails
  identically under a driver and under a hand, so it is a real bug, not a driving artifact. Probe both
  from the same throwaway option, with a session up and without, before concluding either way.
  (`.privateState` is not a third answer — the call hangs.)

### Aiming at a region

**A hint label is not an address.** A `--dump` and the session are two walks of a tree that moves, and
anything re-laying out between them — a clock ticking over is enough — re-letters the hints. Where the
label still exists, a region is held, the shutter fires and the file is of something else, with
nothing in the run to say the target moved. Where the count crossed the alphabet, the labels grew a
character and the old one is now a prefix: the hint never completes and the session ends
`cancelled=true` on its deadline, which reads as a keystroke that never arrived. Best first:

1. **Write the assertion so the region does not matter.** A run that lands on the wrong region still
   produces an outcome line and a clipboard that look like a pass — `copy=selection` says a run was
   picked out, not that it was the one aimed at. An assertion phrased against the text survives that:
   two `⌥⇧→` from a freshly opened box select the first two words of *whatever* it holds, and a caret
   placed mid-run and extended to the end copies a proper suffix of what the same region joins to.
2. **Name no region at all.** An arrow with the hints up holds the largest region, and the arrows reach
   every other region from there, so a sequence of arrows has no label in it to be renumbered — and the
   starting region is the one a dump of the same burst sorts to the top by area. `--focused --bundle`
   narrows the candidates to one window, which holds the rest still.
3. **Take the labels from a `--dump` immediately before, of a window whose content is not moving.** A
   settings window is the easy case; a list view that refreshes itself is the worst.

**A rule that picks the next region is checked to a value, not to plausibility.** Reimplement the rule
over a `--dump` taken inside the same burst, and the expected `rect=` is a number: equality is the
assertion, and it catches a rule ported wrong in one direction while the other three look right, which
no eye on a screenshot would. It costs a second implementation, so it earns its keep on the rules worth
two. The dump has to come from the burst, and at the session's own scope: `--focused --bundle` answers
about that app's window whether or not any of it is exposed, so a narrowed dump beside a session that
hints the whole screen computes the expected region from a list the session never had, and the run
comes back holding something plausible from another window.

**A step key that beeps has two readings** — never reached, or reached and finding nothing to land on —
and the outcome line does not separate them. Each step beeps and stays put when the candidate list
holds no receiver: no leaf that way on screen, no sibling left in the window, no kept box containing
what is held. The nesting collapse makes the last of those ordinary rather than exotic: a toolbar button
whose wrapper was dropped has nothing to widen to, so `⌥↑` on it is correctly a beep. Run the same key
from the same region on a build that predates the change, or read the dump for a candidate that could
receive it, before reading a beep as a key that was never wired up.

### Assertions that need no picture

- **`rect=` on the outcome line** is the assertion for anything that changes *which* region a session
  ends on, checked against the region list from a `--dump` of the same window. Once several windows are
  hinted, the app name on that line is what says the shot came from the window you meant. Photograph
  the overlay only for questions about how it is drawn.
- **A session ending in a copy reads no pixels,** so it needs neither Screen Recording nor the target
  window in front — the walk works on a window behind the overlay, and `--bundle` aims it. It costs the
  keyboard for a couple of seconds and nothing else, the cheapest end-to-end exercise of the tap. Its
  outcome line carries `chars=` and `lines=`, and `pbpaste` is the rest of the assertion.
- **The dimensions of a dragged capture** check the tap, the rectangle arithmetic, the hold and the
  shutter in one number: the file is twice the dragged rectangle in pixels on a Retina display.
- **Where a shot landed** is a shell question, and the one a run through the menu bar app cannot answer,
  since it prints no outcome line anywhere. Put a sentinel string on the clipboard before the run —
  having [asked what the user was carrying](#leaving-the-machine-as-you-found-it) — and afterwards
  `osascript -e 'clipboard info'` names the classes on it: the sentinel still there proves the run did
  not touch the clipboard, and `«class PNGf»` proves it did. Count the save folder before and after; a
  run that copies leaves it unchanged. To check *which* region a clipboard shot holds, write it out and
  measure it:

      osascript -e 'set f to open for access POSIX file "/tmp/clip.png" with write permission' \
                -e 'set eof f to 0' \
                -e 'write (the clipboard as «class PNGf») to f' -e 'close access f'
      sips -g pixelWidth -g pixelHeight /tmp/clip.png

### Reproductions

Run any reproduction against a build *without* the fix before trusting it. One that passes either way
is measuring something other than what it was written for, and it goes on passing after the fix for the
same wrong reason.

The build without the fix and the build with it can be one install. A throwaway that skips the fix
while a flag file exists — `FileManager.default.fileExists(atPath:)` beside the line the fix added —
runs the reproduction twice around a `touch` and an `rm`: one relaunch rather than two, and the lock
held for two bursts rather than two builds.

## Driving the settings window

The status item and its menu are reachable as `menu bar 2` — `menu bar 1` is the app's own menu bar,
which exists only while the app is regular:

    osascript -e 'tell application "System Events" to tell process "Axshot" to click menu bar item 1 of menu bar 2' \
              -e 'delay 0.5' \
              -e 'tell application "System Events" to tell process "Axshot" to click menu item "Settings…" of menu 1 of menu bar item 1 of menu bar 2'

`build.sh` relaunches the app as part of installing, and the status item is not in the menu bar the
instant the process is. A script that drives `menu bar 2` in the same breath fails with
`Invalid index (-1719)`, which reads exactly like the change having broken the menu bar item. Wait a
second and send it again.

- **Keys go to whatever is frontmost at that moment**, not to the process the previous line addressed —
  a window can be open and not focused, and the key then lands in the user's editor. Front the app in
  the same script and confirm it took:

      osascript -e 'tell application "System Events" to tell process "Axshot" to set frontmost to true' \
                -e 'delay 0.5' \
                -e 'tell application "System Events" to keystroke "w" using {command down}'

  Clicking the menu item instead (`click menu item "Close" of menu 1 of menu bar item "File" of menu
  bar 1`) tests the action but not the key equivalent, so it is a diagnostic, not the test.
- **Address controls by name or subrole, never by index.** `button 1 of window 1` is `Choose…`, not the
  close box, so a script meaning to close the window opens the folder picker — in front of the user and
  one Return away from rewriting the save folder. Close it with
  `first button of window "Axshot" whose subrole is "AXCloseButton"`, and name the window rather than
  numbering it: an open panel becomes `window 1`, so a retry aimed there reopens the picker it meant to
  dismiss.
- **A control with no name is addressed by its `description`.** AppleScript's `name` is the tree's
  `AXTitle`, and AppKit gives a segmented control's segments a description and no title — so
  `radio button "Dark"` raises `-1728`, which says "can't get" and reads as the control not being there,
  while `first radio button of radio group "Theme" whose description is "Dark"` clicks it. Ask
  `get {name, description} of ...` before writing the line that drives it; a container is nameless the
  same way unless its code sets a title.
- **Walk `UI elements` recursively.** `entire contents of window 1` raises
  `Can't make item 1 of entire contents … into type specifier` here. Dumping role, title, description,
  value, help and `focused` for every element answers both "is this control named" and "where did Tab
  go" — the second only there, a focus ring being a picture.

**Stage what the window should be showing from the shell; drive only the buttons.** It is built once
and kept, so a `defaults write` does not appear by reopening it — quit the app, write the key, and
relaunch:

    defaults write com.raine.axshot saveDirectory -string /private/var/tmp

Getting there by driving `Choose…` is the worst of both: the panel is modal, holds the keyboard while it
is up, and does not pin the machine's focus, so typing into it can land in the user's own window.
States no key reaches — the status line says something only when something has failed — are staged
from a throwaway build that calls the setter itself, photographed, and then the file is restored and
rebuilt: two builds inside the lock already held. Reaching them by driving the control that fails is the
trap, because the failure is downstream of the write: recording a chord another app owns stores it
before Carbon refuses it, leaving the user a hotkey that does nothing.

**What a control is showing is a shell question, and a cheaper one than a screenshot:**

    osascript -e 'tell application "System Events" to tell process "Axshot" to get {name, enabled, position, size} of buttons of window "Axshot"'

`enabled` is the assertion for a control that dims itself rather than hiding. `position` and `size`
assert that a row still fits — the stack's insets leave the window width less 44pt, and an overrun is
not something a screenshot makes obvious — and the window's height, once it sizes itself to its rows,
says as a number whether it grew for a longer message. The window's own `position` and `size` are also
the one `screencapture -R` rectangle that is not a guess: both speak points, and a couple of points of
margin on each side catches the shadow.

Photographing what these open is `screencapture -l <window id>`, the id from the same
`CGWindowListCopyWindowInfo` the overlay is polled with — at whatever layer the window reports, which is
not 0 for all of them: the shortcut sheet is a panel at 3. Read the layer back rather than assuming one,
or the probe reports no window and the sheet looks like it failed to open.

Whether the app is currently an accessory is a shell question too:

    lsappinfo info -only ApplicationType "Axshot"

`"UIElement"` is accessory and `"Foreground"` is regular, which decides whether it is in the App
Switcher and the Dock. Reading it before and after opening the window is the whole test for a policy
change.

An empty window list is how "the install put no settings window on screen" is asserted — the app opens
one only when a permission is missing or a hotkey was refused — and it is also what
[a locked screen](environment.md#the-screen-is-locked-or-asleep) reports for a window that is there.

What the *cursor* does over a control is the one question here with no shell answer, and it looks like
one because `screencapture -C` draws the pointer. `CGWarpMouseCursorPosition` moves the pointer without
the mouse-moved event that makes AppKit re-read its cursor rects, so the glyph in the capture lags the
position by an unpredictable number of steps — the same point photographs as a hand, an arrow and an
I-beam depending only on where the pointer was before. That is a false pass and a false fail with
nothing in the image to say which, so a hover is one of the few things to hand to the user.
