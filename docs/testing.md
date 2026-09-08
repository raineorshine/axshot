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

## Waiting for the keyboard

The user is typing while this runs, so every activation, every overlay and every posted key goes
behind the gate:

    ./scripts/wait-idle.sh          # returns once nobody has typed for three seconds

It returns silently when the keyboard was already quiet and says so when it had to wait. Exit 1 is
"still typing after two minutes": the user is working, which is a result to report and park on, not
a wait to lengthen. Exit 2 is "could not tell", which is never a licence to proceed as though it had
passed.

What it reads is `CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)` —
seconds since the last hardware keypress. The other three ways to ask are all wrong for this, and
each is wrong quietly:

| | |
|---|---|
| `.hidSystemState` with `.keyDown` | what the gate uses: real typing, plus keys posted to `.cghidEventTap` |
| `.combinedSessionState` | counts keys posted to the *session* tap as well — osascript's among them — so a test driving the app spends its time resetting its own gate |
| any-input instead of `.keyDown` | ambient cursor movement resets it faster than any threshold clears, and the gate never opens |
| `ioreg -c IOHIDSystem`'s `HIDIdleTime` | any input again — and it prints nothing at all without `-d1 -r`, so the one-liner that reads it looks like a machine that has never been touched |

The distinction no source makes is between a person's keypress and one this session posted to
`.cghidEventTap` — the route "Driving the overlay" reaches for to hold a chord: both move the hid
clock by exactly the same amount. So the gate belongs at the *start* of a burst and not between the
keys inside one — run straight after your own drive it spends the whole threshold waiting on its own
echo, and nothing it can read would tell it the typist was itself.

## Saying an agent has the foreground

A burst brackets itself, immediately inside the idle gate and around everything that activates,
posts a key or draws an overlay:

    ./scripts/wait-idle.sh
    bin/axshot --driving on
    # activate the target, send the hint, send Return
    bin/axshot --driving off

`on` makes the running app border every screen in the pink hint style and put a shadow of the same
pink under the pointer; `off` takes both down and
re-activates whatever application had the foreground when `on` was issued. Neither draws anything in the process it is typed in — the border
is a window belonging to the running app, and these two runs are the wire to it. So both report
`app=none` and exit 3 when no app is running, which is the only thing that would say the burst was
marking nothing.

Three edges:

- **Both marks are out of every screenshot, including the one being tested.** Their sharing type
  excludes them, so a capture that runs while they are up photographs whatever they were drawn over.
  Do not read a missing pink edge in a PNG as the border having failed; look at the screen. Judging
  how either one *looks* means building with `sharingType = .readOnly` for the shot and reverting
  after — there is no way to photograph what a capture is defined not to see.
- **It expires after two minutes** and gives the foreground back on the way out, because the session
  that would have run `off` is the one that can die mid-burst. A drive longer than that re-issues
  `--driving on`, which pushes the deadline out rather than drawing a second border.
- **`off` restores the application, not the window.** macOS brings that app's own front window, which
  is the right one unless the user had a second window of the same app in front.

A burst that can fail between the two ends should close itself from a trap rather than from the last
line, or the border stays up until the ceiling catches it:

    trap 'bin/axshot --driving off' EXIT

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

A posted event carries the letter its key sits on and leaves Shift in the flags to say what was
done to it, which matters the moment a driven session is *typing* rather than pressing. `typedString`
uppercases under Shift for exactly this, so `keystroke "ABC"` inserts `ABC` -- but uppercasing is the
whole of the repair, and a shifted punctuation key is not a case change. `keystroke "<<"` inserts
`,,`, `keystroke "!"` inserts `1`, and neither is a bug in the app: a real press carries the shifted
character and never reaches the repair. Assert an edit with letters, and read a stray comma in the
result as the driver rather than as the caret.

A label read from `--dump` is not the label the session will use. They are two walks of a tree that
moves, and anything re-laying out between them renumbers the hints — a clock ticking over is enough.
The typed label is still *a* valid label, so a region is held, the shutter fires and the file is of
something else entirely: nothing in the run says the target moved. Aim at something that does not
redraw, and check what came back rather than what was asked for.

Which is the reason to drive `bin/axshot --out` rather than the hotkey whenever the question is
*which* region was captured. Its outcome line names the app, the role and the rect actually held, and
the instance running from the menu bar prints that nowhere. A rect alone stopped being enough once
several windows are hinted at once — the app name on that line is what says the shot came from the
window you meant.

Wait for the overlay rather than for a few seconds. It is not up until the walk finishes, a key sent
before that goes to the target app, and how long the walk takes belongs to the window it was pointed
at — a page that took two seconds once will not the next time. The overlay is a window, so ask the
window server: `CGWindowListCopyWindowInfo` lists an on-screen window owned by `Axshot` at
`kCGWindowLayer` 1000 for exactly as long as the session is up. Poll for it, and send nothing if it
never appears. That is the app-driven half of the `kill -0` guard below — driving the installed app
through its hotkey leaves no process of your own to test — and without it the hint letter and the
Return land in whatever the drive activated.

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

Better still, write the assertion so the region does not matter. A driven run that lands on a
different region than intended still produces an outcome line and a clipboard, and both look like a
pass — a copy that reports `copy=selection` says the box was open and a run was picked out, not that
either was the one you aimed at. An assertion phrased against the text itself survives that: two
`⌥⇧→` from a freshly opened box select the first two words of *whatever* it holds, and a caret
placed mid-run and extended to the end copies a proper suffix of what the same region joins to. Both
are checkable without knowing which region answered, which is the only kind of check that does not
quietly re-verify itself against the wrong window.

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

The mouse is that case and worse: nothing on a stock machine posts a real click. System Events'
`click at {x, y}` resolves the element under the point and presses it through the accessibility API
-- it returns the element it hit, which reads like proof it worked -- and no CGEvent is ever posted,
so an event tap never sees it and the click lands in the window under the overlay instead. There is
no `cliclick`, and the system `python3` has no PyObjC to post one from. So a click, a double click
and a drag are all driven the same way as a held chord: a throwaway option on axshot itself, posting
`leftMouseDown`, `leftMouseDragged` and `leftMouseUp` with `mouseEventClickState` set, from a second
invocation while the first is holding the overlay. A session that goes on behaving as though the
click never happened -- an arrow that steps the region rather than the caret -- is this, not the
handler.

A modifier *held across* a drag is posted the same way a held chord is — a bare `keyDown` with no
matching up, and the release sent later — and asking whether it worked is the trap, not the posting.
The overlay's own tap eats that key-down, so the session state never records it and
`CGEventSource.keyState(.combinedSessionState, …)` answers false for a key that is genuinely down;
`.hidSystemState` is the hardware and answers true. A feature that reads the wrong one of those
fails identically under a driver and under a hand, which is the good case: it is a real bug, not a
driving artifact. Probe both from the same throwaway option, with a session up and without, before
concluding either way. (`.privateState` is not a third answer — the call hangs.)

The dimensions of what comes out are the assertion for a whole driven drag, and cheaper than a
photograph: the file is twice the dragged rectangle in pixels on a Retina display, so a run that
drags a known box and presses Return checks the tap, the rectangle arithmetic, the hold and the
shutter in one number. Photograph the overlay only for what it *draws* mid-drag.

Run any such reproduction against a build *without* the fix before trusting it. One that passes
either way is measuring something other than what it was written for, and it will go on passing
after the fix for the same wrong reason.

## Driving the menu bar item and the settings window

The status item and its menu are reachable as `menu bar 2` — `menu bar 1` is the app's own menu bar,
which exists only while the app is regular:

    osascript -e 'tell application "System Events" to tell process "Axshot" to click menu bar item 1 of menu bar 2' \
              -e 'delay 0.5' \
              -e 'tell application "System Events" to tell process "Axshot" to click menu item "Settings…" of menu 1 of menu bar item 1 of menu bar 2'

`build.sh` relaunches the app as part of installing, and the status item is not in the menu bar the
instant the process is. A script that drives `menu bar 2` in the same breath fails with `Invalid
index (-1719)`, which reads exactly like the change having broken the menu bar item. Wait a second
and send it again.

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

A control with no name is addressed by its `description` instead. AppleScript's `name` is the tree's
`AXTitle`, and AppKit gives a segmented control's segments a description and no title — so
`radio button "Dark"` raises `-1728`, which says "can't get" and reads as the control not being
there at all, while `first radio button of radio group "Theme" whose description is "Dark"` clicks
it. Ask the tree which of the two a control answers to (`get {name, description} of ...`) before
writing the line that drives it; a container is nameless the same way unless its code sets a title.

`entire contents of window 1` raises `Can't make item 1 of entire contents … into type specifier`
here, so the flat whole-tree read that works elsewhere is not available — walk `UI elements`
recursively instead. Dumping role, title, description, value, help and `focused` for every element
answers both "is this control named" and "where did Tab go" from the shell, which is the only way to
ask the second one at all: a focus ring is a picture, and the tree is where the answer is written.

Stage what the window should be *showing* from the shell; drive only the buttons. It is built once
and kept, so a `defaults write` does not appear by reopening it — quit the app, write the key, and
relaunch, and the window comes up on the state you wanted:

    defaults write com.raine.axshot saveDirectory -string /private/var/tmp

Getting there by driving `Choose…` instead is the worst of both. The panel is modal, it holds the
keyboard for as long as it is up, and typing into it obeys the rule above about keys going wherever
is frontmost — which, since an open panel does not pin the machine's focus, can be the user's own
window. Stage the state, then click the named button to test the *action*.

Some states no key reaches: the status line says something only when something has failed. Stage
those from a throwaway build that calls the setter itself, photograph it, then restore the file and
rebuild — two builds inside the lock already held. Reaching them by driving the control that fails
is the trap, because the failure is downstream of the write: recording a chord another app owns
stores that chord before Carbon refuses it, so the test that produced the message also leaves the
user with a hotkey that does nothing.

What a control is showing is a shell question too, and a cheaper one than a screenshot:

    osascript -e 'tell application "System Events" to tell process "Axshot" to get {name, enabled, position, size} of buttons of window "Axshot"'

`enabled` is the assertion for a control that dims itself rather than hiding. `position` and `size`
are the assertion that a row of them still fits: the stack's insets leave the window width less
44pt, and a row that overruns that is not something a screenshot makes obvious. Height is worth
reading as well as width once the window sizes itself to its rows — that it grew for a longer
message, or did not grow for an empty one, is a number rather than a judgement of a picture.

The window's own `position` and `size` are the one `-R` rectangle that is not a guess: both the tree
and `screencapture -R` speak points, so they compose, and a couple of points of margin on each side
catches the shadow. That is cheaper and sharper than shrinking a whole screen to fit.

What the *cursor* does over a control is the one thing here that is not a shell question, and it
looks like one because `screencapture -C` draws the pointer into the picture.
`CGWarpMouseCursorPosition` puts the pointer somewhere without the mouse-moved event that makes
AppKit re-read its cursor rects, so the glyph in the capture lags the position by an unpredictable
number of steps -- the same point photographs as a hand, an arrow and an I-beam depending only on
where the pointer was before it. Both a false pass and a false fail, with nothing in the image to
say which. A hover is one of the few things to hand to the user instead.

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

Whether the shell running the tests can capture at all is the grant of whatever app is hosting it,
and it is one call to find out rather than a thing to assume either way: `screencapture -x -R
0,0,60,60 /tmp/probe.png`, then look at the file. Ungranted it fails with "could not create image
from rect", and a probe image for anything that reads pixels then has to be rendered rather than
photographed — `qlmanage -t -s 900 -o . file.txt` turns a text file into a PNG of that text, which is
enough to prove a reader reads. Granted, the screen becomes something you can measure, which is most of
what [asking what the system draws](#asking-what-the-system-draws) is for.

## Asking what the tree actually says

`--dump` prints one label per element, already collapsed to a line, so it answers which regions
would be hinted and not where any of their words came from. When the question is about the text a
copy would give — why a name nobody can see is in it, which attribute supplied it, which elements
were recursed into — nothing exposes that, and reading the walk instead of the tree is how a
heuristic gets built against a guess. Print it: a throwaway option that walks one candidate and
dumps each element's role, child count and every text attribute it carries answers in one run what
a dozen driven copies only hint at. It comes back out with the same commit that used it.

## Asking an API directly

Most questions about what macOS will report — an event clock, a window list, what an attribute
actually holds — are a single call, and `swift` runs one with no project around it:

    swift - <<'SWIFT'
    import CoreGraphics
    print(CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown))
    SWIFT

It compiles and runs faster than reading the documentation would settle it, needs no bundle and
takes no grant of its own, so a guess about an API is never worth carrying into a design. `swift -e`
does the same for one line. The section below is the exception rather than the rule: a question
about *identity* is the one the interpreter cannot answer, because the answer is about a bundle it
does not have.

Two things to get right when what is being probed is a shared machine state rather than a pure
function of its arguments:

- **Take a quiet baseline inside the probe.** A reading taken while the user happens to be typing or
  clicking measures them and not the thing under test, and it comes back looking like a clean
  result — the first measurement of the idle clock said a posted event had reset it when what had
  reset it was a person. Loop until the state has been still for longer than the effect being
  measured, then act and read again.
- **Post inert events, never real ones.** A probe that has to *cause* input sends it wherever the
  focus is, which is the user's window. A key bound nowhere — F16 — travels the same path and
  changes nothing on arrival. Posting to the probe's own pid looks safer still and is not the same
  experiment: it never enters the session, so nothing watching the session sees it.

## Asking what the system draws

A number the system draws with and offers no API for — a window's corner radius, say — is measured,
and the measurement is a comparison rather than a fit. Draw the candidates yourself, photograph them
beside a photograph of the real thing, and compare the edge profiles row by row. The one that agrees
to under a device pixel is the answer, and the candidates either side of it coming out an order of
magnitude worse is what says the comparison was sharp enough to have one.

Fitting a formula to the real thing instead returns a confident wrong number, because it assumes the
shape before it measures it. A macOS window corner is a continuous curve rather than a circular arc
— `CALayer`'s `cornerCurve = .continuous` draws it and no `NSBezierPath` does — so least squares
through its edge settles on a radius that is nothing in particular, with a residual small enough to
read as agreement.

## Asking who the process is

A run prints nothing about the identity it is running under, and the same build has two: from the
command line `Bundle.main` is `bin/` and carries no identifier, while the same executable at its
path inside `Axshot.app` is the app. AGENTS.md's "Layout" is why, and which APIs fork on it.

So drive `bin/axshot` and never `Axshot.app/Contents/MacOS/axshot`. They are the same build and not
the same process, and the path inside the bundle is the one that passes whether or not the fix is in.

That identity is what the bundle has to exist for; it is still cheaper to ask of a throwaway one
than of axshot. Copy the `CFBundleIdentifier` into an `Info.plist` beside a few lines of Swift
printing whatever is in doubt, build it into a `.app`, and run it both ways — at its path and
through a symlink to it. It needs no lock, no keyboard and no grant of its own, and it is the only
cheap way to see the *before*: the real binary can only be asked one build at a time, and a fix has
to be taken back out to ask it again.

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
- **`--focused` captures whatever is on top of the window.** It aims the walk and not the camera, so
  the outcome line names the region it meant while the pixels are of whatever was in front. Front the
  target again before *each* run, not once per test: a run that ends gives the foreground back, and
  the next one then photographs a different app at the same coordinates and says nothing about it.
  The default has no such gap — a covered box is not offered — so this is a reason to reach for
  `--focused` deliberately rather than to reach for it by habit.
- **A window that is hinting nothing is usually covered, not broken.** `--dump` says so on the window
  line: a high `over` with `boxes=0` is a window whose elements all straddle something in front of
  it, and `culled=` counts the ones that were dropped before being walked at all. Move the window out
  from under the others before concluding anything about the tree.
- **The lock is in the main checkout, not the worktree.** `axshot-test-lock.sh` resolves it from the
  first entry of `git worktree list`, so a `.claude/axshot-test.lock` *inside* a worktree is a
  leftover from something else and its contents say nothing about the lock in force — a missing file
  in it reads exactly like the script failing to write one. The queue sits beside it, at
  `.claude/axshot-test.queue`, and outlives the lock on purpose: release deletes the lock directory
  and has to be able to wake whoever was waiting. `status` is the readout for both.
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

The foreground is the other thing to put back. Every drive brings some window forward, and the user's
next keystroke goes wherever the last activation left it — which is how a test ends by typing into an
app nobody chose. `bin/axshot --driving off` is what returns it, along with taking the border down,
and it belongs at the end of every burst that ran `--driving on` rather than only at the end of the
test.
