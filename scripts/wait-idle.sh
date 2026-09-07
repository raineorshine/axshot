#!/bin/sh
# Wait for the user to stop typing before taking the machine.
#
# The user is at their own keyboard while a test runs. Every drive of the real
# app brings a window to the front and posts keys into whatever holds focus, so
# a sequence started mid-sentence steals the keystroke they were in the middle
# of and lands the rest of the hint in their editor. This is the gate that goes
# in front of that: foregrounding an app, opening the overlay, or otherwise
# taking control waits here until the keyboard has been quiet.
#
# Quiet means *typing*, not input in general -- seconds since the last hardware
# keyDown. That is what was asked for, and it is also the only measure that
# settles: a mouse-inclusive gate never opens, because ambient cursor movement
# resets it faster than any threshold can clear.
#
# `.hidSystemState` is the source rather than `.combinedSessionState` because
# the combined clock counts keys posted into the session -- osascript's among
# them -- so a test driving the app would spend its time resetting its own gate.
#
# What no source separates is a real keypress from one this session posted to
# `.cghidEventTap`, the route docs/testing.md uses to hold a chord: those move
# the hid clock exactly as a person's would. So this is a gate to pass through
# *before* a burst of keystrokes, not something to call between them -- run
# straight after your own drive it spends the whole threshold waiting on its own
# echo. Which is AGENTS.md's rule about holding the foreground for the
# keystrokes and no longer, arriving from the other direction.
#
#   wait-idle.sh [seconds] [--max ceiling]
#
# Exits 0 once the keyboard has been quiet for `seconds` (default 3), silently
# if it was already quiet. Exits 1 if it is still not quiet after `ceiling`
# seconds (default 120): the user is working, and the answer to that is to say
# so and let them say when, not to take the foreground anyway. Exits 2 if it
# could not tell -- which is never a licence to proceed as though it had passed.
set -eu

QUIET=3
CEILING=120

while [ $# -gt 0 ]; do
  case $1 in
    --max) CEILING=${2:?--max needs a value}; shift 2 ;;
    --max=*) CEILING=${1#--max=}; shift ;;
    -h|--help) sed -n '2,/^set -eu$/p' "$0" | sed '$d; s/^#\{1,\} \{0,1\}//'; exit 0 ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) QUIET=$1; shift ;;
  esac
done

command -v swift >/dev/null 2>&1 ||
  { printf 'wait-idle: no swift in PATH; cannot read the keyboard clock\n' >&2; exit 2; }

AXSHOT_IDLE_QUIET=$QUIET AXSHOT_IDLE_CEILING=$CEILING swift - <<'SWIFT'
import CoreGraphics
import Foundation

let env = ProcessInfo.processInfo.environment
let quiet = Double(env["AXSHOT_IDLE_QUIET"] ?? "") ?? 3
let ceiling = Double(env["AXSHOT_IDLE_CEILING"] ?? "") ?? 120

func say(_ s: String) { FileHandle.standardError.write(Data(s.utf8)) }

let start = Date()
var announced = false
while true {
  // Hardware keyDown only: see the header for why not the combined source.
  let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
  if idle >= quiet {
    if announced { say(String(format: "wait-idle: quiet after %.1fs\n", Date().timeIntervalSince(start))) }
    exit(0)
  }
  if Date().timeIntervalSince(start) >= ceiling {
    say(String(format: "wait-idle: still typing after %.0fs -- not taking the foreground\n", ceiling))
    exit(1)
  }
  if !announced {
    announced = true
    say(String(format: "wait-idle: waiting for %.0fs of quiet before taking the keyboard...\n", quiet))
  }
  usleep(150_000)
}
SWIFT
