# Axshot

A macOS menu bar app that finds screenshot regions in the accessibility tree. One Swift file, four
shell scripts, no dependencies.

**`axshot.swift`'s header comment is the reference for the tool itself** — every option, and the
reasoning behind each moving part. Read it before changing behaviour and update it with the change;
this file does not repeat it, and nothing regenerates it. `README.md` is the same obligation for
anything a user would notice. The header comment is current as of `origin/main`, not of this
worktree's cut, and tuned constants are exactly what other sessions re-measure and move: `git fetch`
and read `origin/main` before quoting a default or a number to the user.

## Guides

This file is read by every session, so it holds what every session needs and stays under 200 lines.
Anything read only when working on one area is a guide, with a one-line claim and a link left here.

- [docs/decisions.md](docs/decisions.md) — what was argued out and measured about the walk, the
  keyboard, the overlay and the workflow. Read it before changing behaviour that reads as arbitrary;
  most of it is not.
- [docs/filter.md](docs/filter.md) — changing which regions are offered. `--dump` is the feedback
  loop, `⌘D` says why a hint is missing, and a rule about what is *drawn* wants a picture.
- [docs/accessibility.md](docs/accessibility.md) — what a new control owes the tree and the keyboard,
  and the AppKit defaults that leave one drawn correctly and reachable by nothing.
- [docs/permissions.md](docs/permissions.md) — what TCC considers "this app", the two identities one
  binary has, why a grant survives one rebuild and not another, and the keychain prompt.
- [docs/testing.md](docs/testing.md) — checking a change with no lock and no keyboard: region-list
  diffs against `origin/main`, scratch harnesses, probes, reading a crash, sandboxing the lock script.
- [docs/driving.md](docs/driving.md) — driving the installed app while the user works: the keyboard
  gate, the driving border, what osascript cannot post, aiming at a region, the settings window, and
  what makes a reproduction worth trusting.
- [docs/seeing.md](docs/seeing.md) — photographing and measuring what is on screen, transitions
  included, and what a capture does not prove.
- [docs/environment.md](docs/environment.md) — failures that are the machine rather than the change:
  a locked screen, a covered window, a build killed by another session's release.
- [docs/cloud-sessions.md](docs/cloud-sessions.md) — what a session with no Mac does with the change
  instead of testing it.

## Skills

[`test`](.github/skills/test/SKILL.md) installs this branch's build into the live app under a mutex
and drives it; [`ship`](.github/skills/ship/SKILL.md) lands the change on `origin/main`. Open and
follow the matching file before doing either — the `Skill` tool does not load `.github/skills/`, so
asking for one by name only reports that no such skill exists.

**A change the user would see or touch gets `test` without being asked.** There is no test suite and
no lint, so a compile gates nothing and is not a place to hand back: nothing is on the user's machine
until `test` puts it there. `ship` is the opposite, and runs only when the user asks for it or a skill
they invoked ends in it.

A skill describing a command its script does not have was clobbered, not left stale, and a copy
byte-identical to an older version is a wholesale revert. `git log --oneline -- <path>` finds the
commit that added the command: take the file back whole where nothing has touched it since, and
reverse the bad commit's hunks with `git apply -R --3way` where something has.

## Layout

| | |
|---|---|
| `axshot.swift` | everything: walk, filter, overlay, hotkeys, settings, CLI |
| `README.md` | what a user reads: install, permission, the command line, tuning the filter |
| `build.sh` | compiles, assembles `Axshot.app`, signs it, links `bin/axshot`, installs it; `--no-install` stops before the install |
| `create-signing-cert.sh` | creates the signing identity once; idempotent |
| `scripts/axshot-test-lock.sh` | the mutex over the installed app and the keyboard, and the queue for it |
| `scripts/wait-idle.sh` | blocks until the user has stopped typing, in front of anything that takes the foreground |

Build output (`Axshot.app/`, `bin/`, `.claude/`) is generated and ignored.

The same binary is the app when launched with no arguments and a CLI when given any, and `bin/axshot`
is a symlink to it. The bytes are the same and the identity is not: on the command line `Bundle.main`
carries no identifier, so code that needs the bundle id or the preferences domain names it rather than
asking the bundle ([permissions.md](docs/permissions.md#one-binary-two-identities)).

There is one installed app, `/Applications/Axshot.app`. Its grants belong to the signature and the
bundle identifier rather than the path, so what is genuinely single is the running instance, which
owns the global hotkeys, and the login item, which names one bundle path. `build.sh` installs through
the lock script, which refuses while *another* session holds the lock; a session that wants a held
lock queues with `wait`, and parallel worktrees test in the order they arrived. Nothing refuses an
install when no lock is held at all, so a `build.sh` run before acquiring puts this branch in
`/Applications` outside the lock and the acquire that follows snapshots that rather than the app the
user had: take the lock first, or pass `--no-install`.

## Driving the app on a live machine

The user is at the keyboard doing their own work while a test runs, and every drive brings some
window to the front. Every burst that activates an app, opens the overlay or posts a key is bracketed:

    scripts/wait-idle.sh        # until nobody has typed for three seconds; non-zero is never a pass
    bin/axshot --driving on     # a pink border on every screen: these windows are this session's
    # activate, send the hint, send Return — the keystrokes and nothing else
    bin/axshot --driving off    # border down, foreground handed back to whoever had it

A non-zero gate means park and let the user name the moment, not take the foreground anyway. Reading
`--dump` output, checking the PNG and deciding what it means happen before the bracket or after it,
never inside. The gate goes at the start of a burst and not between its keys, and it cannot see a
locked screen: [docs/driving.md](docs/driving.md#sharing-the-machine) has why, and what a run puts
back afterwards.

## When there is no Mac

Check `uname -s` before the work, not after. Anything but `Darwin` is a Linux container with a fresh
clone and no `swiftc`, `codesign`, `osascript`, `screencapture` or `/Applications`: it cannot build,
install, drive or photograph the app, so neither `test` nor `ship` is its to run and the lock is not
its to take. It hands the change off untested ([docs/cloud-sessions.md](docs/cloud-sessions.md)) and
never reaches `🔒 `, `📦 ` or `🚀 `: it ends parked at `🚙 `.

## Session titles

The prefix glossary arrives in every session from the `emotive` plugin, and nothing here repeats it.
These are the rows this repo can state exactly.

- `📦 ` means this branch has *been* driven through the `test` skill — its build in the live slot, a
  capture taken through the hotkey — and survives the release that puts the user's app back.
  `./build.sh --no-install` ending in `signed by Axshot Local Signing` is a compile and not that gate
  ("Skills" above).
- `🚀 ` ships to `origin/main`, squashed and fast-forwarded with no PR; the `ship` skill is that
  procedure and sets the prefix itself, once the push lands. `📦 ` holds until then.
- `🚙 ` is what this repo waits on the user for: a decision, or a hands-on look at an installed
  build. That look is the exception — the lock is held for as long as they look, so it stays `🔒 `
  until there is nothing left to hold.
- `💾 ` and `🔍 ` are inert here: no live account or database sits behind this app. The lock is what
  sessions contend for.

`🔒 ` and `🔓 ` are that lock — `scripts/axshot-test-lock.sh`, over the one installed app and the one
keyboard. `🔓 ` covers a session about to acquire, one queued or blocked behind another, and one in
the act of releasing — the stage after the release replaces it at once. `🔒 ` means the installed app
is this branch's build right now, so another session queues rather than installing over it. The
`test` skill sets both around its own acquire and release, not the response, and `status` prints the
title its holder passed to `wait` rather than the live one.

The worktree-and-lock workflow these sit in came from the sibling `karabiner` repo, whose
`docs/workflow.md` holds the reasoning when a convention here reads as thinner than it should.
