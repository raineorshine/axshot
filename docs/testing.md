# Testing without the live app

Axshot is a hotkey, an overlay and a screenshot, all of which sound like they need someone at the
keyboard. Most of a change can be settled with no lock, no keyboard and no installed app, and this is
how. [The `test` skill](../.github/skills/test/SKILL.md) is the procedure once the live app is needed,
and the rest of the mechanics are split by what they cost:

- [driving.md](driving.md) — driving the installed app while the user works, and what a driver gets
  wrong.
- [seeing.md](seeing.md) — photographing and measuring what is on screen, and what a capture does not
  prove.
- [environment.md](environment.md) — failures that are the machine rather than the change.

## What needs no lock

- **`bin/axshot --dump`** walks, filters and prints the regions that would be hinted, without drawing
  anything or touching the installed app. It is the only path that does not touch Screen Recording,
  and [filter.md](filter.md) is how to read it. It cannot see
  [a covered window, or any window while an overlay is up](environment.md#a-window-the-walk-does-not-see).
- **A rect it printed can be photographed** with `screencapture -x -o -R x,y,w,h`, which answers
  whether a computed region frames what it claims to — most of what a filter change is judged on —
  with no overlay, no keyboard and no live slot, given [a shell that can capture](seeing.md).
- **`bin/axshot --pid 1`** runs the permission checks and exits at "no target app", drawing nothing.
  It is the permission probe to poll with: a real capture would flash a full-screen overlay every few
  seconds and swallow the user's keystrokes while it was up.

## A filter change is a diff of region lists

Not of the count: dropping one candidate and revealing the one it was hiding leaves `boxes=` and
`candidates=` where they were. Dump the branch beside a build of `origin/main` and diff the listings
with the labels stripped — a label renumbers everything after the first line that changed. The
comparison build is never installed and needs no lock, but it does need the bundle around it, since
[a loose binary is untrusted](permissions.md#one-binary-two-identities) however it was signed:

    git show origin/main:axshot.swift > /tmp/before/axshot.swift
    swiftc -O -swift-version 5 -o /tmp/before/axshot /tmp/before/axshot.swift
    cp -R Axshot.app /tmp/Before.app && cp /tmp/before/axshot /tmp/Before.app/Contents/MacOS/axshot
    codesign -f -s "Axshot Local Signing" /tmp/Before.app

- **Dump each build twice, alternating, and diff each build against itself as well as the other.**
  The desktop can move between runs, and only an empty self-diff says which lines of the
  before-and-after diff are the change rather than a window redrawing.
- **Strip what renumbers.** A change to *which windows* are walked renumbers `w<n>` on every line
  after the window it added or dropped, the way a label does, so swap each index for the app and pid
  on its window line; strip `walk_ms`, which no two runs share. `--bundle` narrowed to the app the
  change is about then puts the verdict on one line.
- **For a rule about windows rather than elements, ask whether the desktop holds the case before
  either build exists:** a scratch script running the old rule and the new one over
  `CGWindowListCopyWindowInfo` names the windows that would change.

## The real code runs outside the app

It is one file with no dependencies, so any part of it runs in a scratch file.

- **A refactor of a pure pass** — `filter`, `hinted` — is checked by extracting both versions into one
  scratch file, the old one from `git show origin/main:axshot.swift` under another name, and comparing
  their answers over a few thousand generated inputs. Generate the cases each branch is there for —
  boxes the size of their window, repeats inside the tolerance and on the grid, nesting either side of
  the ratio — and tally which verdicts fired, since a branch the generator never reaches passes by
  default.
- **How a drawing looks** is answerable before anything is installed. A draw function is a function of
  a rect and a clock, so a standalone `swift` script that calls it over sample content and writes a PNG
  renders the real thing — the same arithmetic, the same `NSGradient`, the same compositing. Render it
  over white and over black in one image: an overlay drawing sits on whatever window is underneath, and
  the failure that reads as a bug in the code is a colour that disappears into one of them. Settle a
  palette or an amplitude there, over as many rounds as it takes, and the driven run afterwards only
  asks whether the app puts it on screen.
- **What needs the rest of the file** — a view drawn into a PNG, what a `Session` makes of a hand-built
  walk — is a hook spliced into a copy of the whole file ahead of `let arguments`, not into
  `runSession`, which returns before its dump branch whenever no window can be walked. A view with no
  window renders through `bitmapImageRepForCachingDisplay(in:)` and `cacheDisplay(in:to:)`.

## Asking what the tree says

`--dump` prints one label per element, already collapsed to a line: which regions would be hinted, not
what the tree holds or where any of their words came from.

- **What a window's tree contains** — "why is this link not in the tree" — is a standalone Swift file
  that creates an `AXUIElementCreateApplication` for the pid, sets `AXManualAccessibility` on it
  (Chromium exposes nothing of the page until a client asks), and walks `AXChildren` printing role,
  frame and label. It needs no bundle, no lock and no visible window, so it reads the covered window
  `--dump` cannot. It is also not axshot's trust check: measured from a session shell, the probe read a
  fully covered window's tree while axshot built loose from the same source answered `trusted=false`.
  `AXIsProcessTrustedWithOptions` asks about the calling binary's own identity and the reads themselves
  were permitted, so `trusted=false` is no evidence that a probe from the same shell comes back empty.
- **Where a copy's text came from** — why a name nobody can see is in it, which attribute supplied it,
  which elements were recursed into — is a throwaway option that walks one candidate and dumps each
  element's role, child count and every text attribute it carries. One run answers what a dozen driven
  copies only hint at, and the option comes back out with the commit that used it. Reading the walk
  instead of the tree is how a heuristic gets built against a guess.

## Asking an API directly

Most questions about what macOS will report — an event clock, a window list, what an attribute
actually holds — are a single call, and `swift` runs one with no project around it (`swift -e` for one
line):

    swift - <<'SWIFT'
    import CoreGraphics
    print(CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown))
    SWIFT

It answers faster than documentation would, needs no bundle and takes no grant of its own, so a guess
about an API is never worth carrying into a design. Identity is the exception, being a question about a
bundle the interpreter does not have — [below](#asking-who-the-process-is). When the probe reads shared
machine state rather than a pure function of its arguments:

- **Take a quiet baseline inside the probe.** A reading taken while the user happens to be typing or
  clicking measures them, and comes back looking like a clean result — the first measurement of the
  idle clock said a posted event had reset it when a person had. Loop until the state has been still
  for longer than the effect being measured, then act and read again.
- **Post inert events, never real ones.** Input a probe causes goes wherever the focus is, which is the
  user's window. A key bound nowhere — F16 — travels the same path and changes nothing on arrival.
  Posting to the probe's own pid looks safer and is not the same experiment: it never enters the
  session, so nothing watching the session sees it.
- **Turn the run loop the way the app does, and read the answer both ways.** What a process does to its
  own windows reaches the window server only when its run loop turns, so ordering a window out and
  reading `CGWindowListCopyWindowInfo` in the same callout measures that deferral. Read once with the
  thread kept off the run loop and once turning it in millisecond slices: listed the first way and gone
  within a turn the second is an order-out waiting on the run loop; gone only after a stretch of turns
  is an animation. A clear non-activating panel configured like the window in question draws nothing
  and takes no focus, so the probe needs neither the lock nor the idle gate.
- **A question about a grant needs a bundle, and it cannot live in the scratchpad.** LaunchServices
  registers nothing under `/private/tmp`, so TCC has no row to resolve, the app never appears in the
  list, and `tccutil` answers `No such bundle identifier`. Worse, a request made from there is
  recorded as asked: every later request returns false with no dialog and no row, including after the
  app is moved somewhere real. Build the throwaway into `/Applications` with a bundle identifier of
  its own, and if it ever ran from the scratchpad, `tccutil reset <service> <bundle-id>` before
  believing anything it says. Asking what *axshot* has is the other case, and takes axshot's identity
  rather than a bundle id of its own — [permissions.md](permissions.md#one-binary-two-identities).

## Asking who the process is

The same build has [two identities](permissions.md#one-binary-two-identities), and a run prints
neither. Drive `bin/axshot` and never `Axshot.app/Contents/MacOS/axshot`: they are the same build and
not the same process, and the path inside the bundle is the one that passes whether or not an identity
fix is in.

What an API answers under each identity is cheaper to ask of a throwaway bundle than of axshot. Copy
the `CFBundleIdentifier` into an `Info.plist` beside a few lines of Swift printing whatever is in
doubt, build it into a `.app`, and run it both ways — at its path and through a symlink to it. It needs
no lock, no keyboard and no grant, and it is the cheap way to see the *before*: the real binary answers
one build at a time, and a fix has to be taken back out to ask it again.

## Reading a crash

A burst whose `--driving off` answers `app=none` after its `on` answered `running` is the app having
died mid-burst. Put it back with a plain `open /Applications/Axshot.app` before anything else — the
user's hotkey does nothing until then — and read the press it died on out of
`~/Library/Logs/DiagnosticReports/axshot-<date>.ips`: JSON after a one-line header, whose faulting
thread's frames carry an `imageOffset`.

`EXC_BREAKPOINT` is a Swift trap, and a `-O` build names only the function it is in. The offset, plus
the `0x100000000` the binary's text is linked at, lands in a run of `brk #1` stubs at the end of that
function, one per trap site — so disassemble the build that crashed (`objdump -d` over the function,
piped through `xcrun swift-demangle`) and grep for the branch *into* that stub. The instructions before
the branch are the line: a string literal is loaded from immediate constants, so a run of `movk`
spelling out part of an interpolation names it outright. A second frame in the same function is the
link register — the last call made before the trap — rather than a caller.

Throwaway logging is the likeliest source. `Int(_:)` traps on an infinite value, and `CGRect.null` has
one for an origin: `Walk.box` is null for a window with nothing left of it on a screen, which the cull
never walks and `--focused`, culling nothing, walks all the same. Format a rect through `isNull`, as
the `⌘D` account does, or the diagnostic traps on the first run that meets one.

## Exercising the lock script

The queue and the handoff run end to end without the installed app: point `AXSHOT_ROOT` at a scratch
directory and `AXSHOT_LIVE` at a stand-in bundle inside it — one with an executable
`Contents/MacOS/axshot`, since `release` refuses without a snapshot to put back. The copy from
`origin/main` run beside the edited one is the *before*.

- **Each sandboxed session needs a worktree or a session id of its own.** Ownership is the worktree,
  then the session id when both sides carry one, and every process this session starts inherits
  `CLAUDE_CODE_HOST_SESSION_ID` — so a second "session" run from the same checkout is the holder, and
  its `wait` returns at once holding the lock it was meant to queue for. Run each from its own directory
  outside any git checkout, or give each an id of its own.
- **`AXSHOT_LIVE` scopes the files, not the processes.** Whether the app is running, and quitting it,
  go by a process pattern that matches the user's real app wherever the sandbox points. `install`,
  `break` and a restoring `release` can quit the real app and launch the stand-in in its place;
  `acquire`, `wait`, `status`, `dequeue` and `release --keep` touch no process, and are the ones a
  sandbox runs.
