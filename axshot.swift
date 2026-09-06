// Screenshot a region of the screen picked by hint, not by dragging a rectangle.
//
// A region worth capturing -- a sidebar, a message, a diff panel, a single button -- is already
// described in the app's accessibility tree, with a frame that can be read. axshot walks the
// focused window's tree, keeps every element whose box is actually visible, overlays a Surfingkeys
// style hint on each, and captures the one whose hint you type. No dragging, no coordinates, and
// the region is snapped to a real element rather than to wherever the pointer happened to stop.
//
// It runs as a menu bar app holding a global hotkey. Resident, but only as a listener: an idle
// hotkey costs nothing, and the tree is still walked on demand at each invocation rather than kept
// warm. Caching it would save the 26-63ms the walk measures against the 100-300ms the capture
// costs, which is not a saving anyone can see, and would keep every Chromium app's accessibility
// engine switched on all day to buy it.
//
// Launched with arguments it is a command line tool instead, which is how the region filter gets
// looked at:
//
//   axshot --dump            list the regions that would be hinted, and exit
//   axshot --pid 1           ask for Screen Recording and exit without drawing anything
//
//   --bundle <id>     target this bundle id instead of the frontmost app
//   --pid <n>         target this process, for when two instances of an app are running
//   --out <path>      write the PNG to exactly this path instead of a timestamped file
//   --clipboard       put the image on the clipboard and write no file
//   --min-size <pt>   ignore boxes smaller than this on either side (default 24)
//   --max-hints <n>   keep at most this many regions, largest first (default 150)
//   --hint-chars <s>  alphabet for hint labels (default "sadfjklewcmpgh", 14 letters, which is
//                     enough that two dozen regions are one keystroke each and 196 are two)
//   --budget-ms <n>   stop walking after this long (default 2000)
//   --no-prune        walk into elements whose own box is entirely off screen. Off by default:
//                     web layout puts children inside their parent, so an off-screen parent is an
//                     off-screen subtree, and skipping it is most of what makes a long
//                     conversation walkable at all
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
// The arrows adjust the held region without going back to the hints, for when the one that was
// lettered is nearly right: Left and Right step across the tree in document order -- to the next
// sibling, cousin, uncle or nephew, skipping the held region's own ancestors and descendants, which
// are the same region drawn bigger or smaller and are what the other two arrows are for -- while
// Up widens to the smallest kept region containing this one, and Down returns to the region Up was
// last looking at. Only kept candidates are offered, so Up is a visible widening rather than a walk
// through the wrappers that repeat the same box. Down prefers to retrace an ascent rather than
// guess at a child, since a container holds many and containment does not say which; stepping
// sideways abandons that memory, because what it remembers is no longer inside what is held. HJKL do
// the same four things as the arrows: the held region is a selection being adjusted rather than text
// being typed, so the hand does not have to leave the letters it just typed a hint with. They are
// read as physical keys, in the same layout-independent way as the hotkeys, and only while a region
// is held -- before that every letter is a hint.
//
// An arrow pressed with the hints still up holds the outermost region instead, which is where the
// arrows can reach every other region from -- so the tree can be walked without ever picking a
// letter, for when nothing lettered is close and reading the hints is more work than stepping. Only
// the arrows do this, since HJKL are still hints until something is held. It is also the one place
// Down has no ascent to retrace, so there it falls back to the held region's first child in document
// order; without that the entry point would only ever lead outwards.
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
// Only what is visible. A box is kept only where it intersects the focused window, and it is
// captured clipped to that intersection. An element scrolled out of view still has a frame, and
// capturing it would photograph whatever is in that part of the screen instead, so it is dropped
// before it can be hinted. Occlusion by other windows is not considered: the target window is
// frontmost by construction.
//
// The overlay never appears in the shot. It is a borderless window at screen-saver level that is
// ordered out before the capture runs, with --delay-ms for the compositor. Focus is never taken
// from the target app -- the app would redraw its title bar and focus rings unfocused, and the
// screenshot would be of a window that looks inactive, and NSWorkspace would stop calling the
// target frontmost. The menu bar app is an accessory and never activates around a capture, and hint
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
  FileHandle.standardError.write("usage: axshot [--dump] [--bundle ID] [--pid N] [--out PATH] [--clipboard] [--min-size PT] [--max-hints N] [--hint-chars S] [--budget-ms N] [--no-prune] [--enhanced] [--prompt] [--delay-ms N]\n".data(using: .utf8)!)
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
  let options: Options
  let deadline: Date
  var visited = 0
  var timedOut = false
  var path = Set<ElementKey>()
  var found: [Candidate] = []
  let maxDepth = 256

  init(clip: CGRect, options: Options) {
    self.clip = clip
    self.options = options
    deadline = Date().addingTimeInterval(Double(options.budgetMs) / 1000)
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
      let visible = frame.intersection(clip)
      if visible.isNull || visible.isEmpty {
        // Nothing of this element is on screen. Its children are laid out inside it, so neither is
        // anything below it -- which is what keeps a long conversation from being walked in full.
        if options.prune { return }
      } else if visible.width >= options.minSize && visible.height >= options.minSize {
        found.append(Candidate(element: element, role: info.role, subrole: info.subrole, label: info.label, rect: visible, depth: depth, childCount: info.children.count))
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
/// dozen hints on the same pixels. Three passes: drop exact repeats, drop wrappers that say nothing
/// and hold one child, then walk largest-first and drop anything an already-kept box swallows
/// without growing much. Document order is restored at the end so the hints read down the page.
func filter(_ candidates: [Candidate], max limit: Int) -> [Candidate] {
  var seen = Set<String>()
  var distinct: [(offset: Int, candidate: Candidate)] = []
  for (offset, candidate) in candidates.enumerated() {
    if candidate.generic && candidate.childCount <= 1 { continue }
    if !seen.insert(gridKey(candidate.rect)).inserted { continue }
    if distinct.contains(where: { nearlyEqual($0.candidate.rect, candidate.rect) }) { continue }
    distinct.append((offset, candidate))
  }

  var kept: [(offset: Int, candidate: Candidate)] = []
  for entry in distinct.sorted(by: { $0.candidate.area > $1.candidate.area }) {
    let swallowed = kept.contains { outer in
      outer.candidate.rect.insetBy(dx: -2, dy: -2).contains(entry.candidate.rect)
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

final class HintView: NSView {
  var boxes: [(label: String, rect: CGRect)] = []
  var typed = ""
  /// Set once a hint has been typed: the region is held, everything outside it is masked, and the
  /// shutter waits for Return. Preview's crop, without the grid -- the point is to see what the
  /// shot will contain while the target is still on screen to compare it against.
  var selection: CGRect?
  /// The held region's text with its line breaks taken out, drawn over the region itself. What the
  /// tree hands over is not always what the layout showed -- a paragraph split across a dozen
  /// elements comes back as a dozen lines -- so the joined form is put on screen before it is
  /// copied, in the one place the original is still next to it.
  var joined: String?
  /// A word from the app rather than from the region -- "Transcribing..." while the request is out,
  /// or why it failed. Drawn in the same box as the joined text, and deliberately not the same
  /// field: the copy key hands over what the region said, and never what axshot said about it.
  var notice: String?
  /// Set across the shutter that Shift-T fires. The mask stays exactly where it is -- it is drawn
  /// even-odd and never covers the region -- while the two things that *are* drawn inside the region
  /// come off: the corner brackets, and the text box if one is up. Ordering the whole overlay out
  /// instead would photograph the same pixels, but the region would visibly unmask and re-mask
  /// around the shutter, which is a flash the join key never has.
  var bare = false
  /// Set while `?` is asking for the shortcut list, which is drawn over whatever is underneath it.
  var help = false
  /// The hotkey as settings spells it. It is one of the keys the list names -- a second tap cancels
  /// -- and it is not the same chord on every machine.
  var hotkey: String?
  override var isFlipped: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.set()
    dirtyRect.fill()

    drawRegions()
    // Never over a shutter. Nothing can fire one while the sheet is up -- every other key is
    // swallowed -- but the sheet is the one thing on the overlay large enough that drawing it into
    // a photograph would go unnoticed until someone opened the file.
    if help && !bare { drawHelp() }
  }

  private func drawRegions() {
    if let selection {
      // Even-odd over the whole overlay minus the region, so the mask is one fill and the region
      // is left completely untouched rather than drawn over at a low alpha.
      let mask = NSBezierPath(rect: bounds)
      mask.append(NSBezierPath(rect: selection))
      mask.windingRule = .evenOdd
      NSColor(calibratedWhite: 0, alpha: 0.55).setFill()
      mask.fill()

      // Nothing below this line is drawn for the shutter: it all sits inside the region, which is
      // the one part of the screen the photograph is of.
      if bare { return }

      // Corner brackets, drawn inside the region so they mark it without covering its edge pixels.
      let arm = min(24, selection.width / 3, selection.height / 3)
      let thickness: CGFloat = 2
      let corners = NSBezierPath()
      for (x, dx) in [(selection.minX, 1.0 as CGFloat), (selection.maxX, -1.0 as CGFloat)] {
        for (y, dy) in [(selection.minY, 1.0 as CGFloat), (selection.maxY, -1.0 as CGFloat)] {
          corners.move(to: CGPoint(x: x + dx * arm, y: y + dy * thickness / 2))
          corners.line(to: CGPoint(x: x, y: y + dy * thickness / 2))
          corners.move(to: CGPoint(x: x + dx * thickness / 2, y: y))
          corners.line(to: CGPoint(x: x + dx * thickness / 2, y: y + dy * arm))
        }
      }
      NSColor.white.setStroke()
      corners.lineWidth = thickness
      corners.stroke()

      if let joined = notice ?? joined {
        // Over the region rather than beside it: the joined text is what the region says, and the
        // region is the only box on screen guaranteed to be where the eye already is. Opaque,
        // because text drawn over text is neither of them.
        // Padding scaled to the region rather than a fixed 8: a link or a table row is one line
        // tall, which is where a joined run is likeliest to be asked for and where a fixed margin
        // leaves no room to draw it in.
        let padding = min(8, max(2, min(selection.width, selection.height) / 8))
        let inset = selection.insetBy(dx: padding, dy: padding)
        if inset.width > 16 && inset.height > 8 {
          NSColor(calibratedWhite: 0.08, alpha: 0.94).setFill()
          NSBezierPath(roundedRect: selection.insetBy(dx: padding / 2, dy: padding / 2), xRadius: 4, yRadius: 4).fill()
          // Four fifths of the system's own body size, and 1.25 line spacing: this is a region's
          // text laid over the region, so it has to hold more words in the same box than the layout
          // it replaced -- a notch smaller than what the machine reads at, with the lines given
          // room, since a run with its breaks taken out is a wall otherwise.
          let style = NSMutableParagraphStyle()
          style.lineBreakMode = .byWordWrapping
          style.lineHeightMultiple = 1.25
          func attributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
            [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.white, .paragraphStyle: style]
          }
          // Laid out to be measured, rather than asking boundingRect: it does not count the leading
          // that lineHeightMultiple adds, so it reports a wall of text a fifth shorter than it
          // draws, and the box built from that figure cuts the last lines off.
          let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
          func height(_ text: NSAttributedString) -> CGFloat {
            let storage = NSTextStorage(attributedString: text)
            let container = NSTextContainer(size: CGSize(width: inset.width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            let layout = NSLayoutManager()
            layout.addTextContainer(container)
            storage.addLayoutManager(layout)
            layout.ensureLayout(for: container)
            return ceil(layout.usedRect(for: container).height) + 2
          }
          // Shrink below the system size only where the region holds more words than it has room
          // for, down to a floor: the alternative is text cut off mid-sentence with nothing saying so.
          var size = NSFont.systemFontSize * 0.8
          var text = NSAttributedString(string: joined, attributes: attributes(size: size))
          while height(text) > inset.height, size > 8 {
            size -= 1
            text = NSAttributedString(string: joined, attributes: attributes(size: size))
          }
          // Centred vertically in what is left over, which only shows on the short regions -- a row
          // whose one line sat hard against the top read as clipped rather than as centred. The box
          // gives up its top half of the slack and keeps the bottom: text is laid out downwards from
          // the top, so a rect trimmed at the bottom as well would clip anything the measurement
          // undercounted, and the centring is not worth paying for in lost lines.
          let slack = max(0, inset.height - height(text))
          text.draw(with: CGRect(x: inset.minX, y: inset.minY,
                                 width: inset.width, height: inset.height - slack / 2), options: options)
        }
      }
      return
    }

    for box in boxes where box.label.hasPrefix(typed) {
      let remaining = String(box.label.dropFirst(typed.count))
      let text = NSAttributedString(string: remaining.uppercased(), attributes: [
        .font: hintFont,
        .foregroundColor: NSColor.black,
      ])
      let size = text.size()
      let padding: CGFloat = 3
      let plate = CGRect(
        x: box.rect.minX,
        y: box.rect.maxY - (size.height + padding * 2),
        width: size.width + padding * 2,
        height: size.height + padding * 2)
      let rounded = NSBezierPath(roundedRect: plate, xRadius: 3, yRadius: 3)
      NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.35, alpha: 0.96).setFill()
      rounded.fill()
      NSColor(calibratedRed: 0.35, green: 0.25, blue: 0.0, alpha: 0.9).setStroke()
      rounded.lineWidth = 1
      rounded.stroke()
      text.draw(at: CGPoint(x: plate.minX + padding, y: plate.minY + padding))
    }
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
        ("\u{2190} \u{2192} or H L", "select the next/prev region"),
        ("\u{2191} or K", "select the parent region"),
        ("\u{2193} or J", "select the child region"),
      ]),
      ("Any time", [
        ("esc or " + (hotkey ?? ""), "cancel"),
        ("\u{2318},", "settings"),
        ("?", "keyboard shortcuts (you are here)"),
      ]),
    ]
  }

  private static func run(_ string: String, _ font: NSFont, _ alpha: CGFloat) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [
      .font: font, .foregroundColor: NSColor(calibratedWhite: 1, alpha: alpha),
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
    NSColor(calibratedWhite: 0.08, alpha: 0.96).setFill()
    rounded.fill()
    NSColor(calibratedWhite: 1, alpha: 0.18).setStroke()
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

/// Shared with the event tap callback, which is a C function pointer and cannot capture context.
final class Session {
  static var shared: Session!
  var labels: [String] = []
  var candidates: [Candidate] = []
  var typed = ""
  /// The region a hint selected, held while the mask is up and the shutter waits for Return.
  var held: Candidate?
  /// Set when the hold was ended with Command-C, which sends the shot to the clipboard rather than
  /// to a file.
  var toClipboard = false
  /// Where the held region sits in the candidate list, which is what the arrow keys move through.
  var heldIndex: Int?
  /// The indices left behind by each Up, so Down can walk back into the region it came from. An
  /// ascent is the only thing that records a child; stepping sideways abandons the descent, because
  /// the remembered child is no longer inside what is held.
  var descent: [Int] = []
  var chosen: Candidate?
  /// Set alongside `chosen` when Command-Shift-C ended the session: the region's text is wanted,
  /// and the shutter is not fired at all.
  var copying = false
  /// The held region's text with the line breaks joined out, once Shift-J has asked for it. Set
  /// means the joined form is on screen and is what either copy chord will hand over; it survives an
  /// arrow step and is recomputed for whatever is held next, since the question Shift-J asked was
  /// about the text and not about that one region.
  var joined: String?
  /// How long the text walk may take, which is the same budget the region walk was given.
  var budgetMs = 2000
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

  func key(_ event: CGEvent) {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    // Escape, which the shortcut list takes first: a panel is dismissed by it before the thing
    // behind the panel is, and a sheet opened to read is not a session anybody meant to abandon.
    if keyCode == 53 {  // escape
      if help { help = false; refresh(); return }
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
      if keyCode == 51 { release() }  // delete, back to the hints
      if let index = heldIndex {
        switch keyCode {
        case 123, 4: step(from: index, by: -1)  // left, h
        case 124, 37: step(from: index, by: 1)  // right, l
        case 126, 40: ascend(from: index)  // up, k
        case 125, 38: descend()  // down, j
        default: break
        }
      }
      return
    }
    // An arrow with nothing held enters the tree rather than being ignored: the outermost region
    // is the one place every other region can be reached from, and the arrows take it from there.
    if [123, 124, 125, 126].contains(keyCode) {
      guard !candidates.isEmpty else { NSSound.beep(); return }
      typed = ""
      descent = []
      hold(0)
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

  /// Hold this candidate: mask around it, and restart the deadline, since every hold is a decision
  /// the run loop could not have known to wait for.
  func hold(_ index: Int) {
    held = candidates[index]
    heldIndex = index
    view.selection = view.boxes[index].rect
    view.notice = nil
    if transcribed || transcription != nil {
      transcribed = false
      transcription = nil
      joined = nil
    } else if joined != nil {
      joined = regionText(candidates[index], budgetMs: budgetMs, separator: " ")
    }
    deadline = Date().addingTimeInterval(30)
    refresh()
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
    }
    deadline = Date().addingTimeInterval(30)
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
    guard let region = held, let index = heldIndex else { return }
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
        guard let self, !self.cancelled, self.chosen == nil, self.heldIndex == index else { return }
        self.request = nil
        self.view.notice = nil
        if let text {
          self.transcription = text
          self.joined = text
          self.transcribed = true
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
  func step(from index: Int, by offset: Int) {
    let depth = candidates[index].depth
    var shallowest = depth
    var next = index + offset
    while candidates.indices.contains(next) {
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
    guard candidates.indices.contains(next) else { NSSound.beep(); return }
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
      .filter { $0 != index && candidates[$0].rect.insetBy(dx: -2, dy: -2).contains(inner) && candidates[$0].area > candidates[index].area }
      .min { candidates[$0].area < candidates[$1].area }
    guard let parent else { NSSound.beep(); return }
    descent.append(index)
    hold(parent)
  }

  /// Back in to whatever Up was last looking at, or, with no ascent to retrace, into the held
  /// region's first child in document order. Containment alone would not say which child to pick --
  /// a container holds many -- so a remembered descent always wins; the first child is only what
  /// makes the tree reachable inward at all when the arrows entered at the outermost region rather
  /// than at a hint.
  func descend() {
    if let child = descent.popLast() { hold(child); return }
    guard let index = heldIndex, candidates.indices.contains(index + 1),
          candidates[index + 1].depth > candidates[index].depth else { NSSound.beep(); return }
    hold(index + 1)
  }

  /// Back from the mask to the hints, with nothing typed.
  func release() {
    held = nil
    heldIndex = nil
    descent = []
    typed = ""
    joined = nil
    transcribed = false
    transcription = nil
    view.selection = nil
    view.notice = nil
    refresh()
  }

  func refresh() {
    view.typed = typed
    view.joined = joined
    view.help = help
    view.hotkey = cancelChord?.display
    view.needsDisplay = true
  }
}

func tapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  switch type {
  case .keyDown: Session.shared.key(event)
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
  /// which reads at the edge of vision in a way a dimming rectangle does not.
  private func slideOff() {
    let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
    var frame = panel.frame
    frame.origin.x = screen.frame.maxX + 1
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.35
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().setFrame(frame, display: true)
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

  let target: NSRunningApplication?
  if options.pid != 0 {
    target = NSRunningApplication(processIdentifier: options.pid)
  } else if let bundleId = options.bundleId {
    target = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
  } else {
    target = NSWorkspace.shared.frontmostApplication
  }
  guard let app = target else {
    return Outcome(code: 3, line: "app=none total_ms=\(millis(since: start))")
  }
  let name = app.localizedName ?? app.bundleIdentifier ?? "?"

  let appElement = AXUIElementCreateApplication(app.processIdentifier)
  AXUIElementSetMessagingTimeout(appElement, 1)
  // Chromium exposes nothing of the page until a client asks the application object for its role;
  // that one read is the switch. The walk asks every element below it, which covers the rest.
  _ = string(appElement, kAXRoleAttribute)
  AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  if options.enhanced {
    AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
  }

  // An app with no window open answers AXFocusedWindow with its own application element, so insist
  // on something that says it is a window.
  var window: AXUIElement?
  if let focused = attribute(appElement, kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() {
    let element = focused as! AXUIElement
    if string(element, kAXRoleAttribute) == kAXWindowRole { window = element }
  }
  if window == nil {
    window = (attribute(appElement, kAXWindowsAttribute) as? [AXUIElement])?.first
  }
  guard let windowElement = window, let windowFrame = probe(windowElement).frame, !windowFrame.isEmpty else {
    return Outcome(code: 6, line: "app=\(name) windows=0 total_ms=\(millis(since: start))")
  }

  // The window can hang off the edge of its display; only the part on a screen can be captured.
  let screens = NSScreen.screens
  guard let primary = screens.first else {
    return Outcome(code: 6, line: "screens=0 total_ms=\(millis(since: start))")
  }
  let flipBase = primary.frame.maxY
  func flip(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: flipBase - rect.maxY, width: rect.width, height: rect.height)
  }
  let screenArea = screens.map { flip($0.frame) }.reduce(CGRect.null) { $0.union($1) }
  let clip = windowFrame.intersection(screenArea)

  let walkStart = Date()
  let walk = Walk(clip: clip, options: options)
  walk.run(windowElement)
  let walkMs = millis(since: walkStart)
  let candidates = filter(walk.found, max: options.maxHints)
  let labels = hintLabels(count: candidates.count, alphabet: options.hintChars)

  if options.dump {
    print("app=\(name) pid=\(app.processIdentifier) window=(\(Int(windowFrame.minX)),\(Int(windowFrame.minY)) \(Int(windowFrame.width))x\(Int(windowFrame.height)))")
    print("visited=\(walk.visited) boxes=\(walk.found.count) candidates=\(candidates.count) walk_ms=\(walkMs)\(walk.timedOut ? " TIMED OUT" : "")")
    for (index, candidate) in candidates.enumerated() {
      let box = candidate.rect
      let subrole = candidate.subrole.isEmpty ? "" : " \(candidate.subrole)"
      let label = candidate.label.isEmpty ? "" : " \"\(candidate.label.prefix(60))\""
      print("  \(labels[index]) \(candidate.role)\(subrole) depth=\(candidate.depth) (\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height)))\(label)")
    }
    return Outcome(code: 0, line: "")
  }

  guard !candidates.isEmpty else {
    return Outcome(code: 4, line: "app=\(name) visited=\(walk.visited) candidates=0 walk_ms=\(walkMs) total_ms=\(millis(since: start))")
  }

  let overlayFrame = screens.map { $0.frame }.reduce(CGRect.null) { $0.union($1) }
  let overlay = NSWindow(contentRect: overlayFrame, styleMask: .borderless, backing: .buffered, defer: false)
  overlay.isOpaque = false
  overlay.backgroundColor = .clear
  overlay.hasShadow = false
  overlay.ignoresMouseEvents = true
  overlay.level = .screenSaver
  overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

  let view = HintView(frame: CGRect(origin: .zero, size: overlayFrame.size))
  view.boxes = candidates.enumerated().map { index, candidate in
    (labels[index], flip(candidate.rect).offsetBy(dx: -overlayFrame.minX, dy: -overlayFrame.minY))
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
  Session.shared = session

  guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: tapCallback,
    userInfo: nil)
  else {
    overlay.orderOut(nil)
    return Outcome(code: 2, line: "app=\(name) tap=failed total_ms=\(millis(since: start))")
  }
  let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
  CGEvent.tapEnable(tap: tap, enable: true)

  // The tap swallows every key while it is up, so a session that somehow never ends would take the
  // keyboard with it. Run in slices and give up after this long rather than trusting it to stop.
  var sessionDeadline = Date().addingTimeInterval(15)
  while session.chosen == nil && !session.cancelled && Date() < sessionDeadline {
    CFRunLoopRunInMode(.defaultMode, 0.25, false)
    if let extended = session.deadline { sessionDeadline = extended; session.deadline = nil }
  }

  session.request?.cancel()
  CGEvent.tapEnable(tap: tap, enable: false)
  CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
  CFMachPortInvalidate(tap)
  overlay.orderOut(nil)

  // The copy key takes no picture, so there is nothing to wait for the compositor over.
  if session.copying, let chosen = session.chosen {
    // Whatever is on screen is what is copied: the transcription if Shift-T put it there, the joined
    // run if Shift-J did, and otherwise the text laid out the way the region laid it out.
    let text = session.joined ?? regionText(chosen, budgetMs: options.budgetMs)
    let box = chosen.rect
    guard !text.isEmpty else {
      return Outcome(code: 13, line: "app=\(name) role=\(chosen.role) copy=text chars=0 rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) total_ms=\(millis(since: start))")
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    return Outcome(code: 0, line: "app=\(name) role=\(chosen.role) copy=\(session.transcribed ? "transcribed" : session.joined == nil ? "text" : "joined") chars=\(text.count) lines=\(text.split(separator: "\n").count) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) candidates=\(candidates.count) walk_ms=\(walkMs) total_ms=\(millis(since: start))")
  }

  // Give the window server a beat to composite the overlay away before the shutter.
  CFRunLoopRunInMode(.defaultMode, Double(options.delayMs) / 1000, false)

  guard let chosen = session.chosen else {
    return Outcome(code: 11, line: "app=\(name) cancelled=true\(session.settings ? " settings=true" : "") walk_ms=\(walkMs) total_ms=\(millis(since: start))", settings: session.settings)
  }
  let box = chosen.rect
  let destination: Destination = session.toClipboard ? .clipboard : options.destination
  let path = destination.resolve()
  guard capture(box, to: path) else {
    let hint = CGPreflightScreenCaptureAccess() ? "" : " screen_recording=false"
    return Outcome(code: 12, line: "app=\(name) capture=failed\(hint) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) total_ms=\(millis(since: start))")
  }

  // Read back for the toast, which only a shot with a file behind it gets.
  let image = options.toast ? path.flatMap({ NSImage(contentsOfFile: $0) }) : nil

  let label = chosen.label.isEmpty ? "" : " label=\"\(chosen.label.prefix(60))\""
  return Outcome(code: 0, line: "app=\(name) role=\(chosen.role)\(label) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) candidates=\(candidates.count) visited=\(walk.visited) walk_ms=\(walkMs) total_ms=\(millis(since: start)) out=\(path ?? "clipboard")", image: image, path: path)
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

enum Settings {
  static var chord: Chord {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: "hotKeyCode") != nil else { return HotKey.fallback }
    return Chord(
      keyCode: UInt32(defaults.integer(forKey: "hotKeyCode")),
      modifiers: UInt32(defaults.integer(forKey: "hotKeyModifiers")))
  }

  static func setChord(_ chord: Chord) {
    UserDefaults.standard.set(Int(chord.keyCode), forKey: "hotKeyCode")
    UserDefaults.standard.set(Int(chord.modifiers), forKey: "hotKeyModifiers")
  }

  /// Where captures are saved. Unset, this follows wherever macOS has been told to put its own
  /// screenshots -- the same folder the user already looks in -- and falls back to the Desktop,
  /// which is where macOS puts them when it has been told nothing.
  static var saveDirectory: String {
    get {
      if let chosen = UserDefaults.standard.string(forKey: "saveDirectory"), !chosen.isEmpty { return chosen }
      if let system = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !system.isEmpty {
        return (system as NSString).expandingTildeInPath
      }
      return NSHomeDirectory() + "/Desktop"
    }
    set { UserDefaults.standard.set(newValue, forKey: "saveDirectory") }
  }

  /// True while no folder has been chosen, so captures are still landing wherever macOS is putting
  /// its own screenshots. The settings window uses it to know whether there is anything to undo.
  static var followsSystemFolder: Bool {
    (UserDefaults.standard.string(forKey: "saveDirectory") ?? "").isEmpty
  }

  /// Forgets a chosen folder. Choosing one is otherwise a one-way door: the panel always writes a
  /// path, so without this the folder macOS is using can never be got back to by name.
  static func followSystemFolder() {
    UserDefaults.standard.removeObject(forKey: "saveDirectory")
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

/// Click it, press a chord, it takes it. A chord with no modifier is refused: a bare key as a global
/// hotkey would swallow that key everywhere.
final class RecorderView: NSView {
  var chord: Chord { didSet { needsDisplay = true } }
  var onChange: ((Chord) -> Void)?
  private var recording = false

  init(chord: Chord) {
    self.chord = chord
    super.init(frame: .zero)
  }
  required init?(coder: NSCoder) { nil }

  override var acceptsFirstResponder: Bool { true }

  override func mouseDown(with event: NSEvent) {
    recording = true
    window?.makeFirstResponder(self)
    needsDisplay = true
  }

  override func resignFirstResponder() -> Bool {
    recording = false
    needsDisplay = true
    return true
  }

  // A chord that is also a menu shortcut would be eaten before keyDown without this.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard recording else { return false }
    keyDown(with: event)
    return true
  }

  override func keyDown(with event: NSEvent) {
    guard recording else { return super.keyDown(with: event) }
    if event.keyCode == UInt16(kVK_Escape) {
      recording = false
      window?.makeFirstResponder(nil)
      return
    }
    let modifiers = carbonModifiers(event.modifierFlags)
    guard modifiers != 0 else { NSSound.beep(); return }
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

    let text = NSAttributedString(string: recording ? "Press a chord…" : chord.display, attributes: [
      .font: NSFont.systemFont(ofSize: 14, weight: .medium),
      .foregroundColor: recording ? NSColor.secondaryLabelColor : NSColor.labelColor,
    ])
    let size = text.size()
    text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
  }
}

final class SettingsWindow: NSWindowController {
  private var recorder: RecorderView!
  private let folder = NSTextField(labelWithString: "")
  private let resetFolder = NSButton(title: "Reset", target: nil, action: nil)
  private let status = NSTextField(labelWithString: "")
  private var permissionRows: [(Permissions, NSTextField, NSButton)] = []
  private var permissionTimer: Timer?
  /// When each permission was last asked for, so a request that visibly did nothing can offer the
  /// stale-record escape rather than repeating itself.
  private var askedAt: [Int: Date] = [:]
  var onChordChange: (() -> Void)?

  convenience init() {
    // The stack is pinned to the top and the height is a constant, so the window does not shrink to
    // its content: a row added or removed here is a row's worth of height to adjust by hand, or the
    // window keeps a gap where the row was.
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Axshot"
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
    folder.font = .systemFont(ofSize: 12)
    folder.textColor = .secondaryLabelColor
    // Truncate the head: the tail of a path is the part that identifies it.
    folder.lineBreakMode = .byTruncatingHead
    let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseFolder))
    let folderCaption = NSTextField(labelWithString: "Save to")
    folderCaption.font = .systemFont(ofSize: 13)
    // Always on screen, and dimmed while there is nothing to undo: a control that appears only
    // once it can be used is one the user has to discover by making the change it reverses.
    resetFolder.target = self
    resetFolder.action = #selector(followSystemFolder)
    resetFolder.toolTip = "Go back to the macOS screenshot folder."
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
    status.textColor = .secondaryLabelColor
    status.lineBreakMode = .byWordWrapping
    status.maximumNumberOfLines = 2

    let launch = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunch(_:)))
    launch.state = SMAppService.mainApp.status == .enabled ? .on : .off

    var permissionViews: [NSView] = [separator()]
    let spaces = NSTextField(labelWithString: "If no dialog appears, check your other Spaces — macOS opens it wherever it likes.")
    spaces.font = .systemFont(ofSize: 11)
    spaces.textColor = .tertiaryLabelColor
    for permission in [Permissions.accessibility, .screenRecording] {
      let caption = NSTextField(labelWithString: permission.title)
      caption.font = .systemFont(ofSize: 13)
      let state = NSTextField(labelWithString: "")
      state.font = .systemFont(ofSize: 11)
      let button = NSButton(title: "Grant…", target: self, action: #selector(grant(_:)))
      button.tag = permission == .accessibility ? 0 : 1

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

    let relaunch = NSButton(title: "Relaunch", target: self, action: #selector(relaunchApp))
    relaunch.toolTip = "Accessibility only takes effect after a restart."
    let relaunchRow = NSStackView(views: [NSTextField(labelWithString: "After granting Accessibility"), relaunch])
    relaunchRow.orientation = .horizontal
    relaunchRow.spacing = 12

    let stack = NSStackView(
      views: [hotKeyRow, folderRow, launch] + permissionViews + [spaces, relaunchRow, status])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
    stack.translatesAutoresizingMaskIntoConstraints = false

    // The stack goes inside the content view rather than being it: constraining a view to its own
    // anchors is what an NSWindowController does just before it fails to show anything.
    let container = NSView()
    container.addSubview(stack)
    window.contentView = container
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
      status.widthAnchor.constraint(equalToConstant: 456),
    ])
    window.center()
    refreshFolder()
    refreshPermissions()
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

  private func refreshPermissions() {
    for (permission, state, button) in permissionRows {
      let granted = permission.granted
      state.stringValue = granted ? "Granted" : "Not granted"
      state.textColor = granted ? .systemGreen : .systemOrange
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
    status.stringValue = HotKey.shared.register(chord)
      ? "" : "\(chord.display) is already taken by another app."
    onChordChange?()
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

  @objc private func toggleLaunch(_ sender: NSButton) {
    do {
      if sender.state == .on { try SMAppService.mainApp.register() }
      else { try SMAppService.mainApp.unregister() }
    } catch {
      sender.state = sender.state == .on ? .off : .on
      status.stringValue = "Could not change the login item: \(error.localizedDescription)"
    }
  }
}

extension SettingsWindow {
  /// Escape closes the window, the way a panel does. It arrives here only when nothing in front of
  /// it wanted it: a recorder mid-chord takes its own Escape to abandon the recording, and stops.
  override func cancelOperation(_ sender: Any?) {
    window?.performClose(sender)
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

// MARK: - Menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var settings: SettingsWindow?
  private var help: HelpWindow?
  private var busy = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Axshot")

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
