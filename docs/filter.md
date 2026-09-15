# Changing the region filter

`--dump` is the whole feedback loop: it prints what would be hinted, with the walk cost, and never
draws an overlay. Tune against it before looking at pixels;
[the README](../README.md#tuning-the-filter) reads a sample of its output line by line.

It answers *which* regions, though, and never how what is drawn on them lands, so a rule about the
plates has to be written in the plates' own geometry or `--dump` will agree with it and the screen
will not. A distance between two regions is not that geometry: a plate is a box hung off its
region's corner, and whether two collide is whether those boxes intersect. A threshold picked off a
histogram of corner distances reads as decisive — the gaps are bimodal, the stacked ones sit near
zero — and still leaves the overlaps a person sees, because it was never measuring the overlap.
Where a rule is about something drawn, take a picture of the overlay and look at it before believing
a clean number.

`--dump` lists what was kept, and a missing hint is a question about what was not. `⌘D` on a live
overlay answers that one: it copies every element the walk reached, with the pass that stopped each
and the element that pass measured it against — the kept box that swallowed it, the plate already
where its own would go. It is the record of the walk that drew those hints, so it agrees with the
screen where a dump taken beside it has walked a tree that moved. A subtree nothing of which is
visible is one line, its root, with the count of children that were never walked; `--no-prune` is
still the way to see inside one.

That account is kept by the passes themselves, which is what a change to them owes it. `filter` and
`hinted` assign each box its fate at the line that drops it, in an array that starts out holding a
placeholder — `window` for the collapse, `capped` for the plates — so a pass added without an
assignment of its own reports every box it drops as the placeholder, and nothing fails to say so. A
new reason is a new case of `Collapse` or `Plating`. `Walk.run` records an element before every
return, because the dump finds each box's line by counting the walk's `box` entries: a return that
skips the record puts the two out of step, and `⌘D` beeps rather than copy an account that names
the wrong elements.

Prefer changing the filter's passes over changing `--min-size`. The tree is mostly nested containers
that repeat their child's box, and the collapse that removes them is what decides whether the
overlay is legible; the floor only hides small *containers*, text being exempt from it. A count that
needs bringing down is `--max-hints`'s to answer rather than the floor's — most of a text-heavy
window's regions are under the floor and stay there whatever it is set to. `--max-hints` is what
brings the *plates* down and it drops no regions at all: it defaults to as many as the hint alphabet
labels in two keystrokes, and hands them to leaves first, then containers, size descending within
each, skipping any region whose corner lands on a plate already placed. An unlettered region is in
the list like any other and every arrow steps to it, so the ranking decides what is convenient to
reach rather than what is reachable at all.

When quoting costs, measure the walk and the capture together. The capture is the larger half by an
order of magnitude, so a change that halves the walk is invisible, and a benchmark that reports only
the walk will justify work that no one can perceive.
