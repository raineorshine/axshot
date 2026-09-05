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
// same fingers rather than sending the hand off to find Escape.
//
// A hold has three ways out, and one hotkey, because which one a region wants is only clear once
// the region is on screen and masked: Return writes the PNG to the save folder, Command-C puts the
// same picture on the clipboard, and Command-Shift-C puts the region's *text* there instead and
// takes no picture at all -- the tree that gave the box has the words in it too, and a screenshot
// of a paragraph is a poor way to carry the paragraph. The two clipboard exits share a letter
// because they share a destination; Shift is what asks for the words. Each hold restarts the
// session deadline, which is a decision the run loop could not have known to wait for.
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
// window closes, so Cmd-W leaves nothing but the menu bar item behind and the app keeps running.
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
func regionLines(_ element: AXUIElement, clip: CGRect, deadline: Date, path: inout Set<ElementKey>) -> [String] {
  if Date() > deadline { return [] }
  let key = ElementKey(element: element)
  guard path.insert(key).inserted else { return [] }
  defer { path.remove(key) }

  let info = probe(element)
  if let frame = info.frame, !frame.isEmpty, !frame.intersects(clip) { return [] }

  // Read raw rather than reusing the probe's label, which has had its newlines flattened out for
  // the one line the dump prints.
  let own = [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute]
    .lazy.compactMap { string(element, $0) }.first { !$0.isEmpty }

  let speaksForItself = ["AXStaticText", "AXTextField", "AXTextArea"].contains(info.role)
  if info.children.isEmpty || (speaksForItself && own != nil) {
    return own.map { [$0] } ?? []
  }

  var lines: [String] = []
  for child in info.children { lines += regionLines(child, clip: clip, deadline: deadline, path: &path) }
  // A container whose children said nothing still has its own name to give.
  if lines.isEmpty, let own { lines = [own] }
  return lines
}

func regionText(_ candidate: Candidate, budgetMs: Int) -> String {
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
  return kept.joined(separator: "\n")
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
  override var isFlipped: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.set()
    dirtyRect.fill()

    if let selection {
      // Even-odd over the whole overlay minus the region, so the mask is one fill and the region
      // is left completely untouched rather than drawn over at a low alpha.
      let mask = NSBezierPath(rect: bounds)
      mask.append(NSBezierPath(rect: selection))
      mask.windingRule = .evenOdd
      NSColor(calibratedWhite: 0, alpha: 0.55).setFill()
      mask.fill()

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
  var cancelled = false
  /// The chord that opened this session. The tap is inserted ahead of the hotkey manager, so it
  /// sees that chord before Carbon does and a second press can close what the first opened.
  var cancelChord: Chord?
  /// A confirmation step the run loop could not have known to wait for; it restarts the deadline.
  var deadline: Date?
  var view: HintView!

  func key(_ event: CGEvent) {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    if keyCode == 53 { cancelled = true; CFRunLoopStop(CFRunLoopGetCurrent()); return }  // escape
    // The hotkey again, at any point: a press that turned out to be a mistake is undone by
    // repeating it, without the hand having to find Escape. This has to come before the Command
    // branch below, which would otherwise swallow a chord carrying Command and do nothing with it.
    if let chord = cancelChord, keyCode == Int64(chord.keyCode),
       carbonModifiers(event.flags) == chord.modifiers {
      cancelled = true
      CFRunLoopStop(CFRunLoopGetCurrent())
      return
    }
    // The two chords that end a hold, and nothing else: every other chord under Command is
    // swallowed rather than acted on, since the tap reports "c" whether or not Command was down
    // with it and an unfiltered Command-C would otherwise be typed at the hints as a plain letter.
    if event.flags.contains(.maskCommand) {
      guard let region = held, keyCode == 8 else { return }  // c
      // Both ends go to the clipboard, which is why they are the same letter; Shift asks for the
      // words rather than a picture of them.
      if event.flags.contains(.maskShift) { copying = true } else { toClipboard = true }
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
    var length = 0
    var characters = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &characters)
    guard length == 1, let scalar = Unicode.Scalar(characters[0]) else { return }
    let typedCharacter = String(Character(scalar)).lowercased()

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
    deadline = Date().addingTimeInterval(30)
    refresh()
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
    view.selection = nil
    refresh()
  }

  func refresh() {
    view.typed = typed
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

  CGEvent.tapEnable(tap: tap, enable: false)
  CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
  CFMachPortInvalidate(tap)
  overlay.orderOut(nil)

  // The copy key takes no picture, so there is nothing to wait for the compositor over.
  if session.copying, let chosen = session.chosen {
    let text = regionText(chosen, budgetMs: options.budgetMs)
    let box = chosen.rect
    guard !text.isEmpty else {
      return Outcome(code: 13, line: "app=\(name) role=\(chosen.role) copy=text chars=0 rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) total_ms=\(millis(since: start))")
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    return Outcome(code: 0, line: "app=\(name) role=\(chosen.role) copy=text chars=\(text.count) lines=\(text.split(separator: "\n").count) rect=(\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))) candidates=\(candidates.count) walk_ms=\(walkMs) total_ms=\(millis(since: start))")
  }

  // Give the window server a beat to composite the overlay away before the shutter.
  CFRunLoopRunInMode(.defaultMode, Double(options.delayMs) / 1000, false)

  guard let chosen = session.chosen else {
    return Outcome(code: 11, line: "app=\(name) cancelled=true walk_ms=\(walkMs) total_ms=\(millis(since: start))")
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

  /// True while the folder is still whatever macOS is using, so the settings window can say so.
  static var followsSystemFolder: Bool {
    (UserDefaults.standard.string(forKey: "saveDirectory") ?? "").isEmpty
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
  private let followingSystem = NSTextField(labelWithString: "")
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
    let folderRow = NSStackView(views: [folderCaption, folder, choose])
    folderRow.orientation = .horizontal
    folderRow.spacing = 12
    NSLayoutConstraint.activate([
      folderCaption.widthAnchor.constraint(equalToConstant: 150),
      // Without a width the folder path stretches the row past both edges of the window.
      folder.widthAnchor.constraint(equalToConstant: 200),
    ])

    followingSystem.font = .systemFont(ofSize: 11)
    followingSystem.textColor = .tertiaryLabelColor

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
      views: [hotKeyRow, folderRow, followingSystem, launch] + permissionViews + [spaces, relaunchRow, status])
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
    followingSystem.stringValue = Settings.followsSystemFolder
      ? "Following the macOS screenshot location." : ""
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

extension SettingsWindow: NSWindowDelegate {
  /// Closing the window is not quitting: the app drops back to being an accessory, which takes it
  /// out of the App Switcher and the Dock and leaves the menu bar item and the hotkeys running.
  func windowWillClose(_ notification: Notification) {
    permissionTimer?.invalidate()
    NSApp.setActivationPolicy(.accessory)
  }
}

// MARK: - Menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var settings: SettingsWindow?
  private var busy = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Axshot")

    let menu = NSMenu()
    let capture = NSMenuItem(title: HotKey.title, action: #selector(captureFromMenu), keyEquivalent: "")
    capture.target = self
    menu.addItem(capture)
    menu.addItem(.separator())
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
    guard outcome.code != 0 && outcome.code != 11 else { return }

    let alert = NSAlert()
    alert.messageText = "Axshot could not capture that."
    alert.informativeText = outcome.line
    alert.alertStyle = .warning
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
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
