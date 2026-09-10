# Axshot

A macOS menu bar app that finds screenshot regions in the accessibility tree. One Swift file, three
shell scripts, no dependencies.

**`axshot.swift`'s header comment is the reference for the tool itself** — every option, and the
reasoning behind each moving part. Read it before changing behaviour; it is kept current and this
file does not repeat it.

Current on `origin/main`, that is, which a worktree holds only as of its cut. A tuned constant is
exactly what another session re-measures and moves, and the README's `--dump` sample ages with it —
so `git fetch` before quoting a default or a number to the user, not only before shipping. A
question answered off the worktree is answered as of whenever the worktree was made, and by the time
the rebase conflicts on it the user has already decided.

## Guides

- [docs/decisions.md](docs/decisions.md) — what was argued out and measured about the walk, the
  keyboard, the overlay and the workflow. Reopen one only with a reason, not a preference: read it
  before changing behaviour that reads as arbitrary, because most of it is not.
- [docs/filter.md](docs/filter.md) — changing which regions are offered. `--dump` is the whole
  feedback loop, and a rule about what is *drawn* wants a picture rather than a clean number.
- [docs/accessibility.md](docs/accessibility.md) — what a new control owes the tree and the
  keyboard, and the AppKit defaults that leave one drawn correctly and reachable by nothing.
- [docs/permissions.md](docs/permissions.md) — what TCC considers "this app", why a grant survives
  one rebuild and not another, and the three ways granting appears to fail when it has not.
- [docs/testing.md](docs/testing.md) — driving the app with no human at the keyboard, and the
  environment failures that look like product bugs.
- [docs/cloud-sessions.md](docs/cloud-sessions.md) — what a session with no Mac does with the change
  instead of testing it: the handoff card, and everywhere it has to say the change is untested.

## Skills

Two skills live in `.github/skills/`: `test` installs this branch's build into the live app under a
mutex and drives it, `ship` lands the change on `origin/main`. Read the one that matches what you are
about to do, before doing it — `.github/skills/` is not a directory the `Skill` tool loads from, so
these are files to open and follow by hand, and asking for one by name only reports that no such
skill exists. A skill that describes a command its script does not have is the sign of one of these
being clobbered rather than of a stale document, and the repair is in git rather than in a rewrite:
`git log --oneline -- <path>` finds the commit that added it, and a later copy that is byte-identical
to the version from before confirms it was reverted wholesale. Take that file back whole where
nothing has touched it since, and reverse the bad commit's hunks with `git apply -R --3way` where
something has. A change to anything the user sees or touches is always about to be tested, and nobody
has to ask for it: a clean compile is not a place to stop and hand back, because the thing the user
would look at is not on their machine until `test` has put it there. That holds for a session on the
user's Mac, which is the only place either skill can run; one that is somewhere else hands the
testing over instead, and "When there is no Mac" below is what it does with the change.

## Layout

| | |
|---|---|
| `axshot.swift` | everything: walk, filter, overlay, hotkeys, settings, CLI |
| `build.sh` | compiles, assembles `Axshot.app`, signs it, links `bin/axshot`, installs it; `--no-install` stops before the install |
| `create-signing-cert.sh` | creates the signing identity once; idempotent |
| `scripts/axshot-test-lock.sh` | the mutex over the installed app and the keyboard, and the queue for it |
| `scripts/wait-idle.sh` | blocks until the user has stopped typing, in front of anything that takes the foreground |

The same binary is the app when launched with no arguments and a CLI when given any — the same
bytes, but not the same process identity. `bin/axshot` is a symlink into the bundle and dyld reports
the symlink rather than what it points at, so on the command line `Bundle.main` is `bin/` and carries
no identifier at all. Anything that would otherwise ask the bundle who this is — the preferences
domain, the identifier handed to `tccutil` — has to name what it wants instead. Which identity a run
picked up is a shell question, and [docs/testing.md](docs/testing.md#asking-who-the-process-is) is
how to ask it. Build output (`Axshot.app/`, `bin/`, `.claude/`) is generated and ignored.

There is one installed app, `/Applications/Axshot.app`, and the permission grants belong to its
signature rather than its path — so any *bundle* signed with the same certificate satisfies them
wherever it sits. A loose binary outside one does not, however it was signed: the requirement names
the bundle identifier, and a bare Mach-O carries none. What is genuinely single is the running
instance, which owns the global hotkeys, and the login item, which names one bundle path. `build.sh`
compiles inside the checkout and installs from there through the lock, which refuses while another
session is driving the app. A session that wants a held lock does not ask again later: `wait` queues
it and blocks until the release hands it over, so parallel worktrees test in the order they arrived.

## Driving the app on a live machine

The user is at the keyboard doing their own work while a test runs, and every drive of the real app
brings some window to the front. **Wait for them to stop before you start.**
`scripts/wait-idle.sh` blocks until nobody has typed for three seconds, and goes in front of every
activation, every overlay and every posted keystroke: a burst begun mid-sentence takes the letter
they were in the middle of and lands the rest of the hint in their editor. It gives up rather than
waiting forever — someone still typing after two minutes is working, and the answer to that is to
park and let them name the moment, not to take the foreground anyway.

It gates the *start* of a burst and not the keys inside one, because no clock on the machine
separates a person's keypress from one this session posted;
[docs/testing.md](docs/testing.md#waiting-for-the-keyboard) is the measurement and its edges.

And say so while you hold it. `bin/axshot --driving on` opens a burst and `bin/axshot --driving off`
closes it. While it is on, the app draws a pink border around every screen, so a window arriving
uninvited reads as this session rather than as the machine misbehaving — and closing the burst hands
the foreground back to whoever had it before the burst took it. Both ends belong to the burst and
not to the test: a build the user is trying by hand is their own session at their own keyboard, and
the border is off for it.

Then hold the foreground for a second, not for a stretch: activate, send the hint, send Return, and
let go. Everything that is not the keystrokes — reading `--dump` output, checking the PNG, deciding
what the labels mean — happens before the sequence starts or after the capture lands, never in the
middle of it with a window parked in front of whatever the user was typing into. What a run has to
undo before it ends is the last section of
[docs/testing.md](docs/testing.md#leaving-the-machine-as-you-found-it).

## When there is no Mac

Some sessions run in a Linux container holding a fresh clone and nothing else — no `swiftc`, no
`codesign`, no `osascript`, no `screencapture`, no `/Applications` at all. `uname -s` is the cheap
definitive check and it belongs before the work rather than after: anything other than `Darwin`
cannot build, install, drive or photograph the app, so neither `test` nor `ship` is a cloud
session's to run and the change is handed off untested instead.
[docs/cloud-sessions.md](docs/cloud-sessions.md) is what such a session does with it.

## Session titles

A lifecycle prefix on the session title says what a session is doing while it is doing it, so the
sidebar answers "which chat is holding the lock" without opening any of them. One prefix at a time,
replaced rather than stacked, and never reported in the response. Every title carries one: a title
without a prefix says nothing about the session, and the sidebar cannot tell it from a chat that
never had a stage at all. A session is named by the harness and so begins without one; putting the
first prefix on that inherited title is part of the first response, not something to wait for a
stage change to prompt. A prefix comes off only when another replaces it, so a session that has
nothing left to do keeps the one for the last stage it reached.

**Ask which session this is before renaming one.** `get_session "self"` is the only answer, and it
changes under a fork: a forked session carries the whole transcript, the id it read earlier in that
transcript, and a different id of its own, so a rename that reuses the remembered one retitles the
session it forked *from* — which is generally the one still holding the lock, and whose title is
therefore the one the sidebar most needs to be true. A fork also starts in the worktree of whatever
session it forked from. Nothing stops a branch being checked out there, and it moves that worktree
under the other session's feet; put it back on the branch it was on when the work is landed.

| | |
|---|---|
| `⏳ ` | implementing — the weakest of them; every other prefix takes precedence |
| `🔓 ` | about to take the lock — including queued and blocked on it — or just released it |
| `🔒 ` | holding the lock; the installed app is this branch's build |
| `📦 ` | tested, and shippable without re-testing |
| `🚀 ` | shipping, and shipped — it stays until the session starts something else |
| `🚙 ` | parked: the work is sound and waiting on the user — a decision, or a look at a build already in front of them |
| `🪦 ` | dead end — kept for the findings, not to resume |
| `📚 ` | extracting learnings into `AGENTS.md`, `docs/` or the skills |

Set a prefix when the stage *starts*, not when it succeeds, and correct it if the stage falls over: a
title that only becomes true at the end is blank for the whole stretch the sidebar is there to
describe. `📚 ` goes on the moment a `learn` skill is invoked, before anything is read. The lock
and ship prefixes are set by the skills that own them; the rest are set by hand, and nothing
reconciles a title against reality. Handing back is itself a stage: a response that closes on
something for the user to do — test it, look at it, decide — is a park, and `🚙 ` goes on before
that response, since the idle dot cannot tell "waiting on you" from "given up on". Waiting on a
hands-on look is the exception: the lock is held and the installed app is this branch's build for as
long as they are looking, so that stays `🔒 `, and it is `🚙 ` only once there is nothing to hold.

A cloud session never reaches `🔒 `, `📦 ` or `🚀 `: it holds no lock, tests nothing and ships
nothing. It ends at `🚙 ` — the work is sound and waiting on the user — which is the state the handoff
card leaves it parked in.

This vocabulary, and the worktree-and-lock workflow around it, came from the sibling `karabiner`
repo; its `docs/workflow.md` is where the reasoning lives, and where to look first when a convention
here reads as thinner than it should.
