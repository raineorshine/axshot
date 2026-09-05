# Axshot

A macOS menu bar app that finds screenshot regions in the accessibility tree. One Swift file, two
shell scripts, no dependencies.

**`axshot.swift`'s header comment is the reference for the tool itself** — every option, and the
reasoning behind each moving part. Read it before changing behaviour; it is kept current and this
file does not repeat it.

## Guides

- [docs/permissions.md](docs/permissions.md) — what TCC considers "this app", why a grant survives
  one rebuild and not another, and the three ways granting appears to fail when it has not.
- [docs/testing.md](docs/testing.md) — driving the app with no human at the keyboard, and the
  environment failures that look like product bugs.

## Layout

| | |
|---|---|
| `axshot.swift` | everything: walk, filter, overlay, hotkeys, settings, CLI |
| `build.sh` | compiles, assembles `Axshot.app`, signs it, links `bin/axshot` |
| `create-signing-cert.sh` | creates the signing identity once; idempotent |

The same binary is the app when launched with no arguments and a CLI when given any. Build output
(`Axshot.app/`, `bin/`) is generated and ignored.

## Settled decisions

These were argued out and measured. Reopen one only with a reason, not a preference; each is
explained where it is implemented.

- **Nothing is cached between captures.** The tree is walked on demand every time. A resident cache
  would save a fraction of what the capture alone costs, and would keep every Chromium app's
  accessibility engine switched on for as long as the app runs.
- **Only regions that are actually on screen are offered**, clipped to the focused window. An
  element scrolled out of view has a frame that would photograph something else.
- **Regions are picked by hint, not named.** Naming would let the walk stop early, but most of what
  is worth capturing carries no label.
- **The app never takes focus.** Hint keys come from an event tap. A focused target redraws its
  title bar inactive, and the screenshot would show that.
- **The hotkeys are Carbon `RegisterEventHotKey`.** It is the only mechanism that reserves the chord
  system-wide and the only one needing no permission.

## Changing the region filter

`--dump` is the whole feedback loop: it prints what would be hinted, with the walk cost, and never
draws an overlay. Tune against it before looking at pixels.

Prefer changing the filter's passes over changing `--min-size`. The tree is mostly nested containers
that repeat their child's box, and the collapse that removes them is what decides whether the
overlay is legible; a size floor only hides small things.

When quoting costs, measure the walk and the capture together. The capture is the larger half by an
order of magnitude, so a change that halves the walk is invisible, and a benchmark that reports only
the walk will justify work that no one can perceive.
