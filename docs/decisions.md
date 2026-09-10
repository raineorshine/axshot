# Settled decisions

These were argued out and measured. Reopen one only with a reason, not a preference; each is
explained where it is implemented.

## What becomes a region

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

## Reaching a region from the keyboard

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

## The hold and its exits

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

## How keys reach the app

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
- **The hotkey is a Carbon `RegisterEventHotKey`.** It is the only mechanism that reserves the chord
  system-wide and the only one needing no permission.
- **Escape is taken in `keyDown`, never `cancelOperation`.** AppKit only sends `cancelOperation:`
  once some responder has interpreted the key event, and none of this app's windows edits text, so
  in a plain `NSWindow` the keystroke stays a `keyDown` that walks the responder chain and dies
  there unhandled. Both windows take it at the last step of that walk instead, which also leaves it
  behind whatever wanted the key first.

## The overlay on screen

- **A control is named, reachable by Tab and legible at 4.5:1.** What the app draws is pictures — a
  hint plate, a chord box, a swatch, a thumbnail — and a picture says nothing to a reader and
  answers no key by itself, so each carries its own title, value and press and takes Space the way a
  button does. The overlay is the exception: it holds the whole keyboard while it is up, so a reader
  gets Escape and nothing else. [accessibility.md](accessibility.md) is the set of ways
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

## The workflow

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
