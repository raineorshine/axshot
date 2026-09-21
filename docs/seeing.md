# Seeing what is on screen

Axshot keeps its own marks out of its own screenshots — the shutter orders the overlay out, and the
transcription key draws it bare — so an ordinary capture is identical whether the drawing under test
appeared or not. A run that ends in a file proves the session reached the shutter and nothing more, and
the outcome line is the same kind of claim: which region the session ended on, not what was on top of
it. After any change to the filter or to what the overlay draws, photograph the overlay itself.

Whether the shell running the tests can capture at all is the grant of whatever app hosts it, and one
call finds out: `screencapture -x -R 0,0,60,60 /tmp/probe.png`, then look at the file. Ungranted, it
fails with "could not create image from rect", and a probe image for anything that reads pixels then
has to be rendered rather than photographed — `qlmanage -t -s 900 -o . file.txt` turns a text file into
a PNG of that text, which is enough to prove a reader reads.

## Photographing the overlay

`⌘⇧3` on the overlay photographs the display under the pointer with everything axshot has drawn on it
left standing, into the save folder; `⌘⌃⇧3` puts that picture on the clipboard. It is the app's own
capture, so it runs on the app's Screen Recording grant rather than on the driving shell's, which
generally has none. Both it and the capture below are bursts,
[bracketed](driving.md#saying-an-agent-has-the-foreground) like any other, and a script
[waits for the overlay window](driving.md#waiting-for-a-window-not-a-clock) where these sleep:

    ./scripts/wait-idle.sh
    osascript -e 'tell application "System Events" to key code 21 using {option down, command down}'
    sleep 3
    osascript -e 'tell application "System Events" to key code 20 using {command down, shift down}'
    ls -t "$(defaults read com.apple.screencapture location 2>/dev/null || echo ~/Desktop)"/Axshot*.png | head -1

The chord ends the session, so there is no Escape to send after it, and the file lands under the usual
timestamped name — list the save folder by time rather than reconstructing the second it was written.
Three things it cannot show, each deliberately not what the shot is of: the crosshair, taken off before
the shutter; the menu bar strip, dropped; and anything on another display or outside the session, the
corner thumbnail included. For those, capture the screen from a *different* process — a shell with its
own Screen Recording grant — then send Escape:

    osascript -e 'tell application "System Events" to key code 21 using {option down, command down}'
    sleep 3
    screencapture -x -o -R 0,34,1470,922 /tmp/overlay.png
    osascript -e 'tell application "System Events" to key code 53'

## Photographing one window

A window is captured by its id, never by the rectangle it reports: `screencapture -l<id>` crops
exactly the window and follows it to whichever display it is on, where a `-R` built from the window's
own `position` and `size` came back showing a different part of the screen entirely — those numbers
are in the space of the display the window is on, and `-R` reads the main one.

    PID=$(pgrep -f '/Applications/Axshot.app/Contents/MacOS/axshot' | head -1)
    swift -e "
    import CoreGraphics
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
    for w in list {
      guard (w[kCGWindowOwnerPID as String] as? Int) == $PID else { continue }
      guard let n = w[kCGWindowNumber as String] as? Int else { continue }
      guard let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
      guard (b[\"Height\"] as? Double ?? 0) > 100 else { continue }
      print(n)
    }"

The height guard drops the status item's own window, which is in the list under the same pid. Build
that snippet with `guard … else { continue }` lines rather than a `for … where` with a trailing `if`:
interpolating a pid into the `where` clause leaves `== {` when the pid comes back empty, and swift
then reports six errors about `w` not being in scope instead of the one thing that was wrong.

## Measuring instead of looking

**Anything smaller than the overlay** — the corner thumbnail, a badge, a bracket — does not survive a
whole screen shrunk to fit. Capture the screen whole and crop afterwards rather than guessing a `-R`
rectangle, and remember the crop is in *pixels* while the app draws in points, so on a Retina display
the offsets are twice the coordinates the code uses:

    screencapture -x -o /tmp/screen.png
    magick /tmp/screen.png -crop 700x520+2240+1392 +repage -resize 200% /tmp/corner.png

**A low-contrast drawing fails at any size,** and worse, because it reads as absence rather than blur.
The mask is a black fill at 0.55, and a whole screen resized to look at looks alike either way — the eye
reports "no mask" on a picture that has one, and the session goes hunting a bug in the drawing that is
not there. Measure instead, and measure the same content against itself unmasked, since what a half-lit
screen comes out at depends entirely on what is on it:

    magick shot.png -crop 50%x100%+1470+0 +repage -format "%[fx:mean]" info:

One sample, the same two windows a second apart: 0.89 with the hints up against 0.54 with a region
held. The gap answers, not either number — a mask that never drew leaves the two readings equal.

## Timing

Something that shows for a few seconds and then animates away is photographed at three moments — up,
mid-animation, gone — and `magick a.png b.png c.png +append` makes the sequence one thing to look at
rather than three.

Something that *repeats* needs no recording. Sample the rect on a fixed interval across more than one
period — `screencapture -x -o -R` in a loop, straight after the key that starts it — and read one number
per frame:

    magick frame.png -format "%[fx:mean]\n" info:

Frames that differ prove it moves, which no single still can; a run of *identical* means is a pause, and
identical to the last digit is the animation genuinely holding still rather than a slow stretch of it —
which is how a cycle's shape, a pass, a beat and another pass, is read off a handful of PNGs.
`screencapture` takes appreciable time itself, so the interval between frames is longer than the
`sleep` between them and the frame count per phase is a ratio, not a duration. And the mean is over
whatever the region contains, so it answers about change and not about level: compare against a frame
taken before the animation started.

A still cannot show a transition, and a transition is what most overlay complaints are about — a flash,
a gap, a thing that redraws twice. A screen recording from the user is read frame by frame rather than
scrubbed: extract every frame and tile them into one contact sheet, where the frame with the mask
missing is visible at a glance:

    ffmpeg -v error -i rec.mov -vf "scale=760:-1" frames/f%03d.png
    ffmpeg -v error -i frames/f%03d.png -vf "tile=6x4,scale=1400:-1" grid.png

A transition this session causes is recorded rather than waited for — `screencapture -v -V<seconds> -x
out.mov` alongside the drive — and whether it fades or snaps is then a number per frame:

    ffmpeg -v error -i out.mov -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -an -f null -

The differences between consecutive values are the answer: a ramp is several even steps and a snap is
one. The value it settles on is worth as much as the shape, because a mask over a known fraction of the
screen predicts its own final luma, and a level that stops short of that is a fade that never reached
the top.

- **Measure the whole frame** unless a crop has been checked for being already black: a dark window
  under the crop returns the floor for every frame, which reads as nothing having happened.
- **The recording is variable-rate and drops frames** through exactly the fast change being measured,
  so the number of frames a transition spans moves from run to run while its shape does not. It is
  evidence that there is a ramp, not a measurement of how long the ramp is.
- **Ask for every frame, not a sampled `fps=`**; such a clip is often under a second.
- **The file name is not the one you were given.** macOS writes a narrow no-break space (U+202F) before
  AM/PM in screenshot and recording names, so a path that `ls` prints and the user pastes still fails
  `stat` and `ffmpeg` with "No such file or directory". Match it with a glob rather than retyping it.

## Measuring what the system draws

A number the system draws with and offers no API for — a window's corner radius, say — is measured, and
the measurement is a comparison rather than a fit. Draw the candidates yourself, photograph them beside a
photograph of the real thing, and compare the edge profiles row by row. The one that agrees to under a
device pixel is the answer, and the candidates either side of it coming out an order of magnitude worse
is what says the comparison was sharp enough to have one.

Fitting a formula to the real thing instead returns a confident wrong number, because it assumes the
shape before it measures it. A macOS window corner is a continuous curve rather than a circular arc —
`CALayer`'s `cornerCurve = .continuous` draws it and no `NSBezierPath` does — so least squares through
its edge settles on a radius that is nothing in particular, with a residual small enough to read as
agreement.
