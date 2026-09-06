# Accessibility

Everything the app puts on screen except the overlay is a window someone may be reading with a
screen reader or driving with a keyboard, and every control in it is *drawn* rather than assembled —
a plate, a chord box, a thumbnail. A drawn control says nothing to either one unless it is told to.
The rule is that a control is named in the tree, reachable by Tab, and legible at 4.5:1. The overlay
is the exception, and [axshot.swift](../axshot.swift)'s header says why.

What follows is the set of things that look like they are already working.

## Tab does nothing at all

`NSWindow.autorecalculatesKeyViewLoop` is off by default, and a window built in code — which is all
of them here — then has `nextKeyView` nil the whole way round. Tab lands on the first view that will
take it and stays there for ever. Nothing warns, every control draws correctly, and none of them can
be reached. Set it before the subviews go in.

Check it by pressing Tab and reading `focused` back out of the tree, never by looking — walking a
window's elements from a shell is in
[testing.md](testing.md#driving-the-menu-bar-item-and-the-settings-window). Full Keyboard Access has
to be on for Tab to reach a button at all (`defaults read -g AppleKeyboardUIMode`, 2 or 3), and a
loop that was never wired and a machine with the setting off are the same picture.

A view that Tab can land on has to show that it has been landed on. `drawFocusRingMask` plus
`focusRingMaskBounds` is the whole of it — AppKit draws the standard ring off the mask, and a ring
drawn by hand is one more thing to keep matching the system's.

## A container's role is ignored until it is an element

`setAccessibilityRole(.radioGroup)` on the stack view holding the swatches did nothing at all: a
view that is not itself an accessibility element is flattened away and its children handed up to the
window, so the five radio buttons arrived as five unrelated settings and the role sat on nothing.
`setAccessibilityElement(true)` beside it is what makes the container exist. The children still come
through underneath it.

The other half of naming is that a reader takes the *title* and a script looks up by it, so a label
alone leaves the name reading `missing value` — which is why the controls here set both.

## The system colours are fills, not text

`.systemGreen` and `.systemOrange` are tuned to be seen on a control rather than read as an 11pt
word: against a white window each measures a little over 2:1, which is why both words in the
permission rows are drawn in colours picked per appearance instead. The semantic label colours are
gentler about it and still short — `secondaryLabelColor` is around 4:1 in light and
`tertiaryLabelColor` under 2:1 — so tertiary is the colour of something switched off, not a quieter
way to say something that has to be read.

Contrast is a measurement, and arithmetic on the literals is not it. `NSColor(calibratedRed:)` is
the calibrated space rather than sRGB, and a ratio worked out from those three numbers came back
most of a point above what the colour actually measures — the difference between choosing 4.4:1 and
believing it was 5.2:1. Convert with `usingColorSpace(.sRGB)` first. A throwaway `swiftc` harness
that prints the ratio against `windowBackgroundColor` under both `NSAppearance`s takes a minute, and
is the only thing that answers the question.
