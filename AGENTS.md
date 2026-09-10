# Axshot

A macOS menu bar app that finds screenshot regions in the accessibility tree. One Swift file, three
shell scripts, no dependencies.

**`axshot.swift`'s header comment is the reference for the tool itself** — every option, and the
reasoning behind each moving part. Read it before changing behaviour; it is kept current and this
file does not repeat it.

Current on `origin/main`, that is, which a worktree holds only as of its cut. A tuned constant is
exactly what another session re-measures and moves, and the README's `--dump` sample ages with it —
so `git fetch` before quoting a default or a number to the user, not only before shipping. A
question answered off the worktree is answered as of whenever the worktree was made, and by the time
the rebase conflicts on it the user has already decided.

## Guides

- [docs/permissions.md](docs/permissions.md) — what TCC considers "this app", why a grant survives
  one rebuild and not another, and the three ways granting appears to fail when it has not.
- [docs/testing.md](docs/testing.md) — driving the app with no human at the keyboard, and the
  environment failures that look like product bugs.
- [docs/accessibility.md](docs/accessibility.md) — what a new control owes the tree and the
  keyboard, and the AppKit defaults that leave one drawn correctly and reachable by nothing.

## Skills

Two skills live in `.github/skills/`: `test` installs this branch's build into the live app under a
mutex and drives it, `ship` lands the change on `origin/main`. Read the one that matches what you are
about to do, before doing it — `.github/skills/` is not a directory the `Skill` tool loads from, so
these are files to open and follow by hand, and asking for one by name only reports that no such
skill exists. A skill that describes a command its script does not have is the sign of one of these
being clobbered rather than of a stale document, and the repair is in git rather than in a rewrite:
`git log --oneline -- <path>` finds the commit that added it, and a later copy that is byte-identical
to the version from before confirms it was reverted wholesale. Take that file back whole where
nothing has touched it since, and reverse the bad commit's hunks with `git apply -R --3way` where
something has. A change to anything the user sees or touches is always about to be tested, and nobody
has to ask for it: a clean compile is not a place to stop and hand back, because the thing the user
would look at is not on their machine until `test` has put it there. That holds for a session on the
user's Mac, which is the only place either skill can run; one that is somewhere else hands the
testing over instead, and "When there is no Mac" below is what it does with the change.

## Layout

| | |
|---|---|
| `axshot.swift` | everything: walk, filter, overlay, hotkeys, settings, CLI |
| `build.sh` | compiles, assembles `Axshot.app`, signs it, links `bin/axshot`, installs it; `--no-install` stops before the install |
| `create-signing-cert.sh` | creates the signing identity once; idempotent |
| `scripts/axshot-test-lock.sh` | the mutex over the installed app and the keyboard, and the queue for it |
| `scripts/wait-idle.sh` | blocks until the user has stopped typing, in front of anything that takes the foreground |

The same binary is the app when launched with no arguments and a CLI when given any — the same
bytes, but not the same process identity. `bin/axshot` is a symlink into the bundle and dyld reports
the symlink rather than what it points at, so on the command line `Bundle.main` is `bin/` and carries
no identifier at all. Anything that would otherwise ask the bundle who this is — the preferences
domain, the identifier handed to `tccutil` — has to name what it wants instead. Which identity a run
picked up is a shell question, and [docs/testing.md](docs/testing.md#asking-who-the-process-is) is
how to ask it. Build output (`Axshot.app/`, `bin/`, `.claude/`) is generated and ignored.

There is one installed app, `/Applications/Axshot.app`, and the permission grants belong to its
signature rather than its path — so any *bundle* signed with the same certificate satisfies them
wherever it sits. A loose binary outside one does not, however it was signed: the requirement names
the bundle identifier, and a bare Mach-O carries none. What is genuinely single is the running
instance, which owns the global hotkeys, and the login item, which names one bundle path. `build.sh`
compiles inside the checkout and installs from there through the lock, which refuses while another
session is driving the app. A session that wants a held lock does not ask again later: `wait` queues
it and blocks until the release hands it over, so parallel worktrees test in the order they arrived.

## Driving the app on a live machine

The user is at the keyboard doing their own work while a test runs, and every drive of the real app
brings some window to the front. **Wait for them to stop before you start.**
`scripts/wait-idle.sh` blocks until nobody has typed for three seconds, and goes in front of every
activation, every overlay and every posted keystroke: a burst begun mid-sentence takes the letter
they were in the middle of and lands the rest of the hint in their editor. It gives up rather than
waiting forever — someone still typing after two minutes is working, and the answer to that is to
park and let them name the moment, not to take the foreground anyway.

It gates the *start* of a burst and not the keys inside one, because no clock on the machine
separates a person's keypress from one this session posted;
[docs/testing.md](docs/testing.md#waiting-for-the-keyboard) is the measurement and its edges.

And say so while you hold it. `bin/axshot --driving on` opens a burst and `bin/axshot --driving off`
closes it. While it is on, the app draws a pink border around every screen, so a window arriving
uninvited reads as this session rather than as the machine misbehaving — and closing the burst hands
the foreground back to whoever had it before the burst took it. Both ends belong to the burst and
not to the test: a build the user is trying by hand is their own session at their own keyboard, and
the border is off for it.

Then hold the foreground for a second, not for a stretch: activate, send the hint, send Return, and
let go. Everything that is not the keystrokes — reading `--dump` output, checking the PNG, deciding
what the labels mean — happens before the sequence starts or after the capture lands, never in the
middle of it with a window parked in front of whatever the user was typing into. What a run has to
undo before it ends is the last section of
[docs/testing.md](docs/testing.md#leaving-the-machine-as-you-found-it).

## When there is no Mac

Some sessions run in a trusted cloud environment, which is a Linux container holding a fresh clone
and nothing else. Everything above about builds, installs, overlays and screenshots assumes a Mac,
and none of it is there: no `swiftc`, no `codesign`, no `osascript`, no `screencapture`, no
`/Applications` at all. So `test` is impossible from the `build.sh` it starts with and `ship` from
the `build.sh --no-install` it starts with, and neither is partly possible — `--dump`, the lock-free
half of testing, still needs a compiled binary. A session that finds this out by failing has already
written the change as though someone would run it.

`uname -s` is the cheap definitive check, and it belongs before the work rather than after: anything
other than `Darwin` cannot build, install, drive or photograph the app. The harness will also have
said it is running in a managed remote environment. What misleads is the lock:
`scripts/axshot-test-lock.sh status` is shell over a directory, so it answers `unlocked` in a
container exactly as it would on an idle Mac, and looks like an invitation to test something that
cannot exist. Reading `status` is harmless; taking the lock is not. An acquire records a mutex over
nothing — there is no installed app to snapshot — and tells a session on the user's real machine
that a test is in flight when none is.

Everything up to the compile is unchanged: read the tree, change the code, keep `axshot.swift`'s
header comment and `README.md` current, commit, push to the branch the harness designates and open
the pull request it asks for. The clone is ephemeral, so anything not committed and pushed is gone
with the container. Then, at the point the `test` skill would have been invoked, queue a handoff
task card (`spawn_task`) for a session on the user's machine, and park. That card opens a session
with none of this conversation, so its prompt has to stand on its own: the branch to fetch, what
changed and where, the checks in the order they would fail, which assumptions were never verified
and what the fallback is if one of them is wrong, and that fixes go to the same branch and pull
request rather than a new one.

Then say it is untested everywhere it will be read later — in the response, in the pull request
body, and in a line of its own in the commit body, which is the convention step 2 of `ship` already
carries. That the code never reached a running app is the one thing a later reader cannot recover
from the diff.

`ship` is not a cloud session's to run either, even for a docs-only change that would have compiled:
it releases a lock it should never have held, and pushes straight to `origin/main`, where the cloud
harness requires a branch and a pull request instead.

## Session titles

A lifecycle prefix on the session title says what a session is doing while it is doing it, so the
sidebar answers "which chat is holding the lock" without opening any of them. One prefix at a time,
replaced rather than stacked, and never reported in the response. Every title carries one: a title
without a prefix says nothing about the session, and the sidebar cannot tell it from a chat that
never had a stage at all. A session is named by the harness and so begins without one; putting the
first prefix on that inherited title is part of the first response, not something to wait for a
stage change to prompt. A prefix comes off only when another replaces it, so a session that has
nothing left to do keeps the one for the last stage it reached.

**Ask which session this is before renaming one.** `get_session "self"` is the only answer, and it
changes under a fork: a forked session carries the whole transcript, the id it read earlier in that
transcript, and a different id of its own, so a rename that reuses the remembered one retitles the
session it forked *from* — which is generally the one still holding the lock, and whose title is
therefore the one the sidebar most needs to be true. A fork also starts in the worktree of whatever
session it forked from. Nothing stops a branch being checked out there, and it moves that worktree
under the other session's feet; put it back on the branch it was on when the work is landed.

| | |
|---|---|
| `⏳ ` | implementing — the weakest of them; every other prefix takes precedence |
| `🔓 ` | about to take the lock — including queued and blocked on it — or just released it |
| `🔒 ` | holding the lock; the installed app is this branch's build |
| `📦 ` | tested, and shippable without re-testing |
| `🚀 ` | shipping, and shipped — it stays until the session starts something else |
| `🚙 ` | parked: the work is sound and waiting on the user — a decision, or a look at a build already in front of them |
| `🪦 ` | dead end — kept for the findings, not to resume |
| `📚 ` | extracting learnings into `AGENTS.md`, `docs/` or the skills |

Set a prefix when the stage *starts*, not when it succeeds, and correct it if the stage falls over: a
title that only becomes true at the end is blank for the whole stretch the sidebar is there to
describe. `📚 ` goes on the moment a `learn` skill is invoked, before anything is read. The lock
and ship prefixes are set by the skills that own them; the rest are set by hand, and nothing
reconciles a title against reality. Handing back is itself a stage: a response that closes on
something for the user to do — test it, look at it, decide — is a park, and `🚙 ` goes on before
that response, since the idle dot cannot tell "waiting on you" from "given up on". Waiting on a
hands-on look is the exception: the lock is held and the installed app is this branch's build for as
long as they are looking, so that stays `🔒 `, and it is `🚙 ` only once there is nothing to hold.

A cloud session never reaches `🔒 `, `📦 ` or `🚀 `: it holds no lock, tests nothing and ships
nothing. It ends at `🚙 ` — the work is sound and waiting on the user — which is the state the handoff
card leaves it parked in.

This vocabulary, and the worktree-and-lock workflow around it, came from the sibling `karabiner`
repo; its `docs/workflow.md` is where the reasoning lives, and where to look first when a convention
here reads as thinner than it should.

## Settled decisions

These were argued out and measured. Reopen one only with a reason, not a preference; each is
explained where it is implemented.

- **Nothing is cached between captures.** The tree is walked on demand every time. A resident cache
  would save a fraction of what the capture alone costs, and would keep every Chromium app's
  accessibility engine switched on for as long as the app runs.
- **Only regions that are actually on screen are offered**, clipped to their own window and to
  whatever no window in front is drawn over. An element scrolled out of view, or behind another
  window, has a frame that would photograph something else. Both crop rather than reject: half a
  sidebar is still half a sidebar's pixels. A region dragged by hand is the exception and is clipped
  to nothing but the desktop: a rectangle drawn around what someone is looking at is already what is
  on screen.
- **Every window with pixels of its own is hinted, not just the front one**, and they are walked at
  once. Raising a window to capture it changes what is being captured, which is the whole reason to
  reach one by hint. The window server culls the covered windows before any accessibility message is
  sent, which on a crowded desktop is most of them; what survives is a handful of separate processes,
  and waiting on those one at a time is waiting the machine did not have to do.
- **The window itself is never a region.** A box the size of the window is the shot ⌘⇧4 then Space
  already takes, and it was standing in front of the region worth having: the nesting collapse drops
  an inner box the outer one swallows unless the inner is more than two thirds of it, which a content
  area usually is. The test is the size and not the role — the window, its content view and the group
  they wrap all report the same frame, so dropping the AXWindow alone re-offers the same rectangle one
  letter along. An app whose accessibility is one box the size of its window is what the drag is for.
- **Only text that was on screen is copied.** The tree carries names written for screen readers
  alongside the words a person can read, and no attribute separates them — the same field holds a
  button's visible label and an icon's stand-in name — so the test is whether the text would have
  fitted in its own element. A geometric answer to a question the tree does not answer.
- **The size floor measures boxes, not words.** A node carrying text is offered at whatever size the
  text was drawn at. The floor is there to keep the overlay legible against those nested containers,
  which is a reason to measure a box and no reason at all to hide a word: ordinary body text is under
  any floor worth setting for a box. Which of the two an element is comes from the same measurement
  the copy exit makes — a text role is text, anything else counts only where its label would have
  fitted inside it — so an icon's stand-in name still buys no hint. What that costs is the count,
  which is `--max-hints`'s to hold and is set to what the hint alphabet labels in two keystrokes
  rather than to a round number; splitting the cap between boxes and words was weighed and does
  nothing, the boxes being far too few to crowd the words out.
- **What the overlay asks about the keyboard, it asks the hardware.** The tap swallows every
  key-down, so `CGEventSource.keyState(.combinedSessionState, …)` reads false for the key it has
  just eaten — the session state is what is left of the stream after the taps have had it.
  `.hidSystemState` is the physical keyboard and is the one to ask. This is not a detail of the one
  key that reads it today; it is true of any key a session wants the *state* of rather than the
  press.
- **A key is matched by its position or by its letter, according to which one it is.** HJKL and the
  hotkey chords are hand shapes and are read as physical keys, so they stay where the hand is on any
  layout; a key chosen because of the word it stands for is read as the letter the layout types, so
  it stays where the word is. Adding a key means deciding which of the two it is before deciding
  where it goes -- and, for a key the hold reads, whether it applies to a region that is not in the
  candidate list. A dragged rectangle and a half display are held exactly as a hinted region is and
  have no index, so where the key sits either side of that guard is the whole of the answer: the
  Option arrows are past it because they walk the tree, and anything acting on the rectangle itself
  belongs in front of it — which is where the unmodified arrows moved to when they became a step
  across the screen.
- **Regions are picked by hint, not named.** Naming would let the walk stop early, but most of what
  is worth capturing carries no label.
- **What is lettered and what is reachable are two questions.** The alphabet runs out long before
  the tree does, so a plate is how a region is reached *from nothing* and the arrows are how it is
  reached from somewhere; only the first is rationed. The candidate list is what every arrow reads —
  `ascend` included — so a cap applied to it rather than to the labels takes regions off the keyboard
  entirely, and a ranking that fills the alphabet with one kind of region empties the list of the
  other. Kept apart, the ranking is only ever about which regions are convenient to reach first, and
  it puts the leaves there: a leaf is the smallest box at its spot and naming it is the way in, where
  a container is one `⌥↑` from anything underneath it.
- **The bare arrows are the screen; Option is the tree.** Unmodified, each of the four holds the
  nearest leaf that way on screen, preferring one that lines up over one that is merely close. The
  screen is what is being looked at, and the tree's shape says nothing about what sits beside what —
  it will put twenty steps between two boxes two centimetres apart. Leaves only, because a container
  that way is also a container over here, and which regions those are is asked of the boxes and not
  of the tree, for the same reason the copied text is: the tree nests things that are not drawn
  inside each other. Within one window, though — a box in the window behind that contains a box in
  front of it is behind it and not holding it — while the step itself crosses the boundary freely,
  reading no document order to be stopped by.
- **Option is two axes, not four directions, and is not the lesser of the two.** Up and Down move
  along the held region's own line of ancestors and descendants; Left and Right move across it and
  skip that line entirely. A step that lands on a parent or a child is the same region drawn bigger
  or smaller, which is a keystroke the other axis already spends. It is what the unmodified keys
  cannot do: they land on leaves and only leaves, so Option-Up is the whole of how a container is
  reached from a held region — the sidebar rather than the row in it — and a screenshot is very
  often of the container. All three stop at the window they started in, document order between two
  trees saying only which was in front.
- **Shift reaches, and the shot is then the box around everything held.** It composes with whichever
  modifier already chose the axis — bare for the screen step, Option for the tree — so a selection
  is one rule rather than a key per direction, and the opposite arrow gives back the region last
  reached. A capture is one rectangle, so several regions is the rectangle they sit in: that box is
  what the mask has to be drawn around for the overlay to go on showing what will be photographed,
  and the brackets move onto each region, that being the part the mask can no longer say. Everything
  that reads the held region reads the box instead — the shutter, the margin, Option-Up, the
  transcription — while the words stay each region's own, handed over in document order. Shift is
  not free on the letters those keys share: HJKL's Shift is already a word, so the reach is on the
  arrows alone.
- **Which display a key means is answered by the pointer.** Not the one the held region is on, not
  the one the front window is on: the crosshair follows the pointer for the whole session and is the
  only thing on a two-display desktop that says where the keyboard is aimed. Every key that names a
  screen rather than a region reads it that way, and takes the strip below the menu bar with it for
  the same reason each time — no ordinary window is drawn there, so nothing the key was reached for
  can be lost with it. A new one inherits both answers rather than picking again.
- **One hotkey; the hold decides where the shot goes.** The letter masks everything outside the
  region rather than firing the shutter, because the region came from a tree the app describes and
  the one thing worth seeing before the capture is what that tree handed over. Which destination a
  region wants is only clear once it is on screen, so it is chosen at the exit and not at the
  press: Return files the PNG, ⌘C puts that picture on the clipboard, ⌘⇧C puts the region's own
  text there instead — the same tree holds the words, and they are the better carrier whenever the
  point was what it said. A second tap of the hotkey cancels, since the tap sits ahead of the
  hotkey manager and sees the chord before Carbon does; the press that opened the session is the
  one already under the fingers.
- **The text box is a field from the frame it is drawn in.** What `⇧J` and `⇧T` put on screen is on
  its way to the clipboard and is usually nearly right, so the caret is already in it — at the
  start, because the run is read against the region under it before it is typed in. The cost is that
  every other overlay key goes quiet while it is there: a bare letter types, so the arrows stop
  stepping regions and `⇧J` stops toggling. Escape is the single way out and also abandons the edit,
  since everything you would do after closing the box either discards what was typed or works with
  it open; `Return` is the exception and stays the shutter. Standard editing behaviour is spelled
  out by hand because it cannot be borrowed: AppKit's key bindings reach a view through the
  responder chain, and a window in one has the keyboard, which is the focus this app must not take.
- **A control is named, reachable by Tab and legible at 4.5:1.** What the app draws is pictures — a
  hint plate, a chord box, a swatch, a thumbnail — and a picture says nothing to a reader and
  answers no key by itself, so each carries its own title, value and press and takes Space the way a
  button does. The overlay is the exception: it holds the whole keyboard while it is up, so a reader
  gets Escape and nothing else. [docs/accessibility.md](docs/accessibility.md) is the set of ways
  this looks done when it is not.
- **A driven burst says it is one, and gives the foreground back.** `--driving on`/`off` brackets
  it, and what is bracketed is the burst rather than the test lock — a border up for the whole time
  the lock is held is a colour nobody sees by the second look, and the user testing by hand is not
  being driven. The border is kept out of every screenshot by the window's sharing type rather than
  by being hidden around each shutter: it is drawn on a window's own edge, which is inside a region
  a capture clipped to that window can ask for, and the process taking the picture is not always the
  process holding the border. Measured, not assumed — a `sharingType = .none` window photographs as
  the desktop behind it. Which is also why the walk skips such a window rather than counting it as
  cover: a full-screen border that occludes leaves every window on the machine culled, and every
  capture taken during a burst — the burst's own included — ending `windows=0`.

- **The app never takes focus.** Hint keys come from an event tap, and so do the clicks that aim
  the text box and the ones that draw a region — the overlay window ignores the mouse. A focused
  target redraws its title bar inactive, and the screenshot would show that; a window that accepted
  a click would activate the app and cause exactly that, which is why input arrives ahead of any
  window rather than through one. Two things follow, both measured rather than reasoned about, and
  both explained where the overlay is built:
  - **The overlay cannot own the cursor.** A cursor belongs to the *active* application and not to
    whoever owns the window under the pointer, so `NSCursor.set()` and a `.cursorUpdate` tracking
    area are both no-ops here however the window is configured. Anything the pointer should look
    like is drawn into the overlay at the tracked position, with the system arrow riding on top.
  - **The overlay must not accept mouse events.** A session runs a bare `CFRunLoop` and never pumps
    `NSApp`, so events routed to this app queue unanswered and the WindowServer beachballs the
    screen for as long as the session is up. `ignoresMouseEvents` stays true and the tap takes what
    is wanted, which it can, being ahead of every window.
- **The hotkey is a Carbon `RegisterEventHotKey`.** It is the only mechanism that reserves the chord
  system-wide and the only one needing no permission.
- **Escape is taken in `keyDown`, never `cancelOperation`.** AppKit only sends `cancelOperation:`
  once some responder has interpreted the key event, and none of this app's windows edits text, so
  in a plain `NSWindow` the keystroke stays a `keyDown` that walks the responder chain and dies
  there unhandled. Both windows take it at the last step of that walk instead, which also leaves it
  behind whatever wanted the key first.
- **A test lock that cannot move gives up rather than being made unstuckable.** Every way the queue
  can stall ends in a bound or a recovery instead of a mechanism that prevents it: a wait gives up on
  its own deadline and reports what it was waiting on, `dequeue` clears a queue whose head nobody can
  move, `break` recovers an abandoned lock. Handing the lock straight to the next ticket, so that it
  is never unheld, was weighed and turned down — it means rewriting ownership onto a process that has
  not woken yet, tracking that process's liveness, and refreshing the snapshot wherever the live app
  no longer matches it, to close a window that a refusal already covers.
- **`origin/main` advances by fast-forward only, and "merge main" names the rebase.** A branch
  squashes onto it and pushes, so the history carries no merge commits and a rejected push costs a
  rebase and a retry rather than anything else. Both skills say the word loosely — `ship` is titled
  "finish change → merge to main" and calls a rebase conflict a merge — so an instruction to merge
  main before testing or shipping is the fetch-and-rebase each of them already opens with, and not a
  request to start keeping merge commits.

## Changing the region filter

`--dump` is the whole feedback loop: it prints what would be hinted, with the walk cost, and never
draws an overlay. Tune against it before looking at pixels; [the README](README.md#tuning-the-filter)
reads a sample of its output line by line.

Prefer changing the filter's passes over changing `--min-size`. The tree is mostly nested containers
that repeat their child's box, and the collapse that removes them is what decides whether the
overlay is legible; the floor only hides small *containers*, text being exempt from it. A count that
needs bringing down is `--max-hints`'s to answer rather than the floor's — most of a text-heavy
window's regions are under the floor and stay there whatever it is set to. `--max-hints` is what
brings the *plates* down and it drops no regions at all: it defaults to as many as the hint alphabet
labels in two keystrokes, and hands them to leaves first, then containers, size descending within
each. An unlettered region is in the list like any other and every arrow steps to it, so the ranking
decides what is convenient to reach rather than what is reachable at all.

When quoting costs, measure the walk and the capture together. The capture is the larger half by an
order of magnitude, so a change that halves the walk is invisible, and a benchmark that reports only
the walk will justify work that no one can perceive.
