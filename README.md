# axshot

Screenshot a region of the screen by typing a hint, not by dragging a rectangle.

Every region worth capturing — a sidebar, a message, a diff panel, a button — is already described
in the app's accessibility tree, with a frame that can be read. `axshot` walks the focused window's
tree, keeps the boxes that are actually visible, overlays a Surfingkeys-style hint on each, and
captures the one whose hint you type. The region snaps to a real element instead of to wherever the
pointer happened to stop.

Typing a hint holds the region rather than firing the shutter: everything outside it is masked and
`Return` takes the shot. The arrows adjust what is held — `←` and `→` step to the neighbouring
region, `↑` widens to the one enclosing it, `↓` goes back in — so a hint that lands near the mark
does not have to be retyped. `Delete` returns to the hints and `Escape` cancels.

`⌘C` ends it the other way: the held region's text goes to the clipboard and no picture is taken.
The words come from the same tree the box did — every text element inside the region, in document
order, clipped to the region the way the shot would be — so it is the region's own text rather than
anything read back off the pixels.

    ./build.sh

`build.sh` compiles, signs, and installs `/Applications/Axshot.app`, relaunching it if it was
already running. `./build.sh --no-install` stops before that.

It lives in the menu bar with two global hotkeys, alongside the pair macOS uses for the same two
things:

| | axshot | macOS |
|---|---|---|
| Save to folder | ⌥⌘4 | ⌘⇧4 |
| Copy to clipboard | ⌥⇧⌘4 | ⌃⌘⇧4 |

A shot saved to the folder is shown as a thumbnail in the bottom right corner for a few seconds
before it slides off; clicking it opens the file. A clipboard shot shows none, the way macOS shows
none for its own.

Both are re-recordable in Settings, as is the save folder — which by default follows wherever macOS
has been told to put its own screenshots, and falls back to the Desktop. Files are timestamped:
`Axshot 2026-09-05 at 12.34.56.png`.

Resident, but only as a listener. An idle hotkey costs nothing and the tree is still walked on
demand; nothing is cached between captures. See "Measured" for why.

## Command line

Given arguments, the same binary is a CLI instead of the app. `bin/axshot` links to it.

    bin/axshot --dump             # list the regions that would be hinted, and exit
    bin/axshot --clipboard        # capture to the clipboard
    bin/axshot --out /tmp/x.png   # capture to an exact path

`axshot.swift`'s header comment is the full reference: every option, and why each part works the way
it does. [AGENTS.md](AGENTS.md) is the entry point for working on the code, with guides on
[permissions](docs/permissions.md) and [testing](docs/testing.md).

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

    app=Claude pid=92604 window=(0,34 735x922)
    visited=587 boxes=91 candidates=32 walk_ms=26
      s AXWindow AXStandardWindow depth=0 (0,34 735x922) "Claude"
      a AXGroup AXLandmarkComplementary depth=13 (0,34 215x922) "Sidebar"
      ...

`boxes` is what survived the visibility filter, `candidates` what survived the nesting collapse. A
page that hints the same pixels a dozen times over wants `--min-size` or `nestingRatio` looked at;
one that misses a region wants `--no-prune` tried first.

## Measured

On a 735x922 window:

| app        | elements | walk  | boxes | hinted |
|------------|----------|-------|-------|--------|
| Claude     | 587      | 26ms  | 91    | 32     |
| Brave      | 847      | 63ms  | 110   | 64     |

The walk is far cheaper than a whole-tree read would suggest, for two reasons: every element is read
in one round trip rather than four, and a subtree whose parent is entirely off screen is never
entered. `screencapture` itself, at 100–300ms, is the larger half of the operation — which is why
nothing is cached between captures. A resident tree cache would turn a ~300ms operation into a
~250ms one while keeping every Chromium app's accessibility engine switched on all day to do it.
