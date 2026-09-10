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
