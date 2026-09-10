# axshot

Screenshot a region of the screen by typing a hint, not by dragging a rectangle.

Every region worth capturing — a sidebar, a message, a diff panel, a button — is already described
in the app's accessibility tree, with a frame that can be read. `axshot` walks the tree of every
window with pixels of its own on screen, keeps the boxes that are actually visible, overlays a
Surfingkeys-style hint on each, and captures the one whose hint you type. The region snaps to a real
element instead of to wherever the pointer happened to stop — and where the tree describes nothing to
snap to, a rectangle can still be dragged by hand.

Every window and not just the front one, because raising a window to capture it changes the thing
being captured — the log that is still scrolling, the dialog sitting over what it is about, the two
windows being compared. A region under another window is not offered: it would photograph that
window instead. A region the front window takes half of is offered on the half that is left, the
same way one running off the edge of the screen always has been. A window that no capture can see
is the exception and covers nothing — the window server marks it, and a shot of that rectangle
returns what is behind it, which is a window worth hinting.

Typing a hint holds the region rather than firing the shutter: everything outside it is masked and
`Return` takes the shot. The mask fades in rather than appearing, so what the eye follows is the
darkness closing on the region it leaves clear and not the whole screen going dark at once, and it
fades back out again wherever it leaves without a picture having been taken. The arrows adjust what
is held: each of the four holds the nearest *leaf* region that way on screen, across the window
boundary and all, so a hint that lands near the mark does not have to be retyped and what is next to
it on screen is reached by pointing at it. `HJKL` do the same four things so the hand can stay on the
letters. `⇧` with any arrow reaches rather than moves — that region is added to what is held, and
the shot grows to the box around the lot, a capture being one rectangle — with the opposite arrow
giving the last one back. An arrow pressed while the hints are still up holds the largest region, so
the screen can be walked without typing a letter at all. `⌥` with any of them walks the tree instead — `⌥←` `⌥→`
step to the neighbouring region, `⌥↑` widens to the one enclosing it, `⌥↓` goes back in — which is
how a container is reached at all, the unmodified keys landing only on leaves; those three stay
inside the window they started in, since two windows are two trees. `⌥⇧←` and `⌥⇧→` reach along
that axis the way `⇧` and a bare arrow reach across the screen. `Delete` returns to the hints;
`Escape` — or a second tap of the hotkey — cancels. `⌘,` cancels and opens settings, held region or not — the overlay covers the menu
bar it would otherwise take to get there. `?` puts the whole list of keys on screen — the
overlay is the only interface there is, so the legend is drawn over the middle of it and comes back
down on `?` or `Escape`. The same list is on the menu bar as **Keyboard Shortcuts**, for reading it
without pressing the hotkey first.

A region can also be drawn by hand, for what the tree does not describe — a slide, a video, a corner
of a canvas, half a paragraph, an app whose accessibility is one box the size of its window. Press
the left button anywhere and drag; the mask follows the rectangle as it is made, and letting go
holds it exactly as a hint would have, so everything below reads it without knowing where it came
from. Hold `space` while the button is down to lock the size and move the whole rectangle — the
corner you put down first is otherwise fixed, and a rectangle the right size in the wrong place
would have to be drawn again. `Escape` abandons a rectangle being drawn before it abandons the
session, and a click that goes nowhere holds nothing.

A dragged region is the one region not clipped to the focused window: a rectangle drawn around what
you are looking at is by definition what is on screen. Its *words* still come out of the focused
window's tree, so `⌘⇧C` over the target window copies what the rectangle covers and over another
app's window copies nothing. The arrows have nothing to step to from a region that is not in the
tree, and beep; `Delete` goes back to the hints.

`⌘⌥←` and `⌘⌥→` hold the left or right half of a display, which is the one rectangle worth drawing
often enough to be worth a key — a window tiled to one side, a video beside the notes about it,
either half of a comparison. The tree describes none of them: it has each window's box, and a half
is a region of the screen rather than of anything on it. What is held is a rectangle exactly as a
dragged one is, so the arrows beep at it and `Delete` goes back to the hints, and the two halves are
complementary to the point — an odd width is split once and the second half takes what the first
left. It is the display the pointer is on, since the crosshair is the one thing on screen through
the whole session saying which that is, and it starts below the menu bar — no ordinary window is
drawn in that strip, so it is the one part of a display that cannot hold any of what the half was
reached for, and it is the same clock and the same icons in every shot that keeps it. The Dock
stays: it floats over the window rather than beside it, so its band holds window pixels and taking
it out would cut a strip out of the picture. An auto-hidden menu bar leaves nothing to take out, and
the half runs to the top.

While a session is up a crosshair follows the pointer with the coordinates under it drawn beside it
— the same global top-left numbers `--dump` prints frames in and every capture line ends with, so an
edge found by eye can be read off rather than measured. It is drawn into the overlay rather than
being the cursor, which belongs to whichever app is *active* and so is never this one; the system
arrow rides on top of it. The overlay swallows the mouse to take the drag, which also means a scroll
or a right-click under the mask no longer reaches the window beneath — content scrolled out from
under hints that were computed once would leave every one of them pointing at something else.
Neither the crosshair nor the numbers land in a shot.

`+` and `-` put a margin around what is held, ten points to the press, for the boxes the tree draws
tight to their own contents — a paragraph whose text runs to the edge of its box is otherwise
photographed with the words against the edge of the picture. It is what takes a hinted region
outside the window it was clipped to, and the mask has drawn what it will pull in before `Return` is
pressed. `-` beeps at zero, a margin being space around the region rather than a crop into it, and
`+` stops at the edge of the screens. It is asked of whatever is held, so a dragged rectangle and a
half display take it too, and it stays put across a step and a return to the hints — it is about how
the shot should look rather than about which region it is of. The picture only: the words `⌘⇧C`
copies and the picture `⇧T` reads are still the region's own.

`⌘⇧3` photographs the display under the pointer with the overlay still on it — hints, mask,
brackets, whatever is held — and `⌘⌃⇧3` puts that picture on the clipboard instead: the system's own
screenshot chords, doing on the overlay what they do off it. Every other key here hides axshot
before the shutter, so these two are the only picture of axshot there is, and nothing outside the
session can take it — the overlay swallows the keyboard for as long as it is up, which makes the
system's own chord underneath exactly the key that cannot reach it. The crosshair is left out, being
a cursor and no more in this shot than in any other, and the menu bar strip goes the way `⌘⌥←` drops
it.

A hold has three ways out, so where a shot lands is decided with the region on screen rather than
back at the hotkey, and two keys that put the region's words on screen first:

| | |
|---|---|
| `Return` | save the region as a PNG in the save folder |
| `⌘C` | put that same picture on the clipboard |
| `⌘⇧C` | put the region's **text** on the clipboard, and take no picture |
| `⇧J` | show that text joined into one run of prose, which either copy chord then copies |
| `⇧T` | transcribe the region's *picture* instead, for when the tree has no text |
| `⇧E` | put the caret back in that text after `Escape` |
| `⇧←` `⇧→` `⌘A` | select part of that text, which is then all either copy chord takes |
| click, drag | place the caret or select with the mouse |

`⇧J` — the letter as your layout types it, not the key `J` sits on — joins the region's text into
one run of prose — the line breaks the layout put in taken back out — and draws it over the region,
where the original is still there to check it against. `⌘⇧C` then copies that joined form instead —
and so does a bare `⌘C`, which drops the picture while a join is up, since the picture would be of
the region the join is drawn over. It is a toggle, and it follows the arrows onto whatever is held
next.

The words come from the same tree the box did — every text element inside the region, in document
order, clipped to the region the way the shot would be — so it is the region's own text rather than
anything read back off the pixels. Only what was on screen: the tree also holds the names screen
readers read for icons, and a name is kept only where it would have fitted inside its own control,
so the trash can beside a row does not paste the word "Trash".

`⇧T` is for the regions where that tree has nothing — a canvas, a PDF, a terminal, a screenshot of a
table, anywhere `⇧J` just beeps. It photographs the held region, sends the picture to the Claude API
to be transcribed, and draws the answer in the same box `⇧J` draws in, for the same two chords to
copy. The mask stays up across that photograph — it never covered the region — and only the corner
brackets come off, which would otherwise be transcribed along with it; ordering the whole overlay
out would take the same picture but unmask and re-mask around the shutter. It is a toggle like `⇧J`,
and toggling it is free — the answer is kept while the region stays held, so it goes off and back on
without asking again. What it does not do is follow the arrows: the transcription was of that
region's picture, and re-reading the next one is another call nobody asked for.

While the request is out the held box is dimmed and a wave of light and shade crosses it, rests a
beat and crosses again, rather than a word being drawn over it: what is being read is those pixels,
and they stay visible underneath. The band carries a dark half and a pale half, so it shows on a
black terminal and a white page alike. Reduce Motion gets the word back.
The keyboard stays swallowed for as long as the call takes; `Escape` cancels. A region costs
roughly half a cent on `claude-opus-5` — about 1200 input tokens for a typical box.

The box is a text field, and the caret is in it from the moment it appears. What either key puts
there is usually nearly right and not quite — a heading and a timestamp the tree put either side of
the sentence worth keeping, a word a transcription read off a blurry glyph — so you correct it where
the original is still on screen beside it, rather than after pasting it somewhere.

It behaves the way a field behaves. Characters insert, `Delete` takes off the character before the
caret, and the arrows carry their usual modifiers: `⌥←` `⌥→` (or `⌃`) move a word, `⌘←`
`⌘→` move to the ends of the drawn line, `⌘↑` `⌘↓` to the ends of the whole run, and
`⇧` with any of them selects rather than moves. `⌥⌫` and `⌘⌫` delete exactly what the
matching arrow would have moved over. `⌘A` selects everything. Click to place the caret, drag to
select, double-click for the run between the spaces either side, triple-click for all of it.

`⌘C` and `⌘⇧C` copy the selection and not the box around it, which is usually the correction:
not that the words are wrong, but that only part of them was wanted. Typing or `Delete` over a
selection replaces it.

The price is that nothing else on the overlay reads the keyboard while the caret is in the box: a
bare letter types, so the arrows no longer step regions and `⇧J` no longer toggles. `Escape` is
the way out, and it is the same key that abandons the edit — one thing, not two, since everything
you would do after closing the box either discards what you typed anyway or works fine with it open.
The box stays drawn and unfocused; `⇧E` puts the caret back, and a second `Escape` cancels the
session. `Return` is the exception and stays the shutter throughout.

While a box is up the overlay takes every click, so one that misses the box does nothing rather than
starting a rectangle over the words being read; with no box up, the button draws a region. What
you typed does not survive an arrow step, for the reason a transcription does not: it is about the
region it was typed over.

The key is read from `CLAUDE_API_KEY`: the environment first, then `~/.config/axshot/.env`, then a
`.env` in the working directory. Only the first two reach the menu bar app — launched from
`/Applications` at login it has no environment and no useful working directory, so a `.env` in a
checkout is found by `bin/axshot` and not by the app:

    mkdir -p ~/.config/axshot && echo 'CLAUDE_API_KEY=sk-ant-...' > ~/.config/axshot/.env

    ./build.sh

`build.sh` compiles, signs, and installs `/Applications/Axshot.app`, relaunching it if it was
already running. `./build.sh --no-install` stops before that.

It lives in the menu bar with one global hotkey, `⌥⌘4` — the shape of the `⌘⇧4` macOS uses for the
same thing, with Option standing in for the Shift that macOS has taken.

A shot saved to the folder is shown as a thumbnail in the bottom right corner for a few seconds
before it slides off; clicking it opens the file. A clipboard shot shows none, the way macOS shows
none for its own.

The chord is re-recordable in Settings, as is the save folder — which by default follows wherever
macOS has been told to put its own screenshots, and falls back to the Desktop. Reset, beside Choose,
drops a folder you picked and goes back to following macOS. Files are timestamped:
`Axshot 2026-09-05 at 12.34.56.png`.

Hint style, also in Settings, is what the hint plates look like. Five of them, quietest first: grey,
the default, which leaves the window as the thing being looked at; dark, its opposite number for
pale content; yellow, the loudest of the warm ones; blue, which almost no page's text is; and pink,
for a screen busy enough that every other plate colour is already somewhere in it. They are picked
by clicking the plate itself rather than a name for it, and apply from the next capture.

Theme, in Settings too, is what the app's own windows look like — Settings, its menu bar, the menu
bar item's menu, an alert. System, the default, follows macOS; Light and Dark are for a desktop
left on one theme by someone who wants this window on the other. It is independent of Hint style:
plates are chosen for the window underneath them, these windows for the desktop around them. What
axshot draws over other apps — the overlay, the key sheet, the capture thumbnail — keeps its own
colours either way.

Settings needs no mouse: Tab moves between the rows, Space or Return presses, and the plates walk
under Left and Right as the radio group they are. The letters on every plate clear 4.5:1 against
both ends of its gradient, the chord recorder and the plates are named and pressable through the
accessibility tree, and the shortcut list hands itself over as text as well as glyphs. The corner
thumbnail fades in place rather than sliding when Reduce Motion is on; the mask's own fade is left
alone by that setting, since a cross-fade is what it asks for in place of travel. The overlay is the
one part
that is not: it holds the whole keyboard while it is up, so `Escape` is the only key anything else
can get, and the session expires on its own.

Resident, but only as a listener. An idle hotkey costs nothing and the tree is still walked on
demand; nothing is cached between captures. See "Measured" for why.

## Command line

Given arguments, the same binary is a CLI instead of the app. `bin/axshot` links to it.

    bin/axshot --dump             # list the regions that would be hinted, and exit
    bin/axshot --clipboard        # capture to the clipboard
    bin/axshot --out /tmp/x.png   # capture to an exact path

`axshot.swift`'s header comment is the full reference: every option, and why each part works the way
it does. [AGENTS.md](AGENTS.md) is the entry point for working on the code, with guides on
[permissions](docs/permissions.md), [testing](docs/testing.md) and
[accessibility](docs/accessibility.md).

## Permission

Two grants, both keyed to the binary's signature:

- **Accessibility** — the tree walk and the key-reading event tap.
- **Screen Recording** — the capture.

Neither is asked for at launch. The Settings window shows what is missing and its buttons are what
ask, so starting the app — including at login — puts nothing on screen. Accessibility takes effect
only after a relaunch; Screen Recording takes effect at once.

Two things that cost an hour once:

- **The system dialog can open on another Space.** It looks like nothing happened. Check your other
  desktops before concluding the request failed.
- **A grant made against an earlier ad-hoc build stays listed but stops working.** TCC keeps the
  code requirement from when the row was created, and a differently-signed binary no longer
  satisfies it — the switch reads on while every check says no. Clear it and ask again:

      tccutil reset Accessibility com.raine.axshot
      tccutil reset ScreenCapture com.raine.axshot

`build.sh` signs with a stable self-signed identity created by `create-signing-cert.sh`, which is
what keeps both grants alive across rebuilds. The first build after the certificate is created puts
up a one-time keychain dialog asking to let `codesign` use the key; **Always Allow** is the answer
that stops it coming back. To set that up in advance instead:

    AXSHOT_KEYCHAIN_PASSWORD='…' ./create-signing-cert.sh

`AXSHOT_ADHOC=1 ./build.sh` skips signing entirely — no dialog, but both permissions then have to be
granted again after every build.

A command line run re-spawns itself with its responsibility disclaimed, so TCC judges `axshot`
rather than the terminal, and one pair of grants serves both the app and the shell.

[docs/permissions.md](docs/permissions.md) has the rest: what TCC treats as this app, what breaks a
grant, and what to do when one is listed but denied.

## Tuning the filter

`--dump` prints what would be hinted, with the walk cost:

    windows=4 culled=22 unmatched=0
    visited=943 boxes=226 candidates=104 hinted=104 walk_ms=30
      w0 Claude pid=37166 (0,34 735x922) over=0 visited=618 boxes=108 walk_ms=30
      w1 Preview pid=18770 (0,34 850x922) over=1 visited=32 boxes=5 walk_ms=20
      w2 Finder pid=1580 (311,190 848x610) over=3 visited=58 boxes=27 walk_ms=21
      w3 Brave pid=39523 (735,34 735x922) over=3 visited=235 boxes=86 walk_ms=23
      s w0 AXGroup AXLandmarkComplementary depth=13 (0,34 215x922) "Sidebar"
      a w0 AXGroup depth=14 (215,34 520x922)
      ...

`boxes` is what survived the visibility filter, `candidates` what survived the nesting collapse, and
`hinted` how many of those the alphabet could letter — the regions past that carry a `-` in the
label column and are stepped to by the arrows like any other. Part of the gap between the first two
is each window's own box: a region the size of the window it was found
in is dropped before anything else, so the first hint of a window is the first thing *inside* it —
here the sidebar, and behind it the pane the window's box had been swallowing. A page that hints the
same pixels a dozen times over wants `nestingRatio` looked at; one that misses a region wants
`--no-prune` tried first.

`--min-size` is the other knob and it is a narrower one than it looks, because it measures boxes and
not words: an element carrying text is offered at whatever size the text was drawn at, so raising the
floor hides small *containers* and leaves every line of prose where it was. Which is why most of a
text-heavy window's hints are under the floor — 126 of the 164 on one measured here — and why
`--max-hints` rather than `--min-size` is what a crowded overlay is short of. It defaults to the
alphabet's own number — as many regions as 14 letters label in two keystrokes, which is 196 — and it
caps the *plates*, not the regions: nothing is dropped, and what goes unlettered is stepped to by
every arrow exactly as a lettered region is. Which is what decides who gets one: containers first,
then leaves, biggest first within each. The bare arrows land on leaves and only leaves and reach
every one of them from any other, so a leaf near the mark is already a keystroke away; a container is
reached only by widening onto it. On one desktop measured here, 387 regions came out as 149
containers and 238 leaves, and the 196 plates went to every container and the 47 biggest leaves.

The first line is the window list. `culled` is the windows nothing could be seen of, dropped before
they were walked; `over` is how many windows are drawn over the one on that line, and a window with a
high `over` and few `boxes` is mostly hidden rather than badly filtered. The per-window `walk_ms`
overlap, because the windows are walked at once — four of them adding up to 94ms and finishing in 30
is the concurrency, not a miscount. Each candidate names the window it came out of, and `--focused`
walks the frontmost window alone, which is the way to look at one app's filtering without the rest of
the desktop in the output.

## Measured

On a 735x922 window:

| app        | elements | walk  | boxes | hinted |
|------------|----------|-------|-------|--------|
| Claude     | 375      | 23ms  | 193   | 135    |
| Brave      | 998      | 72ms  | 188   | 107    |

The walk is far cheaper than a whole-tree read would suggest, for two reasons: every element is read
in one round trip rather than four, and a subtree whose parent cannot be seen is never entered.
`screencapture` itself, at 100–300ms, is the larger half of the operation — which is why nothing is
cached between captures. A resident tree cache would turn a ~300ms operation into a ~250ms one while
keeping every Chromium app's accessibility engine switched on all day to do it.

Hinting every window rather than one costs almost nothing on top of that. A desktop with 26 ordinary
windows open had 4 with any pixels of their own; the window server says which, in under a
millisecond and before any accessibility message is sent. Those four walked in 30ms together against
21ms for the front window alone, because they are four processes answering at the same time:

| windows walked | one at a time | at once |
|----------------|---------------|---------|
| 4 (exposed)    | 94ms          | 30ms    |
| 26 (unculled)  | 541ms         | 244ms   |
