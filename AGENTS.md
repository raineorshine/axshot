# Axshot

A macOS menu bar app that finds screenshot regions in the accessibility tree. One Swift file, three
shell scripts, no dependencies.

**`axshot.swift`'s header comment is the reference for the tool itself** — every option, and the
reasoning behind each moving part. Read it before changing behaviour; it is kept current and this
file does not repeat it.

## Guides

- [docs/permissions.md](docs/permissions.md) — what TCC considers "this app", why a grant survives
  one rebuild and not another, and the three ways granting appears to fail when it has not.
- [docs/testing.md](docs/testing.md) — driving the app with no human at the keyboard, and the
  environment failures that look like product bugs.

Two skills live in `.github/skills/`: `test` installs this branch's build into the live app under a
mutex and drives it, `ship` lands the change on `origin/main`. Read the one that matches what you are
about to do, before doing it.

## Driving the app on a live machine

The user is at the keyboard doing their own work while a test runs, and every drive of the real app
brings some window to the front. Hold the foreground for a second, not for a stretch: activate,
send the hint, send Return, and let go. Everything that is not the keystrokes — reading `--dump`
output, checking the PNG, deciding what the labels mean — happens before the sequence starts or
after the capture lands, never in the middle of it with a window parked in front of whatever the
user was typing into.

## Layout

| | |
|---|---|
| `axshot.swift` | everything: walk, filter, overlay, hotkeys, settings, CLI |
| `build.sh` | compiles, assembles `Axshot.app`, signs it, links `bin/axshot`, installs it; `--no-install` stops before the install |
| `create-signing-cert.sh` | creates the signing identity once; idempotent |
| `scripts/axshot-test-lock.sh` | the mutex over the installed app and the keyboard, and the queue for it |

The same binary is the app when launched with no arguments and a CLI when given any. Build output
(`Axshot.app/`, `bin/`, `.claude/`) is generated and ignored.

There is one installed app, `/Applications/Axshot.app`, and the permission grants belong to its
signature rather than its path — so any build signed with the same certificate satisfies them
wherever it sits. What is genuinely single is the running instance, which owns the global hotkeys,
and the login item, which names one bundle path. `build.sh` compiles inside the checkout and installs
from there through the lock, which refuses while another session is driving the app. A session that
wants a held lock does not ask again later: `wait` queues it and blocks until the release hands it
over, so parallel worktrees test in the order they arrived.

## Session titles

A lifecycle prefix on the session title says what a session is doing while it is doing it, so the
sidebar answers "which chat is holding the lock" without opening any of them. One prefix at a time,
replaced rather than stacked, and never reported in the response. Every title carries one: a title
without a prefix says nothing about the session, and the sidebar cannot tell it from a chat that
never had a stage at all. A session is named by the harness and so begins without one; putting the
first prefix on that inherited title is part of the first response, not something to wait for a
stage change to prompt. A prefix comes off only when another replaces it, so a session that has
nothing left to do keeps the one for the last stage it reached.

| | |
|---|---|
| `⏳ ` | implementing — the weakest of them; every other prefix takes precedence |
| `🔓 ` | about to take the lock — including queued and blocked on it — or just released it |
| `🔒 ` | holding the lock; the installed app is this branch's build |
| `📦 ` | tested, passed the user's own hands-on look, and shippable without re-testing |
| `🚀 ` | shipping, and shipped — it stays until the session starts something else |
| `🚙 ` | parked: the work is sound and waiting on the user — a decision, or a hands-on look |
| `🪦 ` | dead end — kept for the findings, not to resume |
| `📚 ` | extracting learnings into `AGENTS.md`, `docs/` or the skills |

Set a prefix when the stage *starts*, not when it succeeds, and correct it if the stage falls over: a
title that only becomes true at the end is blank for the whole stretch the sidebar is there to
describe. `📚 ` goes on the moment a `learn` skill is invoked, before anything is read. The lock
and ship prefixes are set by the skills that own them; the rest are set by hand, and nothing
reconciles a title against reality. Handing back is itself a stage: a response that closes on
something for the user to do — test it, look at it, decide — is a park, and `🚙 ` goes on before
that response, since the idle dot cannot tell "waiting on you" from "given up on".

This vocabulary, and the worktree-and-lock workflow around it, came from the sibling `karabiner`
repo; its `docs/workflow.md` is where the reasoning lives, and where to look first when a convention
here reads as thinner than it should.

## Settled decisions

These were argued out and measured. Reopen one only with a reason, not a preference; each is
explained where it is implemented.

- **Nothing is cached between captures.** The tree is walked on demand every time. A resident cache
  would save a fraction of what the capture alone costs, and would keep every Chromium app's
  accessibility engine switched on for as long as the app runs.
- **Only regions that are actually on screen are offered**, clipped to the focused window. An
  element scrolled out of view has a frame that would photograph something else.
- **Only text that was on screen is copied.** The tree carries names written for screen readers
  alongside the words a person can read, and no attribute separates them — the same field holds a
  button's visible label and an icon's stand-in name — so the test is whether the text would have
  fitted in its own element. A geometric answer to a question the tree does not answer.
- **A key is matched by its position or by its letter, according to which one it is.** HJKL and the
  hotkey chords are hand shapes and are read as physical keys, so they stay where the hand is on any
  layout; a key chosen because of the word it stands for is read as the letter the layout types, so
  it stays where the word is. Adding a key means deciding which of the two it is before deciding
  where it goes.
- **Regions are picked by hint, not named.** Naming would let the walk stop early, but most of what
  is worth capturing carries no label.
- **The arrows are two axes, not four directions.** Up and Down move along the held region's own
  line of ancestors and descendants; Left and Right move across it and skip that line entirely. A
  step that lands on a parent or a child is the same region drawn bigger or smaller, which is a
  keystroke the other axis already spends.
- **One hotkey; the hold decides where the shot goes.** The letter masks everything outside the
  region rather than firing the shutter, because the region came from a tree the app describes and
  the one thing worth seeing before the capture is what that tree handed over. Which destination a
  region wants is only clear once it is on screen, so it is chosen at the exit and not at the
  press: Return files the PNG, ⌘C puts that picture on the clipboard, ⌘⇧C puts the region's own
  text there instead — the same tree holds the words, and they are the better carrier whenever the
  point was what it said. A second tap of the hotkey cancels, since the tap sits ahead of the
  hotkey manager and sees the chord before Carbon does; the press that opened the session is the
  one already under the fingers.
- **The app never takes focus.** Hint keys come from an event tap. A focused target redraws its
  title bar inactive, and the screenshot would show that.
- **The hotkey is a Carbon `RegisterEventHotKey`.** It is the only mechanism that reserves the chord
  system-wide and the only one needing no permission.
- **A test lock that cannot move gives up rather than being made unstuckable.** Every way the queue
  can stall ends in a bound or a recovery instead of a mechanism that prevents it: a wait gives up on
  its own deadline and reports what it was waiting on, `dequeue` clears a queue whose head nobody can
  move, `break` recovers an abandoned lock. Handing the lock straight to the next ticket, so that it
  is never unheld, was weighed and turned down — it means rewriting ownership onto a process that has
  not woken yet, tracking that process's liveness, and refreshing the snapshot wherever the live app
  no longer matches it, to close a window that a refusal already covers.

## Changing the region filter

`--dump` is the whole feedback loop: it prints what would be hinted, with the walk cost, and never
draws an overlay. Tune against it before looking at pixels; [the README](README.md#tuning-the-filter)
reads a sample of its output line by line.

Prefer changing the filter's passes over changing `--min-size`. The tree is mostly nested containers
that repeat their child's box, and the collapse that removes them is what decides whether the
overlay is legible; a size floor only hides small things.

When quoting costs, measure the walk and the capture together. The capture is the larger half by an
order of magnitude, so a change that halves the walk is invisible, and a benchmark that reports only
the walk will justify work that no one can perceive.
