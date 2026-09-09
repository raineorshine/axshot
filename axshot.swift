// Screenshot a region of the screen picked by hint, not by dragging a rectangle.
//
// A region worth capturing -- a sidebar, a message, a diff panel, a single button -- is already
// described in the app's accessibility tree, with a frame that can be read. axshot walks the tree of
// every window that has pixels of its own on screen, keeps every element whose box is actually
// visible, overlays a Surfingkeys style hint on each, and captures the one whose hint you type.
// Nothing is dragged and no coordinates are typed: the region snaps to a real element rather than to
// wherever the pointer happened to stop -- and where the tree describes nothing to snap to, a
// rectangle can still be drawn by hand.
//
// Every window and not only the front one, because the reason to want a region of a window behind is
// that raising it would change the thing being captured: a log still scrolling, a dialog sitting
// over what it is about, the two windows being compared. The hints are already how a region is
// picked without a pointer, and a window is just one more thing to pick.
//
// It runs as a menu bar app holding a global hotkey. Resident, but only as a listener: an idle
// hotkey costs nothing, and the trees are still walked on demand at each invocation rather than kept
// warm. Caching them would save the 20-45ms the walk measures against the 100-300ms the capture
// costs, which is not a saving anyone can see, and would keep every Chromium app's accessibility
// engine switched on all day to buy it. The engines of the apps with an exposed window do get
// switched on at each press, which is the standing cost of hinting more than one of them; it is the
// same switch the front window has always paid for, thrown for a handful of apps instead of one.
//
// Walking several windows costs about what walking one did, for two reasons. The window server lists
// what is on screen front to back, so the windows nothing can be seen of are dropped before a single
// accessibility message is sent -- on a crowded desktop that was 22 of the 26 ordinary windows, in
// under a millisecond. And what is left is walked all at once rather than in turn: each window is a
// different process answering its own messages, so what overlaps is the waiting. Four exposed
// windows measured 20, 21, 23 and 30ms and took 30ms together, against 21ms for the front window
// alone. Staggering them -- hints for the front window first, the rest as they arrive -- would buy
// those few milliseconds at the price of renumbering every hint under a half-typed one, so the
// overlay waits for all of them.
//
// Launched with arguments it is a command line tool instead, which is how the region filter gets
// looked at:
//
//   axshot --dump            list the regions that would be hinted, and exit
//   axshot --pid 1           ask for Screen Recording and exit without drawing anything
//   axshot --driving on|off  say that an agent has the foreground, and mark it while it holds
//
//   --bundle <id>     hint only this bundle id's windows instead of every app's
//   --pid <n>         hint only this process's windows, for when two instances of an app are running
//   --focused         hint only the focused window of the frontmost app, the way this worked before
//                     every window did. Nothing is walked beside it and nothing counts as drawn over
//                     it, which is what makes it the one to tune the filter against
//   --out <path>      write the PNG to exactly this path instead of a timestamped file
//   --clipboard       put the image on the clipboard and write no file
//   --min-size <pt>   ignore boxes smaller than this on either side (default 24)
//   --max-hints <n>   keep at most this many regions, largest first (default 150)
//   --hint-chars <s>  alphabet for hint labels (default "sadfjklewcmpgh", 14 letters, which is
//                     enough that two dozen regions are one keystroke each and 196 are two)
//   --budget-ms <n>   stop walking after this long (default 2000)
//   --no-prune        walk into elements nothing can be seen of -- off screen, or under another
//                     window. Off by default: web layout puts children inside their parent, so an
//                     invisible parent is an invisible subtree, and skipping it is most of what
//                     makes a long conversation walkable at all
//   --enhanced        also set AXEnhancedUserInterface, the switch VoiceOver uses. Only if the app
//                     will not expose its web content otherwise; Chromium reads it as a screen
//                     reader running and changes behaviour accordingly
//   --prompt          ask macOS for Accessibility with the system dialog if it is not granted
//   --delay-ms <n>    wait this long after hiding the overlay before capturing (default 60), which
//                     is the window server being given a beat to composite the overlay away
//
// Why the hints and not a label. Naming one region and searching for it would let the walk stop at
// the first match, which on a page of 5000 elements costs tens of milliseconds rather than the whole
// tree. A hint overlay has to have every candidate before it can draw anything, so it pays for the
// full walk -- and in exchange it reaches regions carrying no label at all, which is most of what is
// worth screenshotting, and it lets you pick what you can see rather than guess what the tree calls
// it.
//
// Typing a hint holds the region rather than firing the shutter: everything outside it is masked,
// corner brackets mark it, and Return takes the shot -- Preview's crop, without the grid. The
// region comes from a tree the app describes rather than from a rectangle that was dragged, so the
// one thing worth seeing before the capture is what the tree actually handed over; Delete goes back
// to the hints, and Escape or a second tap of the hotkey cancels. The tap is inserted ahead of the
// hotkey manager and so sees that chord before Carbon does, which is what lets the press that
// opened the session close it again -- an overlay that went up by accident comes down under the
// same fingers rather than sending the hand off to find Escape. Command-comma ends the session and
// opens settings, held region or not, since the overlay is in the way of the menu bar and what a
// shortcut needs changing for is generally the screen it was pressed on.
//
// The mask fades in over a tenth of a second rather than appearing, and fades out again wherever it
// leaves with no picture having been taken -- Delete back to the hints, or a cancelled session. The
// point of the mask is to show what the shot will contain, and a rectangle announced by flashing
// the whole screen dark is read as the flash rather than as the rectangle: the ramp is what lets
// the eye follow the darkness to the one place it did not reach. The corner brackets ride the same
// level, since they are the same announcement. An arrow step only moves the mask -- the darkness is
// already up and being compared against, and re-fading it under every step would blink the thing
// the steps are for -- and the text box waits for the level to reach the top and goes at the first
// sign of it falling, because half-lit words are not words. The exits that photograph something do
// not fade at all: the shutter is already waiting out a beat for the window server to composite the
// overlay away, and a fade in front of that is either a slower shot or a mask caught half-lit
// inside it. Neither does a rectangle drawn by hand, in or out: that mask is under the pointer and
// follows it, and darkness ramping in behind the hand would trail the corner being drawn from.
//
// The plates are a light grey gradient by default, and settings offers four more -- dark, yellow,
// blue, pink -- picked by clicking the plate rather than a name for it. Which one reads better is a
// property of the window underneath rather than of the app, so it is a setting and not a rule: the
// list runs from the ones that leave the window as the thing being looked at to the ones that no
// interface has anywhere else on screen.
//
// Settings also carries a theme -- System, Light, Dark, following macOS unless it is told
// otherwise -- and it is the app's own chrome that it themes, not the plates: this window, its menu
// bar, the status item's menu, an alert. The two are separate settings because they answer to
// different things. A plate sits on top of another app's window and is chosen for what is
// underneath it; these windows sit on the desktop with everything else. The theme reaches one
// thing that is drawn over another app -- the key sheet, which is a page of the app's own text and
// nothing to do with the window behind it. The overlay and the toast state their colours outright
// and stay as they are: a mask that went light with the desktop would stop masking.
//
// A hold has three ways out, and one hotkey, because which one a region wants is only clear once
// the region is on screen and masked: Return writes the PNG to the save folder, Command-C puts the
// same picture on the clipboard, and Command-Shift-C puts the region's *text* there instead and
// takes no picture at all -- the tree that gave the box has the words in it too, and a screenshot
// of a paragraph is a poor way to carry the paragraph. Only the words that were on screen: the
// tree also names things for screen readers -- "gearshape" on a symbol, "More options" on a plus
// sign -- and since nothing marks those as standing in for an icon, a name is taken only where it
// would have fitted inside its own control at the system's font size, and an image's alt text is
// never taken at all. It is a measurement rather than a rule the tree offers, so a short name on a
// wide enough control still comes through. The two clipboard exits share a letter
// because they share a destination; Shift is what asks for the words. Each hold restarts the
// session deadline, which is a decision the run loop could not have known to wait for.
//
// Shift-J joins those words: the region's text with its line breaks taken out, drawn over the
// region itself rather than beside it, and it is then what Command-Shift-C copies. A paragraph the
// layout broke across a dozen elements comes back out of the tree as a dozen lines, and pasting
// that into prose is a re-flow by hand -- so the join happens where the original is still on screen
// to check it against. While it is up Command-C copies it as well, without the Shift: the run on
// screen is the thing being looked at, and the picture that chord would otherwise take is of the
// region underneath it. It is a toggle, since what it draws covers the region it describes, and it
// survives an arrow step, recomputing for whatever is held next: the question it asked was about
// the text, not about that one region. A bare J is still Down; the region is held, so Shift is
// free to mean something else. It is the letter J as the layout types it, not the key at J's
// position -- the opposite of the HJKL sharing that key, and for the reason those are physical:
// HJKL is a hand shape that has to stay where the hand is, and J for join is a word that has to
// stay where the word is.
//
// Shift-T reads the words the tree does not have. A canvas, a PDF, a terminal, a screenshot of a
// table: the box is there and the text inside it is not, and Shift-J beeps at exactly the regions
// worth asking about. So T photographs the held region and sends the picture to the Claude API to
// be transcribed, and draws the answer in the box Shift-J draws in -- the same question, answered
// off the pixels instead of out of the tree, and copied by the same two chords. The mask stays up
// across that photograph -- it is drawn even-odd and never covered the region -- and what comes off
// is the corner brackets and the text box, which sit inside the region and would otherwise come back
// transcribed as though the app had written them there. Ordering the whole overlay out takes the
// same picture, and unmasks and re-masks around the shutter, which is a flash the join key does not
// have. It is a toggle like J, and toggling it costs nothing: the
// answer is kept for as long as the region is held, so it can go off and back on without the picture
// being sent anywhere a second time. What it does not survive is an arrow step -- the transcription
// was of that region's picture, and re-reading for the next region is a second call and a second
// charge no keystroke asked for.
//
// While the request is out the overlay says "Transcribing...", the hold deadline is pushed out to 90
// seconds so a slow call cannot be cut off mid-sentence, and Escape still cancels -- the tap is up
// the whole time, so the keyboard is swallowed for as long as the call takes. What comes back is
// drawn in a separate field from the joined text, so that the copy chords hand over what the region
// said and never what axshot said about it.
//
// The key comes from CLAUDE_API_KEY: the environment first, so a command line run can be given one
// for a single invocation, then ~/.config/axshot/.env, then a .env in the working directory. The
// fixed absolute path is the one the app can use -- launched from /Applications at login it has no
// environment and no useful working directory, and would never find a .env in a checkout.
//
// Shift-E opens whichever of them is on screen to the keyboard. What the box holds is on its way to
// the clipboard, and what it holds is frequently nearly right and not quite: a tree that put a
// heading and a timestamp either side of the sentence worth keeping, a transcription that read one
// word off a blurry glyph. The alternative is pasting it somewhere and correcting it there, which
// is the re-flow by hand that Shift-J exists to avoid, and it is done away from the region rather
// than over it. So the box grows a caret and a border, and the keys do what a one-line field does:
// characters insert, Delete takes off the composed character before the caret, Left and Right walk
// it, Up and Down go to the two ends. Return keeps what was typed and Escape puts back what the
// region or the API said -- there is no undo on an overlay and nowhere to hang one, and an edit
// that cannot be abandoned where it was made is an edit nobody starts. A second Escape then cancels
// the session, the way it does under the shortcut sheet.
//
// The caret is in the box from the frame it is drawn in. A box that showed the words and ignored
// the keyboard until a second key was found is a box that does not answer the first thing tried on
// it, and what it is showing is a field. So Shift-J and Shift-T both land the caret at the start of
// what they put there -- at the start and not at the end a field would pick, because this box is
// read before it is typed in and the eye starts where the words do -- and Shift-E only exists to put
// it back after an Escape.
//
// The price is that nothing else on the overlay reads the keyboard while it is in: a bare letter
// types, so the arrows no longer step regions and Shift-J no longer toggles. Escape is the way out
// and it is the same key that abandons the edit -- one thing, not two, since everything you would do
// after closing the box either discards what was typed anyway or works with it open. Return is the
// exception and stays the shutter: making the app's oldest key a second press to reach would be
// paying for a commit nobody needs.
//
// A click does the same thing, and opens the box on its way: the mouse is what a person reaches for
// when they can see a field, and Shift-E being the only way in was a field that did not answer the
// first thing tried on it. Click to place the caret, drag to select, twice for the run between the
// spaces either side, three times for the lot. The click arrives through the same tap the keys do
// rather than through the window, which is what keeps it off the one thing the app must not do: the
// overlay ignores the mouse, and a window that accepted a click would activate the app and redraw
// the target's title bar inactive. While a box is up the overlay answers every click, not only the
// ones that land on it -- a click that missed by a few points would otherwise go to a window the
// mask is hiding. With no box up the click draws a region instead.
//
// The arrows carry the modifiers they carry in every other field, because a box that looked like one
// and moved a character at a time under Option would be a box that lied about what it was: Option or
// Control moves a word, Command moves to the ends of the drawn line, and Shift with any of them
// selects rather than moves -- as do Option-Delete and Command-Delete, which take out exactly what
// the matching arrow would have moved over. None of that arrives for free. AppKit's key bindings
// come through the responder chain and this box is never in one: a window that took the keyboard
// would take the focus with it and photograph the target with its title bar greyed out. So the
// bindings are spelled out, but over Foundation's own word boundaries and the layout manager's own
// lines rather than over a character scan invented here.
//
// Shift and an arrow reach rather than move, and Command-A takes the lot, because the correction is
// often that only part of the box was wanted: a paragraph the region wrapped in a heading and a
// timestamp, a transcription that read a table and a caption. With a run picked out both copy chords
// hand over that run and not the box around it -- the same two keys, still the same destination, and
// the selection is what says how much of the answer was the answer. Deleting or typing over a
// selection replaces it, the way it does anywhere else.
//
// It is the one of the three that is a mode rather than a toggle, because the letters it has to eat
// are the letters the arrows are: a held region is steered by the keyboard right up until the words
// under it are being retyped, and no reading of a bare H is both a step left and an aitch. So while
// the box is open every key that is not a chord is a character -- `?` types a question mark instead
// of drawing the shortcut list -- and only Command gets through, because the two chords that copy
// are what the box was opened for and they read it as it stands. What is typed does not survive an
// arrow step: a transcription is pinned to the picture it was read off, and an edit is pinned the
// same way to words a different region never said.
//
// The arrows adjust the held region without going back to the hints, for when the one that was
// lettered is nearly right: each of the four holds the nearest region that way on screen -- the
// nearest leaf, strictly, which is most of what follows. HJKL do the same four things, the held
// region being a selection under adjustment rather than text being typed, so the hand does not have
// to leave the letters it just typed a hint with. They are read as physical keys, in the same
// layout-independent way as the hotkeys, and only while a region is held -- before that every letter
// is a hint.
//
// The screen and not the tree, because the screen is what is being looked at. A hint that landed
// near the mark landed near it on screen, and the region actually wanted is the one next to it
// there; whether the tree calls that a sibling, a nephew or nothing at all is the app's own
// bookkeeping, and it will happily put twenty steps between two boxes two centimetres apart -- a
// sidebar and the button beside it. So the unmodified key answers the question that was asked by
// looking, which is which way, and Option is left holding the one only the tree can answer.
//
// Leaves and not every kept region, because a container that way is also a container over here: it
// covers the place the step started from, and a step still holding where it came from did not go
// anywhere. Which regions those are is asked of the boxes rather than of the tree, which costs a
// pass over the list and is the only one of the two that answers: Chromium hands back a 28 point
// toolbar button with the page's own toolbar nested somewhere underneath it, drawn 700 points away,
// and what is inside a rectangle is a question rectangles answer. Asked within one window, though,
// the way the nesting collapse is -- a box in the window behind that happens to contain a box in
// front of it is not holding it, it is behind it.
//
// Direction is centre to centre, but a leaf lining up with the held region beats a nearer one that
// does not, because lining up is what a row and a column are: Left out of an address bar is the
// padlock beside it and not the toolbar button below, which by centres is half as far away. Where
// nothing lines up there is no row to stay in, and the fall-back is a quarter turn either side of
// the direction, so Left cannot answer with whatever is directly overhead; the cones tile the
// screen between them, which is what leaves no leaf unreachable.
//
// They cross the window boundary, which the tree steps under Option stop at. What stops those is
// that document order between two windows says only which was in front; a step across the screen
// reads no document order, and coordinates mean the same thing either side of the edge. The window
// beside this one is precisely the case of a region two centimetres away and nowhere in the tree.
//
// Option puts the same four keys back on the tree, which is two axes rather than four directions:
// Left and Right step across it in document order -- to the next sibling, cousin, uncle or nephew,
// skipping the held region's own ancestors and descendants, which are the same region drawn bigger
// or smaller and are what the other two are for -- while Up widens to the smallest kept region
// containing this one, and Down returns to the region Up was last looking at. Only kept candidates
// are offered, so Up is a visible widening rather than a walk through the wrappers that repeat the
// same box. Down prefers to retrace an ascent rather than guess at a child, since a container holds
// many and containment does not say which; stepping sideways abandons that memory, because what it
// remembers is no longer inside what is held.
//
// Modified, but not the lesser of the two. The screen walk lands on leaves and only leaves, so
// Option-Up is the whole of how a container is reached from a held region at all -- the sidebar
// rather than the row inside it, the message rather than the sentence -- and a screenshot is very
// often of the container. What the unmodified keys change is which region; what Up and Down change
// is how much of it.
//
// All four of them stop at the window they were pressed in. What they walk is a tree and two windows
// are two of them; across the boundary document order says only which window was in front, and a key
// that steps to the next sibling would be stepping to something else on the screen entirely. The
// unmodified arrows are how another window is reached from a held region, and the hints are how it
// is reached from nothing.
//
// An arrow pressed with the hints still up holds the largest region instead -- so the screen can be
// walked without ever picking a letter, for when nothing lettered is close and reading the hints is
// more work than stepping. Every region is reachable from every other one, the screen steps crossing
// the window boundary the tree steps stop at, so what the entry point owes is somewhere to start
// reading rather than a root: the biggest box holds the most of the others, and it is no longer the
// window, which stopped being a region. The first in document order would be neither -- with the
// window's box gone that is whatever the frontmost window's layout begins with, as often a sidebar
// as the thing worth capturing. Only the arrows do this, since HJKL are still hints until something
// is held. It is also the one place Option-Down has no ascent to retrace, so there it falls back to
// the held region's first child in document order; without that the entry point would only ever
// lead outwards.
//
// A region can also be drawn by hand, for what the tree does not describe: a slide, a video, a
// corner of a canvas, half a paragraph, an app whose accessibility is one box the size of its
// window. Press the left button anywhere and drag -- the mask follows the rectangle as it is made,
// and letting go holds it exactly as a hint would have, so Return, the two copy chords, the join
// and the transcription all read the same held region and cannot tell where it came from. Holding
// space while the button is down locks the size and moves the whole rectangle by however far the
// mouse moves, which is the one thing a two-corner drag cannot otherwise correct: the corner put
// down first is fixed, and a rectangle the right size in the wrong place would have to be drawn
// again. Space is read off the hardware rather than out of a key event, since a lock that ends when
// the key comes up would need key-ups tapped, and the tap deliberately does not take those.
//
// The button is swallowed as completely as the keyboard is, and for the same reason: a click that
// reached the window underneath would press whatever it landed on, or raise something over the
// target, and the shot would be of a screen the session itself had changed. A press and release
// under 8 points on either side is a click rather than a drag and holds nothing, so a slip leaves
// the hints where they were. Escape abandons a rectangle being drawn before it abandons the
// session.
//
// A dragged region is the one region not clipped to the focused window. A frame out of the tree can
// describe an element scrolled out of view, and photographing it would return whatever is in that
// part of the screen instead; a rectangle drawn around what someone is looking at *is* that part of
// the screen, so nothing holds it but the edges of the desktop. Its words still come out of the
// focused window's tree, clipped to the rectangle the way a candidate's are -- a drag over the
// target window copies what it covers, and a drag over some other app's window copies nothing. The
// arrows have nothing to offer it: it is not in the candidate list, so there is no line of
// ancestors to widen along and no sibling to step to, and they beep. Delete goes back to the hints,
// which is where the tree is.
//
// Command-Option-Left and Command-Option-Right hold half a display, which is the one rectangle
// worth drawing often enough to be worth a key. A window tiled to one side, a video beside the
// notes about it, either half of a comparison: the tree describes none of them -- what it has is
// each window's own box, and the half is a region of the screen rather than of anything in it --
// and a hand drawing it to the pixel is a hand drawing it twice. What comes out is a rectangle
// exactly as a dragged one is, so the arrows beep at it and Delete goes back to the hints, and the
// two halves are complementary to the point: an odd width is split once and the second half takes
// what the first left, rather than both rounding and overlapping down the middle.
//
// The display under the pointer, and not the one the held region or the front window is on. Which
// screen a key means has to be answered by something the eye can already see, and on a desktop
// spanning two displays the crosshair is the only thing that is there through the whole session
// saying so.
//
// It starts below the menu bar and runs to the bottom of the display. No ordinary window is drawn
// in that strip, so it is the one part of a display that cannot hold any of what the half was
// reached for -- and it is the same clock and the same icons in every shot that keeps it. The Dock
// stays, which is not an inconsistency about furniture: it floats over the window rather than
// beside it, so its band holds window pixels and taking it out would cut a strip out of the
// picture. Both are read off the screen rather than assumed, so an auto-hidden menu bar leaves
// nothing to take out and the half runs to the top.
//
// A crosshair follows the pointer for as long as a session is up, with the coordinates under it
// drawn beside it -- the same global top-left numbers --dump prints frames in and every capture line
// ends with, so an edge found by eye can be read off rather than measured. Both are painted into the
// overlay rather than being a cursor: a cursor belongs to the *active* application, and this app is
// never that. `NSCursor.set()` and a `.cursorUpdate` tracking area were both tried on the overlay
// and the WindowServer kept the arrow; activating to win the cursor would cost the target window its
// active title bar, which is the thing the whole design is arranged around. So the system arrow
// stays, and rides on top of a crosshair whose centre is its own tip.
//
// The mouse is taken in the tap and not by the window, which goes on letting everything through.
// A window that took them would be handing events to an app that is running a bare CFRunLoop for
// the length of a session and never answering AppKit -- which the WindowServer reports as a
// beachball over the whole screen. The tap is ahead of the window anyway: it swallows the button,
// and with it the scroll and the right button, which is worth having on its own. The hints are
// computed once from a tree read at the press, and content scrolled out from under them would
// leave every box pointing at something else.
//
// The readout follows the mouse-moved events the tap is already watching, and marks only the plate
// it left and the plate it arrived at. A hand makes those events as fast as the screen refreshes,
// and redrawing every hint on a display -- and refilling a display's worth of transparent pixels --
// for a label that moved four points is the one thing on the overlay that could be made to stutter.
// Neither the crosshair nor the numbers reach a photograph: screencapture(1) is never asked for the
// cursor, the overlay is ordered out before the shutter and drawn bare across the one Shift-T
// fires, and the one Command-Shift-3 fires -- which is of the overlay and keeps everything else it
// draws -- has them taken off it by hand first.
//
// Command-Shift-3 photographs the display with the overlay still on it, and
// Command-Control-Shift-3 puts that picture on the clipboard -- the system's own two screenshot
// chords, doing on the overlay what they do off it. Every other capture here hides axshot to take
// it; this one is of axshot, which is what a README, or an argument about whether the hints are
// legible against that page, actually needs -- and which nothing else can take: the overlay
// swallows the keyboard while it is up, so the system's chord underneath is precisely the key that
// cannot reach it. Whatever is on the overlay comes with it -- held region or not, box open or not,
// mask and brackets and a half-typed hint included -- and the one thing that does not is the
// crosshair, which is this app's cursor drawn by hand and is left out for the reason
// screencapture(1) leaves the real one out. The display under the pointer, and below its menu bar,
// on the two readings the half-display key already takes: the crosshair is the thing on screen
// saying which display a key means, and no window is drawn in that top strip. It is the key at 3's
// position rather than the character the layout types there, which is the reading macOS gives the
// same chord: what is being quoted is a place the hand already knows, not a word.
//
// `+` and `-` put a margin around whatever is held, ten points to the press. A box out of the tree
// is the element and nothing else, which is a tight crop rather than a framed one: a paragraph
// whose text runs to the edge of its own box is photographed with the words against the edge of the
// picture, and a button comes out as a button-shaped hole. The margin is the room back, and it is
// what takes a hinted region outside the window it was clipped to -- what it pulls in is whatever
// the region sits next to, which is generally the page it is on, and the mask has drawn it before
// Return is pressed. It stops at the edges of the screens, past which there is nothing to
// photograph, and at nothing on the way down: a margin is space around the region rather than a
// crop into it, so `-` puts back what `+` asked for and beeps at zero. The step that would change
// nothing is refused rather than counted, since a margin still counting up past the screen would
// owe several presses of `-` before anything moved back.
//
// It is asked of whatever is held rather than of the candidate list, so a dragged rectangle and a
// half display take it exactly as a hinted region does: a rectangle drawn by eye is as likely to
// have been drawn tight as a box out of a tree, and neither is a reason for the key to go quiet. It
// outlives a step and a return to the hints, unlike everything else a hold carries, because it is a
// statement about how the shot should look rather than about which region it is of. And it is the
// picture only -- the words the copy chords hand over, and the picture Shift-T reads, are still the
// region's own, since padding that reached into the paragraph next door would be text the region
// never said.
//
// They are the characters the layout types rather than the keys they sit on, like `?` and Shift-J
// -- arithmetic is a word, not a hand shape -- and both characters a key can type count, so Shift
// is neither asked for nor refused: `+` is Shift-`=` on most layouts, and a hand holding Shift for
// it would otherwise find `-` typing `_` and doing nothing. The two are pressed one after the other
// on the same number, and a pair where one key wants Shift and the other refuses it cannot be
// alternated without letting go in between.
//
// A question mark puts the whole list of keys on screen, grouped by whether it is the hints or a
// held region that reads them, and dims what is behind it. There is nowhere else to put a legend
// mid-session: the overlay covers the screen and the keys are the only interface it has, so the
// sheet is drawn where the eye is and taken back down by the key that raised it -- or by Escape, which a panel is
// entitled to before the thing behind the panel is. While it is up every other key is swallowed
// rather than acted on, since a letter typed under the sheet would hold a region the reader cannot
// see. The hotkey is spelled out on it as settings spells it, being the one key on the list that is
// not the same on every machine. It is the character `?` as the layout types it, not the key Shift
// and slash sit on -- a key picked for what it means, like Shift-J.
//
// The same list is a menu bar item, "Keyboard Shortcuts", because `?` is only reachable from inside
// a session and a session is only opened by someone who already knows the hotkey -- which is the
// one thing a key list is most wanted for. Off the overlay there is nothing behind the sheet to dim
// and nothing to go back to, so it is a borderless window that is the sheet and nothing else, taking
// key so Escape and `?` still close it, and closing when it stops being key: a click elsewhere is
// how a legend is put down. The window is built fresh each time it is opened, since the hotkey it
// spells out is a setting that can change between one reading and the next.
//
// Only what is visible, which is now two rules that are the same rule. A box is kept only where it
// intersects its own window, and only where no window in front of that one is drawn over it; it is
// captured clipped to what is left. An element scrolled out of view, or under another window, still
// has a frame, and capturing it would photograph whatever is in that part of the screen instead.
//
// Both crop rather than reject, because that is what the window edge has always done and an element
// half behind another window is in the same position as one half off the screen: there is a part of
// it that is genuinely its own pixels, and it is worth a hint. Where a window is covered across its
// middle that leaves more than one piece and the largest is the one hinted. What that costs is
// honest and visible -- a window showing a 115pt strip of itself offers hints on 115pt strips -- and
// the overlay masks and brackets the region before the shutter, so what will be photographed is on
// screen before Return is pressed.
//
// A window with nothing left at all is never walked, which is what makes the rest affordable.
// Everything on screen counts as drawn over: the menu bar, the Dock, a floating notification panel.
// Only ordinary windows are hinted, so a menu, a popover or a Spotlight panel masks the window it
// is over rather than being offered as a region of its own.
//
// Except a window no capture can see, which covers nothing and is not hinted either. The window
// server says so outright -- a sharing state of none is a window left out of every picture taken of
// the screen -- so a shot of that rectangle returns whatever is behind it, which is a window worth
// hinting rather than one to cull. This app's own driving border is exactly such a window and is
// the size of the screen: counted as cover it culled every window on the machine, and a capture
// taken while an agent said it had the foreground ended "no window" -- including the capture the
// agent was driving.
//
// And never the whole window. A box the size of the window it was found in is the shot
// Command-Shift-4 and then Space already takes, and it was standing in front of the region worth
// having: the nesting collapse keeps an outer box that swallows an inner one unless the inner is
// more than two thirds of it, and a window's content area usually is -- so dropping the window is
// what puts a file list, a browser's page and a sidebar's neighbour on the screen as regions of
// their own.
//
// It is a size test and not a role test, because the window is never one element: the window, its
// content view and whatever split or group they wrap all report the same frame, so dropping the
// AXWindow by role hands the same rectangle straight to its child, which is the same hint one letter
// along. What the size is compared against is the window as a candidate would carry it -- clipped to
// the screen and cropped to the largest piece no window in front covers -- so a window showing a
// strip of itself loses the strip-sized box for the same reason it loses the whole one. The window's
// parts are untouched however large, a page filling everything below a toolbar being a region and
// not a window; an app whose accessibility is one box the size of its window offers no hints at all,
// which is the case the drag is there for.
//
// The overlay never appears in the shot, bar the one shot that is of the overlay. It is a
// borderless window at screen-saver level that is ordered out before the capture runs, with
// --delay-ms for the compositor; Command-Shift-3 keeps it up and spends that same beat on taking
// the crosshair off instead, the subject of the picture being everything else it draws.
// Focus is never taken from the target app -- the app would redraw its title bar and focus rings
// unfocused, and the screenshot would be of a window that looks inactive, and NSWorkspace would
// stop calling the target frontmost. The menu bar app is an accessory and never activates around a capture, and hint
// keys are read with a CGEventTap, which sees them without focus and swallows them so they never
// reach the app. Key-downs only: the tap sits ahead of the hotkey manager, so a swallowed key-up
// would leave the chord that started the session looking held, and every second press would fire
// nothing.
//
// After the shutter, a thumbnail of the shot sits in the bottom right corner for a few seconds and
// then slides off the right edge, the way macOS's own does: the shot is a region of a window rather
// than the window, so the one thing worth confirming is which region landed. A click opens the file
// and dismisses it. It is a non-activating panel, so it takes no more focus than the overlay does,
// and the next capture dismisses it before walking rather than waiting for it to expire -- a toast
// still on screen is something screencapture(1) would photograph.
//
// The one time it is not an accessory is while the settings window is open: it turns regular so the
// window can be reached from the App Switcher and gets a menu bar, and back to accessory when the
// window closes, so Cmd-W -- or Escape, which closes it the way a panel does -- leaves nothing but
// the menu bar item behind and the app keeps running.
//
// What the app is to a screen reader, and to a keyboard with no mouse beside it. Settings is
// ordinary controls except for the two that are pictures rather than controls -- the chord recorder
// and the five plates -- and those carry their own name, value and press, take Space and Return the
// way a button does, and in the plates' case walk under the arrows as the radio group they are, so
// nothing in that window has to be pointed at. The shortcut list is drawn glyph by glyph rather
// than laid out in controls, which would leave the one window whose whole purpose is to say what
// the keys are saying nothing at all, so it hands the same list over as text as well. The letters
// on a plate clear 4.5:1 against both ends of its gradient, which is what decides how dark the blue
// is and why the pink's letter is black rather than white. The toast fades in place instead of
// sliding when Reduce Motion is on, and says what it saved, the app never having taken focus and a
// thumbnail being a picture.
//
// The overlay is the exception and stays one. It takes the keyboard whole for as long as it is up
// -- and the mouse with it -- so nothing else on the machine reads a key while a session is
// running, a screen reader included. Nothing it offers needs the mouse: a custom region is the one
// thing that can only be drawn with one, and the hints reach every region the tree describes
// without it. Escape is always the way out, and the session expires on its
// own rather than being trusted to stop.
//
// There is one hotkey, Option-Command-4, because where a shot lands is decided at the end of a hold
// rather than at the press. It is a Carbon RegisterEventHotKey rather than a tap or a global
// monitor: the only one of the three that reserves the chord system-wide, so the frontmost app
// never sees it, and the only one that needs no permission at all.
//
// Permission. Accessibility, for the tree and the hint tap; Screen Recording, for the capture.
// Neither is asked for at launch: the settings window says which is missing and its buttons are what
// ask, so starting the app, including at login, puts nothing on screen. Asking at the first press
// instead would draw the dialog underneath the overlay, and an ungranted screencapture(1) fails with
// nothing more useful than "could not create image".
//
// A command line run re-spawns itself with its responsibility disclaimed, so TCC judges axshot
// rather than the terminal that launched it and one pair of grants serves both the app and the
// shell. The app bundle is already its own responsible process and does not.
//
// --driving is the one mode that draws nothing where it is typed. A session driving the real app
// posts keystrokes onto the keyboard a person is sitting at and brings windows forward that nobody
// asked for, and from the outside that is indistinguishable from the machine doing it by itself. So
// a burst brackets itself: --driving on before it takes the foreground, --driving off when it lets
// go. While it holds, the running app draws a border around every screen, in the pink of the hint
// style -- the plate colour picked for turning up in the fewest interfaces, which is the property
// wanted here too. Letting go puts the foreground back where the burst found it. It marks the burst
// and not the test: a build being tried by hand is the user's own session, and a border up for an
// hour is a colour nobody sees by the second look.
//
// The screen and not the frontmost window, because what a burst has taken is the machine. A band
// around one window says the drive is happening in there, and the next thing a burst does is
// activate something else; a person glancing over saw a mark on a window that is no longer the one
// being driven, which is a worse answer than no mark at the edge of that window at all. It also
// takes an accessibility read of the frontmost app five times a second, for a rectangle that is
// under the app's control -- where the desktop's edge is known outright and changes only when a
// display does. One band per screen rather than one around the bounding box of them: two displays of
// different heights leave that box running through dead space at the top of the shorter one, drawing
// a band nobody can see instead of the one along the edge that is there.
//
// The border is taken out of every screenshot on the machine by the window's sharing type rather
// than by being hidden around each shutter -- a band at the screen's edge is inside any capture that
// reaches it, and the process photographing is not always the one holding the border. A frame nobody
// turns off goes out after two minutes and gives the foreground back, since the session that would
// have turned it off is the one that can die mid-burst. Its corners are square: the 16pt continuous
// curve the band used to carry was measured against a window, a display's corner is a different
// shape and one nothing reports, and where a panel rounds it the panel's own mask clips the band --
// which is a better relationship than a guessed curve competing with it.
//
// Exit codes (command line only): 0 captured or copied, 2 not trusted, 3 no target app, 4 no
// candidate regions, 6 no window, 11 cancelled, 12 capture failed, 13 nothing to copy. A capture that failed for want of Screen
// Recording says screen_recording=false on that line.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import QuartzCore
import Foundation
import ScreenCaptureKit
import ServiceManagement

@_silgen_name("responsibility_spawnattrs_setdisclaim")
func responsibility_spawnattrs_setdisclaim(_ attrs: UnsafeMutablePointer<posix_spawnattr_t?>, _ disclaim: Int32) -> Int32

// MARK: - Arguments

struct Options {
  var dump = false
  var bundleId: String?
  var pid: pid_t = 0
  var destination = Destination.directory(Settings.saveDirectory)
  var minSize: CGFloat = 24
  var maxHints = 150
  var hintChars = "sadfjklewcmpgh"
  var budgetMs = 2000
  var prune = true
  /// Walk only the focused window of the frontmost app, the way it worked before every window did.
  /// Nothing occludes it and nothing else is walked, which is what makes it the one to tune the
  /// filter against.
  var focused = false
  var enhanced = false
  var prompt = false
  var delayMs = 60
  var worker = false
  /// Read the shot back and show the corner thumbnail. The menu bar app does; a command line run
  /// exits at once and would only be paying to decode a PNG nobody sees.
  var toast = false
  /// The chord that opened the session, so pressing it again closes it. Set by the menu bar app; a
  /// command line run was not opened by a chord and leaves it nil.
  var cancelChord: Chord?
}

func usage() -> Never {
  FileHandle.standardError.write("usage: axshot [--dump] [--bundle ID] [--pid N] [--focused] [--out PATH] [--clipboard] [--min-size PT] [--max-hints N] [--hint-chars S] [--budget-ms N] [--no-prune] [--enhanced] [--prompt] [--delay-ms N]\n       axshot --driving on|off\n".data(using: .utf8)!)
  exit(64)
}

func parse(_ argv: [String]) -> Options {
  var options = Options()
  var i = 0
  while i < argv.count {
    func next() -> String { i += 1; guard i < argv.count else { usage() }; return argv[i] }
    switch argv[i] {
    case "--dump": options.dump = true
    case "--bundle": options.bundleId = next()
    case "--pid": guard let n = Int32(next()) else { usage() }; options.pid = n
    case "--out": options.destination = .file((next() as NSString).expandingTildeInPath)
    case "--clipboard": options.destination = .clipboard
    case "--min-size": guard let n = Double(next()) else { usage() }; options.minSize = CGFloat(n)
    case "--max-hints": guard let n = Int(next()), n > 0 else { usage() }; options.maxHints = n
    case "--hint-chars": options.hintChars = next(); if options.hintChars.count < 2 { usage() }
    case "--budget-ms": guard let n = Int(next()) else { usage() }; options.budgetMs = n
    case "--no-prune": options.prune = false
    case "--focused": options.focused = true
    case "--enhanced": options.enhanced = true
    case "--prompt": options.prompt = true
    case "--delay-ms": guard let n = Int(next()) else { usage() }; options.delayMs = n
    case "--worker": options.worker = true
    default: usage()
    }
    i += 1
  }
  return options
}

// MARK: - Re-spawn with responsibility disclaimed

/// Run this same binary again as its own responsible process and exit with its status, so that TCC
/// attributes the Accessibility and Screen Recording grants to axshot wherever it was launched from.
func respawnDisclaimed() -> Never {
  let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
  var attrs: posix_spawnattr_t? = nil
  posix_spawnattr_init(&attrs)
  defer { posix_spawnattr_destroy(&attrs) }
  let disclaimed = responsibility_spawnattrs_setdisclaim(&attrs, 1)
  if disclaimed != 0 {
    FileHandle.standardError.write("axshot: responsibility_spawnattrs_setdisclaim failed (\(disclaimed))\n".data(using: .utf8)!)
  }

  let arguments = [path] + Array(CommandLine.arguments.dropFirst()) + ["--worker"]
  var cArguments: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
  cArguments.append(nil)
  defer { cArguments.forEach { free($0) } }

  var pid: pid_t = 0
  let spawned = posix_spawn(&pid, path, nil, &attrs, cArguments, environ)
  if spawned != 0 {
    FileHandle.standardError.write("axshot: posix_spawn failed (\(spawned))\n".data(using: .utf8)!)
    exit(70)
  }
  var status: Int32 = 0
  waitpid(pid, &status, 0)
  let exited = (status & 0x7f) == 0
  exit(exited ? (status >> 8) & 0xff : 128 + (status & 0x7f))
}

// MARK: - Accessibility

/// AXUIElement as a set member, so a traversal can tell when a child is one of its own ancestors.
struct ElementKey: Hashable {
  let element: AXUIElement
  static func == (a: ElementKey, b: ElementKey) -> Bool { CFEqual(a.element, b.element) }
  func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Everything the walk needs from one element. Read in a single round trip: the walk touches every
/// element in the window, so four separate reads would be four times the IPC for the same answer.
struct Probe {
  var role = ""
  var subrole = ""
  var label = ""
  var frame: CGRect?
  var children: [AXUIElement] = []
}

let probeAttributes: [String] = [
  kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute,
  kAXChildrenAttribute, kAXDescriptionAttribute, kAXTitleAttribute, kAXValueAttribute,
]

func probe(_ element: AXUIElement) -> Probe {
  var result = Probe()
  var raw: CFArray?
  let error = AXUIElementCopyMultipleAttributeValues(element, probeAttributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &raw)
  guard error == .success, let values = raw as? [AnyObject], values.count == probeAttributes.count else { return result }

  // A value this element does not carry comes back as an AXValue holding an AXError, not as a gap.
  func value(_ index: Int) -> AnyObject? {
    let candidate = values[index]
    if CFGetTypeID(candidate) == AXValueGetTypeID(), AXValueGetType(candidate as! AXValue) == .axError { return nil }
    return candidate
  }

  result.role = value(0) as? String ?? ""
  result.subrole = value(1) as? String ?? ""
  if let point = value(2), let size = value(3),
     CFGetTypeID(point) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() {
    var origin = CGPoint.zero
    var extent = CGSize.zero
    AXValueGetValue(point as! AXValue, .cgPoint, &origin)
    AXValueGetValue(size as! AXValue, .cgSize, &extent)
    result.frame = CGRect(origin: origin, size: extent)
  }
  result.children = value(4) as? [AXUIElement] ?? []
  for index in 5...7 {
    if let text = value(index) as? String, !text.isEmpty {
      result.label = text.replacingOccurrences(of: "\n", with: " ")
      break
    }
  }
  return result
}

func string(_ element: AXUIElement, _ name: String) -> String? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value as? String
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
  var value: CFTypeRef?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

/// The frontmost window of an application, as the tree reports it. An app with no window open
/// answers AXFocusedWindow with its own application element, so insist on something that says it is
/// a window; the fallback is for the apps that answer nothing at all.
func focusedWindow(_ application: AXUIElement) -> AXUIElement? {
  if let focused = attribute(application, kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() {
    let window = focused as! AXUIElement
    if string(window, kAXRoleAttribute) == kAXWindowRole { return window }
  }
  return (attribute(application, kAXWindowsAttribute) as? [AXUIElement])?.first
}

/// The screen's y-axis turned over. The tree reports frames from the top-left of the primary screen
/// and AppKit draws from its bottom-left, and this is the whole of the difference -- it is its own
/// inverse, so the same call converts either way and there is no second definition to disagree with.
func flipY(_ rect: CGRect) -> CGRect {
  let base = NSScreen.screens.first?.frame.maxY ?? 0
  return CGRect(x: rect.minX, y: base - rect.maxY, width: rect.width, height: rect.height)
}

// MARK: - Windows

/// What is left of `rect` once `cover` is taken out of it: up to four bands, and nothing at all when
/// the cover swallows it. Rectangles rather than a region type, because everything downstream is one
/// -- a candidate's box, the rect handed to screencapture -- and a region would only have to be
/// turned back into these to be used.
func subtract(_ rect: CGRect, _ cover: CGRect) -> [CGRect] {
  let hit = rect.intersection(cover)
  if hit.isNull || hit.isEmpty { return [rect] }
  var pieces: [CGRect] = []
  if hit.minY > rect.minY { pieces.append(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: hit.minY - rect.minY)) }
  if hit.maxY < rect.maxY { pieces.append(CGRect(x: rect.minX, y: hit.maxY, width: rect.width, height: rect.maxY - hit.maxY)) }
  if hit.minX > rect.minX { pieces.append(CGRect(x: rect.minX, y: hit.minY, width: hit.minX - rect.minX, height: hit.height)) }
  if hit.maxX < rect.maxX { pieces.append(CGRect(x: hit.maxX, y: hit.minY, width: rect.maxX - hit.maxX, height: hit.height)) }
  return pieces
}

/// The parts of `rect` that no window in `covers` is drawn over. Empty is a box that would
/// photograph something else entirely.
func exposed(_ rect: CGRect, under covers: [CGRect]) -> [CGRect] {
  var pieces = [rect]
  for cover in covers {
    guard pieces.contains(where: { $0.intersects(cover) }) else { continue }
    pieces = pieces.flatMap { subtract($0, cover) }
    if pieces.isEmpty { return [] }
    // A deep stack of overlapping windows would split the remainder without bound. Past the cap the
    // answer is "covered" rather than a cheaper approximation of what is left: every caller uses
    // this to decide what may be photographed, and the only safe way to be wrong about that is to
    // offer too little. The cap is high enough that reaching it means a window under dozens of
    // others, which had nothing worth hinting anyway.
    if pieces.count > 256 { return [] }
  }
  return pieces
}

/// One on-screen window worth walking: the tree to walk, the box it occupies, and the boxes of the
/// windows drawn over it.
struct WindowTarget {
  let app: NSRunningApplication
  let element: AXUIElement
  /// In global top-left coordinates, the space both the window server and the tree report in.
  let frame: CGRect
  let occluders: [CGRect]
}

/// How far apart two frames are, added up corner by corner. Used only to pair a window the window
/// server named with the one the tree calls the same thing.
func frameDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
  abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) + abs(a.height - b.height)
}

/// The windows on screen, front to back, with the ones nothing can be seen of dropped and the rest
/// paired with the accessibility tree that describes them. `only` narrows it to one process.
///
/// The list comes from the window server rather than from the tree, because the tree does not know
/// the stacking order and the window server does -- and because it answers before a single
/// accessibility message has been sent, which is what makes the culling free. A desktop of forty
/// on-screen windows is usually four with any pixels of their own; the other thirty-six are dropped
/// here, and are never asked anything.
func onScreenWindows(options: Options, only: pid_t?) -> (targets: [WindowTarget], culled: Int, unmatched: Int) {
  let listed = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
  let ownPid = ProcessInfo.processInfo.processIdentifier

  // Front to back. Everything on screen occludes -- the menu bar, the Dock, a floating notification
  // panel -- but only ordinary windows are hinted: a menu or a popover is drawn over the window it
  // belongs to, so leaving it out of the targets masks that window rather than offering the menu as
  // a region of its own.
  var covers: [CGRect] = []
  var wanted: [(pid: pid_t, frame: CGRect, occluders: [CGRect])] = []
  var culled = 0
  for entry in listed {
    guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
          let bounds = entry[kCGWindowBounds as String] as? [String: Any] else { continue }
    var frame = CGRect.zero
    CGRectMakeWithDictionaryRepresentation(bounds as CFDictionary, &frame)
    let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
    if alpha <= 0 || frame.isEmpty { continue }
    // A window no capture can see covers nothing. Sharing state 0 is the window server saying this
    // one is left out of every picture taken of the screen, so what a shot of that rectangle
    // returns is whatever is behind it -- which is a window worth hinting, not one to cull. This
    // app's own driving border is exactly that and is the whole screen: counted as cover, an agent
    // saying it has the foreground would leave every window on the machine culled and every capture
    // ending "no window", including the one the burst was driving. Nor is such a window hinted
    // itself: its own pixels are the ones nothing can photograph.
    if (entry[kCGWindowSharingState as String] as? Int) == 0 { continue }
    let layer = (entry[kCGWindowLayer as String] as? Int) ?? 0
    // axshot's own windows are never hinted -- the settings window and the shortcut sheet are not
    // regions of anyone's work -- but they are drawn over what is behind them like anything else, so
    // they still count as cover. The overlay is not one of them: it does not go up until the walk
    // has finished, and the toast is dismissed before the walk starts.
    if layer == 0, pid != ownPid, only == nil || only == pid {
      let over = covers.filter { $0.intersects(frame) }
      let open = exposed(frame, under: over)
      if open.contains(where: { $0.width >= options.minSize && $0.height >= options.minSize }) {
        wanted.append((pid, frame, over))
      } else {
        culled += 1
      }
    }
    covers.append(frame)
  }

  // The window server names a window by a number the tree does not offer, so the two are paired on
  // the frame they agree about. Two windows of one app can sit on the same box, so a tree already
  // spoken for is not offered again; a window nothing matches is dropped rather than guessed at.
  var targets: [WindowTarget] = []
  var trees: [pid_t: [(element: AXUIElement, frame: CGRect)]] = [:]
  var applications: [pid_t: NSRunningApplication] = [:]
  var taken = Set<ElementKey>()
  var unmatched = 0
  for window in wanted {
    if trees[window.pid] == nil {
      trees[window.pid] = []
      guard let app = NSRunningApplication(processIdentifier: window.pid) else { unmatched += 1; continue }
      applications[window.pid] = app
      let appElement = AXUIElementCreateApplication(window.pid)
      AXUIElementSetMessagingTimeout(appElement, 1)
      // Chromium exposes nothing of the page until a client asks the application object for its
      // role; that one read is the switch. The walk asks every element below it, which covers the
      // rest.
      _ = string(appElement, kAXRoleAttribute)
      AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
      if options.enhanced {
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
      }
      trees[window.pid] = ((attribute(appElement, kAXWindowsAttribute) as? [AXUIElement]) ?? [])
        .compactMap { element in
          guard let frame = probe(element).frame, !frame.isEmpty else { return nil }
          return (element, frame)
        }
    }
    guard let app = applications[window.pid], let known = trees[window.pid] else { unmatched += 1; continue }
    let match = known
      .filter { !taken.contains(ElementKey(element: $0.element)) }
      .min { frameDistance($0.frame, window.frame) < frameDistance($1.frame, window.frame) }
    guard let match, frameDistance(match.frame, window.frame) <= 8 else { unmatched += 1; continue }
    taken.insert(ElementKey(element: match.element))
    targets.append(WindowTarget(app: app, element: match.element, frame: window.frame, occluders: window.occluders))
  }
  return (targets, culled, unmatched)
}

/// The one window `--focused` walks, with nothing over it and nothing beside it.
func focusedTarget(_ app: NSRunningApplication, options: Options) -> WindowTarget? {
  let appElement = AXUIElementCreateApplication(app.processIdentifier)
  AXUIElementSetMessagingTimeout(appElement, 1)
  _ = string(appElement, kAXRoleAttribute)
  AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  if options.enhanced {
    AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
  }
  guard let element = focusedWindow(appElement), let frame = probe(element).frame, !frame.isEmpty else { return nil }
  return WindowTarget(app: app, element: element, frame: frame, occluders: [])
}

// MARK: - Candidates

struct Candidate {
  /// Kept so the copy key can read the region's text out of the tree it came from. The walk holds
  /// the element anyway; letting go of it would mean walking again to find it.
  let element: AXUIElement
  let role: String
  let subrole: String
  let label: String
  /// Clipped to the window and in global top-left coordinates, the space the tree reports frames in.
  let rect: CGRect
  let depth: Int
  let childCount: Int
  /// Which of the walked windows this came out of. Two windows are two trees, so the nesting
  /// collapse and the arrows both stay inside one of them: a box in the window behind that happens
  /// to contain a box in the window in front is not its parent, and stepping between them is not a
  /// step across a tree.
  let window: Int

  var area: CGFloat { rect.width * rect.height }

  /// A container that says nothing about itself. Chromium wraps everything in these, so a run of
  /// them stacks a dozen hints on the same pixels; a labelled or subroled element is a real thing
  /// on the page and is always worth a hint.
  var generic: Bool {
    label.isEmpty && subrole.isEmpty && ["AXGroup", "AXGenericElement", "AXUnknown"].contains(role)
  }
}

final class Walk {
  let clip: CGRect
  /// The windows drawn over this one, in the same coordinates as `clip`.
  let occluders: [CGRect]
  /// Which window is being walked, stamped onto every candidate it finds.
  let window: Int
  let options: Options
  /// Shared with every other window's walk: what the budget protects is the keyboard the overlay is
  /// about to take, and that is one keyboard however many trees are being read to fill it.
  let deadline: Date
  var visited = 0
  var timedOut = false
  var path = Set<ElementKey>()
  var found: [Candidate] = []
  /// How long this window's walk took on its own. With the windows walked at once these overlap, so
  /// the dump adding up to more than its own total is the concurrency being visible rather than an
  /// arithmetic error.
  var ms = 0
  let maxDepth = 256

  init(clip: CGRect, occluders: [CGRect], window: Int, deadline: Date, options: Options) {
    self.clip = clip
    self.occluders = occluders
    self.window = window
    self.deadline = deadline
    self.options = options
  }

  /// This window's own box, as a candidate filling it would be recorded: clipped to the screen and
  /// cropped to the largest piece nothing in front covers. What fills a window is a run of elements
  /// rather than one, all reporting the same frame, so this is what the filter measures against
  /// instead of asking for a role.
  var box: CGRect {
    exposed(clip, under: occluders).max { $0.width * $0.height < $1.width * $1.height } ?? .null
  }

  func measure(_ element: AXUIElement) {
    let start = Date()
    run(element)
    ms = millis(since: start)
  }

  /// Pre-order, so an outer box is recorded before the inner boxes that repeat it and the dedupe
  /// below keeps the outer one.
  func run(_ element: AXUIElement, depth: Int = 0) {
    if timedOut || depth > maxDepth { return }
    // The tree is not always a tree: a child can lead back to an ancestor, and following it walks
    // until the stack gives out. Keep the ancestor path and refuse to re-enter it.
    let key = ElementKey(element: element)
    if path.contains(key) { return }
    path.insert(key)
    defer { path.remove(key) }

    visited += 1
    if visited % 64 == 0, Date() > deadline { timedOut = true; return }

    let info = probe(element)
    if let frame = info.frame, !frame.isEmpty {
      // What of this element could be photographed: the part inside its own window, less whatever a
      // window in front is drawn over. One rule twice -- a box is worth hinting only where the
      // pixels in it are this element's -- and it crops rather than rejects both times, so an
      // element the screen edge or the window in front takes half of is still offered on the half
      // that is there. The largest remaining piece, since a window covered across its middle leaves
      // more than one and the biggest is the one worth a keystroke.
      let onWindow = frame.intersection(clip)
      let open = onWindow.isNull || onWindow.isEmpty ? [] : exposed(onWindow, under: occluders)
      if let visible = open.max(by: { $0.width * $0.height < $1.width * $1.height }) {
        if visible.width >= options.minSize && visible.height >= options.minSize {
          found.append(Candidate(element: element, role: info.role, subrole: info.subrole, label: info.label, rect: visible, depth: depth, childCount: info.children.count, window: window))
        }
      } else if options.prune {
        // Nothing of this element can be seen at all -- off the screen, or under another window.
        // Its children are laid out inside it, so neither can anything below it, and not entering
        // the subtree is what keeps a long conversation walkable and a covered window unwalked.
        return
      }
    }

    for child in info.children { run(child, depth: depth + 1) }
  }
}

/// The text of a held region, read out of the tree rather than off the pixels, and only when the
/// copy key asks: the walk that drew the hints keeps one label per element, which is whatever the
/// element calls itself, and this is what its descendants actually say.
///
/// Text-bearing elements answer for their whole subtree -- a text area's value already spells out
/// what its children hold -- and everything else is recursed into, so a run of nested containers
/// contributes its parts once rather than once per wrapper. Clipped the way the regions are: a
/// subtree whose box falls entirely outside what is held is not in the shot the same keystroke
/// would have taken, so it is not in the copy either.
let textRoles: Set<String> = ["AXStaticText", "AXTextField", "AXTextArea"]

/// Whether a label could have been rendered inside this box, measured at the size the system draws
/// labels at. Controls do not wrap their labels, so one line that runs past the control's own edge
/// was never drawn there. This is what separates the two, since nothing in the tree marks a name as
/// standing in for an icon: "Edit" beside a rule is a button 64 points wide and is on screen,
/// "Trash" is the same word on the 26-point can next to it and is not.
func fits(_ text: String, in frame: CGRect) -> Bool {
  let width = (text as NSString)
    .size(withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]).width
  return width <= frame.width + 2
}

func regionLines(_ element: AXUIElement, clip: CGRect, deadline: Date, path: inout Set<ElementKey>) -> [String] {
  if Date() > deadline { return [] }
  let key = ElementKey(element: element)
  guard path.insert(key).inserted else { return [] }
  defer { path.remove(key) }

  let info = probe(element)
  if let frame = info.frame, !frame.isEmpty, !frame.intersects(clip) { return [] }

  // Read raw rather than reusing the probe's label, which has had its newlines flattened out for
  // the one line the dump prints.
  var own = [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute]
    .lazy.compactMap { string(element, $0) }.first { !$0.isEmpty }

  // An image's text is its alt text, which is a stand-in for the picture and was never on screen.
  if info.role == "AXImage" { own = nil }

  // A control's name is only its visible label where the label could have been drawn in the
  // control's own box. An icon button carries a name for screen readers -- "More options" on a
  // plus sign 24 points wide, "gearshape" on the symbol beside a row -- and copying the region
  // would otherwise hand back words nobody can see in it. Text elements are exempt: they wrap and
  // scroll and are the visible text by definition.
  if let name = own, !textRoles.contains(info.role), let frame = info.frame, !fits(name, in: frame) {
    own = nil
  }

  let speaksForItself = textRoles.contains(info.role)
  if info.children.isEmpty || (speaksForItself && own != nil) {
    return own.map { [$0] } ?? []
  }

  var lines: [String] = []
  for child in info.children { lines += regionLines(child, clip: clip, deadline: deadline, path: &path) }
  // A container whose children said nothing still has its own name to give -- where that name was
  // itself on screen, by the same measure.
  if lines.isEmpty, let own { lines = [own] }
  return lines
}

/// The region's text, one line per text-bearing element. `separator` is what those lines are put
/// back together with: a newline keeps the layout the region had, and a space joins them into the
/// running prose the layout had broken up, which is what Shift-J asks for.
func regionText(_ candidate: Candidate, budgetMs: Int, separator: String = "\n") -> String {
  var path = Set<ElementKey>()
  let lines = regionLines(
    candidate.element, clip: candidate.rect,
    deadline: Date().addingTimeInterval(Double(budgetMs) / 1000), path: &path)

  var kept: [String] = []
  for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    // A wrapper that names itself after its only child repeats it; one of the two is enough.
    if trimmed.isEmpty || trimmed == kept.last { continue }
    kept.append(trimmed)
  }
  return kept.joined(separator: separator)
}

/// Snap to a 2pt grid so boxes that differ by a rounding error collapse into one key.
func gridKey(_ rect: CGRect) -> String {
  func snap(_ value: CGFloat) -> Int { Int((value / 2).rounded()) }
  return "\(snap(rect.minX)),\(snap(rect.minY)),\(snap(rect.width)),\(snap(rect.height))"
}

func nearlyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 4) -> Bool {
  abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
    && abs(a.maxX - b.maxX) <= tolerance && abs(a.maxY - b.maxY) <= tolerance
}

/// How much bigger a box must be than one it contains before both are worth hinting. Below this the
/// two are the same region drawn twice, and the outer one is the better screenshot.
let nestingRatio: CGFloat = 1.5

/// The tree is mostly nested containers that repeat their child's box, and hinting them raw stacks a
/// dozen hints on the same pixels. Four passes: drop the boxes that are their own window, drop exact
/// repeats, drop wrappers that say nothing and hold one child, then walk largest-first and drop
/// anything an already-kept box swallows without growing much. Document order is restored at the end
/// so the hints read down the page -- front window first, since that is the order the windows were
/// walked in.
///
/// All four compare within one window, `windows` holding each walk's own box under the index its
/// candidates are stamped with: the rectangle an element filling that window would be recorded at,
/// clipped to the screen and cropped to the largest piece nothing in front covers. A box that size
/// is the whole window, which is the shot Command-Shift-4 and then Space already takes, and it is
/// never one element -- the window, its content view and whatever split or group they wrap all
/// report the same frame -- so dropping it by role would hand the same rectangle to its child, one
/// letter along. The cap on hints is the only thing that is shared, which is what makes it the cap
/// it says it is; a box in the window behind that a box in the window in front happens to sit inside
/// is not a repeat of it, and collapsing the two would take away the region the second window was
/// walked for.
///
/// Largest-first spends that cap on the front window without being told to. A window behind is
/// partly covered by definition, so its boxes are the clipped ones and rank below the whole ones in
/// front: a crowded desktop cut to twenty hints kept fourteen of them in the front window.
func filter(_ candidates: [Candidate], max limit: Int, windows: [CGRect]) -> [Candidate] {
  var seen = Set<String>()
  var distinct: [(offset: Int, candidate: Candidate)] = []
  for (offset, candidate) in candidates.enumerated() {
    if nearlyEqual(candidate.rect, windows[candidate.window]) { continue }
    if candidate.generic && candidate.childCount <= 1 { continue }
    if !seen.insert("\(candidate.window):\(gridKey(candidate.rect))").inserted { continue }
    if distinct.contains(where: { $0.candidate.window == candidate.window && nearlyEqual($0.candidate.rect, candidate.rect) }) { continue }
    distinct.append((offset, candidate))
  }

  var kept: [(offset: Int, candidate: Candidate)] = []
  for entry in distinct.sorted(by: { $0.candidate.area > $1.candidate.area }) {
    let swallowed = kept.contains { outer in
      outer.candidate.window == entry.candidate.window
        && outer.candidate.rect.insetBy(dx: -2, dy: -2).contains(entry.candidate.rect)
        && outer.candidate.area < entry.candidate.area * nestingRatio
    }
    if swallowed { continue }
    kept.append(entry)
    if kept.count == limit { break }
  }
  return kept.sorted { $0.offset < $1.offset }.map { $0.candidate }
}

/// Prefix-free labels, as short as the alphabet allows: with 14 letters a page of two dozen regions
/// gets mostly single keystrokes, and nothing needs more than two until there are 197 of them.
/// The short labels are the low numbers and the long ones start above them, so no short label is
/// ever a prefix of a long one and a complete label can be acted on the moment it is typed.
///
/// Which also settles who gets them once several windows are hinted, without anything having to
/// decide it: the candidates are in front-to-back order, so the low numbers are the front window's
/// and the single keystrokes go there. Hinting the whole screen costs the front window some of them
/// -- seven rather than twelve, on a desktop of four exposed windows -- and costs it none of the
/// shortest ones.
func hintLabels(count: Int, alphabet: String) -> [String] {
  let letters = Array(alphabet)
  let base = letters.count
  guard count > 0 else { return [] }
  if count <= base { return (0..<count).map { String(letters[$0]) } }

  var digits = 1
  var capacity = base
  while capacity < count { capacity *= base; digits += 1 }
  let short = (capacity - count) / (base - 1)

  func label(_ number: Int, width: Int) -> String {
    var value = number
    var characters: [Character] = []
    for _ in 0..<width {
      characters.append(letters[value % base])
      value /= base
    }
    return String(characters.reversed())
  }

  var labels = (0..<short).map { label($0, width: digits - 1) }
  labels += (0..<(count - short)).map { label(short * base + $0, width: digits) }
  return labels
}

// MARK: - Overlay

let hintFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)

/// Under this on either side, a press and release was a click rather than a drag. It is the size of
/// the slip a hand makes pressing a button, and nothing anyone means to photograph.
let minimumDrag: CGFloat = 8

/// What a hint plate looks like. The plates sit on top of whatever the target window is showing, so
/// which one reads best is a property of the screen underneath rather than of the app: the grey is
/// quiet enough not to be the first thing the eye lands on, and the yellow is loud enough to be
/// found on a page dense enough to lose a plate in.
enum HintStyle: String, CaseIterable {
  /// The default. Quiet enough to leave the window it is sitting on as the thing being looked at.
  case grey
  /// The grey's opposite number, for pale content: as quiet in hue, and as far from the page as a
  /// plate can get without a colour.
  case dark
  /// The original, and the loudest of the warm ones.
  case yellow
  /// Cool and saturated, which almost no page's text is -- the plates separate from the words even
  /// where they land on top of them.
  case blue
  /// The one that appears in the fewest interfaces, for a screen busy enough that every other
  /// plate colour is also somewhere in the window underneath it.
  case pink

  var title: String {
    switch self {
    case .grey: return "Grey"
    case .dark: return "Dark"
    case .yellow: return "Yellow"
    case .blue: return "Blue"
    case .pink: return "Pink"
    }
  }

  /// The fill, top to bottom. Every style is a gradient rather than a colour: a plate shaded the way
  /// the light falls reads as sitting on the window rather than as a hole cut in it, and the shading
  /// is what keeps an edge where the plate lands on something its own colour.
  ///
  /// Both stops clear 4.5:1 against the letter drawn on them, measured at the lighter of the two,
  /// which for a white letter is the top: a plate is a 12pt label and nothing else, so the letters
  /// are the one thing on it that has to be read at all. That floor is what holds the blue down
  /// where it is rather than at the lighter blue it would otherwise be (4.7:1, from 2.9:1).
  private var gradient: (top: NSColor, bottom: NSColor) {
    switch self {
    case .grey:
      return (NSColor(calibratedWhite: 0.97, alpha: 0.96), NSColor(calibratedWhite: 0.78, alpha: 0.96))
    case .dark:
      return (NSColor(calibratedWhite: 0.26, alpha: 0.96), NSColor(calibratedWhite: 0.08, alpha: 0.96))
    case .yellow:
      return (NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.45, alpha: 0.96),
              NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.25, alpha: 0.96))
    case .blue:
      return (NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.95, alpha: 0.96),
              NSColor(calibratedRed: 0.10, green: 0.38, blue: 0.90, alpha: 0.96))
    case .pink:
      return (NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.74, alpha: 0.96),
              NSColor(calibratedRed: 0.92, green: 0.24, blue: 0.57, alpha: 0.96))
    }
  }

  /// Dark enough to hold the plate's shape against a page of the same tone, since the fill alone
  /// cannot: a light plate on white and a dark plate on black both need the outline to exist.
  private var border: NSColor {
    switch self {
    case .grey: return NSColor(calibratedWhite: 0.45, alpha: 0.9)
    case .dark: return NSColor(calibratedWhite: 0.78, alpha: 0.7)
    case .yellow: return NSColor(calibratedRed: 0.35, green: 0.25, blue: 0.0, alpha: 0.9)
    case .blue: return NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.48, alpha: 0.9)
    case .pink: return NSColor(calibratedRed: 0.45, green: 0.05, blue: 0.26, alpha: 0.9)
    }
  }

  /// Dark or light, whichever clears 4.5:1 against the gradient underneath. The pink is the one
  /// that surprises: it is as saturated as the blue and reads as a strong colour, but it is a far
  /// brighter one, and a white letter on it came to 2.4:1 -- so it takes the dark letter its own
  /// brightness asks for rather than the white its loudness suggests.
  private var letter: NSColor {
    switch self {
    case .grey: return NSColor(calibratedWhite: 0.1, alpha: 1)
    case .yellow, .pink: return .black
    case .dark, .blue: return .white
    }
  }

  /// The space around the letters, which is what makes a plate bigger than its text.
  private static let padding: CGFloat = 3

  func plateSize(_ label: String) -> CGSize {
    let size = plateText(label).size()
    return CGSize(width: size.width + Self.padding * 2, height: size.height + Self.padding * 2)
  }

  private func plateText(_ label: String) -> NSAttributedString {
    NSAttributedString(string: label, attributes: [.font: hintFont, .foregroundColor: letter])
  }

  /// Draws one plate with its top-left corner at `topLeft`. The settings swatches draw through this
  /// too, so a style is defined in one place and a swatch cannot come to disagree with the overlay
  /// it is a picture of.
  func drawPlate(_ label: String, topLeft: CGPoint) {
    let size = plateSize(label)
    let plate = CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
    let rounded = NSBezierPath(roundedRect: plate, xRadius: 3, yRadius: 3)
    // Downwards, which is where the light is.
    NSGradient(starting: gradient.top, ending: gradient.bottom)?.draw(in: rounded, angle: -90)
    border.setStroke()
    rounded.lineWidth = 1
    rounded.stroke()
    plateText(label).draw(at: CGPoint(x: plate.minX + Self.padding, y: plate.minY + Self.padding))
  }

  /// The style as one colour, for what outlines rather than fills. The drive frame is the only
  /// caller: a four point band around a window is too thin for a gradient to read as one, and a band
  /// that has to follow the system's own corner curve is drawn by a layer rather than by hand -- a
  /// layer's border takes a colour and not a shading. Blended from the two stops rather than picked
  /// out of the air, so a border and a plate cannot come to disagree about what pink is.
  var line: NSColor {
    gradient.top.blended(withFraction: 0.5, of: gradient.bottom) ?? gradient.top
  }
}

final class HintView: NSView {
  var boxes: [(label: String, rect: CGRect)] = []
  var typed = ""
  /// Set once a hint has been typed: the region is held, everything outside it is masked, and the
  /// shutter waits for Return. Preview's crop, without the grid -- the point is to see what the
  /// shot will contain while the target is still on screen to compare it against.
  var selection: CGRect?
  /// The mask itself: the box it leaves clear, and how far the darkness has come in -- 0 is a
  /// screen with nothing over it, 1 is the mask at full strength. A second fact rather than a level
  /// hung off `selection`, because the two have different lives: Delete lets the region go and puts
  /// the hints back while the darkness is still on its way off the screen, and the hints are drawn
  /// through whatever is left of it.
  var mask: (rect: CGRect, level: CGFloat)?
  /// The held region's text with its line breaks taken out, drawn over the region itself. What the
  /// tree hands over is not always what the layout showed -- a paragraph split across a dozen
  /// elements comes back as a dozen lines -- so the joined form is put on screen before it is
  /// copied, in the one place the original is still next to it.
  var joined: String?
  /// A word from the app rather than from the region -- "Transcribing..." while the request is out,
  /// or why it failed. Drawn in the same box as the joined text, and deliberately not the same
  /// field: the copy key hands over what the region said, and never what axshot said about it.
  var notice: String?
  /// Where the caret sits in `joined` while Shift-E has the box open for typing, as a UTF-16 offset
  /// -- nil when it is closed, which is the only thing that says whether the next letter is a key
  /// or a character. Never drawn over a notice: that field is the app talking, and there is nothing
  /// in it to correct.
  var caret: Int?
  /// The end of the selection the caret is not on. Equal to the caret is no selection: one offset
  /// says where the next character goes, two say what it replaces.
  var anchor = 0

  /// The selected run, clamped to the text it is being asked about. Empty is the plain insertion
  /// point, and the two are drawn differently: a highlight behind the words, or a bar between them.
  private func selected(length: Int) -> NSRange? {
    guard let caret else { return nil }
    let low = max(0, min(min(caret, anchor), length))
    let high = max(0, min(max(caret, anchor), length))
    return NSRange(location: low, length: high - low)
  }
  /// Set across the shutter that Shift-T fires. The mask stays exactly where it is -- it is drawn
  /// even-odd and never covers the region -- while the two things that *are* drawn inside the region
  /// come off: the corner brackets, and the text box if one is up. Ordering the whole overlay out
  /// instead would photograph the same pixels, but the region would visibly unmask and re-mask
  /// around the shutter, which is a flash the join key never has.
  var bare = false
  /// Set for the window shot, which is the one photograph the overlay stays whole for. `bare` is
  /// too much there -- it takes off the brackets and the box, which are the subject -- and the
  /// crosshair is the only thing that has to go: it stands in for a cursor, and screencapture(1) is
  /// never asked for one of those either.
  var hidesPointer = false
  /// Set while `?` is asking for the shortcut list, which is drawn over whatever is underneath it.
  var help = false
  /// The hotkey as settings spells it. It is one of the keys the list names -- a second tap cancels
  /// -- and it is not the same chord on every machine.
  var hotkey: String?
  /// The one colour on the overlay that is neither black, white, nor the window underneath, and it
  /// is behind selected words and nowhere else. There is no ring around the box: the caret is in it
  /// from the moment it is drawn, so a border would mark a state the box is never in the other half
  /// of -- decoration answering a question nobody has.
  private static let selectionFill = NSColor(calibratedRed: 0.35, green: 0.62, blue: 1, alpha: 0.45)
  /// Where the pointer is, in this view's own coordinates, and the numbers drawn beside it. Those
  /// are the global top-left coordinates the tree reports frames in and the dump prints, which is
  /// not the space this view draws in -- the readout is for reading off the screen, not for finding
  /// anything in here.
  var pointer: CGPoint?
  var pointerLabel: String?
  override var isFlipped: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    // Erased rather than painted over. The window is transparent, so a clear fill composited the
    // usual way leaves whatever was drawn there last -- which never showed while the whole view was
    // being redrawn every time, and does the moment only the readout's own plate is.
    NSColor.clear.setFill()
    dirtyRect.fill(using: .copy)

    drawRegions()
    // Never into a photograph, and not over the sheet: one is the shutter, and the other is a page
    // being read rather than a screen being pointed at. `hidesPointer` is the second of those for
    // the shot that keeps everything else -- the crosshair is a cursor, and no screenshot takes one.
    if !bare && !help && !hidesPointer { drawPointer() }
    // Never over a shutter. Nothing can fire one while the sheet is up -- every other key is
    // swallowed -- but the sheet is the one thing on the overlay large enough that drawing it into
    // a photograph would go unnoticed until someone opened the file.
    if help && !bare { drawHelp() }
  }

  /// The crosshair is drawn rather than set. A cursor belongs to the *active* application, not to
  /// whichever app owns the window under the pointer: `NSCursor.set()` and a `.cursorUpdate`
  /// tracking area were both tried on this overlay and the WindowServer kept the arrow, because this
  /// app is never the active one and the whole design turns on it staying that way. Measured on a
  /// machine, not reasoned about -- the readout drawn by the same call that set the cursor appeared
  /// and the cursor did not. So the mark is painted into the overlay at the tracked position, and
  /// the system arrow rides on top of it: a crosshair whose centre is where the shot will start,
  /// with the arrow's own tip in the same place.

  /// Move the readout, marking only the plate it left and the plate it arrived at. Mouse-moved
  /// events arrive as fast as a hand can make them, and marking the whole overlay dirty would redraw
  /// every hint on the screen -- and refill a display's worth of transparent pixels -- for a label
  /// that moved four points.
  func movePointer(to point: CGPoint, label: String) {
    if let mark = pointerMark { setNeedsDisplay(mark) }
    pointer = point
    pointerLabel = label
    if let mark = pointerMark { setNeedsDisplay(mark) }
  }

  private static let pointerFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
  private static let pointerPadding: CGFloat = 4
  /// Clear of the crosshair drawn below, and of the system arrow still riding on top of it, which
  /// reaches about that far down and to the right of its own tip.
  private static let pointerOffset: CGFloat = 20
  /// How far each arm of the crosshair reaches from the centre, and the gap left around the centre
  /// itself so the point being aimed at is not the one point the mark covers.
  private static let crossReach: CGFloat = 12
  private static let crossGap: CGFloat = 3

  private var pointerRun: NSAttributedString? {
    pointerLabel.map {
      NSAttributedString(string: $0, attributes: [.font: Self.pointerFont, .foregroundColor: NSColor.white])
    }
  }

  /// The plate the numbers sit on. In one place because a move invalidates it twice -- where it was
  /// and where it now is -- and a second copy of this arithmetic would be a second place for the two
  /// to disagree and leave a plate on screen with nothing redrawing it.
  private var pointerPlate: CGRect? {
    guard let pointer, let run = pointerRun else { return nil }
    let size = run.size()
    let width = size.width + Self.pointerPadding * 2
    let height = size.height + Self.pointerPadding * 2
    // Below and to the right of the crosshair, and folded back across it where the screen runs out:
    // a readout half off the edge is least readable exactly where the edge is what is being aimed
    // at.
    var x = pointer.x + Self.pointerOffset
    var y = pointer.y - Self.pointerOffset - height
    if x + width > bounds.maxX - 4 { x = pointer.x - Self.pointerOffset - width }
    if y < bounds.minY + 4 { y = pointer.y + Self.pointerOffset }
    return CGRect(x: x, y: y, width: width, height: height)
  }

  /// Where the pointer is, in the numbers the rest of the tool speaks: a region worth capturing is
  /// often one whose edge has to be found by eye, and the same coordinates come back out of --dump
  /// and off the end of every capture line.
  private func drawPointer() {
    guard let pointer else { return }
    // The crosshair, in white over a dark halo, because it is drawn on whatever the target window
    // is showing and either colour alone disappears against half of them.
    let arms = NSBezierPath()
    for (dx, dy) in [(CGFloat(1), CGFloat(0)), (-1, 0), (0, 1), (0, -1)] {
      arms.move(to: CGPoint(x: pointer.x + dx * Self.crossGap, y: pointer.y + dy * Self.crossGap))
      arms.line(to: CGPoint(x: pointer.x + dx * Self.crossReach, y: pointer.y + dy * Self.crossReach))
    }
    NSColor(calibratedWhite: 0, alpha: 0.55).setStroke()
    arms.lineWidth = 3
    arms.stroke()
    NSColor.white.setStroke()
    arms.lineWidth = 1
    arms.stroke()

    guard let plate = pointerPlate, let run = pointerRun else { return }
    // Stated outright rather than themed, like the mask and the joined-text box it matches: the
    // readout is drawn over another app's window, and a plate that went light with the desktop
    // would be unreadable on half of them.
    NSColor(calibratedWhite: 0.08, alpha: 0.9).setFill()
    NSBezierPath(roundedRect: plate, xRadius: 3, yRadius: 3).fill()
    run.draw(at: CGPoint(x: plate.minX + Self.pointerPadding, y: plate.minY + Self.pointerPadding))
  }

  /// Everything the readout paints -- the crosshair and the plate -- as one rectangle, which is what
  /// a move has to mark dirty where it was and where it now is. In one place because a second copy
  /// of this arithmetic would be a second place for the two to disagree and leave a mark on screen
  /// with nothing redrawing it.
  private var pointerMark: CGRect? {
    guard let pointer else { return nil }
    let cross = CGRect(x: pointer.x - Self.crossReach, y: pointer.y - Self.crossReach,
                       width: Self.crossReach * 2, height: Self.crossReach * 2)
    return (pointerPlate.map { cross.union($0) } ?? cross).insetBy(dx: -3, dy: -3)
  }

  private func drawRegions() {
    if let mask {
      // Even-odd over the whole overlay minus the region, so the mask is one fill and the region
      // is left completely untouched rather than drawn over at a low alpha.
      let path = NSBezierPath(rect: bounds)
      path.append(NSBezierPath(rect: mask.rect))
      path.windingRule = .evenOdd
      NSColor(calibratedWhite: 0, alpha: 0.55 * mask.level).setFill()
      path.fill()

      // Corner brackets, drawn inside the region so they mark it without covering its edge pixels,
      // and dimmed by the same level the darkness is: the mask and the brackets are one
      // announcement, and brackets snapping on at the end of the mask's fade would read as two.
      //
      // Nothing from here down is drawn for the shutter: the brackets and the box below them sit
      // inside the region, which is the one part of the screen the photograph is of.
      if !bare {
        let region = mask.rect
        let arm = min(24, region.width / 3, region.height / 3)
        let thickness: CGFloat = 2
        let corners = NSBezierPath()
        for (x, dx) in [(region.minX, 1.0 as CGFloat), (region.maxX, -1.0 as CGFloat)] {
          for (y, dy) in [(region.minY, 1.0 as CGFloat), (region.maxY, -1.0 as CGFloat)] {
            corners.move(to: CGPoint(x: x + dx * arm, y: y + dy * thickness / 2))
            corners.line(to: CGPoint(x: x, y: y + dy * thickness / 2))
            corners.move(to: CGPoint(x: x + dx * thickness / 2, y: y))
            corners.line(to: CGPoint(x: x + dx * thickness / 2, y: y + dy * arm))
          }
        }
        NSColor(calibratedWhite: 1, alpha: mask.level).setStroke()
        corners.lineWidth = thickness
        corners.stroke()
      }
    }

    // A region held is the hints answered: they stop being drawn the moment one is, and come back
    // only when it is let go of -- through what is left of the mask, which is still receding.
    if selection != nil {
      if let plate = textBox() {
        NSColor(calibratedWhite: 0.08, alpha: 0.94).setFill()
        NSBezierPath(roundedRect: plate.box, xRadius: 4, yRadius: 4).fill()
        // The highlight is laid down before the words and the caret after them, which is the only
        // order that leaves both visible; they are never both up, since a selection is exactly the
        // state in which there is no one place the next character goes.
        var bar: CGRect?
        if let caret, let range = selected(length: plate.text.length), notice == nil {
          if range.length > 0 {
            let glyphs = plate.layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            Self.selectionFill.setFill()
            // One rect per line fragment rather than one per glyph, so a selection running over a
            // wrap is drawn as the two part-lines it looks like rather than as a stack of boxes.
            plate.layout.enumerateEnclosingRects(forGlyphRange: glyphs,
                                                 withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                                 in: plate.container) { rect, _ in plate.place(rect).fill() }
          } else {
            var caretPlace = plate.place(caretRect(caret, layout: plate.layout, container: plate.container,
                                                   length: plate.text.length))
            caretPlace.size.width = 2
            bar = caretPlace
          }
        }
        plate.text.draw(with: plate.field, options: [.usesLineFragmentOrigin, .usesFontLeading])
        if let bar {
          NSColor.white.setFill()
          bar.fill()
        }
      }
      return
    }

    let style = Settings.hintStyle
    for box in boxes where box.label.hasPrefix(typed) {
      let remaining = String(box.label.dropFirst(typed.count))
      style.drawPlate(remaining.uppercased(), topLeft: CGPoint(x: box.rect.minX, y: box.rect.maxY))
    }
  }

  /// The text box exactly as it is drawn: where it sits, and the run laid out at the size it was
  /// fitted to. It is worked out in one place because three things have to agree about where a word
  /// is -- the glyphs, the caret between them, and the point a click landed on -- and the shrink
  /// loop picks a different size for every region, so geometry derived a second time is geometry
  /// that can disagree with what is on screen.
  ///
  /// The storage is carried along with the two things it feeds. A text storage owns its layout
  /// managers and they refer back to it without owning it, so one left behind is deallocated on the
  /// way out and the manager that comes back has no text and no glyphs -- which reads as a caret
  /// asking after glyph indices that do not exist rather than as an object that is gone.
  struct TextBox {
    let box: CGRect
    let field: CGRect
    let text: NSAttributedString
    let storage: NSTextStorage
    let layout: NSLayoutManager
    let container: NSTextContainer

    /// A container rect in the view's coordinates. The run is laid out downwards from the top of
    /// `field` in a view that is not flipped, so a rect's top edge is `field.maxY` less its own
    /// bottom.
    func place(_ rect: CGRect) -> CGRect {
      CGRect(x: field.minX + rect.minX, y: field.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
  }

  /// Nil whenever nothing is drawn: no region held, the shutter running bare, the mask still on its
  /// way in or already on its way out, no text to show, or a region too small to fit any of it.
  ///
  /// Words rather than chrome, which is why this waits for the fade the brackets ride: half-lit
  /// text is not text, and the box is opaque over the region besides -- a box dissolving into the
  /// window it covers reads as a rendering fault rather than as something leaving.
  func textBox() -> TextBox? {
    guard let selection, !bare, mask?.level == 1, let string = notice ?? joined else { return nil }
    // Over the region rather than beside it: the joined text is what the region says, and the
    // region is the only box on screen guaranteed to be where the eye already is. Opaque, because
    // text drawn over text is neither of them.
    // Padding scaled to the region rather than a fixed 8: a link or a table row is one line tall,
    // which is where a joined run is likeliest to be asked for and where a fixed margin leaves no
    // room to draw it in.
    let padding = min(8, max(2, min(selection.width, selection.height) / 8))
    let inset = selection.insetBy(dx: padding, dy: padding)
    guard inset.width > 16, inset.height > 8 else { return nil }
    // Four fifths of the system's own body size, and 1.25 line spacing: this is a region's text
    // laid over the region, so it has to hold more words in the same box than the layout it
    // replaced -- a notch smaller than what the machine reads at, with the lines given room, since
    // a run with its breaks taken out is a wall otherwise.
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.lineHeightMultiple = 1.25
    func attributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
      [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.white, .paragraphStyle: style]
    }
    func laid(_ text: NSAttributedString) -> (NSTextStorage, NSLayoutManager, NSTextContainer) {
      let storage = NSTextStorage(attributedString: text)
      let container = NSTextContainer(size: CGSize(width: inset.width, height: .greatestFiniteMagnitude))
      container.lineFragmentPadding = 0
      let layout = NSLayoutManager()
      layout.addTextContainer(container)
      storage.addLayoutManager(layout)
      layout.ensureLayout(for: container)
      return (storage, layout, container)
    }
    // Laid out to be measured, rather than asking boundingRect: it does not count the leading that
    // lineHeightMultiple adds, so it reports a wall of text a fifth shorter than it draws, and the
    // box built from that figure cuts the last lines off.
    func height(_ text: NSAttributedString) -> CGFloat {
      let (storage, layout, container) = laid(text)
      defer { _ = storage }
      return ceil(layout.usedRect(for: container).height) + 2
    }
    // Shrink below the system size only where the region holds more words than it has room for,
    // down to a floor: the alternative is text cut off mid-sentence with nothing saying so.
    var size = NSFont.systemFontSize * 0.8
    var text = NSAttributedString(string: string, attributes: attributes(size: size))
    while height(text) > inset.height, size > 8 {
      size -= 1
      text = NSAttributedString(string: string, attributes: attributes(size: size))
    }
    // Centred vertically in what is left over, which only shows on the short regions -- a row whose
    // one line sat hard against the top read as clipped rather than as centred. The box gives up its
    // top half of the slack and keeps the bottom: text is laid out downwards from the top, so a rect
    // trimmed at the bottom as well would clip anything the measurement undercounted, and the
    // centring is not worth paying for in lost lines.
    let slack = max(0, inset.height - height(text))
    let (storage, layout, container) = laid(text)
    return TextBox(box: selection.insetBy(dx: padding / 2, dy: padding / 2),
                   field: CGRect(x: inset.minX, y: inset.minY,
                                 width: inset.width, height: inset.height - slack / 2),
                   text: text, storage: storage, layout: layout, container: container)
  }

  /// The character a point in the view lands between, or nil when it is not over the box at all.
  /// The fraction is what makes a click land on a boundary rather than on a glyph: past the middle
  /// of a character the caret belongs after it, which is where a person aiming between two letters
  /// expects it.
  func offset(at point: CGPoint) -> Int? {
    guard let plate = textBox(), plate.box.contains(point) else { return nil }
    let inContainer = CGPoint(x: point.x - plate.field.minX, y: plate.field.maxY - point.y)
    var fraction: CGFloat = 0
    let index = plate.layout.characterIndex(for: inContainer, in: plate.container,
                                            fractionOfDistanceBetweenInsertionPoints: &fraction)
    return index + (fraction > 0.5 && index < plate.text.length ? 1 : 0)
  }

  /// The drawn line an offset sits on, trailing space trimmed off. A line here is a line on the
  /// screen: the run has no breaks left in it, so the only lines it has are the ones the box
  /// wrapped, and the end of one is where the words stop rather than where the wrap happened.
  func lineBounds(around offset: Int) -> NSRange? {
    guard let plate = textBox() else { return nil }
    let string = plate.text.string as NSString
    guard string.length > 0 else { return NSRange(location: 0, length: 0) }
    let glyph = plate.layout.glyphIndexForCharacter(at: max(0, min(offset, string.length - 1)))
    var glyphs = NSRange()
    _ = plate.layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &glyphs)
    var line = plate.layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
    while line.length > 0,
          CharacterSet.whitespacesAndNewlines.contains(
            Unicode.Scalar(string.character(at: NSMaxRange(line) - 1)) ?? " ") {
      line.length -= 1
    }
    return line
  }

  /// The offset one drawn line up or down, holding the horizontal place the caret was at -- the
  /// column-keeping move every other field makes, worked out on the layout that drew the text
  /// rather than on a guess at the line height.
  func verticalOffset(from offset: Int, down: Bool) -> Int? {
    guard let plate = textBox() else { return nil }
    let here = caretRect(offset, layout: plate.layout, container: plate.container, length: plate.text.length)
    let step = here.height > 0 ? here.height : 12
    let target = CGPoint(x: here.minX, y: here.midY + (down ? step : -step))
    guard target.y >= 0 else { return 0 }
    guard target.y <= plate.layout.usedRect(for: plate.container).maxY else { return plate.text.length }
    var fraction: CGFloat = 0
    let index = plate.layout.characterIndex(for: target, in: plate.container,
                                            fractionOfDistanceBetweenInsertionPoints: &fraction)
    return index + (fraction > 0.5 && index < plate.text.length ? 1 : 0)
  }

  /// Where the caret sits in a laid-out run, in the container's own downward coordinates. The end
  /// of the run is the case the layout manager has no glyph to answer with, and it is where a caret
  /// spends most of its time -- so it is taken from the trailing edge of the last glyph, or from the
  /// empty fragment AppKit keeps past a trailing newline.
  private func caretRect(_ index: Int, layout: NSLayoutManager, container: NSTextContainer,
                         length: Int) -> CGRect {
    let index = max(0, min(index, length))
    if length == 0 || (index >= length && layout.extraLineFragmentTextContainer != nil) {
      let line = layout.extraLineFragmentRect
      return CGRect(x: 0, y: line.minY, width: 0, height: line.height > 0 ? line.height : 12)
    }
    if index >= length {
      let glyph = layout.glyphIndexForCharacter(at: length - 1)
      let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
      let last = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
      return CGRect(x: last.maxX, y: line.minY, width: 0, height: line.height)
    }
    let glyph = layout.glyphIndexForCharacter(at: index)
    let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    return CGRect(x: line.minX + layout.location(forGlyphAt: glyph).x,
                  y: line.minY, width: 0, height: line.height)
  }

  /// The shortcut list over the middle of the overlay, with everything behind it dimmed: the keys
  /// it names are the ones that would otherwise be typed at the hints underneath. The sheet itself
  /// is drawn by `HelpSheet`, which the menu bar opens a window on -- the list is the same list
  /// whether it is read mid-session or read at leisure.
  private func drawHelp() {
    NSColor(calibratedWhite: 0, alpha: 0.45).setFill()
    bounds.fill()
    let size = HelpSheet.size(hotkey: hotkey)
    HelpSheet.draw(in: CGRect(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2,
                              width: size.width, height: size.height),
                   hotkey: hotkey)
  }
}

/// The shortcut list, drawn into a rect that is exactly the sheet. Grouped by when each key applies
/// rather than listed alphabetically: the hints and a held region take different keys, and the sheet
/// is read in the middle of one or the other. It is measured before it is drawn because it has two
/// callers that frame it differently -- the overlay centres it on a screen it is already filling,
/// and the menu bar opens a window that is the sheet and nothing else.
enum HelpSheet {
  /// The sheet is the one thing drawn over another app that follows the theme, because it is a page
  /// of text rather than a mark on the screen underneath: nothing about it has to stay dark for the
  /// masking to keep working. Read from the application rather than from the view being drawn into,
  /// so the picture is the same one whether the caller is the overlay or the menu bar's window.
  private static var isDark: Bool {
    NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
  }

  private static let keyFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
  private static let textFont = NSFont.systemFont(ofSize: 12)
  private static let headingFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

  private static let padding: CGFloat = 30
  /// Less above the first heading than below the last row: a heading is set small and its own
  /// ascent already leaves a gap that the rows underneath do not.
  private static let topPadding: CGFloat = 22
  private static let gap: CGFloat = 16
  private static let rowHeight: CGFloat = 19
  private static let headingHeight: CGFloat = 20
  private static let headingGap: CGFloat = 6
  private static let sectionGap: CGFloat = 22

  /// The hotkey is spelled out as settings spells it, being the one key on the list that is not the
  /// same on every machine.
  private static func sections(hotkey: String?) -> [(String, [(String, String)])] {
    [
      ("Hints", [
        ("a-z", "select the region based on the hint letters"),
      ]),
      ("Selected Region", [
        ("\u{21A9}", "save screenshot"),
        ("\u{2318}C", "copy image"),
        ("\u{2318}\u{21E7}C", "copy text"),
        ("\u{21E7}J", "join text into one line"),
        ("\u{21E7}T", "transcribe the text in the image"),
        ("\u{21E7}E", "put the caret back in that text"),
        ("\u{2190} \u{2192} \u{2191} \u{2193} or HJKL", "select the nearest region that way on screen"),
        ("\u{2325}\u{2190} \u{2325}\u{2192}", "select the prev/next region in the tree"),
        ("\u{2325}\u{2191}", "select the parent region"),
        ("\u{2325}\u{2193}", "select the child region"),
        ("+ -", "grow or shrink the margin around it"),
      ]),
      ("Editing Text", [
        ("click or drag", "put the caret there, or select"),
        ("\u{2325}\u{2190} \u{2325}\u{2192}", "move by word"),
        ("\u{2318}\u{2190} \u{2318}\u{2192}", "move to the ends of the line"),
        ("\u{21E7}", "with any move, select instead"),
        ("\u{2318}A", "select all"),
        ("\u{2318}C or \u{2318}\u{21E7}C", "copy the selection"),
        ("esc", "put back what it said, and stop editing"),
      ]),
      ("Any time", [
        ("drag", "select a custom region"),
        ("space", "hold while dragging to move the region"),
        ("\u{2318}\u{2325}\u{2190} \u{2318}\u{2325}\u{2192}", "select the left/right half of the screen"),
        ("esc or " + (hotkey ?? ""), "cancel"),
        ("\u{2318},", "settings"),
        ("\u{2318}\u{21E7}3", "screenshot the overlay, hints and all"),
        ("\u{2318}\u{2303}\u{21E7}3", "that same picture, on the clipboard"),
        ("?", "keyboard shortcuts (you are here)"),
      ]),
    ]
  }

  /// The same alphas either way round: they are how much of a row is heading, key or prose, and
  /// that ranking does not change with the ground it is set on -- only which end of the scale the
  /// ink starts from.
  private static func run(_ string: String, _ font: NSFont, _ alpha: CGFloat) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [
      .font: font, .foregroundColor: NSColor(calibratedWhite: isDark ? 1 : 0, alpha: alpha),
    ])
  }

  /// The alternatives on a row are two ways of pressing the same thing, and the word between them
  /// is prose rather than a key: set in the text font so the row reads as "this key or that one"
  /// and not as a chord with letters in it.
  private static func keys(_ chord: String) -> NSAttributedString {
    let line = NSMutableAttributedString()
    for (index, part) in chord.components(separatedBy: " or ").enumerated() {
      if index > 0 { line.append(run("  or  ", textFont, 0.45)) }
      line.append(run(part, keyFont, 1))
    }
    return line
  }

  /// The same list as one run of text. The sheet is drawn glyph by glyph into a rect, so without
  /// this the one window whose whole purpose is to say what the keys are says nothing at all to
  /// anything reading the tree. The key column goes through as it is drawn rather than spelled out
  /// into words: the glyphs are what is printed on the keys, and a second table naming them is a
  /// second place for the list to be wrong.
  static func text(hotkey: String?) -> String {
    sections(hotkey: hotkey).map { heading, rows in
      ([heading] + rows.map { "\($0.0): \($0.1)" }).joined(separator: "\n")
    }.joined(separator: "\n\n")
  }

  /// The width of the widest row and the height of every row stacked: the sheet is as big as its
  /// contents and never scrolls, so this is the only size it has.
  static func size(hotkey: String?) -> CGSize {
    let sections = sections(hotkey: hotkey)
    let rows = sections.flatMap { $0.1 }
    let keyColumn = rows.map { keys($0.0).size().width }.max() ?? 0
    let textColumn = max(
      rows.map { run($0.1, textFont, 1).size().width }.max() ?? 0,
      sections.map { run($0.0, headingFont, 1).size().width }.max() ?? 0)
    let height = topPadding + padding + sections.reduce(-sectionGap) { total, section in
      total + headingHeight + headingGap + CGFloat(section.1.count) * rowHeight + sectionGap
    }
    return CGSize(width: padding * 2 + keyColumn + gap + textColumn, height: height)
  }

  /// `panel` is the sheet's own frame, which is what `size` returned. Nothing outside it is touched:
  /// dimming what is behind the sheet belongs to the caller that has something behind it.
  static func draw(in panel: CGRect, hotkey: String?) {
    let sections = sections(hotkey: hotkey)
    let keyColumn = sections.flatMap { $0.1 }.map { keys($0.0).size().width }.max() ?? 0

    let rounded = NSBezierPath(roundedRect: panel, xRadius: 10, yRadius: 10)
    // Not quite white on the light side: the sheet is read against the desktop or against the
    // overlay's dimming, and a pure white page has no edge of its own on either.
    NSColor(calibratedWhite: isDark ? 0.08 : 0.97, alpha: 0.96).setFill()
    rounded.fill()
    NSColor(calibratedWhite: isDark ? 1 : 0, alpha: 0.18).setStroke()
    rounded.lineWidth = 1
    rounded.stroke()

    var y = panel.maxY - topPadding
    for (heading, rows) in sections {
      y -= headingHeight
      // Centred over the whole panel rather than started at the key column: a heading names the
      // block under it, and the two columns beneath it have their own edges to line up on.
      let title = run(heading, headingFont, 0.45)
      title.draw(at: CGPoint(x: panel.midX - title.size().width / 2, y: y))
      y -= headingGap
      for (chord, what) in rows {
        y -= rowHeight
        let key = keys(chord)
        key.draw(at: CGPoint(x: panel.minX + padding + keyColumn - key.size().width, y: y))
        run(what, textFont, 0.8).draw(at: CGPoint(x: panel.minX + padding + keyColumn + gap, y: y))
      }
      y -= sectionGap
    }
  }
}

/// The letter a key event types, as the layout has it -- which is not where the key sits. Hints are
/// matched on this, and so is the join key: both are letters someone read off a screen or was told,
/// rather than positions the hand already knows.
/// Whether this event is a question mark. Posted key events do not all carry the shifted character
/// -- some report the letter the key sits on and leave the flags to say what was done to it -- so a
/// shifted slash is read as the same question the character would have asked.
func questionMark(_ event: CGEvent) -> Bool {
  let letter = typedLetter(event)
  return letter == "?" || (event.flags.contains(.maskShift) && letter == "/")
}

func typedLetter(_ event: CGEvent) -> String? {
  var length = 0
  var characters = [UniChar](repeating: 0, count: 4)
  event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &characters)
  guard length == 1, let scalar = Unicode.Scalar(characters[0]) else { return nil }
  return String(Character(scalar)).lowercased()
}

/// What a key event would insert into a text field: the shift and the dead-key composition kept, the
/// case kept, and any length. `typedLetter` is the other question, asked by the hints and by the
/// keys picked for the word they stand for, and it folds the case away because those match either
/// way.
func typedString(_ event: CGEvent) -> String? {
  var length = 0
  var characters = [UniChar](repeating: 0, count: 32)
  event.keyboardGetUnicodeString(maxStringLength: 32, actualStringLength: &length, unicodeString: &characters)
  guard length > 0 else { return nil }
  var string = String(utf16CodeUnits: characters, count: length)
  // A control character is a key rather than text. Tab, Home and the function keys all report one,
  // and inserting it would put a glyph nobody typed into the middle of the run.
  guard !string.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else { return nil }
  // The same repair `questionMark` makes, for the same reason: a synthesised event does not always
  // carry the shifted character, and reports the letter the key sits on with the flags left to say
  // what was done to it. Uppercasing under Shift is what the layout already did on a real press, so
  // it changes nothing there and is the whole answer for a posted one -- which is what a text
  // expander, a remote desktop and this repo's own driver all send.
  if event.flags.contains(.maskShift) { string = string.uppercased() }
  return string
}

/// Shared with the event tap callback, which is a C function pointer and cannot capture context.
final class Session {
  static var shared: Session!
  var labels: [String] = []
  var candidates: [Candidate] = []
  var typed = ""
  /// The region a hint selected, held while the mask is up and the shutter waits for Return.
  var held: Candidate?
  /// Set when the shot goes to the clipboard rather than to a file: Command-C on a held region, and
  /// Command-Control-Shift-3 on the window shot, which takes Control to mean what the system's own
  /// screenshot chord takes it to mean.
  var toClipboard = false
  /// The rectangle Command-Shift-3 ended the session for: the display under the pointer, below its
  /// menu bar, photographed with the overlay left standing so the hints are in the picture rather
  /// than composited away before it. The one capture that is of axshot rather than of the apps
  /// underneath it, and so the one whose rect is a screen rather than a region.
  var windowShot: CGRect?
  /// Where the held region sits in the candidate list, which is what the arrow keys move through.
  var heldIndex: Int?
  /// The indices left behind by each Up, so Down can walk back into the region it came from. An
  /// ascent is the only thing that records a child; stepping sideways abandons the descent, because
  /// the remembered child is no longer inside what is held.
  var descent: [Int] = []
  /// How far the shot reaches outside the held region, in points, as `+` and `-` have left it. The
  /// box came off the tree and is the element and nothing else, which is a tight crop rather than a
  /// framed one; the margin is the room back. It is a statement about how the shot should look
  /// rather than about which region it is of, so it outlives a step and a return to the hints,
  /// unlike everything else a hold carries -- the framing that was wanted for one region is
  /// generally what is wanted for the next.
  ///
  /// The picture only. The words either copy chord hands over, and the picture Shift-T reads, stay
  /// the region's own: padding that pulled in the paragraph next door would be text the region
  /// never said.
  var margin: CGFloat = 0
  /// One press of `+` or `-`. Ten points is a step that can be seen at a glance without three of
  /// them adding up to a second region around the first.
  static let marginStep: CGFloat = 10
  var chosen: Candidate?
  /// Set alongside `chosen` when Command-Shift-C ended the session: the region's text is wanted,
  /// and the shutter is not fired at all.
  var copying = false
  /// The held region's text with the line breaks joined out, once Shift-J has asked for it. Set
  /// means the joined form is on screen and is what either copy chord will hand over; it survives an
  /// arrow step and is recomputed for whatever is held next, since the question Shift-J asked was
  /// about the text and not about that one region.
  var joined: String?
  /// Where the caret sits in `joined` while Shift-E has the box open for typing, as a UTF-16 offset.
  /// Nil is the closed box, and the difference is the whole keyboard: with the box open every key
  /// that is not a chord is a character, HJKL and `?` included.
  var caret: Int?
  /// The end of the selection the caret is not on, so Shift and an arrow describe a run rather than
  /// a point. Equal to the caret is no selection, which is where every edit starts.
  var anchor = 0
  /// What the box held when Shift-E opened it, and whether that was itself typed, so Escape can put
  /// it back. There is no undo on the overlay and nowhere to hang one, and an edit that cannot be
  /// abandoned where it was made is an edit nobody starts.
  var beforeEdit: (text: String, edited: Bool)?
  /// Whether what the copy chords would hand over is something the user typed rather than something
  /// the region or the API said. It pins the text to the region it was typed over, the way a
  /// transcription is pinned to the picture it was read off: a step takes it down rather than
  /// carrying hand-typed words onto a region that never said them.
  var edited = false
  /// How long the text walk may take, which is the same budget the region walk was given.
  var budgetMs = 2000

  /// The selected run, clamped to the text there is. Empty is the plain insertion point.
  var selectedRange: NSRange {
    guard let caret, let joined else { return NSRange(location: 0, length: 0) }
    let length = (joined as NSString).length
    let low = max(0, min(min(caret, anchor), length))
    let high = max(0, min(max(caret, anchor), length))
    return NSRange(location: low, length: high - low)
  }

  /// Whether part of the box is selected, which is the one thing that changes what a copy chord
  /// means: with a run picked out, both of them hand over that run and not the box around it.
  var selecting: Bool { caret != nil && selectedRange.length > 0 }

  /// What a copy chord hands over. The selected run if there is one, the whole box if not, and
  /// nothing at all if no box is up -- in which case the caller falls back to walking the region's
  /// text, the way it did before either key existed.
  var copyText: String? {
    guard let joined else { return nil }
    guard selecting else { return joined }
    return (joined as NSString).substring(with: selectedRange)
  }
  /// What the last Shift-T read off the held region, kept while that region stays held so the key
  /// can be toggled without paying for the answer again. Dropped by a step, which changes the
  /// picture the answer was about.
  var transcription: String?
  /// Whether that answer is the thing currently on screen, as opposed to merely remembered. It is
  /// what Command-C reads to decide that a picture cannot be what the press meant.
  var transcribed = false
  /// The transcription request in flight, kept so the session can cancel it on the way out. The
  /// overlay's deadline is not the request's, and an answer that arrives after the overlay is down
  /// has nothing to draw itself on.
  var request: URLSessionTask?
  /// How long the overlay waits after hiding itself before photographing the region, so the window
  /// server has composited the mask away. The same beat the shutter takes.
  var delayMs = 60
  /// How long the mask takes to arrive, and to leave. Long enough to read as darkness closing in
  /// rather than as a flash of it, and short enough to be over before the eye has finished moving
  /// to the region it is closing in on -- a reveal much past a fifth of a second stops reading as
  /// the app answering and starts reading as the app being slow.
  ///
  /// Not gated on Reduce Motion, unlike the toast's slide: a cross-fade is what that setting asks
  /// for in place of travel, and this is already one.
  static let fadeMs = 120.0
  /// The fade in flight, if there is one. Held so a hold landing mid-release turns the darkness
  /// around from where it is rather than queueing a second ramp behind the first.
  private var fading: Timer?
  /// Set across the photograph, so a key arriving in that beat cannot start a second one.
  var photographing = false
  var cancelled = false
  /// The chord that opened this session. The tap is inserted ahead of the hotkey manager, so it
  /// sees that chord before Carbon does and a second press can close what the first opened.
  var cancelChord: Chord?
  /// Set while the shortcut list is up. It is a toggle on `?`, and while it is up every other key
  /// is swallowed rather than acted on: the list covers the hints, and a letter typed under it
  /// would hold a region the reader cannot see.
  var help = false
  /// Set when Command-comma ended the session: the overlay comes down and the settings window goes
  /// up, so the shortcut that opens preferences everywhere else reaches them from the hints too.
  var settings = false
  /// A confirmation step the run loop could not have known to wait for; it restarts the deadline.
  var deadline: Date?
  var view: HintView!
  /// The windows that were walked, front to back. A dragged region has no element of its own, so it
  /// takes the tree of the window it landed in and lets the clip do the selecting -- which is what
  /// `regionText` was already doing with every candidate it was handed. With more than one window
  /// hinted it also has to say *which*, or the outcome would name whichever app happened to be in
  /// front of a rectangle drawn over some other one.
  var windows: [(element: AXUIElement, frame: CGRect)] = []
  /// How many regions have been held, so an answer that arrives late can tell whether it is still
  /// about what is on screen. An index would not do it: a dragged region has none.
  var holds = 0
  /// The union of the screens, in the global top-left space the tree reports frames in. A drag is
  /// clamped to it: the pointer stops at the edge of the desktop, but a region translated by the
  /// space key does not.
  var screenArea = CGRect.infinite
  /// The screens one at a time, in the same space, each with the height of the menu bar strip along
  /// its own top. Half a display is a rectangle on one of them, and the union cannot say which:
  /// split down the middle it runs between two displays rather than across either. The strip is a
  /// second fact because the frame is still what says which display the pointer is on -- including
  /// while the pointer is up in the menu bar, which is exactly where a rect that had it taken out
  /// already would answer no display at all.
  var screens: [(frame: CGRect, menuBar: CGFloat)] = []
  /// Where the pointer is, in the same space -- the point the crosshair is drawn at. Kept because
  /// it is also the answer to which display a key means: it is the one thing on screen through the
  /// whole session saying where the eye is.
  var pointer = CGPoint.zero
  /// What turns a global top-left point or rect -- where a click lands, and where the tree reports
  /// frames -- into the overlay view's own coordinates: Quartz counts down from the top of the
  /// primary screen and the view counts up from the overlay's own corner.
  var flipBase: CGFloat = 0
  var overlayOrigin = CGPoint.zero
  /// The corner the drag started from and the corner under the pointer, in global top-left
  /// coordinates; nil means no button is down. Space moves the two together, which is what locks
  /// the size while the region is being placed.
  var dragAnchor: CGPoint?
  var dragPoint = CGPoint.zero
  /// Where the pointer was at the previous drag event, which is what a translation is measured
  /// against: space moves the region by however far the mouse moved, not to where the mouse now is.
  var dragLast = CGPoint.zero

  func key(_ event: CGEvent) {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    // Escape, which the shortcut list takes first: a panel is dismissed by it before the thing
    // behind the panel is, and a sheet opened to read is not a session anybody meant to abandon.
    if keyCode == 53 {  // escape
      // The innermost thing first: a rectangle still being drawn, then a sheet opened over the
      // session, and only then the session itself.
      if dragAnchor != nil { cancelDrag(); return }
      if help { help = false; refresh(); return }
      // An open box is dismissed before the session under it, for the same reason the sheet above
      // is: the key that abandons an edit is the key everything else abandons an edit with, and a
      // session nobody meant to end is a worse thing to lose than a line of retyping.
      if caret != nil { abandonEdit(); return }
      cancelled = true
      CFRunLoopStop(CFRunLoopGetCurrent())
      return
    }
    // The hotkey again, at any point: a press that turned out to be a mistake is undone by
    // repeating it, without the hand having to find Escape. This has to come before the Command
    // branch below, which would otherwise swallow a chord carrying Command and do nothing with it.
    if let chord = cancelChord, keyCode == Int64(chord.keyCode),
       carbonModifiers(event.flags) == chord.modifiers {
      cancelled = true
      CFRunLoopStop(CFRunLoopGetCurrent())
      return
    }
    // A drag owns the keyboard while the button is down, ahead of the box: a press puts the box
    // away, so nothing typed mid-drag was meant for it. The two keys above are the only ones that
    // mean anything to a drag -- and space, which the drag reads off the hardware on its way past
    // rather than being handed here.
    if dragAnchor != nil { return }
    // The open box is asked before everything below it, and it answers Command keys too -- the
    // arrows, the deletes and Command-A are a field's. `ownedByField` is where the line is drawn.
    if ownedByField(event) { edit(event); return }
    // The shortcut list, in either state and before everything below it, since what it draws
    // covers the keys the rest of this reads. `?` as the layout types it rather than the key Shift
    // and slash sit on, for the same reason Shift-J is a letter: it was picked for what it means.
    if help {
      if questionMark(event) { help = false; refresh() }
      return
    }
    if questionMark(event) {
      help = true
      deadline = Date().addingTimeInterval(30)
      refresh()
      return
    }
    // The two chords that end a hold, and nothing else: every other chord under Command is
    // swallowed rather than acted on, since the tap reports "c" whether or not Command was down
    // with it and an unfiltered Command-C would otherwise be typed at the hints as a plain letter.
    if event.flags.contains(.maskCommand) {
      // Settings are reachable whether or not a region is held: the overlay is in the way of the
      // only other route to them, and what a shortcut needs changing for is usually on screen.
      if keyCode == 43 {  // comma
        settings = true
        cancelled = true
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
      }
      // The system's own two screenshot chords, borrowed for the one shot the overlay is in:
      // Shift-3 files it, Control-Shift-3 puts it on the clipboard, which is what each does off the
      // overlay. Held region or not -- what the picture is of is the window and everything axshot
      // has drawn on it. The key at 3's position rather than the character the layout types there,
      // which is how macOS reads the chord this is quoting: a place the hand knows, not a word.
      if keyCode == 20 {  // 3
        let modifiers = carbonModifiers(event.flags)
        // Exactly those modifiers and no others: a fourth one is a chord somebody meant elsewhere.
        guard modifiers == UInt32(cmdKey | shiftKey) || modifiers == UInt32(cmdKey | controlKey | shiftKey)
        else { return }
        // The display under the pointer and the strip below its menu bar, both for the reasons the
        // half-display key takes them: the crosshair is what says which screen a key means, and no
        // window is drawn in that strip, so nothing the hints are on can be lost with it.
        guard let screen = screens.first(where: { $0.frame.contains(pointer) }) ?? screens.first
        else { NSSound.beep(); return }
        let top = screen.frame.minY + screen.menuBar
        windowShot = CGRect(x: screen.frame.minX, y: top,
                            width: screen.frame.width, height: screen.frame.maxY - top)
        toClipboard = modifiers & UInt32(controlKey) != 0
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
      }
      // Half the display, which is a region the tree never describes and a drag never gets exactly
      // right: a window tiled to one side, a video beside the notes about it, either half of a
      // comparison. It holds whatever is already held out of the way, the way a drag does, and what
      // it holds is a rectangle rather than an element -- so the arrows beep at it and Delete goes
      // back to the hints, as they do for one drawn by hand.
      if event.flags.contains(.maskAlternate), keyCode == 123 || keyCode == 124 {
        half(left: keyCode == 123)
        return
      }
      guard let region = held, keyCode == 8 else { return }  // c
      // Both ends go to the clipboard, which is why they are the same letter; Shift asks for the
      // words rather than a picture of them. With either text box on screen the bare chord asks for
      // them too: the words are what is being looked at, the box is opaque and the region is not
      // visible behind it, and a picture would carry what the box is drawn over rather than what was
      // asked for. One condition covers both, since a transcription is held in the same field a join
      // is.
      if event.flags.contains(.maskShift) || joined != nil { copying = true } else { toClipboard = true }
      chosen = region
      CFRunLoopStop(CFRunLoopGetCurrent())
      return
    }
    if held != nil {
      if keyCode == 36 || keyCode == 76 {  // return, keypad enter
        chosen = held
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
      }
      // Shift-J before the arrows, which is where a bare J means Down. It is read as the letter the
      // layout types rather than as the key at J's position, unlike the HJKL beneath it: those are
      // a hand shape, and this is a word.
      if event.flags.contains(.maskShift), typedLetter(event) == "j" { join(); return }
      // Shift-T beside it, and read as a letter for the same reason: J joins the words the tree
      // already has, T reads the ones only the pixels have.
      if event.flags.contains(.maskShift), typedLetter(event) == "t" { transcribe(); return }
      // Shift-E on whatever those two put in the box. A letter again, and for the third time the
      // same reason: it is the word, not the key the word starts on.
      if event.flags.contains(.maskShift), typedLetter(event) == "e" { beginEdit(); return }
      // The margin, before the arrows and the delete: `+` and `-` frame the shot without changing
      // which region it is of. Read as the characters the layout types rather than as the keys they
      // sit on, for the reason Shift-J is -- arithmetic is a word, not a hand shape.
      //
      // Both characters a key can type count, so Shift is neither asked for nor refused. `+` is
      // Shift-`=` on most layouts, and a hand holding Shift for it finds `-` typing `_`: the two
      // keys are pressed one after the other, adjusting the same number in either direction, and a
      // pair where one wants Shift and the other refuses it cannot be alternated without letting go
      // between presses. Taking all four characters is also what answers a synthesised Shift-`=`,
      // which carries the flag without always carrying the shifted character.
      switch typedLetter(event) ?? "" {
      case "+", "=": widen(by: Self.marginStep); return
      case "-", "_": widen(by: -Self.marginStep); return
      default: break
      }
      if keyCode == 51 { release() }  // delete, back to the hints
      // The screen steps read the rectangle that is held and nothing else, so they are in front of
      // the guard below: a dragged region and a half display are boxes on the screen like any other,
      // and which way is a question a box answers without a place in the tree.
      if !event.flags.contains(.maskAlternate), let region = held {
        switch keyCode {
        case 123, 4: leap(from: region.rect, dx: -1, dy: 0); return  // left, h
        case 124, 37: leap(from: region.rect, dx: 1, dy: 0); return  // right, l
        case 126, 40: leap(from: region.rect, dx: 0, dy: -1); return  // up, k
        case 125, 38: leap(from: region.rect, dx: 0, dy: 1); return  // down, j
        default: break
        }
      }
      guard let index = heldIndex else {
        // The tree steps are the ones a region outside the candidate list has nothing for: no line
        // of ancestors to widen along and no sibling to step to. Delete goes back to the hints,
        // which is where the tree is.
        if [123, 124, 125, 126, 4, 37, 40, 38].contains(keyCode) { NSSound.beep() }
        return
      }
      switch keyCode {
      case 123, 4: step(from: index, by: -1)  // left, h
      case 124, 37: step(from: index, by: 1)  // right, l
      case 126, 40: ascend(from: index)  // up, k
      case 125, 38: descend()  // down, j
      default: break
      }
      return
    }
    // An arrow with nothing held enters the screen rather than being ignored, at the largest region
    // on it: these steps reach every other region from anywhere, crossing the window boundary the
    // tree steps stop at, so what the entry point owes is somewhere to start reading rather than a
    // root. By area and not by document order -- with the window's own box no longer a region, the
    // first of them is whatever the front window's layout begins with, as often a sidebar as
    // anything worth capturing. A partly covered window's boxes are the cropped ones, so the
    // largest is in the window in front without that having to be asked for.
    if [123, 124, 125, 126].contains(keyCode) {
      guard let largest = candidates.indices.max(by: { candidates[$0].area < candidates[$1].area })
      else { NSSound.beep(); return }
      typed = ""
      descent = []
      hold(largest)
      return
    }
    if keyCode == 51 {  // delete
      if !typed.isEmpty { typed.removeLast(); refresh() }
      return
    }
    guard let typedCharacter = typedLetter(event) else { return }

    let attempt = typed + typedCharacter
    guard labels.contains(where: { $0.hasPrefix(attempt) }) else { NSSound.beep(); return }
    typed = attempt
    if let index = labels.firstIndex(of: typed) {
      descent = []
      hold(index)
      return
    }
    refresh()
  }

  /// Bring the mask in around `rect`, or move it there if it is already up. A hold that follows
  /// another -- every arrow step -- only moves it: the darkness is on screen and being looked at,
  /// and re-fading it under each step would blink the thing the steps exist to compare.
  func showMask(_ rect: CGRect) {
    if view.mask == nil { view.mask = (rect, 0) } else { view.mask?.rect = rect }
    fade(to: 1)
  }

  /// Put the mask exactly here, or take it away, with no fade either way. What the hand is drawing
  /// is not animated: a dragged rectangle is direct manipulation, and darkness ramping in behind the
  /// pointer would trail the corner it is being drawn from. The fade belongs to the mask that
  /// arrives on a keystroke, which has nothing on screen already saying where it will land.
  func drawMask(_ rect: CGRect?) {
    stopFade()
    if let rect { view.mask = (rect, 1) } else { view.mask = nil }
  }

  /// Take it off again. The rect stays where it is: it is what the darkness is still drawn around
  /// for the length of the fade, after the region it came from has been let go of.
  func hideMask() { fade(to: 0) }

  /// Ramp the mask to `level` and stop there. Timed from where the darkness actually is rather than
  /// from the end it set out from, so a hold interrupting a release finishes sooner than one
  /// starting from a clear screen: at a fixed duration the same keystroke would take the same time
  /// to show a fifth of a fade as a whole one.
  private func fade(to level: CGFloat) {
    fading?.invalidate()
    fading = nil
    guard let from = view.mask?.level, from != level else {
      // Gone rather than transparent: a mask at zero still answers `if let mask`, and a fade asked
      // to end where it already is has nothing to run but the tidying up.
      if level == 0 { view.mask = nil; view.needsDisplay = true }
      return
    }
    let start = Date()
    let span = Self.fadeMs / 1000 * Double(abs(level - from))
    fading = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] timer in
      guard let self else { timer.invalidate(); return }
      let progress = min(1, Date().timeIntervalSince(start) / span)
      // Assigned outright at the end rather than interpolated up to it: a ramp between two decimals
      // lands its last step a hair off, and exactly 1 is what says the mask is all the way in.
      self.view.mask?.level = progress < 1 ? from + (level - from) * CGFloat(progress) : level
      if progress >= 1 {
        timer.invalidate()
        self.fading = nil
        if level == 0 { self.view.mask = nil }
      }
      self.view.needsDisplay = true
    }
  }

  /// Stop whatever fade is turning, on the way out. A repeating timer outlives the session that
  /// scheduled it: the run loop holds it, the overlay it redraws has been ordered out, and nothing
  /// else ever ends it. The shutter exits are the ones that leave one in flight -- Return pressed
  /// inside the tenth of a second the mask was still arriving in.
  func stopFade() {
    fading?.invalidate()
    fading = nil
  }

  /// Take the mask off and wait for it to go. Only for the exits that end in nothing: an exit on
  /// its way to a photograph is already waiting out a beat for the window server, and a fade in
  /// front of that is either a delay on the shot or a half-lit mask inside it.
  func fadeOutMask() {
    hideMask()
    // The tap is down by the time this runs, so the keys arriving during the fade go where the
    // session is no longer in the way of. Bounded rather than run until the mask clears: this
    // turns the run loop, and a fade that somehow never finished would hold the app in it.
    let deadline = Date().addingTimeInterval(Self.fadeMs / 1000 + 0.1)
    while view.mask != nil && Date() < deadline {
      CFRunLoopRunInMode(.defaultMode, 1 / 60, false)
    }
  }

  /// The held region with the margin `+` and `-` have left around it, stopped at the edges of the
  /// screens: past those there is nothing to photograph. In the tree's own coordinates, which is
  /// what both callers want -- the shutter aims in them, and the mask is drawn from `viewRect` of
  /// this rather than from an outset applied a second time in the view's.
  func framed(_ rect: CGRect) -> CGRect {
    rect.insetBy(dx: -margin, dy: -margin).intersection(screenArea)
  }

  /// Hold this candidate: mask around it, and restart the deadline, since every hold is a decision
  /// the run loop could not have known to wait for.
  func hold(_ index: Int) { hold(candidates[index], at: index) }

  /// The same for a region that came off the mouse rather than out of the tree, which is why the
  /// index is optional: a dragged rectangle has no place in the candidate list for the arrows to
  /// step from. Its rect is put into view coordinates by the arithmetic that built `view.boxes`
  /// rather than read back out of them, that being the only one a custom region has.
  func hold(_ candidate: Candidate, at index: Int?) {
    holds += 1
    held = candidate
    heldIndex = index
    let rect = viewRect(framed(candidate.rect))
    view.selection = rect
    showMask(rect)
    view.notice = nil
    caret = nil
    anchor = 0
    beforeEdit = nil
    // A join follows the step and is recomputed, because the question it asked was about the text
    // and not about that one region. A transcription and an edit do not: one was read off a picture
    // this is no longer of, and the other was typed over words this region never said.
    if transcribed || transcription != nil || edited {
      transcribed = false
      transcription = nil
      edited = false
      joined = nil
    } else if joined != nil {
      joined = regionText(candidate, budgetMs: budgetMs, separator: " ")
    }
    deadline = Date().addingTimeInterval(30)
    refresh()
  }

  /// A global top-left point -- the space the mouse is reported in -- in the overlay view's own
  /// bottom-left coordinates.
  func viewPoint(_ point: CGPoint) -> CGPoint {
    CGPoint(x: point.x - overlayOrigin.x, y: flipBase - point.y - overlayOrigin.y)
  }

  /// A global top-left rect -- the space the tree reports frames in, and the space the mouse is
  /// reported in -- in the overlay view's own bottom-left coordinates.
  func viewRect(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX - overlayOrigin.x, y: flipBase - rect.maxY - overlayOrigin.y,
           width: rect.width, height: rect.height)
  }

  /// The rectangle between the two corners, clamped to the desktop: a region translated off the
  /// edge would otherwise ask for a photograph of pixels that are not there.
  var dragRect: CGRect {
    guard let anchor = dragAnchor else { return .null }
    let box = CGRect(x: min(anchor.x, dragPoint.x), y: min(anchor.y, dragPoint.y),
                     width: abs(dragPoint.x - anchor.x), height: abs(dragPoint.y - anchor.y))
    return box.intersection(screenArea)
  }

  /// The pointer, which the crosshair and its numbers follow. Watched rather than taken: the tap
  /// only wants to know where the mouse is, and an app that lights a button up under the mask has
  /// changed nothing about the region or the tree.
  func moved(_ event: CGEvent) {
    guard !help, !photographing else { return }
    updatePointer(event.location)
  }

  /// Move the crosshair and the readout under it. Both are drawn into the overlay rather than being
  /// a cursor, since the cursor belongs to the active application and this app is never that.
  func updatePointer(_ point: CGPoint) {
    pointer = point
    view.movePointer(to: viewPoint(point),
                     label: "\(Int(point.x.rounded())), \(Int(point.y.rounded()))")
  }

  /// The left button, for the regions the tree has no box for. It is swallowed as completely as the
  /// keyboard is and for the same reason: a click that reached the window underneath would press
  /// whatever it landed on, or raise something over the target, and the shot would be of a screen
  /// the session itself had changed.
  func drag(_ type: CGEventType, _ event: CGEvent) {
    // Not under the shortcut sheet, which covers the hints and would be dragged over blind, and not
    // across the beat the transcribe shutter takes.
    guard !help, !photographing else { return }
    let point = event.location
    // The button moves the pointer as surely as a bare move does, and a drag is exactly when the
    // numbers are being watched.
    updatePointer(point)
    switch type {
    case .leftMouseDown:
      // A press replaces whatever was held, mask and all: a region is being drawn, and the old one
      // is what the press was aimed past. Nothing is drawn until the rectangle has a size.
      if held != nil { release() }
      typed = ""
      dragAnchor = point
      dragPoint = point
      dragLast = point
      view.selection = nil
      drawMask(nil)
      deadline = Date().addingTimeInterval(30)
      refresh()
    case .leftMouseDragged:
      guard let anchor = dragAnchor else { return }
      // Space is read off the hardware rather than out of a key event, because a lock that ends
      // when the key comes up would need key-ups tapped and the tap deliberately does not take
      // those -- a swallowed key-up leaves the hotkey manager believing the chord that opened the
      // session is still held. Nothing has to happen the instant it goes down or up, either: a
      // locked size only shows once the mouse moves, so the drag can ask on its way past.
      //
      // `.hidSystemState` and not `.combinedSessionState`: the session state is what is left after
      // the taps have had the stream, and this session's own tap swallows every key-down there is,
      // so the space it would be asked about is the one it just ate. Measured, not reasoned about
      // -- with a session up the same press reads true off the hardware and false off the session.
      if CGEventSource.keyState(.hidSystemState, key: 49) {  // space
        // By however far the mouse moved rather than to where it now is: both corners travel, so
        // the size is untouched, and letting go of space resumes sizing from the corner as it now
        // sits rather than from where it was put down.
        dragAnchor = CGPoint(x: anchor.x + point.x - dragLast.x, y: anchor.y + point.y - dragLast.y)
        dragPoint = CGPoint(x: dragPoint.x + point.x - dragLast.x, y: dragPoint.y + point.y - dragLast.y)
      } else {
        dragPoint = point
      }
      dragLast = point
      let rect = dragRect
      let drawn = rect.isNull || rect.isEmpty ? nil : viewRect(rect)
      view.selection = drawn
      drawMask(drawn)
      deadline = Date().addingTimeInterval(30)
      refresh()
    case .leftMouseUp:
      guard dragAnchor != nil else { return }
      let rect = dragRect
      dragAnchor = nil
      // A press and release that went nowhere is a click, and a click is not a region: the hints
      // come back rather than a few pixels nobody meant to select being held.
      // Front to back, so a rectangle over two windows belongs to the one drawn on top -- which is
      // the one whose pixels it is about to photograph.
      let landed = windows.firstIndex { $0.frame.intersects(rect) }
      guard let landed, !rect.isNull, rect.width >= minimumDrag, rect.height >= minimumDrag else {
        view.selection = nil
        drawMask(nil)
        refresh()
        return
      }
      hold(Candidate(element: windows[landed].element, role: "custom", subrole: "", label: "", rect: rect, depth: 0, childCount: 0, window: landed), at: nil)
    default: break
    }
  }

  /// Abandon a rectangle half-drawn, leaving the hints as they were.
  func cancelDrag() {
    dragAnchor = nil
    view.selection = nil
    drawMask(nil)
    refresh()
  }

  /// Hold half a display, left or right. The pointer says which display: the crosshair is on screen
  /// for the whole session saying where it is, and it is the only thing that is -- the held region
  /// is one of the things this key replaces, and the frontmost window can be on a screen nobody is
  /// looking at.
  ///
  /// It starts below the menu bar. No ordinary window is ever drawn up there, so the strip is the
  /// one part of a display that cannot hold any of what the half was reached for, and it is the
  /// same clock and the same icons in every shot that keeps it. The Dock stays, and the difference
  /// is not which of the two is furniture: the Dock floats over the window rather than beside it,
  /// so the band it sits in holds window pixels and taking it out would cut a strip out of the
  /// picture. Where the menu bar is hidden there is nothing to take out, and the half runs to the
  /// top of the display -- the strip is measured off the screen rather than assumed.
  func half(left: Bool) {
    // Neither list can be empty inside a session -- there is no overlay without a screen to draw it
    // on, and no session without a window to hint -- but both are indexed below.
    guard let screen = screens.first(where: { $0.frame.contains(pointer) }) ?? screens.first,
          !windows.isEmpty else { NSSound.beep(); return }
    // Split on a whole point, with the right half taking exactly what the left one left: on an odd
    // width the two would otherwise overlap by a point, or leave one between them uncaptured.
    let split = (screen.frame.width / 2).rounded()
    let top = screen.frame.minY + screen.menuBar
    let rect = CGRect(x: left ? screen.frame.minX : screen.frame.minX + split, y: top,
                      width: left ? split : screen.frame.width - split,
                      height: screen.frame.maxY - top)
    // Front to back, so the words come from the window drawn on top of that half -- the same
    // question a drag asks of a rectangle. A half with no window on it at all is a picture of the
    // desktop, which is worth taking and has no text in it: the front window stands in, and its
    // tree clipped to a rectangle it is nowhere near yields nothing, which is the honest answer.
    let landed = windows.firstIndex { $0.frame.intersects(rect) } ?? 0
    typed = ""
    descent = []
    hold(Candidate(element: windows[landed].element, role: "custom", subrole: "", label: "",
                   rect: rect, depth: 0, childCount: 0, window: landed), at: nil)
  }

  /// Show the held region's text as one run of prose, or take it back down. A toggle rather than a
  /// mode with its own exit: what it draws covers the region it describes, so the way back to the
  /// picture is the key that covered it.
  func join() {
    guard let region = held else { return }
    if joined != nil {
      joined = nil
    } else {
      let text = regionText(region, budgetMs: budgetMs, separator: " ")
      guard !text.isEmpty else { NSSound.beep(); return }
      joined = text
      openBox()
    }
    deadline = Date().addingTimeInterval(30)
    refresh()
  }

  /// A click on the text box, arriving through the tap rather than through the window. The overlay
  /// ignores the mouse the way it ignores focus, and it has to: a window that accepted a click would
  /// activate the app and redraw the target's title bar inactive, which is the picture every other
  /// decision here is arranged not to take. The tap sees the press before any window does, so the
  /// box can answer it without the app ever becoming the thing that was clicked.
  ///
  /// Returns whether the click was the box's. Only ever while one is on screen; everywhere else the
  /// button draws a region. With a box up the whole overlay takes them, because a click that missed
  /// the box by a few points would otherwise start a rectangle over the words being read.
  func mouse(_ event: CGEvent, type: CGEventType) -> Bool {
    guard let text = joined, view.notice == nil, !photographing else { return false }
    let string = text as NSString
    let point = CGPoint(x: event.location.x - overlayOrigin.x,
                        y: (flipBase - event.location.y) - overlayOrigin.y)
    switch type {
    case .leftMouseDown:
      guard let offset = view.offset(at: point) else { return true }
      // A click opens the box as well as aiming it. Shift-E is the key that says "correct this",
      // but a person who can see a field reaches for the mouse first, and a click that placed a
      // caret in a box that was not listening would be the worst of both.
      if caret == nil { beforeEdit = (text, edited) }
      caret = offset
      anchor = offset
      // Twice for the run between the spaces either side, three times for the lot. Whitespace
      // rather than word boundaries: what is in the box is being trimmed rather than written, and
      // the thing being cut out is generally a stamp or a label that carries its own punctuation.
      switch event.getIntegerValueField(.mouseEventClickState) {
      case 2:
        let before = string.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards,
                                             range: NSRange(location: 0, length: offset))
        let after = string.rangeOfCharacter(from: .whitespacesAndNewlines,
                                            range: NSRange(location: offset, length: string.length - offset))
        anchor = before.location == NSNotFound ? 0 : NSMaxRange(before)
        caret = after.location == NSNotFound ? string.length : after.location
      case let repeated where repeated >= 3:
        anchor = 0
        caret = string.length
      default: break
      }
    case .leftMouseDragged:
      guard caret != nil, let offset = view.offset(at: point) else { return true }
      caret = offset
    default:
      return true
    }
    deadline = Date().addingTimeInterval(30)
    refresh()
    return true
  }

  /// Put the caret in the box, at the start and selecting nothing. At the start rather than at the
  /// end a field would use, because the box is read before it is typed in: the run is put on screen
  /// to be checked against the region under it, and the eye starts where the words do. Selecting
  /// nothing, since a box that came up with everything selected would be one keystroke from losing
  /// all of it.
  ///
  /// Called the moment either key fills the box, so what is drawn is a field from the first frame:
  /// a box that showed the words and ignored the keyboard until a second key was found is a box that
  /// does not answer the first thing tried on it.
  ///
  /// Nothing else on the overlay reads the keyboard while it is open. That is the price of it, and
  /// the way back out is Escape: the box stays drawn and unfocused, the arrows step regions again,
  /// and a second Escape ends the session.
  func openBox() {
    guard joined != nil else { return }
    if let text = joined, caret == nil { beforeEdit = (text, edited) }
    caret = 0
    anchor = 0
  }

  /// Put the caret back after an Escape. Only ever on text that is already on screen: there is
  /// nothing to correct before Shift-J or Shift-T has put something in the box, and a notice is the
  /// app talking rather than the region.
  func beginEdit() {
    guard joined != nil, view.notice == nil, request == nil else { NSSound.beep(); return }
    openBox()
    deadline = Date().addingTimeInterval(30)
    refresh()
  }

  /// Take the caret out of the box and put back what the region or the API said. One key does both
  /// because they are one thing: an edit made in the place the original is still on screen beside it
  /// should be abandonable there too, and there is no undo on an overlay to abandon it with
  /// otherwise. What is left behind is the box as Shift-J drew it, unfocused -- the arrows step
  /// regions again, Shift-J takes it down, and a second Escape ends the session.
  func abandonEdit() {
    if let before = beforeEdit {
      joined = before.text
      edited = before.edited
    }
    caret = nil
    anchor = 0
    beforeEdit = nil
    deadline = Date().addingTimeInterval(30)
    refresh()
  }

  /// One keystroke into the open box. What a one-line field does and nothing beyond it: no
  /// selection, no undo past Escape, and no clipboard of its own -- the two chords that end a hold
  /// are the clipboard, and handing them a corrected run is the whole point of the box being open.
  /// Where a word ends, or begins, from here. Foundation's own word enumeration rather than a scan
  /// invented in this file, so "one word" means what it means in every other field on the machine
  /// -- including in the places a run of punctuation is not one.
  func wordBoundary(_ string: NSString, from offset: Int, forward: Bool) -> Int {
    var landing = forward ? string.length : 0
    let range = forward ? NSRange(location: offset, length: string.length - offset)
                        : NSRange(location: 0, length: offset)
    guard range.length > 0 else { return landing }
    string.enumerateSubstrings(in: range,
                               options: forward ? [.byWords] : [.byWords, .reverse]) { _, word, _, stop in
      let edge = forward ? NSMaxRange(word) : word.location
      guard forward ? edge > offset : edge < offset else { return }
      landing = edge
      stop.pointee = true
    }
    return landing
  }

  /// Whether the open box takes this key, or whether the session does. Everything unmodified is the
  /// field's -- `?` and the letters the arrows share included, since a field that ate its own
  /// question mark to draw a shortcut list would be the one place on the overlay where typing does
  /// not type. Under Command it is the keys a field is expected to own: the arrows and the deletes,
  /// which carry their usual far-and-wide meanings, and Command-A. What the session keeps is the two
  /// chords that end a hold and the one that opens settings -- a Command-C aimed at the clipboard is
  /// not a keystroke a text box should swallow.
  func ownedByField(_ event: CGEvent) -> Bool {
    guard caret != nil else { return false }
    switch event.getIntegerValueField(.keyboardEventKeycode) {
    // Return is the shutter and stays the shutter. A field would commit on it, but there is nothing
    // here for a commit to mean: everything you would do after closing the box either discards the
    // edit anyway -- a step, a Shift-J -- or works perfectly well with it open, which the copy
    // chords do. What is left is Return, and making the app's oldest key a second press to reach
    // would be paying for a state nobody needs.
    case 36, 76: return false
    // The keys a field owns however they are modified: the letter A so Command-A selects, the two
    // deletes, and the arrows.
    case 0, 51, 117, 123, 124, 125, 126: return true
    // Everything else is the field's only unmodified. What Command keeps is the two chords that end
    // a hold and the one that opens settings -- a Command-C aimed at the clipboard is not a
    // keystroke a text box should swallow.
    default: return !event.flags.contains(.maskCommand)
    }
  }

  /// One keystroke into the open box. What a field does, and the modifiers mean on the arrows and
  /// the deletes what they mean everywhere else: Option or Control a word, Command the ends of the
  /// drawn line, Shift with any of them selecting rather than moving. None of it comes for free --
  /// AppKit's key bindings arrive through the responder chain, and this box is never in one, because
  /// a window that took the keyboard would take the focus with it and photograph the target with its
  /// title bar greyed out. So the bindings are spelled out here, over Foundation's word boundaries
  /// and the layout manager's lines, rather than reinvented on top of a character scan.
  func edit(_ event: CGEvent) {
    guard let caret, let text = joined else { return }
    let string = text as NSString
    let selection = selectedRange
    let flags = event.flags
    let extending = flags.contains(.maskShift)
    // Option is the macOS habit and Control the one people bring with them; both mean a word here,
    // since neither has anything else to mean inside a box that has the whole keyboard anyway.
    let byWord = flags.contains(.maskAlternate) || flags.contains(.maskControl)
    let toEnd = flags.contains(.maskCommand)
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    // Restarted on every keystroke, the way a hold is. Retyping a sentence takes longer than
    // reading one, and the run loop had no way to know it was being asked to wait for that.
    defer { deadline = Date().addingTimeInterval(30) }

    func caretAndAnchor(_ offset: Int) {
      self.caret = offset
      anchor = offset
    }
    /// Put the caret somewhere, dropping the selection unless Shift is asking to keep the far end.
    func move(to offset: Int) {
      self.caret = offset
      if !extending { anchor = offset }
    }
    /// Replace the selected run, or insert at the caret when nothing is selected. Both are the same
    /// operation on a range, which is why a typed character and a Delete over a selection agree
    /// about what they take out.
    func replace(_ range: NSRange, with insert: String) {
      joined = string.replacingCharacters(in: range, with: insert)
      caretAndAnchor(range.location + (insert as NSString).length)
      edited = true
    }
    /// Where an arrow lands, given what is held with it. Vertical Command and Option go to the ends
    /// of the whole run rather than of a line: the box holds one paragraph, so there is no third
    /// distance for them to mean.
    func destination(_ keyCode: Int64) -> Int {
      switch keyCode {
      case 123:  // left
        if toEnd { return view.lineBounds(around: caret)?.location ?? 0 }
        if byWord { return wordBoundary(string, from: caret, forward: false) }
        return caret > 0 ? string.rangeOfComposedCharacterSequence(at: caret - 1).location : 0
      case 124:  // right
        if toEnd { return view.lineBounds(around: caret).map { NSMaxRange($0) } ?? string.length }
        if byWord { return wordBoundary(string, from: caret, forward: true) }
        return caret < string.length ? NSMaxRange(string.rangeOfComposedCharacterSequence(at: caret)) : string.length
      case 126:  // up
        return toEnd || byWord ? 0 : (view.verticalOffset(from: caret, down: false) ?? 0)
      default:  // down
        return toEnd || byWord ? string.length : (view.verticalOffset(from: caret, down: true) ?? string.length)
      }
    }
    switch keyCode {
    case 0 where toEnd:  // command-a
      anchor = 0
      self.caret = string.length
    case 51:  // delete
      // A selection is what the key takes out when there is one; otherwise it takes out whatever the
      // matching arrow would have moved over, which is what makes Option-Delete a word and
      // Command-Delete the start of the line without either being spelled out twice.
      if selection.length > 0 { replace(selection, with: ""); break }
      let from = destination(123)
      guard from < caret else { NSSound.beep(); return }
      replace(NSRange(location: from, length: caret - from), with: "")
    case 117:  // forward delete
      if selection.length > 0 { replace(selection, with: ""); break }
      let to = destination(124)
      guard to > caret else { NSSound.beep(); return }
      replace(NSRange(location: caret, length: to - caret), with: "")
    case 123, 124, 125, 126:  // the arrows
      // A plain horizontal arrow over a selection collapses to the end it points at rather than
      // stepping one character from the caret, which is what every other field does with it. A
      // modified one moves off that end instead, which is also what they do.
      if selection.length > 0, !extending, !byWord, !toEnd, keyCode == 123 || keyCode == 124 {
        caretAndAnchor(keyCode == 123 ? selection.location : NSMaxRange(selection))
        break
      }
      move(to: destination(keyCode))
    default:
      guard !toEnd, let typed = typedString(event) else { return }
      replace(selection.length > 0 ? selection : NSRange(location: caret, length: 0), with: typed)
    }
    refresh()
  }

  /// Read the held region's words off its pixels, for the regions the tree has none for -- a canvas,
  /// a PDF, a terminal, a screenshot of a table. The answer lands in the same box Shift-J draws in,
  /// because it answers the same question; a second press takes it back down, as with Shift-J.
  ///
  /// The overlay stays on screen for the photograph and is drawn bare instead. The mask never
  /// covered the region, but the corner brackets are drawn inside it and the text box over it, and
  /// either would be transcribed as though the app had written them there.
  func transcribe() {
    guard let region = held else { return }
    // What the answer is about, so a region held after it was asked for -- stepped to, or drawn --
    // can tell that the answer is no longer its own.
    let token = holds
    // Off, back on, off again, all without asking twice. The answer is kept for as long as the
    // region is held, so the toggle costs nothing after the first press; only a region that has
    // never been read sends a picture anywhere.
    if transcribed || view.notice != nil {
      transcribed = false
      joined = nil
      view.notice = nil
      request?.cancel()
      request = nil
      deadline = Date().addingTimeInterval(30)
      refresh()
      return
    }
    if let transcription {
      joined = transcription
      transcribed = true
      openBox()
      deadline = Date().addingTimeInterval(30)
      refresh()
      return
    }
    guard request == nil, !photographing else { return }

    // Drawn bare rather than ordered out, so the mask never leaves the screen: the region goes
    // straight from selected to transcribed, the way Shift-J does, instead of unmasking for the
    // length of a screencapture and coming back.
    //
    // Slept rather than run: this is inside the tap callback, and re-entering the run loop here
    // would deliver the next key event on top of a half-finished one -- a second Shift-T inside the
    // beat the compositor is being given would photograph a region with the brackets half off. The
    // window server does the compositing on its own thread, so it does not need ours turning.
    photographing = true
    defer { photographing = false }
    view.bare = true
    view.display()
    CATransaction.flush()
    Thread.sleep(forTimeInterval: Double(delayMs) / 1000)
    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("axshot-transcribe.png")
    // The region's own box rather than the framed one, whatever the margin is: padding is room
    // around the picture, and the words standing in it belong to whatever the region sits next to.
    let captured = capture(region.rect, to: path)
    view.bare = false
    let png = captured ? FileManager.default.contents(atPath: path) : nil
    try? FileManager.default.removeItem(atPath: path)
    guard let png else {
      view.notice = CGPreflightScreenCaptureAccess() ? "Could not photograph the region" : "Screen Recording is not granted"
      NSSound.beep()
      deadline = Date().addingTimeInterval(30)
      refresh()
      return
    }

    view.notice = "Transcribing..."
    // Generous, and restarted again when the answer lands: the request has its own timeout, and a
    // hold that expired underneath a call in flight would take the overlay down mid-sentence.
    deadline = Date().addingTimeInterval(90)
    refresh()
    request = transcribeImage(png) { [weak self] text, failure in
      DispatchQueue.main.async {
        // The held region can have moved on under an arrow while the call was out; the answer is
        // about the picture that was taken, so it is dropped rather than drawn over a different box.
        guard let self, !self.cancelled, self.chosen == nil, self.holds == token else { return }
        self.request = nil
        self.view.notice = nil
        if let text {
          self.transcription = text
          self.joined = text
          self.transcribed = true
          self.openBox()
        } else {
          self.view.notice = "Transcription failed (\(failure ?? "unknown"))"
          NSSound.beep()
        }
        self.deadline = Date().addingTimeInterval(30)
        self.refresh()
      }
    }
  }

  /// The next region off the held one's direct line: its siblings, cousins, uncles and nephews, in
  /// document order. Anything on the line is what Up and Down are for, and stepping onto it would
  /// spend a keystroke on the same region drawn bigger or smaller. The walk is pre-order, so a
  /// candidate's descendants are exactly the run that follows it while the depth stays greater, and
  /// its ancestors are the entries before it that keep setting a new shallowest depth.
  ///
  /// It stops at the window it started in, as all three tree steps do. Document order across two
  /// windows says only which was in front, and a key that walks a tree should not step out of the
  /// tree to a region somewhere else on the screen -- the unmodified arrows are how another window
  /// is reached from a held region, and the hints are how it is reached from nothing.
  func step(from index: Int, by offset: Int) {
    let window = candidates[index].window
    let depth = candidates[index].depth
    var shallowest = depth
    var next = index + offset
    while candidates.indices.contains(next), candidates[next].window == window {
      let other = candidates[next].depth
      if offset > 0 {
        if other > depth { next += offset; continue }  // a descendant
      } else if other < shallowest {
        shallowest = other  // an ancestor
        next += offset
        continue
      }
      break
    }
    guard candidates.indices.contains(next), candidates[next].window == window else { NSSound.beep(); return }
    descent = []
    hold(next)
  }

  /// Out to the smallest kept region that contains this one. The filter has already thrown away the
  /// wrappers that merely repeat their child's box, so the enclosing candidate is a visibly bigger
  /// region rather than the same one again -- which is what makes this a widening rather than a
  /// walk up a chain of identical rectangles.
  func ascend(from index: Int) {
    let inner = candidates[index].rect
    let parent = candidates.indices
      .filter { $0 != index && candidates[$0].window == candidates[index].window && candidates[$0].rect.insetBy(dx: -2, dy: -2).contains(inner) && candidates[$0].area > candidates[index].area }
      .min { candidates[$0].area < candidates[$1].area }
    guard let parent else { NSSound.beep(); return }
    descent.append(index)
    hold(parent)
  }

  /// Back in to whatever Up was last looking at, or, with no ascent to retrace, into the held
  /// region's first child in document order. Containment alone would not say which child to pick --
  /// a container holds many -- so a remembered descent always wins; the first child is only what
  /// makes the tree reachable inward at all when an arrow entered at the largest region rather than
  /// a hint picked one.
  func descend() {
    if let child = descent.popLast() { hold(child); return }
    guard let index = heldIndex, candidates.indices.contains(index + 1),
          candidates[index + 1].window == candidates[index].window,
          candidates[index + 1].depth > candidates[index].depth else { NSSound.beep(); return }
    hold(index + 1)
  }

  /// Put a margin around the held region, or take one off. A box out of the tree is the element and
  /// nothing else, so a paragraph whose text runs to the edge of its own box is photographed with
  /// the words against the edge of the picture; this is the room back, and the mask has already
  /// drawn what it will pull in before Return is pressed.
  ///
  /// Asked of whatever is held rather than of the candidate list, so a dragged rectangle and a half
  /// display take it as a hinted region does -- as they now take the unmodified arrows, and unlike
  /// the tree steps under Option, which have a line of ancestors to walk and nothing to walk it on.
  /// The mask is moved rather than faded in again: the darkness is already on screen and being
  /// looked at, and this is the same region drawn slightly larger.
  ///
  /// It stops at nothing on the way down -- a margin is space around the region rather than a crop
  /// into it, so `-` puts back what `+` asked for and beeps at zero -- and at the edges of the
  /// screens on the way up, where the box being asked for is already the box that would be
  /// photographed. Refusing the step that changes nothing is what keeps the two ends honest: a
  /// margin that carried on counting past the screen would owe several presses of `-` before
  /// anything moved back.
  func widen(by points: CGFloat) {
    guard let region = held else { return }
    let before = margin
    margin = max(0, margin + points)
    let rect = viewRect(framed(region.rect))
    guard margin != before, rect != view.selection else { margin = before; NSSound.beep(); return }
    view.selection = rect
    showMask(rect)
    deadline = Date().addingTimeInterval(30)
    refresh()
  }

  /// Whether nothing kept sits inside this candidate: the smallest box drawn at that spot, which is
  /// the only kind of region a step across the screen can land on and have gone anywhere. Asked of
  /// the boxes and not of the tree, which costs this pass over the list and is the only one of the
  /// two that answers -- Chromium hands back a 28 point toolbar button with the page's own toolbar
  /// nested under it and drawn 700 points away, so being a parent there says nothing about what is
  /// inside the rectangle. Within one window, the way the nesting collapse is: a box in the window
  /// behind that happens to contain a box in front of it is not holding it, it is behind it. The 2pt
  /// slack is `ascend`'s, against the same rounding.
  func isLeaf(_ index: Int) -> Bool {
    let candidate = candidates[index]
    let outer = candidate.rect.insetBy(dx: -2, dy: -2)
    return !candidates.contains {
      $0.window == candidate.window && $0.area < candidate.area && outer.contains($0.rect)
    }
  }

  /// The nearest leaf in one of four directions on screen, which is what the arrows do unmodified.
  /// The screen is what is being looked at: a hint that landed near the mark landed near it there,
  /// and the region actually wanted is the one next to it there. Whether the tree calls that a
  /// sibling, a nephew or nothing at all is the app's own bookkeeping, and it will happily put
  /// twenty steps between two boxes two centimetres apart. `step` and `ascend` are the same four
  /// keys under Option, for the question only the tree answers.
  ///
  /// Which is also why this is the one of the two that leaves the window it started in. What stops
  /// the tree steps at the boundary is that document order between two windows says only which was
  /// in front; this reads no document order, screen coordinates mean the same thing either side of
  /// the edge, and the window beside this one is exactly the case the key is for.
  ///
  /// Leaves, and not every kept region, because a container that way is also a container over here:
  /// it covers the place the step started from, so it is a step that did not go anywhere. The
  /// smallest thing at a spot is the thing at that spot, and Option-Up is how a region is made
  /// bigger.
  ///
  /// Which way is centre to centre, and how near is too -- but a leaf that lines up with the held
  /// region wins over one that is closer without lining up, because lining up is what a row and a
  /// column are, and Left out of an address bar means the padlock beside it and not the toolbar
  /// button below it, which by centres is half the distance away. Where nothing lines up there is no
  /// row to stay in and the fall-back is a quarter turn either side of the direction, so that Left
  /// cannot answer with whatever happens to be directly overhead. The cones tile the screen between
  /// them, which is what leaves no leaf unreachable.
  ///
  /// Takes the rectangle rather than a place in the list, which is what lets a dragged region and a
  /// half display be stepped off as a hinted one is: nothing here asks the tree anything. The held
  /// region needs no excluding either, its own centre being no distance at all in any direction.
  ///
  /// The region's own box and not the framed one: a margin is room around the picture rather than a
  /// bigger region, and the arrows have never read it either.
  func leap(from origin: CGRect, dx: CGFloat, dy: CGFloat) {
    var best: (index: Int, aligned: Bool, distance: CGFloat)?
    for other in candidates.indices where isLeaf(other) {
      let rect = candidates[other].rect
      // Along the direction and across it. Frames are top-left origin, the space the tree reports
      // in, so Down is +y and there is no flip to do here.
      let offsetX = rect.midX - origin.midX
      let offsetY = rect.midY - origin.midY
      let along = offsetX * dx + offsetY * dy
      let across = abs(offsetX * dy + offsetY * dx)
      guard along > 0 else { continue }
      let aligned = dx == 0
        ? rect.minX < origin.maxX && origin.minX < rect.maxX
        : rect.minY < origin.maxY && origin.minY < rect.maxY
      guard aligned || across <= along else { continue }
      let distance = hypot(along, across)
      let better = best.map { aligned == $0.aligned ? distance < $0.distance : aligned } ?? true
      if better { best = (other, aligned, distance) }
    }
    guard let best else { NSSound.beep(); return }
    // Abandoned for the reason a sideways step abandons it: what Up was looking at is no longer
    // inside what is held.
    descent = []
    hold(best.index)
  }

  /// Back from the mask to the hints, with nothing typed.
  func release() {
    holds += 1
    held = nil
    heldIndex = nil
    descent = []
    typed = ""
    joined = nil
    transcribed = false
    transcription = nil
    edited = false
    caret = nil
    anchor = 0
    beforeEdit = nil
    view.selection = nil
    view.notice = nil
    hideMask()
    refresh()
  }

  func refresh() {
    view.typed = typed
    view.joined = joined
    view.caret = caret
    view.anchor = anchor
    view.help = help
    view.hotkey = cancelChord?.display
    view.needsDisplay = true
  }
}

/// What the tap asks for: the keyboard whole, the left button so a region can be drawn, and the
/// scroll and right button so neither reaches the window underneath. Assembled a term at a time
/// because the type checker gives up on the one expression.
let tapMask: CGEventMask = {
  let types: [CGEventType] = [
    .keyDown, .leftMouseDown, .leftMouseDragged, .leftMouseUp,
    .rightMouseDown, .rightMouseUp, .scrollWheel, .mouseMoved,
  ]
  var mask: UInt64 = 0
  for type in types { mask |= 1 << UInt64(type.rawValue) }
  return CGEventMask(mask)
}()

func tapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  switch type {
  case .keyDown: Session.shared.key(event)
  case .leftMouseDown, .leftMouseDragged, .leftMouseUp:
    // The box first when one is up, since it takes the whole overlay -- a click that missed it by a
    // few points would otherwise start a rectangle instead of moving the caret. Everywhere else the
    // button draws a region, and either way it is swallowed: down, drag and up are answered
    // together or not at all, and a press whose release got through would leave the app underneath
    // holding a button it never saw let go of.
    if !Session.shared.mouse(event, type: type) { Session.shared.drag(type, event) }
  // Swallowed and nothing else. A scroll would move the content out from under every hint -- they
  // were computed once, from a tree read at the press -- and a right button would put a menu over
  // the region about to be photographed.
  case .rightMouseDown, .rightMouseUp, .scrollWheel: break
  case .mouseMoved:
    // Followed and handed on: the crosshair needs to know where the pointer is, and an app that
    // lights a button up under it has changed nothing about the region or the tree.
    Session.shared.moved(event)
    return Unmanaged.passUnretained(event)
  case .tapDisabledByTimeout, .tapDisabledByUserInput:
    if let tap = context { CGEvent.tapEnable(tap: Unmanaged<CFMachPort>.fromOpaque(tap).takeUnretainedValue(), enable: true) }
    return nil
  default: return Unmanaged.passUnretained(event)
  }
  // Swallowed, so hint characters never reach the app underneath. Key-ups are deliberately not
  // asked for: the tap is inserted ahead of the hotkey manager, and the walk is fast enough (tens
  // of milliseconds) that the tap is up before the chord that started the session is released. A
  // swallowed key-up leaves that manager believing the key is still down, so the next press is not
  // a fresh transition and fires nothing -- the session after that works, and the hotkey appears to
  // alternate. Nothing needs the up, and letting it through costs an app underneath at most a
  // key-up it never saw the key-down for. A swallowed key-*down* is the harmless direction, which
  // is what the cancel chord relies on: the manager simply does not fire, and the next press is
  // still a fresh transition.
  return nil
}

// MARK: - Capture

/// Where a capture goes. Decided at the end of a hold rather than at the hotkey: Return files it,
/// Command-C puts it on the clipboard.
enum Destination {
  /// A timestamped file in this directory.
  case directory(String)
  /// Exactly this path, for a command line run that wants a predictable name.
  case file(String)
  /// The clipboard, and no file at all.
  case clipboard

  /// macOS names its own shots "Screenshot 2026-09-05 at 12.34.56.png"; match that shape, capital
  /// included, so the two sort together in whichever folder they share.
  static func timestamped(in directory: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    return (directory as NSString).appendingPathComponent("Axshot \(formatter.string(from: Date())).png")
  }

  /// The path this capture will be written to, creating the directory if it is missing. Nil for the
  /// clipboard, which screencapture writes to directly.
  func resolve() -> String? {
    switch self {
    case .clipboard: return nil
    case .file(let path): return path
    case .directory(let directory):
      try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
      return Destination.timestamped(in: directory)
    }
  }
}

func capture(_ rect: CGRect, to path: String?) -> Bool {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  let region = "\(Int(rect.minX.rounded())),\(Int(rect.minY.rounded())),\(Int(rect.width.rounded())),\(Int(rect.height.rounded()))"
  process.arguments = ["-x", "-o", "-R", region] + (path.map { [$0] } ?? ["-c"])
  do { try process.run() } catch { return false }
  process.waitUntilExit()
  guard process.terminationStatus == 0 else { return false }
  return path.map { FileManager.default.fileExists(atPath: $0) } ?? true
}

// MARK: - Transcription

/// The model that reads a region's pixels. Opus rather than something cheaper because this key is
/// only ever reached for the regions the tree had no words for -- a canvas, a PDF, a terminal, an
/// image of a table -- which are exactly the ones a weaker reader gets wrong.
let claudeModel = "claude-opus-5"

/// Where the key is looked for, in order. The environment first, so a command line run can be given
/// one for a single invocation; then a fixed absolute path, because the app is launched from
/// /Applications at login with no environment and no useful working directory and would never find
/// a .env in a checkout; then the working directory, for a CLI run from the checkout itself.
func claudeAPIKey() -> String? {
  if let key = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !key.isEmpty { return key }
  let files = [
    (NSHomeDirectory() as NSString).appendingPathComponent(".config/axshot/.env"),
    (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(".env"),
  ]
  for path in files {
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
    for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
      var entry = line.trimmingCharacters(in: .whitespaces)
      if entry.hasPrefix("export ") { entry = String(entry.dropFirst(7)) }
      guard let split = entry.firstIndex(of: "="),
            entry[entry.startIndex..<split].trimmingCharacters(in: .whitespaces) == "CLAUDE_API_KEY"
      else { continue }
      let value = entry[entry.index(after: split)...]
        .trimmingCharacters(in: .whitespaces)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
      if !value.isEmpty { return value }
    }
  }
  return nil
}

/// Read the words off a picture of a region. Returns the task so the session can cancel it: the
/// overlay's deadline is not the request's, and a session that ended has nothing to draw the answer
/// on.
///
/// Raw URLSession rather than an SDK because there is no official Anthropic SDK for Swift, and this
/// file has no dependencies by design. Effort is low and thinking is left alone: transcription is
/// not a reasoning task, and the overlay is frozen with the keyboard swallowed for as long as the
/// call takes, so latency is the thing being bought. The refusal fallback is on -- a screenshot of
/// somebody's window is not a request anyone chose the contents of, and a refused one should come
/// back as words rather than as an error the user cannot act on.
@discardableResult
func transcribeImage(_ png: Data, completion: @escaping (String?, String?) -> Void) -> URLSessionTask? {
  guard let key = claudeAPIKey() else { completion(nil, "no_api_key"); return nil }
  let instruction = """
    Transcribe every word visible in this image, in reading order. Reproduce the text exactly, \
    including its punctuation and capitalisation. Do not describe the image, do not explain what \
    you see, and do not wrap the transcription in code fences or quotation marks. If the image \
    contains no text at all, reply with nothing.
    """
  let body: [String: Any] = [
    "model": claudeModel,
    "max_tokens": 16000,
    "output_config": ["effort": "low"],
    "fallbacks": "default",
    "messages": [[
      "role": "user",
      "content": [
        ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": png.base64EncodedString()]],
        ["type": "text", "text": instruction],
      ],
    ]],
  ]
  guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
    completion(nil, "encode_failed")
    return nil
  }

  var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
  request.httpMethod = "POST"
  request.timeoutInterval = 60
  request.setValue("application/json", forHTTPHeaderField: "content-type")
  request.setValue(key, forHTTPHeaderField: "x-api-key")
  request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
  request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
  request.httpBody = payload

  let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error as NSError?, error.code == NSURLErrorCancelled { return }
    if error != nil { completion(nil, "unreachable"); return }
    guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      completion(nil, "unreadable")
      return
    }
    // The API says what went wrong in the body, and the status alone does not: a 400 for an image
    // over the size limit and a 401 for a stale key are the same number to a caller that only reads
    // the code, and both are things the person at the keyboard can fix.
    if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
      let detail = (json["error"] as? [String: Any])?["type"] as? String
      completion(nil, detail ?? "http_\(status)")
      return
    }
    if json["stop_reason"] as? String == "refusal" { completion(nil, "refused"); return }
    let text = (json["content"] as? [[String: Any]] ?? [])
      .filter { $0["type"] as? String == "text" }
      .compactMap { $0["text"] as? String }
      .joined()
      .trimmingCharacters(in: .whitespacesAndNewlines)
    completion(text.isEmpty ? nil : text, text.isEmpty ? "no_text" : nil)
  }
  task.resume()
  return task
}

// MARK: - Toast

/// The thumbnail macOS drops in the bottom right corner after its own screenshots: proof that the
/// shutter fired, and a handle on the file without going to look for it. It lingers a few seconds
/// and then slides off the right edge, the way macOS's does; a click opens what was captured and
/// dismisses it early. Only a shot that went to a file gets one, as with macOS: a clipboard shot is
/// already where it is wanted, and the thumbnail's whole job is the file it stands in for.
///
/// It is a non-activating panel, for the same reason the overlay never takes focus -- a toast that
/// activated the app would redraw the target's title bar inactive the moment the shot landed. It is
/// also dismissed at the start of the next capture rather than left to expire, since a toast still
/// on screen is something the next screencapture(1) would photograph.
final class ToastView: NSView {
  var image: NSImage?
  var onClick: (() -> Void)?
  /// What the shot was called. The thumbnail is a picture of the file, and the name is the only
  /// part of it that can be read out.
  var name = ""
  /// The mat the thumbnail is framed in. Black rather than the white macOS uses: the shots are of
  /// one region of a window rather than a whole desktop, and a light one needs an edge that a white
  /// frame does not give it.
  static let mat: CGFloat = 6

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill()
    NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
    guard let image else { return }
    let inner = bounds.insetBy(dx: ToastView.mat, dy: ToastView.mat)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: inner, xRadius: 3, yRadius: 3).addClip()
    image.draw(in: inner)
    NSGraphicsContext.restoreGraphicsState()
    // A capture of something dark would otherwise dissolve into the mat.
    NSColor.white.withAlphaComponent(0.2).setStroke()
    let edge = NSBezierPath(roundedRect: inner.insetBy(dx: 0.25, dy: 0.25), xRadius: 3, yRadius: 3)
    edge.lineWidth = 0.5
    edge.stroke()
  }

  override func mouseDown(with event: NSEvent) { onClick?() }

  // A picture with a click behind it and no text anywhere near it, so it is named here or it is an
  // unnamed window that appears for four seconds and goes away again.
  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .button }
  override func accessibilityLabel() -> String? { "Screenshot saved" }
  override func accessibilityValue() -> Any? { name }
  override func accessibilityHelp() -> String? { "Open the file that was just captured." }
  override func accessibilityPerformPress() -> Bool { onClick?(); return true }
}

final class Toast {
  private static var current: Toast?
  /// The thumbnail is fitted inside this, so a wide region and a tall one are the same weight on
  /// screen, and the corner it sits in stays the same size.
  private static let maxSize = CGSize(width: 240, height: 150)
  private static let margin: CGFloat = 16
  private static let linger: TimeInterval = 4

  private let panel: NSPanel
  private var timer: Timer?

  private init(_ image: NSImage, open path: String) {
    let scale = min(
      Toast.maxSize.width / max(image.size.width, 1),
      Toast.maxSize.height / max(image.size.height, 1),
      1)
    let mat = ToastView.mat * 2
    let size = CGSize(
      width: (image.size.width * scale).rounded() + mat,
      height: (image.size.height * scale).rounded() + mat)
    let screen = NSScreen.main ?? NSScreen.screens[0]
    let area = screen.visibleFrame
    let frame = CGRect(
      x: area.maxX - Toast.margin - size.width,
      y: area.minY + Toast.margin,
      width: size.width,
      height: size.height)

    panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isFloatingPanel = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

    let view = ToastView(frame: CGRect(origin: .zero, size: size))
    view.image = image
    view.name = (path as NSString).lastPathComponent
    view.onClick = { [weak self] in
      NSWorkspace.shared.open(URL(fileURLWithPath: path))
      self?.close()
    }
    panel.contentView = view
    panel.orderFrontRegardless()

    timer = Timer.scheduledTimer(withTimeInterval: Toast.linger, repeats: false) { [weak self] _ in
      self?.slideOff()
    }
  }

  /// Off the right edge rather than a fade in place: the corner is emptied by something leaving it,
  /// which reads at the edge of vision in a way a dimming rectangle does not. Unless motion has been
  /// asked to stop, and then the dimming rectangle is exactly what is wanted -- this is the only
  /// travel the app draws, and travel across the corner of the eye is what the setting is about.
  /// The overlay's mask fades rather than moves, and so is left alone by it.
  private func slideOff() {
    let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
    var frame = panel.frame
    frame.origin.x = screen.frame.maxX + 1
    NSAnimationContext.runAnimationGroup { context in
      context.duration = still ? 0.2 : 0.35
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      if !still { panel.animator().setFrame(frame, display: true) }
      panel.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      self?.close()
    }
  }

  private func close() {
    timer?.invalidate()
    timer = nil
    panel.orderOut(nil)
    if Toast.current === self { Toast.current = nil }
  }

  /// Replaces whatever is on screen: one shot, one thumbnail.
  static func show(_ image: NSImage, open path: String) {
    dismiss()
    current = Toast(image, open: path)
    // The app never takes focus, the overlay is already down, and the thumbnail is a picture: with
    // nothing said, the shutter firing has no sign at all for anyone not watching that corner.
    NSAccessibility.post(
      element: NSApp as Any, notification: .announcementRequested,
      userInfo: [.announcement: "Screenshot saved to \((path as NSString).lastPathComponent)"])
  }

  static func dismiss() {
    current?.close()
    current = nil
  }
}

// MARK: - One capture

struct Outcome {
  var code: Int32
  var line: String
  /// The shot that was just taken, for the toast. Nil unless it was asked for and read back.
  var image: NSImage?
  /// Where it landed, or nil for the clipboard.
  var path: String?
  /// The session was ended by Command-comma and the caller should open the settings window. Only
  /// the app has one; a command line run reads this as a plain cancel.
  var settings = false
}

func millis(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }

/// Walk, hint, capture. Returns rather than exits, because the menu bar app does this once per
/// hotkey press and has to go back to waiting afterwards.
func runSession(_ options: Options) -> Outcome {
  let start = Date()
  let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
  guard AXIsProcessTrustedWithOptions([promptKey: options.prompt] as CFDictionary) else {
    return Outcome(code: 2, line: "trusted=false total_ms=\(millis(since: start))")
  }

  // Screen Recording is a separate grant from Accessibility, and without it the screencapture this
  // spawns fails with nothing but "could not create image from rect". Ask before the overlay goes
  // up, so the system dialog is not drawn underneath it -- but do not refuse on the answer. The
  // preflight reports whether this process may capture through CoreGraphics, and the capture here
  // goes through screencapture(1) instead, which is judged on its own and can succeed where the
  // preflight says no. A wrong no would be a tool that refuses to work at all, so the capture
  // attempt is left to be the thing that decides.
  if !options.dump && !Permissions.screenRecording.granted { Permissions.screenRecording.request() }

  // --bundle and --pid narrow which windows are hinted; they never narrow what occludes them, since
  // a window in front is in front whoever owns it.
  var only: pid_t?
  if options.pid != 0 {
    guard NSRunningApplication(processIdentifier: options.pid) != nil else {
      return Outcome(code: 3, line: "app=none total_ms=\(millis(since: start))")
    }
    only = options.pid
  } else if let bundleId = options.bundleId {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
      return Outcome(code: 3, line: "app=none total_ms=\(millis(since: start))")
    }
    only = app.processIdentifier
  }

  let targets: [WindowTarget]
  var culled = 0
  var unmatched = 0
  if options.focused {
    let app = only.flatMap { NSRunningApplication(processIdentifier: $0) } ?? NSWorkspace.shared.frontmostApplication
    guard let app else {
      return Outcome(code: 3, line: "app=none total_ms=\(millis(since: start))")
    }
    guard let window = focusedTarget(app, options: options) else {
      return Outcome(code: 6, line: "app=\(app.localizedName ?? "?") windows=0 total_ms=\(millis(since: start))")
    }
    targets = [window]
  } else {
    (targets, culled, unmatched) = onScreenWindows(options: options, only: only)
  }
  guard !targets.isEmpty else {
    return Outcome(code: 6, line: "windows=0 culled=\(culled) unmatched=\(unmatched) total_ms=\(millis(since: start))")
  }
  func name(_ target: WindowTarget) -> String {
    target.app.localizedName ?? target.app.bundleIdentifier ?? "?"
  }

  // A window can hang off the edge of its display; only the part on a screen can be captured.
  let screens = NSScreen.screens
  guard let primary = screens.first else {
    return Outcome(code: 6, line: "screens=0 total_ms=\(millis(since: start))")
  }
  let flipBase = primary.frame.maxY
  let screenArea = screens.map { flipY($0.frame) }.reduce(CGRect.null) { $0.union($1) }

  // Each window is a different process answering its own stream of accessibility messages, so
  // walking them at once overlaps the waiting rather than the work: it costs the slowest app rather
  // than the sum of them. Every walk has its own object and touches nothing else's, and the array
  // holding them is only ever read, so the one thing they share is the deadline.
  let walkStart = Date()
  let deadline = walkStart.addingTimeInterval(Double(options.budgetMs) / 1000)
  let walks = targets.enumerated().map { index, target in
    Walk(clip: target.frame.intersection(screenArea), occluders: target.occluders, window: index, deadline: deadline, options: options)
  }
  if walks.count > 1 {
    DispatchQueue.concurrentPerform(iterations: walks.count) { walks[$0].measure(targets[$0].element) }
  } else {
    walks[0].measure(targets[0].element)
  }
  let walkMs = millis(since: walkStart)
  let visited = walks.reduce(0) { $0 + $1.visited }
  let boxes = walks.reduce(0) { $0 + $1.found.count }
  let candidates = filter(walks.flatMap { $0.found }, max: options.maxHints, windows: walks.map { $0.box })
  let labels = hintLabels(count: candidates.count, alphabet: options.hintChars)

  if options.dump {
    print("windows=\(targets.count) culled=\(culled) unmatched=\(unmatched)")
    print("visited=\(visited) boxes=\(boxes) candidates=\(candidates.count) walk_ms=\(walkMs)\(walks.contains { $0.timedOut } ? " TIMED OUT" : "")")
    for (index, target) in targets.enumerated() {
      let frame = target.frame
      print("  w\(index) \(name(target)) pid=\(target.app.processIdentifier) (\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))) over=\(target.occluders.count) visited=\(walks[index].visited) boxes=\(walks[index].found.count) walk_ms=\(walks[index].ms)")
    }
    for (index, candidate) in candidates.enumerated() {
      let box = candidate.rect
      let subrole = candidate.subrole.isEmpty ? "" : " \(candidate.subrole)"
      let label = candidate.label.isEmpty ? "" : " \"\(candidate.label.prefix(60))\""
      print("  \(labels[index]) w\(candidate.window) \(candidate.role)\(subrole) depth=\(candidate.depth) (\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height)))\(label)")
    }
    return Outcome(code: 0, line: "")
  }

  // No hints is a session all the same, since the drag needs none: an app whose accessibility is one
  // box the size of its window is precisely what a rectangle drawn by hand is for, and refusing to
  // put the overlay up would take away the one way left to capture it. The crosshair is on screen,
  // and Escape or the hotkey closes an empty overlay as it closes any other.

  let overlayFrame = screens.map { $0.frame }.reduce(CGRect.null) { $0.union($1) }
  // The window still lets every mouse event through to whatever is underneath, and the mouse is
  // taken in the tap instead. Routing them here rather than there was tried and beachballs the
  // machine for the length of a session: a session runs a bare CFRunLoop and never pumps NSApp, so
  // events delivered to this app are queued and never answered, and the WindowServer puts the
  // spinner up over an app that is not going to reply. The tap is ahead of all of that -- it
  // swallows the button, the scroll and the right button before any window is picked -- and the
  // one thing the window could have given us, the cursor, it could not: that belongs to the active
  // application, which this one never is.
  let overlay = NSWindow(contentRect: overlayFrame, styleMask: .borderless, backing: .buffered, defer: false)
  overlay.isOpaque = false
  overlay.backgroundColor = .clear
  overlay.hasShadow = false
  overlay.ignoresMouseEvents = true
  overlay.level = .screenSaver
  overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

  let view = HintView(frame: CGRect(origin: .zero, size: overlayFrame.size))
  view.boxes = candidates.enumerated().map { index, candidate in
    (labels[index], flipY(candidate.rect).offsetBy(dx: -overlayFrame.minX, dy: -overlayFrame.minY))
  }
  overlay.contentView = view
  overlay.orderFrontRegardless()

  let session = Session()
  session.labels = labels
  session.candidates = candidates
  session.view = view
  session.budgetMs = options.budgetMs
  session.delayMs = options.delayMs
  session.cancelChord = options.cancelChord
  session.windows = targets.map { (element: $0.element, frame: $0.frame) }
  session.screenArea = screenArea
  // The top inset rather than the visible frame whole: that also takes out the Dock, which is a
  // band the window underneath is drawn through.
  session.screens = screens.map { (flipY($0.frame), $0.frame.maxY - $0.visibleFrame.maxY) }
  session.flipBase = flipBase
  session.overlayOrigin = overlayFrame.origin
  Session.shared = session
  // Where the pointer already is. The session is opened by a keystroke, so a hand that never
  // touches the mouse would otherwise be given a crosshair with nothing beside it until it did.
  session.updatePointer(CGPoint(x: NSEvent.mouseLocation.x, y: flipBase - NSEvent.mouseLocation.y))

  guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: tapMask,
    callback: tapCallback,
    userInfo: nil)
  else {
    overlay.orderOut(nil)
    return Outcome(code: 2, line: "windows=\(targets.count) tap=failed total_ms=\(millis(since: start))")
  }
  let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
  CGEvent.tapEnable(tap: tap, enable: true)

  // The tap swallows every key while it is up, so a session that somehow never ends would take the
  // keyboard with it. Run in slices and give up after this long rather than trusting it to stop.
  var sessionDeadline = Date().addingTimeInterval(15)
  while session.chosen == nil && !session.cancelled && session.windowShot == nil && Date() < sessionDeadline {
    CFRunLoopRunInMode(.defaultMode, 0.25, false)
    if let extended = session.deadline { sessionDeadline = extended; session.deadline = nil }
  }

  session.request?.cancel()
  CGEvent.tapEnable(tap: tap, enable: false)
  CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
  CFMachPortInvalidate(tap)

  // The one capture the overlay is in, and so the only one taken before it is ordered out. The
  // crosshair comes off first and the compositor gets the same beat every other shutter gives it,
  // which is the whole of what this picture is not of: a cursor is not in a screenshot.
  var windowShot: (rect: CGRect, path: String?, taken: Bool)?
  if let rect = session.windowShot {
    view.hidesPointer = true
    view.display()
    CATransaction.flush()
    Thread.sleep(forTimeInterval: Double(options.delayMs) / 1000)
    let path = (session.toClipboard ? Destination.clipboard : options.destination).resolve()
    windowShot = (rect, path, capture(rect, to: path))
  }
  // A session that ends with nothing takes its mask off the way it put it on -- Escape, a second
  // tap of the hotkey, or a hold left to expire. A session that ends with something does not: the
  // overlay vanishing on the keystroke is the acknowledgement, and on the exits that photograph
  // anything a fade in front of the shutter is either a delay or a mask half-lit in the picture.
  // The window shot is one of those exits, and the one it would be half-lit inside of: it has
  // already been taken, just above, with the mask at whatever strength the picture wanted it.
  if session.chosen == nil && session.windowShot == nil { session.fadeOutMask() }
  session.stopFade()
  overlay.orderOut(nil)

  if let windowShot {
    let box = windowShot.rect
    let rect = "rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height)))"
    guard windowShot.taken else {
      let hint = CGPreflightScreenCaptureAccess() ? "" : " screen_recording=false"
      return Outcome(code: 12, line: "capture=failed shot=overlay\(hint) \(rect) total_ms=\(millis(since: start))")
    }
    // Read back for the toast, the way a region shot is, and for the same reason: a shot with a file
    // behind it gets one, and the clipboard resolves to no path and so to no thumbnail.
    let image = options.toast ? windowShot.path.flatMap({ NSImage(contentsOfFile: $0) }) : nil
    return Outcome(code: 0, line: "shot=overlay \(rect) windows=\(targets.count) candidates=\(candidates.count) walk_ms=\(walkMs) total_ms=\(millis(since: start)) out=\(windowShot.path ?? "clipboard")", image: image, path: windowShot.path)
  }

  // The copy key takes no picture, so there is nothing to wait for the compositor over.
  if session.copying, let chosen = session.chosen {
    // Whatever is on screen is what is copied: the transcription if Shift-T put it there, the joined
    // run if Shift-J did, and otherwise the text laid out the way the region laid it out.
    let text = session.copyText ?? regionText(chosen, budgetMs: options.budgetMs)
    let box = chosen.rect
    guard !text.isEmpty else {
      return Outcome(code: 13, line: "app=\(name(targets[chosen.window])) role=\(chosen.role) copy=text chars=0 rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) total_ms=\(millis(since: start))")
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    return Outcome(code: 0, line: "app=\(name(targets[chosen.window])) role=\(chosen.role) copy=\(session.selecting ? "selection" : session.edited ? "edited" : session.transcribed ? "transcribed" : session.joined == nil ? "text" : "joined") chars=\(text.count) lines=\(text.split(separator: "\n").count) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) candidates=\(candidates.count) walk_ms=\(walkMs) total_ms=\(millis(since: start))")
  }

  // Give the window server a beat to composite the overlay away before the shutter.
  CFRunLoopRunInMode(.defaultMode, Double(options.delayMs) / 1000, false)

  guard let chosen = session.chosen else {
    return Outcome(code: 11, line: "windows=\(targets.count) cancelled=true\(session.settings ? " settings=true" : "") walk_ms=\(walkMs) total_ms=\(millis(since: start))", settings: session.settings)
  }
  // What `+` and `-` left, clamped to the screens: past those there is nothing to photograph.
  let box = session.framed(chosen.rect)
  let destination: Destination = session.toClipboard ? .clipboard : options.destination
  let path = destination.resolve()
  guard capture(box, to: path) else {
    let hint = CGPreflightScreenCaptureAccess() ? "" : " screen_recording=false"
    return Outcome(code: 12, line: "app=\(name(targets[chosen.window])) capture=failed\(hint) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) total_ms=\(millis(since: start))")
  }

  // Read back for the toast, which only a shot with a file behind it gets.
  let image = options.toast ? path.flatMap({ NSImage(contentsOfFile: $0) }) : nil

  let label = chosen.label.isEmpty ? "" : " label=\"\(chosen.label.prefix(60))\""
  return Outcome(code: 0, line: "app=\(name(targets[chosen.window])) role=\(chosen.role)\(label) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) windows=\(targets.count) candidates=\(candidates.count) visited=\(visited) walk_ms=\(walkMs) total_ms=\(millis(since: start)) out=\(path ?? "clipboard")", image: image, path: path)
}

// MARK: - Hotkey

/// A chord as Carbon states it: a virtual key code and Carbon's own modifier mask, which is what
/// RegisterEventHotKey takes and so what gets stored.
struct Chord: Equatable {
  var keyCode: UInt32
  var modifiers: UInt32

  var isEmpty: Bool { modifiers == 0 }

  var display: String {
    var text = ""
    if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
    if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
    if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
    if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
    return text + keyName(keyCode)
  }
}

func keyName(_ code: UInt32) -> String {
  let named: [Int: String] = [
    kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋",
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
    kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_ForwardDelete: "⌦",
    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
    kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
  ]
  if let name = named[Int(code)] { return name }

  // Anything else is a character key, and which character depends on the layout, so ask the layout
  // rather than assuming the key next to Q is a W.
  guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
        let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
  else { return "Key \(code)" }
  let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
  var deadKeys: UInt32 = 0
  var length = 0
  var characters = [UniChar](repeating: 0, count: 4)
  let translated = data.withUnsafeBytes { bytes -> OSStatus in
    guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
    return UCKeyTranslate(
      layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
      OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
  }
  guard translated == noErr, length > 0 else { return "Key \(code)" }
  return String(utf16CodeUnits: characters, count: length).uppercased()
}

/// Carbon's RegisterEventHotKey, rather than an event tap or a global monitor: it is the only one
/// that reserves the chord so the frontmost app never sees it, and the only one needing no
/// permission. The handler is a C callback, so the action lives here rather than being captured.
final class HotKey {
  static let shared = HotKey()

  static let title = "Capture Region"
  /// Option-Command-4: the shape of the Command-Shift-4 macOS uses for the same thing, with Option
  /// standing in for the Shift that macOS has taken.
  static let fallback = Chord(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(optionKey | cmdKey))

  private var reference: EventHotKeyRef?
  private var installed = false
  var action: () -> Void = {}

  func register(_ chord: Chord) -> Bool {
    unregister()
    guard !chord.isEmpty else { return false }

    if !installed {
      var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        HotKey.shared.action()
        return noErr
      }, 1, &spec, nil, nil)
      installed = true
    }

    let id = EventHotKeyID(signature: OSType(0x41585348), id: 1)  // 'AXSH'
    guard RegisterEventHotKey(chord.keyCode, chord.modifiers, id, GetApplicationEventTarget(), 0, &reference) == noErr,
          reference != nil
    else { return false }
    return true
  }

  func unregister() {
    if let reference { UnregisterEventHotKey(reference) }
    reference = nil
  }
}

/// Light or dark for the app's own chrome -- the settings window, its menu bar, the status item's
/// menu, an alert. Unset it follows macOS, which is what an app that is mostly a menu bar item
/// should do until it is told otherwise; the two named cases are for a desktop left on one theme by
/// someone who wants this window on the other.
///
/// Nothing to do with the hint style, which is why they are two settings rather than one. A plate
/// is drawn on top of somebody else's window and answers to what is underneath it; these windows
/// are the app's own and answer to the rest of the desktop. Dark plates on a light app, or the
/// other way about, is a pairing a screen can call for.
enum Theme: String, CaseIterable {
  /// The default: whatever macOS is currently doing, and it follows a change made while running.
  case system
  case light
  case dark

  var title: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  /// `nil` is already AppKit's word for "follow the system", which is why `system` is a case here
  /// rather than the absence of a stored value.
  private var appearance: NSAppearance? {
    switch self {
    case .system: return nil
    case .light: return NSAppearance(named: .aqua)
    case .dark: return NSAppearance(named: .darkAqua)
    }
  }

  /// Set on the application, so it reaches what is already on screen and whatever is opened later.
  /// What it reaches is whatever asked for a semantic colour, which is this window and the menus and
  /// panels around it, plus the key sheet, which reads the resolved appearance back off the
  /// application and colours itself by hand. The overlay and the toast name their colours outright
  /// and are unmoved: they are marks on somebody else's window rather than pages of their own, and a
  /// mask that went light with the desktop would stop masking. The sheet is the same picture from
  /// the menu bar as it is mid-session, so a theme it followed in one place and not the other would
  /// be two sheets.
  func apply() {
    NSApp.appearance = appearance
  }
}

enum Settings {
  /// The bundle identifier, as the preferences domain rather than as a bundle. `UserDefaults`
  /// derives its own domain from whatever `Bundle.main` turns out to be, and on the command line
  /// that is not this app: `bin/axshot` is a symlink into the bundle, dyld reports the symlink
  /// rather than what it points at, so the main bundle comes out as `bin/` with no identifier at
  /// all and `.standard` lands in a nameless per-process domain that nothing has ever written. The
  /// settings the app saved are still there; the CLI was reading somewhere else and getting every
  /// fallback back. Naming the domain outright makes both processes read the one file.
  static let domain = "com.raine.axshot"

  /// Reads and writes `domain` from inside the app and from the command line alike. It has to be
  /// spelled two ways to do that: `UserDefaults` rejects a suite that names the running process's
  /// own bundle -- it logs "does not make sense and will not work" and then returns nothing -- so
  /// where the identifier did resolve, the domain is already `.standard` and asking for it by name
  /// is the way to get nothing back.
  private static let store: UserDefaults =
    Bundle.main.bundleIdentifier == domain ? .standard : (UserDefaults(suiteName: domain) ?? .standard)

  static var chord: Chord {
    guard store.object(forKey: "hotKeyCode") != nil else { return HotKey.fallback }
    return Chord(
      keyCode: UInt32(store.integer(forKey: "hotKeyCode")),
      modifiers: UInt32(store.integer(forKey: "hotKeyModifiers")))
  }

  static func setChord(_ chord: Chord) {
    store.set(Int(chord.keyCode), forKey: "hotKeyCode")
    store.set(Int(chord.modifiers), forKey: "hotKeyModifiers")
  }

  /// Where captures are saved. Unset, this follows wherever macOS has been told to put its own
  /// screenshots -- the same folder the user already looks in -- and falls back to the Desktop,
  /// which is where macOS puts them when it has been told nothing.
  static var saveDirectory: String {
    get {
      if let chosen = store.string(forKey: "saveDirectory"), !chosen.isEmpty { return chosen }
      if let system = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !system.isEmpty {
        return (system as NSString).expandingTildeInPath
      }
      return NSHomeDirectory() + "/Desktop"
    }
    set { store.set(newValue, forKey: "saveDirectory") }
  }

  /// True while no folder has been chosen, so captures are still landing wherever macOS is putting
  /// its own screenshots. The settings window uses it to know whether there is anything to undo.
  static var followsSystemFolder: Bool {
    (store.string(forKey: "saveDirectory") ?? "").isEmpty
  }

  /// How the hint plates are drawn. Stored by name rather than by index, so a style added or
  /// reordered later does not silently repoint what someone already chose.
  static var hintStyle: HintStyle {
    get { HintStyle(rawValue: store.string(forKey: "hintStyle") ?? "") ?? .grey }
    set { store.set(newValue.rawValue, forKey: "hintStyle") }
  }

  /// What the app's own windows look like. Stored by name for the same reason the hint style is,
  /// and defaulting to following macOS.
  static var theme: Theme {
    get { Theme(rawValue: store.string(forKey: "theme") ?? "") ?? .system }
    set { store.set(newValue.rawValue, forKey: "theme") }
  }

  /// Forgets a chosen folder. Choosing one is otherwise a one-way door: the panel always writes a
  /// path, so without this the folder macOS is using can never be got back to by name.
  static func followSystemFolder() {
    store.removeObject(forKey: "saveDirectory")
  }
}

/// The same four modifiers off a tap event, so the chord that opened the session can be recognised
/// in the keys the overlay is reading. Only these four are compared: a tap event also carries
/// numeric-pad, function and non-coalesced bits that a chord never states.
func carbonModifiers(_ flags: CGEventFlags) -> UInt32 {
  var modifiers: UInt32 = 0
  if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
  if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
  if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
  if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
  return modifiers
}

func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
  var modifiers: UInt32 = 0
  if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
  if flags.contains(.option) { modifiers |= UInt32(optionKey) }
  if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
  if flags.contains(.control) { modifiers |= UInt32(controlKey) }
  return modifiers
}

// MARK: - Permissions

/// The two grants, and the asking. Both are checked without prompting, so that nothing appears on
/// screen until someone presses the button for it.
enum Permissions {
  case accessibility
  case screenRecording

  static var allGranted: Bool { accessibility.granted && screenRecording.granted }

  var title: String { self == .accessibility ? "Accessibility" : "Screen Recording" }

  var explanation: String {
    self == .accessibility
      ? "Reads the window's layout to find the regions, and takes the hint keystrokes."
      : "Captures the image."
  }

  var granted: Bool {
    switch self {
    case .accessibility: return AXIsProcessTrusted()
    case .screenRecording: return CGPreflightScreenCaptureAccess()
    }
  }

  /// The TCC service name, for clearing a record that has gone stale.
  var service: String { self == .accessibility ? "Accessibility" : "ScreenCapture" }

  /// A row granted against an earlier build of this app keeps that build's code requirement, so a
  /// differently signed binary no longer satisfies it: the switch reads on and every check still
  /// says no, with no way to tell that from never having been asked. Clearing the record is the
  /// only way out, and it is offered only after asking plainly has visibly failed.
  func reset() {
    guard let bundleId = Bundle.main.bundleIdentifier else { return }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
    process.arguments = ["reset", service, bundleId]
    try? process.run()
    process.waitUntilExit()
  }

  /// The system dialog, which also puts axshot in the right list in System Settings. Granting
  /// Accessibility does not take effect until relaunch, which is why the button says so.
  func request() {
    switch self {
    case .accessibility:
      let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
      _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    case .screenRecording:
      // CGRequestScreenCaptureAccess on its own did not add axshot to the Screen Recording list at
      // all -- no row, granted or denied. What registers a client is touching the capture path, and
      // on this macOS the only way in is ScreenCaptureKit; CGWindowListCreateImage is gone. Asking
      // what is on screen is enough, and the answer is thrown away. screencapture(1) does the real
      // work later, judged as axshot because it inherits this process's responsibility.
      let asked = DispatchSemaphore(value: 0)
      SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { _, _ in asked.signal() }
      _ = asked.wait(timeout: .now() + 3)
      _ = CGRequestScreenCaptureAccess()
    }
  }

  func openSettingsPane() {
    let pane = self == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
      NSWorkspace.shared.open(url)
    }
  }
}

// MARK: - Settings window

/// Name a control something other than the words drawn on it. Title and label both, the way the
/// swatches carry both: which of the two a reader takes as the name is the reader's business, and a
/// button whose title still says `Grant…` is named for neither of the two rows it could be in.
extension NSControl {
  func setAccessibilityName(_ name: String) {
    setAccessibilityTitle(name)
    setAccessibilityLabel(name)
  }
}

/// Click it, press a chord, it takes it -- or Tab to it and press Space, since the one control here
/// with no ordinary control behind it would otherwise be the one a keyboard could not reach. A chord
/// with no modifier is refused, and the box says so: a bare key as a global hotkey would swallow
/// that key everywhere.
final class RecorderView: NSView {
  var chord: Chord { didSet { needsDisplay = true; announce() } }
  var onChange: ((Chord) -> Void)?
  private var recording = false { didSet { needsDisplay = true; announce() } }
  /// Set when a bare key arrived at a recording. The refusal was a beep and nothing else, which
  /// with the sound down is no answer at all, so the box says what is missing until a chord
  /// arrives.
  private var refused = false { didSet { needsDisplay = true; announce() } }

  init(chord: Chord) {
    self.chord = chord
    super.init(frame: .zero)
  }
  required init?(coder: NSCoder) { nil }

  override var acceptsFirstResponder: Bool { true }

  override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

  /// Everything this view says is its accessibility value, so anything that changes what the box
  /// reads is the same one notification.
  private func announce() { NSAccessibility.post(element: self, notification: .valueChanged) }

  override func mouseDown(with event: NSEvent) { record() }

  /// Wait for the next chord. Reached by a click, by Space or Return once Tab has arrived here, and
  /// by a screen reader's press: the hotkey is the only setting in this window with no ordinary
  /// control behind it, and it would otherwise be the only one a mouse alone could change.
  private func record() {
    refused = false
    recording = true
    window?.makeFirstResponder(self)
  }

  /// What the box says, which is also what it reports as its value: one string, so the two cannot
  /// come to disagree.
  private var caption: String {
    guard recording else { return chord.display }
    return refused ? "Add a modifier" : "Press a chord…"
  }

  override func resignFirstResponder() -> Bool {
    recording = false
    return true
  }

  // The standard ring, drawn by AppKit wherever the mask is: a view that Tab can land on has to
  // show that it has been landed on, and this one has no control underneath to do it.
  override func drawFocusRingMask() {
    NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
  }
  override var focusRingMaskBounds: NSRect { bounds }

  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .button }
  // Title as well as label, for the same reason the swatches carry both: a script addresses a
  // control by title, and a label alone leaves the name reading `missing value`.
  override func accessibilityTitle() -> String? { "Capture region shortcut" }
  override func accessibilityLabel() -> String? { "Capture region shortcut" }
  override func accessibilityValue() -> Any? { caption }
  override func accessibilityHelp() -> String? { "Press, then hold the modifiers and key to use as the capture hotkey." }
  override func accessibilityPerformPress() -> Bool { record(); return true }

  // A chord that is also a menu shortcut would be eaten before keyDown without this.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard recording else { return false }
    keyDown(with: event)
    return true
  }

  override func keyDown(with event: NSEvent) {
    guard recording else {
      // The two keys that press any other control press this one. Not routed through
      // `performKeyEquivalent`, which only runs while recording and is there for the opposite
      // case -- a chord the menu bar would otherwise eat.
      if event.keyCode == UInt16(kVK_Space) || event.keyCode == UInt16(kVK_Return) { record(); return }
      return super.keyDown(with: event)
    }
    if event.keyCode == UInt16(kVK_Escape) {
      recording = false
      window?.makeFirstResponder(nil)
      return
    }
    let modifiers = carbonModifiers(event.modifierFlags)
    guard modifiers != 0 else { refused = true; NSSound.beep(); return }
    refused = false
    recording = false
    chord = Chord(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    window?.makeFirstResponder(nil)
    onChange?(chord)
  }

  override func draw(_ dirtyRect: NSRect) {
    let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
    (recording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
    box.fill()
    (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
    box.lineWidth = recording ? 2 : 1
    box.stroke()

    let text = NSAttributedString(string: caption, attributes: [
      .font: NSFont.systemFont(ofSize: 14, weight: .medium),
      // The prompt is set back the way a placeholder is; the refusal is not a placeholder, it is
      // the one thing in the box that has to be read.
      .foregroundColor: recording && !refused ? NSColor.secondaryLabelColor : NSColor.labelColor,
    ])
    let size = text.size()
    text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
  }
}

/// One hint style, drawn as the plate it actually produces. A menu names the styles and leaves the
/// choosing to be done from memory of what the names look like; the thing being chosen here is a
/// picture, so the control is the picture, and the choice is made by pointing at the one you want.
final class SwatchView: NSView {
  let style: HintStyle
  var isSelected: Bool {
    didSet {
      needsDisplay = true
      NSAccessibility.post(element: self, notification: .valueChanged)
    }
  }
  var onSelect: ((HintStyle) -> Void)?

  /// The app's own initials, since the letters on a swatch stand for nothing -- a real hint label
  /// would read as the hint it is not.
  private let sample = "AX"

  init(style: HintStyle, isSelected: Bool) {
    self.style = style
    self.isSelected = isSelected
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    toolTip = style.title
  }

  required init?(coder: NSCoder) { fatalError() }

  override var isFlipped: Bool { false }

  override var acceptsFirstResponder: Bool { true }

  // The standard ring, drawn by AppKit off this mask. Round the whole swatch, outside the accent
  // ring that marks the chosen one: focus and selection are two different things here, and a row
  // walked by the arrows shows both at once on whichever swatch the walk has reached.
  override func drawFocusRingMask() {
    NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 9, yRadius: 9).fill()
  }
  override var focusRingMaskBounds: NSRect { bounds }

  /// A plate, and room for the ring that marks the chosen one. No name beside it: the plate is what
  /// the setting is, and a word next to a picture of the thing it names is the picture repeated
  /// worse. The name is still on the swatch for anything that cannot see it -- the tooltip, and the
  /// accessibility tree.
  override var intrinsicContentSize: NSSize { NSSize(width: 44, height: 34) }

  override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

  override func mouseDown(with event: NSEvent) { onSelect?(style) }

  /// Space and Return choose the focused plate; Left and Right walk the row, moving the selection
  /// with the focus the way a radio group does. The plates are the only setting here that is a
  /// picture rather than a control, and a picture is the one thing a keyboard cannot point at.
  override func keyDown(with event: NSEvent) {
    switch Int(event.keyCode) {
    case kVK_Space, kVK_Return: onSelect?(style)
    case kVK_LeftArrow: step(by: -1)
    case kVK_RightArrow: step(by: 1)
    default: super.keyDown(with: event)
    }
  }

  /// The swatches share a container that holds nothing else, which is what makes them addressable
  /// as a row here and announceable as one group to a screen reader.
  private func step(by offset: Int) {
    let row = superview?.subviews.compactMap { $0 as? SwatchView } ?? []
    guard let index = row.firstIndex(of: self), row.count > 1 else { return }
    let next = row[(index + offset + row.count) % row.count]
    next.onSelect?(next.style)
    window?.makeFirstResponder(next)
  }

  // Named and pressable through the accessibility tree, which is how a screen reader reaches a
  // plain NSView and how this window is driven with no one at the keyboard. Without these the
  // swatches are a picture with nothing behind it.
  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .radioButton }
  // Title as well as label: a script addresses `radio button "Yellow"` by title, and a label alone
  // leaves the name reading `missing value` there.
  override func accessibilityTitle() -> String? { style.title }
  override func accessibilityLabel() -> String? { style.title }
  override func accessibilityValue() -> Any? { isSelected }
  override func accessibilityHelp() -> String? { "Draw the hint plates in this style." }
  override func accessibilityPerformPress() -> Bool { onSelect?(style); return true }

  override func draw(_ dirtyRect: NSRect) {
    let size = style.plateSize(sample)
    let plate = CGRect(
      x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
      width: size.width, height: size.height)
    // No card behind it. A plate is drawn straight onto whatever app is being captured, so a
    // swatch that sat it on a panel of its own would be showing something the overlay never does;
    // the ring is the only thing here that is not the setting itself.
    if isSelected {
      let ring = NSBezierPath(roundedRect: plate.insetBy(dx: -5, dy: -5), xRadius: 7, yRadius: 7)
      NSColor.controlAccentColor.setStroke()
      ring.lineWidth = 2
      ring.stroke()
    }
    style.drawPlate(sample, topLeft: CGPoint(x: plate.minX, y: plate.maxY))
  }
}

/// An `NSButton` that says it is clickable by the cursor as well as by its border. AppKit leaves the
/// arrow in place over every control, which reads as "nothing here" on the borderless rows this
/// window is mostly made of; the swatches and the recorder answer the same way.
final class PointerButton: NSButton {
  // A disabled button is not clickable, so it keeps the arrow. Cursor rects are rebuilt only when
  // something asks, and enabling is not one of the things that asks -- hence the invalidation.
  override var isEnabled: Bool {
    didSet { window?.invalidateCursorRects(for: self) }
  }

  override func resetCursorRects() {
    guard isEnabled else { return }
    addCursorRect(bounds, cursor: .pointingHand)
  }
}

/// The same for a segmented control, which AppKit also leaves the arrow over.
final class PointerSegmentedControl: NSSegmentedControl {
  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .pointingHand)
  }
}

final class SettingsWindow: NSWindowController {
  private var recorder: RecorderView!
  private let folder = NSTextField(labelWithString: "")
  private let resetFolder = PointerButton(title: "Reset", target: nil, action: nil)
  private let status = NSTextField(labelWithString: "")
  /// The rows, kept only to be measured: the window is as tall as they are.
  private var rows: NSStackView!
  private var swatches: [SwatchView] = []
  private var permissionRows: [(Permissions, NSTextField, NSButton)] = []
  private var permissionTimer: Timer?
  /// When each permission was last asked for, so a request that visibly did nothing can offer the
  /// stale-record escape rather than repeating itself.
  private var askedAt: [Int: Date] = [:]
  var onChordChange: (() -> Void)?

  convenience init() {
    // No height here, because there is no longer one to know. `fit()` measures the stack and sets the
    // real one, so a row added or removed is no longer a constant to re-tune by hand -- and the
    // window keeps neither a gap where a row was nor a margin reserved for a message it is not
    // showing. The width is the one real number: 456 of content inside 22pt insets.
    let window = SettingsPanel(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 0),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Axshot"
    // Off by default, and with it off `nextKeyView` is nil the whole way round: Tab lands on the
    // first view that will take it and then has nowhere to go, which is every control in this
    // window but one unreachable without a mouse. AppKit builds the loop in layout order once this
    // is set, so it has to be set before the views go in.
    window.autorecalculatesKeyViewLoop = true
    self.init(window: window)
    window.delegate = self

    let caption = NSTextField(labelWithString: "Capture region")
    caption.font = .systemFont(ofSize: 13)
    recorder = RecorderView(chord: Settings.chord)
    recorder.translatesAutoresizingMaskIntoConstraints = false
    recorder.onChange = { [weak self] chord in self?.apply(chord) }

    let hotKeyRow = NSStackView(views: [caption, recorder])
    hotKeyRow.orientation = .horizontal
    hotKeyRow.spacing = 12
    NSLayoutConstraint.activate([
      caption.widthAnchor.constraint(equalToConstant: 150),
      recorder.widthAnchor.constraint(equalToConstant: 190),
      recorder.heightAnchor.constraint(equalToConstant: 36),
    ])
    let styleCaption = NSTextField(labelWithString: "Hint style")
    styleCaption.font = .systemFont(ofSize: 13)
    swatches = HintStyle.allCases.map { style in
      let swatch = SwatchView(style: style, isSelected: style == Settings.hintStyle)
      swatch.onSelect = { [weak self] chosen in self?.chooseHintStyle(chosen) }
      return swatch
    }
    // Flush, because they are one control rather than five: each swatch already carries the air its
    // selection ring needs, and a gap on top of that reads as five separate settings.
    let swatchRow = NSStackView(views: swatches)
    swatchRow.orientation = .horizontal
    swatchRow.spacing = 0
    // A container holding the swatches and nothing else, which is what lets it say what it is: five
    // radio buttons loose in the row with the caption would be five unrelated settings to anything
    // reading the tree, and the arrows that walk between them read this row too.
    // An element in its own right, not just a role: a container that is not one is flattened away
    // and its children handed up to the window, which is where the five plates were arriving as
    // five unrelated settings.
    swatchRow.setAccessibilityElement(true)
    swatchRow.setAccessibilityRole(.radioGroup)
    swatchRow.setAccessibilityLabel("Hint style")
    let styleRow = NSStackView(views: [styleCaption, swatchRow])
    styleRow.orientation = .horizontal
    styleRow.spacing = 12
    styleCaption.widthAnchor.constraint(equalToConstant: 150).isActive = true

    let themeCaption = NSTextField(labelWithString: "Theme")
    themeCaption.font = .systemFont(ofSize: 13)
    // Words, where the row above it is pictures. One of the three is not a look at all but a
    // deferral to macOS, which has nothing to draw, and the other two are this whole window rather
    // than something that fits beside its own name.
    let themes = PointerSegmentedControl(
      labels: Theme.allCases.map(\.title), trackingMode: .selectOne,
      target: self, action: #selector(chooseTheme(_:)))
    themes.selectedSegment = Theme.allCases.firstIndex(of: Settings.theme) ?? 0
    // The caption beside it is a label in the window and not a label of the control, so without
    // this the group is nameless in the tree -- the same gap the swatches spell out a title for,
    // and a title rather than a label for the same reason: a script addresses `radio group "Theme"`
    // by title, and a label alone leaves the name reading `missing value` there. The segments
    // already name themselves, being real AppKit controls rather than bare views.
    themes.setAccessibilityTitle("Theme")
    let themeRow = NSStackView(views: [themeCaption, themes])
    themeRow.orientation = .horizontal
    themeRow.spacing = 12
    NSLayoutConstraint.activate([
      themeCaption.widthAnchor.constraint(equalToConstant: 150),
      // The recorder's width, so the two controls that are neither a plate nor a path line up.
      themes.widthAnchor.constraint(equalToConstant: 190),
    ])

    folder.font = .systemFont(ofSize: 12)
    folder.textColor = .secondaryLabelColor
    // Truncate the head: the tail of a path is the part that identifies it.
    folder.lineBreakMode = .byTruncatingHead
    // The path is this field's whole content, so without a name it is a value read out of nowhere.
    folder.setAccessibilityLabel("Save to")
    let choose = PointerButton(title: "Choose…", target: self, action: #selector(chooseFolder))
    choose.setAccessibilityName("Choose save folder")
    let folderCaption = NSTextField(labelWithString: "Save to")
    folderCaption.font = .systemFont(ofSize: 13)
    // Always on screen, and dimmed while there is nothing to undo: a control that appears only
    // once it can be used is one the user has to discover by making the change it reverses.
    resetFolder.target = self
    resetFolder.action = #selector(followSystemFolder)
    resetFolder.toolTip = "Go back to the macOS screenshot folder."
    resetFolder.setAccessibilityName("Reset save folder")
    let folderRow = NSStackView(views: [folderCaption, folder, choose, resetFolder])
    folderRow.orientation = .horizontal
    folderRow.spacing = 12
    NSLayoutConstraint.activate([
      folderCaption.widthAnchor.constraint(equalToConstant: 150),
      // Without a width the folder path stretches the row past both edges of the window. Two
      // buttons after it leave 116pt, which the head truncation was already there to handle.
      folder.widthAnchor.constraint(equalToConstant: 116),
    ])

    status.font = .systemFont(ofSize: 11)
    status.setAccessibilityLabel("Status")
    // Full strength, unlike every other small line here: this one is empty until something has gone
    // wrong, and an error set in the colour of an aside is one at 4:1 that reads as decoration.
    status.textColor = .labelColor
    status.lineBreakMode = .byWordWrapping
    status.maximumNumberOfLines = 2
    // Hidden while it has nothing to say, which the stack collapses rather than leaves as a blank
    // line -- and since the window is its content's height, an empty status is not a gap at the
    // bottom of the window either. A message unhides it and the window grows by the line.
    status.isHidden = true

    let launch = PointerButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunch(_:)))
    launch.state = SMAppService.mainApp.status == .enabled ? .on : .off

    var permissionViews: [NSView] = [separator()]
    let spaces = NSTextField(labelWithString: "If no dialog appears, check your other Spaces — macOS opens it wherever it likes.")
    spaces.font = .systemFont(ofSize: 11)
    // Secondary rather than tertiary. Tertiary is the colour of something switched off, and at 11pt
    // it comes to 1.9:1 on a white window -- which is fine for a placeholder and not for the line
    // that says where the dialog went. Still the quietest thing in the window, and now readable.
    spaces.textColor = .secondaryLabelColor
    for permission in [Permissions.accessibility, .screenRecording] {
      let caption = NSTextField(labelWithString: permission.title)
      caption.font = .systemFont(ofSize: 13)
      let state = NSTextField(labelWithString: "")
      state.font = .systemFont(ofSize: 11)
      state.setAccessibilityLabel(permission.title)
      let button = PointerButton(title: "Grant…", target: self, action: #selector(grant(_:)))
      button.tag = permission == .accessibility ? 0 : 1
      // Both rows have a button reading the same word, so the title alone names neither of them.
      button.setAccessibilityName("Grant \(permission.title)")

      let row = NSStackView(views: [caption, state, button])
      row.orientation = .horizontal
      row.spacing = 12
      NSLayoutConstraint.activate([
        caption.widthAnchor.constraint(equalToConstant: 150),
        state.widthAnchor.constraint(equalToConstant: 130),
      ])
      permissionRows.append((permission, state, button))
      permissionViews.append(row)
    }

    let relaunch = PointerButton(title: "Relaunch", target: self, action: #selector(relaunchApp))
    relaunch.toolTip = "Accessibility only takes effect after a restart."
    relaunch.setAccessibilityName("Relaunch Axshot")
    let relaunchRow = NSStackView(views: [NSTextField(labelWithString: "After granting Accessibility"), relaunch])
    relaunchRow.orientation = .horizontal
    relaunchRow.spacing = 12

    let stack = NSStackView(
      views: [hotKeyRow, styleRow, themeRow, folderRow, launch] + permissionViews + [spaces, relaunchRow, status])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
    stack.translatesAutoresizingMaskIntoConstraints = false

    // The stack goes inside the content view rather than being it: constraining a view to its own
    // anchors is what an NSWindowController does just before it fails to show anything.
    rows = stack
    let container = NSView()
    container.addSubview(stack)
    window.contentView = container
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      status.widthAnchor.constraint(equalToConstant: 456),
    ])
    fit()
    window.center()
    refreshFolder()
    refreshPermissions()
  }

  /// The window at the height of its rows. Called again whenever the status line appears or goes,
  /// which is the one thing here that changes height while the window is open. The top edge is held
  /// rather than the bottom: `setContentSize` would grow the window upwards, and a title bar that
  /// jumps is a worse answer to an error message than the message itself.
  private func fit() {
    guard let window else { return }
    let content = NSRect(x: 0, y: 0, width: 500, height: rows.fittingSize.height)
    var frame = window.frame
    let height = window.frameRect(forContentRect: content).height
    frame.origin.y += frame.height - height
    frame.size.height = height
    window.setFrame(frame, display: true)
  }

  private func separator() -> NSView {
    let line = NSBox()
    line.boxType = .separator
    line.translatesAutoresizingMaskIntoConstraints = false
    line.widthAnchor.constraint(equalToConstant: 456).isActive = true
    return line
  }

  override func showWindow(_ sender: Any?) {
    super.showWindow(sender)
    refreshPermissions()
    // A grant is made in System Settings, not here, so there is no event to wait for -- poll while
    // the window is up so the row turns green as soon as the switch is flipped.
    permissionTimer?.invalidate()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
      guard let self, self.window?.isVisible == true else { timer.invalidate(); return }
      self.refreshPermissions()
    }
  }

  // `.systemGreen` is tuned to shout from a control, and on the settings window's near-black it
  // reads as neon. A grant is a resting state, not an alert, so the word is drawn in a muted green
  // picked per appearance: dark enough to sit against white, light enough to sit against black.
  private static let grantedColor = NSColor(name: "granted") { appearance in
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      ? NSColor(calibratedRed: 0.51, green: 0.73, blue: 0.54, alpha: 1)
      : NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.26, alpha: 1)
  }

  // `.systemOrange` had the opposite problem and the same cause: a fill colour read as 11pt text,
  // which on a white window is 2.3:1 -- unreadable on the one row that is asking to be acted on.
  // Picked per appearance like the green, and left louder than it, since this is the alert the
  // green is not: rust against white, apricot against black -- 5.2:1 and 10.7:1.
  private static let notGrantedColor = NSColor(name: "notGranted") { appearance in
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      ? NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.42, alpha: 1)
      : NSColor(calibratedRed: 0.60, green: 0.26, blue: 0.0, alpha: 1)
  }

  private func refreshPermissions() {
    for (permission, state, button) in permissionRows {
      let granted = permission.granted
      state.stringValue = granted ? "Granted" : "Not granted"
      state.textColor = granted ? Self.grantedColor : Self.notGrantedColor
      button.isHidden = granted
      button.toolTip = permission.explanation
      if granted { askedAt[button.tag] = nil }
      // Asking plainly comes first. Only once that has been given time to work does the button
      // become the one that clears a stale record, so a normal grant is never undone by a
      // second click.
      let stale = (askedAt[button.tag].map { Date().timeIntervalSince($0) > 8 } ?? false)
      button.title = stale ? "Reset & ask again" : "Grant…"
    }
  }

  @objc private func grant(_ sender: NSButton) {
    let permission: Permissions = sender.tag == 0 ? .accessibility : .screenRecording
    if sender.title != "Grant…" { permission.reset() }
    askedAt[sender.tag] = Date()
    permission.request()
    // The dialog only offers to open System Settings, and it can land on another Space, so put the
    // pane itself in front too.
    permission.openSettingsPane()
    refreshPermissions()
  }

  /// Accessibility is decided for a process when it starts, so a grant made while axshot is running
  /// does nothing until it runs again.
  @objc private func relaunchApp() {
    let path = Bundle.main.bundleURL.path
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "sleep 1; open -n \"$0\"", path]
    try? process.run()
    NSApp.terminate(nil)
  }

  private func apply(_ chord: Chord) {
    Settings.setChord(chord)
    // Another app may already own the chord; Carbon simply refuses to register it.
    say(HotKey.shared.register(chord) ? "" : "\(chord.display) is already taken by another app.")
    onChordChange?()
  }

  /// The one way the status line is written, so it is never left showing an empty row of its own.
  /// Said as well as written: macOS has no live region, so a chord another app already owns is
  /// refused silently to anything that is not looking at this line.
  private func say(_ message: String) {
    status.stringValue = message
    status.isHidden = message.isEmpty
    fit()
    guard !message.isEmpty else { return }
    NSAccessibility.post(
      element: NSApp as Any, notification: .announcementRequested,
      userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
  }

  private func refreshFolder() {
    let directory = Settings.saveDirectory
    let shown = directory.hasPrefix(NSHomeDirectory())
      ? "~" + directory.dropFirst(NSHomeDirectory().count)
      : directory
    folder.stringValue = shown
    folder.toolTip = directory
    resetFolder.isEnabled = !Settings.followsSystemFolder
  }

  @objc private func followSystemFolder() {
    Settings.followSystemFolder()
    refreshFolder()
  }

  @objc private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.directoryURL = URL(fileURLWithPath: Settings.saveDirectory)
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Settings.saveDirectory = url.path
    refreshFolder()
  }

  /// Takes effect at the next capture. Nothing is on screen to redraw but the swatches themselves:
  /// the overlay only exists while a session is up, and settings cannot be reached from one without
  /// ending it.
  private func chooseHintStyle(_ style: HintStyle) {
    Settings.hintStyle = style
    for swatch in swatches { swatch.isSelected = swatch.style == style }
  }

  /// Takes effect at once, on this window among others -- the setting is what the window it is set
  /// in looks like, so applying it later would be asking someone to judge it from memory.
  @objc private func chooseTheme(_ sender: NSSegmentedControl) {
    guard Theme.allCases.indices.contains(sender.selectedSegment) else { return }
    let theme = Theme.allCases[sender.selectedSegment]
    Settings.theme = theme
    theme.apply()
  }

  @objc private func toggleLaunch(_ sender: NSButton) {
    do {
      if sender.state == .on { try SMAppService.mainApp.register() }
      else { try SMAppService.mainApp.unregister() }
    } catch {
      sender.state = sender.state == .on ? .off : .on
      say("Could not change the login item: \(error.localizedDescription)")
    }
  }
}

/// Escape closes the window, the way a panel does. `cancelOperation` is the documented route and is
/// never sent here: nothing in this window interprets key events, so the keystroke arrives as a
/// plain `keyDown` that walks the responder chain to the window and stops. Taking it here is that
/// same walk's last step, and it still runs behind whatever wanted the key first -- a recorder
/// mid-chord takes its own Escape to abandon the recording and never calls super.
final class SettingsPanel: NSWindow {
  override func keyDown(with event: NSEvent) {
    if event.keyCode == UInt16(kVK_Escape) {
      performClose(nil)
      return
    }
    super.keyDown(with: event)
  }
}

extension SettingsWindow: NSWindowDelegate {
  /// Closing the window is not quitting: the app drops back to being an accessory, which takes it
  /// out of the App Switcher and the Dock and leaves the menu bar item and the hotkeys running.
  func windowWillClose(_ notification: Notification) {
    permissionTimer?.invalidate()
    NSApp.setActivationPolicy(.accessory)
  }
}

// MARK: - Shortcut list window

/// The sheet on its own, opened from the menu bar. `?` reaches the same list from inside a session,
/// but a session is only ever opened by someone who already knows the hotkey -- the menu is where
/// the keys can be looked up by someone who does not, which is who a key list is for.
final class HelpWindow: NSWindowController, NSWindowDelegate {
  convenience init() {
    let size = HelpSheet.size(hotkey: Settings.chord.display)
    let window = HelpPanel(contentRect: CGRect(origin: .zero, size: size),
                           styleMask: .borderless, backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    // Above ordinary windows, and nowhere near the overlay's screen-saver level: this one is read
    // while nothing else of the app's is on screen.
    window.level = .floating
    // Borderless, so it is never drawn -- but it is the window's name in the tree, and this window
    // has no other.
    window.title = "Keyboard Shortcuts"
    window.contentView = HelpSheetView()
    self.init(window: window)
    window.delegate = self
    window.center()
  }

  /// Clicking anywhere else puts the list away. The app is an accessory and this window is the only
  /// thing it had on screen, so losing key means the reader has gone back to their own work.
  func windowDidResignKey(_ notification: Notification) {
    window?.close()
  }
}

/// A borderless window refuses key by default, and this one is dismissed by a keystroke.
final class HelpPanel: NSWindow {
  override var canBecomeKey: Bool { true }
}

/// The sheet at its own size, and the keys that take it back down. Nothing on the list is a control,
/// so any click at all is a dismissal rather than a hit test.
final class HelpSheetView: NSView {
  override var acceptsFirstResponder: Bool { true }

  // One element holding the whole list, rather than a row apiece: it is a legend read straight
  // through, and the rows are not controls to be stopped on one at a time.
  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
  override func accessibilityLabel() -> String? { "Keyboard Shortcuts" }
  override func accessibilityValue() -> Any? { HelpSheet.text(hotkey: Settings.chord.display) }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.set()
    dirtyRect.fill()
    // Half a point in, so the sheet's own border is inside the window rather than clipped by it.
    HelpSheet.draw(in: bounds.insetBy(dx: 0.5, dy: 0.5), hotkey: Settings.chord.display)
  }

  override func keyDown(with event: NSEvent) {
    // Escape, or `?` again: the two keys that close the list inside a session close it here too.
    if event.keyCode == 53 || event.characters == "?" {
      window?.close()
      return
    }
    super.keyDown(with: event)
  }

  override func mouseDown(with event: NSEvent) {
    window?.close()
  }
}

// MARK: - Driving

/// The pink frame that says an agent has the foreground.
///
/// Nothing about a driven run looks different from the outside. The windows that come forward are
/// the user's own applications, the keystrokes arrive on the keyboard they are typing on, and the
/// app doing it is the app they installed -- so a burst says so: `axshot --driving on` before it
/// takes the foreground and `--driving off` when it lets go, and for as long as it holds, every
/// screen is drawn with a border in the pink hint style. Pink because it is the plate colour chosen
/// for appearing in the fewest interfaces, which is the same property wanted here.
///
/// It marks the *drive* and not the test. A build under the test lock that the user is trying by
/// hand is their own session at their own keyboard, and a border up for the whole time the lock is
/// held is a colour they would stop seeing by the second look. So the two ends belong to the burst.
///
/// Letting go puts the foreground back where it was found. Taking it is the price of driving the
/// real app; keeping it afterwards means the user's next keystroke lands in whatever the burst
/// activated last, which is the complaint the frame is drawn for and not one it answers by itself.
///
/// The window is excluded from screen capture rather than hidden around each shutter. A band drawn
/// on a window's own edge is inside the region any capture clipped to that window could ask for,
/// and this app is not the only process that photographs -- a command line run draws its own
/// overlay in its own process and could not order this one out. `sharingType = .none` takes it out
/// of every capture on the machine without either process having to know about the other.
final class DriveFrame {
  /// One name, and the object says which end. Distributed notifications match on the object and it
  /// has to be a string, so this is what the daemon will carry.
  private static let name = Notification.Name("com.raine.axshot.driving")

  /// How long a burst may hold the frame before it is given back unasked. A drive is seconds and the
  /// longest thing inside one is a transcription at ninety, so this clears both; what it is sized
  /// for is the session that dies mid-burst, which would otherwise leave the border up and the
  /// foreground somewhere the user did not put it until the app is quit. `--driving on` again pushes
  /// it out, which is how a longer drive asks for more.
  private static let ceiling: TimeInterval = 120

  private static var current: DriveFrame?

  private let window: NSWindow
  private let view: DriveFrameView
  /// Whoever had the foreground when the burst began.
  private let interrupted: NSRunningApplication?
  private var timer: Timer?
  private var watch: NSObjectProtocol?
  private var deadline = Date()

  /// Listens for both ends. Registered by the menu bar app and by nothing else: the frame is a
  /// window, and a command line run exits before one would be worth drawing.
  static func observe() {
    DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { note in
      if (note.object as? String) == "on" { begin() } else { end() }
    }
  }

  /// Says which end from a process that is not the app. Nothing is drawn here -- this is the wire.
  static func post(on: Bool) {
    DistributedNotificationCenter.default().postNotificationName(
      name, object: on ? "on" : "off", userInfo: nil, deliverImmediately: true)
  }

  private static func begin() {
    if let current { current.deadline = Date().addingTimeInterval(ceiling); return }
    current = DriveFrame()
  }

  private static func end() {
    current?.close()
    current = nil
  }

  private init() {
    interrupted = NSWorkspace.shared.frontmostApplication
    let area = NSScreen.screens.map { $0.frame }.reduce(CGRect.null) { $0.union($1) }
    window = NSWindow(contentRect: area, styleMask: .borderless, backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.ignoresMouseEvents = true
    // Above the hint overlay rather than beside it. Two windows at the same level are ordered by
    // whichever went front last, and a frame that ended up underneath would be the one thing on
    // screen the overlay's mask was not drawn to dim.
    window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    window.sharingType = .none
    // Half, on the window rather than in the colours, so the band and the outline holding its shape
    // go down together. It is up for as long as a burst runs and sits on top of what the user is
    // reading underneath it: it has to be unmissable at a glance and not worth looking away from.
    window.alphaValue = 0.5
    view = DriveFrameView(frame: CGRect(origin: .zero, size: area.size))
    view.origin = area.origin
    window.contentView = view
    window.orderFrontRegardless()

    deadline = Date().addingTimeInterval(Self.ceiling)
    layout()
    // The one thing that moves the band now. A screen coming or going, or changing resolution, is
    // the only event that changes where the edge of the desktop is -- where a window's edge changed
    // with every activation, every drag and every resize, none of which this has to hear about any
    // more.
    watch = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
        self?.layout()
      }
    // The ceiling is the only thing this watches, and a second of slack on two minutes is nothing.
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self else { return }
      if Date() >= self.deadline { DriveFrame.end() }
    }
  }

  /// Where the band goes: one around each screen. Every screen and not the bounding box of them,
  /// because two displays that are not the same height leave the box running through dead space at
  /// the top of the shorter one -- a band nobody sees, and no band along the edge that is there.
  private func layout() {
    let screens = NSScreen.screens
    let area = screens.map { $0.frame }.reduce(CGRect.null) { $0.union($1) }
    guard !area.isNull else { return }
    window.setFrame(area, display: true)
    view.frame = CGRect(origin: .zero, size: area.size)
    view.origin = area.origin
    view.boxes = screens.map { $0.frame }
  }

  private func close() {
    timer?.invalidate()
    if let watch { NotificationCenter.default.removeObserver(watch) }
    window.orderOut(nil)
    guard let interrupted, !interrupted.isTerminated,
          interrupted.processIdentifier != getpid() else { return }
    interrupted.activate(options: [])
  }
}

/// The band itself: one square-cornered frame per screen, drawn as layers.
///
/// Square, because a screen is not a window. The band used to trace whatever window was frontmost,
/// and macOS rounds a window with a continuous corner -- a squircle, fuller through the diagonal
/// than a circle of the same radius -- which no `NSBezierPath` draws; that is what the layers and
/// their `cornerCurve = .continuous` were for, at a radius of 16 measured against a real window row
/// by row. A display's corner is a different shape and not one anything reports. Where the panel
/// rounds it, the panel's own mask clips the band, and a curve guessed at here would compete with
/// that mask rather than match it -- so the band states the bounds it knows and lets the corner
/// belong to the hardware. The layers stay because the inward falloff is still drawn as concentric
/// rings, and the radius measurement is kept above in case a band ever has to follow a window again.
///
/// Not an accessibility element and deliberately so: it is a mark drawn over somebody else's window
/// rather than a control, it answers no key, and a borderless window sitting over every app is the
/// last thing a reader should have to step through to get past. The overlay is out of the tree for
/// the same reason and says as much in the header.
final class DriveFrameView: NSView {
  /// The solid band on the screen's own edge.
  private static let band: CGFloat = 4
  /// The shadow cast inward from it, as concentric borders rather than as a blur. A blurred shadow
  /// needs a path to be cast from and the only exact one here is a curve no path can hold, so the
  /// falloff is drawn out of the same curve instead: each step is a layer, so every ring is the
  /// window's corner again rather than an approximation of it.
  private static let steps = 16
  private static let step: CGFloat = 1

  /// The frame window's own origin, so a box in screen coordinates can be drawn in view ones.
  var origin = CGPoint.zero
  /// One box per screen, in screen coordinates.
  var boxes: [CGRect] = [] {
    didSet { if boxes != oldValue { place() } }
  }

  /// Built to match the number of screens rather than up front, since that is not known until the
  /// first layout and can change under a burst. Never taken down again -- a display unplugged and
  /// replugged inside two minutes would otherwise rebuild them, and a hidden layer costs nothing.
  private var bands: [(edge: CALayer, glow: [CALayer])] = []

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
  }

  private func makeBand() -> (edge: CALayer, glow: [CALayer]) {
    let pink = HintStyle.pink.line
    let edge = CALayer()
    edge.borderColor = pink.cgColor
    edge.borderWidth = Self.band
    layer?.addSublayer(edge)
    var glow: [CALayer] = []
    for i in 0..<Self.steps {
      let ring = CALayer()
      // Quadratic, so the shadow leaves the band quickly and then trails off, which is what an inset
      // shadow looks like and what a linear ramp reads as a stack of rings instead.
      let fade = pow(1 - CGFloat(i) / CGFloat(Self.steps), 2)
      ring.borderColor = pink.withAlphaComponent(0.34 * fade).cgColor
      ring.borderWidth = Self.step
      layer?.addSublayer(ring)
      glow.append(ring)
    }
    return (edge, glow)
  }

  required init?(coder: NSCoder) { nil }

  override var isFlipped: Bool { false }
  override func isAccessibilityElement() -> Bool { false }

  private func place() {
    // A layer moved without this animates itself into position, and a band that slides after the
    // window it is marking is a band that is wrong for as long as the slide lasts.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }
    while bands.count < boxes.count { bands.append(makeBand()) }
    for (index, band) in bands.enumerated() {
      guard index < boxes.count else {
        band.edge.isHidden = true
        band.glow.forEach { $0.isHidden = true }
        continue
      }
      let rect = boxes[index].offsetBy(dx: -origin.x, dy: -origin.y)
      band.edge.isHidden = false
      band.edge.frame = rect
      for (i, ring) in band.glow.enumerated() {
        let inset = Self.band + CGFloat(i) * Self.step
        ring.isHidden = false
        ring.frame = rect.insetBy(dx: inset, dy: inset)
      }
    }
  }
}

// MARK: - Menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var settings: SettingsWindow?
  private var help: HelpWindow?
  private var busy = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Before anything is built, so the first window drawn is already the right one rather than a
    // window that changes colour once it is on screen.
    Settings.theme.apply()

    // Costs nothing until something says a burst has started, which is why it is registered here
    // rather than being something the app has to be launched a particular way to get.
    DriveFrame.observe()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Axshot")
    // The image's description names it, but the title is what a name is looked up by, and an
    // image-only button leaves that empty: the item reads `missing value` to a script and has to be
    // found by position instead.
    statusItem.button?.setAccessibilityName("Axshot")

    let menu = NSMenu()
    let capture = NSMenuItem(title: HotKey.title, action: #selector(captureFromMenu), keyEquivalent: "")
    capture.target = self
    menu.addItem(capture)
    menu.addItem(.separator())
    // No key equivalent, unlike Settings: `?` opens this list from the overlay, but it is a bare
    // key there and a menu can only offer it under Command, which is a chord nothing answers.
    let shortcuts = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showShortcuts), keyEquivalent: "")
    shortcuts.target = self
    menu.addItem(shortcuts)
    let preferences = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    preferences.target = self
    menu.addItem(preferences)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit Axshot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    statusItem.menu = menu
    NSApp.mainMenu = mainMenu()

    HotKey.shared.action = { [weak self] in self?.capture() }
    let refused = !HotKey.shared.register(Settings.chord)
    refreshMenuTitles()

    // Neither permission is asked for here. Launching, including at login, should put up no dialog
    // at all; the settings window says what is missing and its buttons are what ask. Asking at the
    // first press instead would draw the dialog underneath the overlay.
    if refused || !Permissions.allGranted { showSettings() }
  }

  /// An accessory app has no menu bar of its own, but the settings window is reachable from the App
  /// Switcher and so needs the keys that come with one -- Cmd-W above all, which closes the window
  /// and, unlike Cmd-Q, leaves the app running.
  private func mainMenu() -> NSMenu {
    let application = NSMenuItem()
    application.submenu = NSMenu()
    let preferences = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    preferences.target = self
    application.submenu?.addItem(preferences)
    application.submenu?.addItem(.separator())
    application.submenu?.addItem(
      NSMenuItem(title: "Hide Axshot", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
    application.submenu?.addItem(
      NSMenuItem(title: "Quit Axshot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    let file = NSMenuItem()
    file.submenu = NSMenu(title: "File")
    file.submenu?.addItem(
      NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

    let menu = NSMenu()
    menu.addItem(application)
    menu.addItem(file)
    return menu
  }

  private func refreshMenuTitles() {
    statusItem.menu?.item(at: 0)?.title = "\(HotKey.title)  \(Settings.chord.display)"
  }

  @objc private func captureFromMenu() {
    capture()
  }

  private func capture() {
    // The hotkey can be pressed again while the overlay is up; one session at a time.
    guard !busy else { return }
    busy = true
    defer { busy = false }

    // A toast still on screen is something the next screencapture(1) would photograph.
    Toast.dismiss()

    var options = Options()
    options.destination = .directory(Settings.saveDirectory)
    options.toast = true
    options.cancelChord = Settings.chord
    let outcome = runSession(options)
    if outcome.code == 0, let image = outcome.image, let path = outcome.path {
      Toast.show(image, open: path)
    }
    if outcome.settings { showSettings(); return }
    guard outcome.code != 0 && outcome.code != 11 else { return }

    let alert = NSAlert()
    alert.messageText = "Axshot could not capture that."
    alert.informativeText = outcome.line
    alert.alertStyle = .warning
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }

  /// A new window every time rather than one kept around: the sheet is laid out around the hotkey,
  /// which settings can change between one reading of the list and the next.
  @objc func showShortcuts() {
    help?.close()
    help = HelpWindow()
    NSApp.activate(ignoringOtherApps: true)
    help?.showWindow(nil)
    help?.window?.makeKeyAndOrderFront(nil)
    if let view = help?.window?.contentView { help?.window?.makeFirstResponder(view) }
  }

  @objc func showSettings() {
    if settings == nil {
      settings = SettingsWindow()
      settings?.onChordChange = { [weak self] in self?.refreshMenuTitles() }
    }
    // Regular for as long as the window is up, so it can be reached from the App Switcher and its
    // menu bar carries Cmd-W. windowWillClose puts the app back to being an accessory.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    settings?.showWindow(nil)
    settings?.window?.makeKeyAndOrderFront(nil)
  }
}

// MARK: - Entry

let arguments = Array(CommandLine.arguments.dropFirst()).filter { $0 != "--worker" }

if arguments.first == "--driving" {
  // Says so and exits. The frame belongs to the running app and this process is only the way to
  // tell it, so it needs no permission and no bundle identity of its own -- which is why it goes
  // ahead of the disclaimed re-spawn rather than through it.
  guard arguments.count == 2, arguments[1] == "on" || arguments[1] == "off" else { usage() }
  let app = NSRunningApplication.runningApplications(withBundleIdentifier: Settings.domain).first
  DriveFrame.post(on: arguments[1] == "on")
  // A burst that turned the frame on and drew nothing is a burst driving an app that is not there,
  // and the outcome line is the only place that would say so.
  print("driving=\(arguments[1]) app=\(app == nil ? "none" : "running")")
  exit(app == nil ? 3 : 0)
}

if arguments.isEmpty {
  let application = NSApplication.shared
  application.setActivationPolicy(.accessory)
  let delegate = AppDelegate()
  application.delegate = delegate
  application.run()
} else {
  let options = parse(Array(CommandLine.arguments.dropFirst()))
  // A terminal-launched run would otherwise be judged as the terminal; disclaiming makes TCC judge
  // axshot, so the app's grants serve the command line too.
  if !options.worker { respawnDisclaimed() }
  let application = NSApplication.shared
  application.setActivationPolicy(.accessory)
  let outcome = runSession(options)
  if !outcome.line.isEmpty { print(outcome.line) }
  exit(outcome.code)
}
