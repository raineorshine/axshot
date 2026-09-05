---
name: test
description: "Test an axshot change by installing this branch's build into the live app under a mutex, so parallel sessions do not clobber each other or fight over the keyboard. Use when trying out, verifying, or debugging a change to the walk, the filter, the overlay or the hotkeys."
---

# Test (drive this branch's build as the installed app)

There is one installed app, `/Applications/Axshot.app`, and one keyboard. A worktree compiles its
own bundle freely, but testing means putting that build in the live slot and driving it — and while
the hint overlay is up it swallows every keystroke on the machine. **Editing is parallel, testing is
serial.**

`scripts/axshot-test-lock.sh` is that mutex. It snapshots the installed app *inside the lock* before
overwriting it, so release puts back byte-exactly whatever was there, and records whether the app
was running so a test never ends with the user's menu bar app missing.

[docs/testing.md](../../../docs/testing.md) has the mechanics — driving the overlay from a shell,
photographing it, and which failures are the environment. This skill is the order and what passes.

**None of it needs the user.** The overlay reads posted events, so AppleScript drives the whole
path. Ask for a human only when the question is how something *looks* and you have already captured
it and cannot judge.

## Division of labor

| Where | What it holds | Rule |
|---|---|---|
| `/Applications/Axshot.app` | the app the user runs; owns the hotkeys and the login item | Never edited directly. Written only through `install`. |
| `<checkout>/Axshot.app` | this branch's build, gitignored | Where `build.sh` compiles. Free, parallel, lock-free. |
| `.claude/axshot-test.lock/` | the mutex and the pre-test snapshot | Held only while actually testing. |

**Acquire late, release fast.** Compiling, `--dump` against another app, and reading the candidate
list need no lock — `--dump` never draws an overlay and never touches the installed app. Take the
lock only once you are about to put a build in the live slot.

## Procedure

### 1. Check the lock before starting

```bash
./scripts/axshot-test-lock.sh status
```

If another session holds it, **do not wait in a loop.** The lock names the holding session, so tell
the user which chat it is and how long it has held it, then either carry on with lock-free work or
ask them — they are the one whose keyboard is involved.

### 2. Acquire

Prefix this session's title with `🔓 ` first (`set_session_title`, replacing any existing lifecycle
prefix — see AGENTS.md "Session titles"). Set it before the acquire, not after: if the acquire is
denied, drop the prefix again. Do not report this.

```bash
./scripts/axshot-test-lock.sh acquire "what you are testing" "<this session's title>"
```

Snapshots the installed app and records whether it was running. Re-running from the same worktree is
a no-op and will not re-snapshot, so an interrupted session can resume.

Once the acquire succeeds, swap the prefix to `🔒 `. Do not report this.

### 3. Build and install

```bash
./build.sh
```

The signing line must read `signed by Axshot Local Signing`. If it says `signed by -`, the build fell
back to ad-hoc: **both permission grants are dead for that bundle**, `install` will refuse it, and
any result from it is meaningless. Fix the signing first.

`build.sh` installs through the lock — quitting the running instance, swapping the bundle, and
relaunching if it was running. It refuses outright while another session holds the lock.

### 4. Confirm the grants survived

The app opens its settings window **only** when a permission is missing or a hotkey was refused. No
window is the pass. If one appears, stop and read [docs/permissions.md](../../../docs/permissions.md)
before granting anything by hand — a row that is listed and switched on can still be denied.

### 5. Test

Check what the filter would hint, against at least two apps, one Chromium-based:

```bash
bin/axshot --dump --bundle <some.bundle.id> | head -30
```

Read the list, not the count. You want regions a person would ask for — a sidebar, a message, a
panel — and not a run of near-identical boxes at increasing depth, which is the nesting collapse
failing, and not an empty list on a window with obvious content, which is the tree never being
exposed.

Then drive a real capture through the hotkey, not just the CLI, and confirm three things: a file
appeared with the timestamped name; its pixel dimensions are twice the reported rect on a Retina
display; and **the overlay is not in the image**. That last one is the regression that would
otherwise ship quietly.

After any change to the filter, the hint alphabet or the drawing, photograph the overlay itself
(docs/testing.md) and look at hint density and placement.

### 6. Iterate without releasing

Edit, re-run `./build.sh`. The lock stays held, so a debugging loop costs one acquire and one
release however many rounds it takes.

### 7. Hand it to the user if it is visible

**Do not release yet if the change is one the user sees or touches** — the overlay, the settings
window, the menu, the hotkeys, focus, permission prompts. Releasing restores the app they had, so
the moment the lock drops there is nothing of the change left to try. Keep it held, tell them this
branch is live and what to look at, and wait for their answer; the `ship` skill will not ship a
visible change without it. Stay `🔒 ` while waiting — the lock is held and the installed app is this
branch's build, which is exactly what the prefix says.

Iterate under the same lock until they are happy, then release.

### 8. Release

Swap the prefix to `🔓 ` before releasing. Do not report this.

```bash
./scripts/axshot-test-lock.sh release
```

Restores the snapshot, puts the app back the way it was found — running or not — and drops the lock.
Do this as soon as the last capture is done; do not hold it while writing up results or shipping.

Then retitle: `📦 ` if the change passed and is worth shipping without re-testing, otherwise drop the
prefix. Do not report this.

If the installed app changed underneath you, release refuses rather than discarding it, and offers
`--keep` (drop the lock, leave the app alone) or `--force` (restore anyway). That happens when
someone built on main mid-test. Pick `--keep` if that build was intentional; the snapshot path is
printed either way.

### 9. Ship

Release first, then follow the `ship` skill.

## Hazards

- **The overlay owns the keyboard while it is up.** A stuck session releases itself after 15
  seconds — 30 from the moment a hint holds a region under the mask — and Escape cancels, but do
  not start one and walk away.
- **The clipboard is the user's too.** Anything that drives a clipboard path overwrites whatever
  they were carrying, and it is not restored by releasing the lock. Save it with `pbpaste` before
  the first run and put it back after the last one.
- **A capture takes whatever is frontmost.** Activate the app you mean, or you will measure the
  wrong window and conclude the filter is broken.
- **Never change the bundle identifier or the signing certificate to make a test pass.** Either
  costs a full re-grant of both permissions, which needs the user.
- **`build.sh` installs unless told `--no-install`.** It is not a compile step you can take before
  acquiring: it writes the live slot, so a build run first puts your bundle in `/Applications`
  *outside* the lock, and the acquire that follows snapshots that instead of the app the user had.
  Take the lock first, even for a build you only meant to compile, or use `--no-install`. Once that
  has happened the snapshot cannot restore what was lost; put the app back with a second lock cycle
  that builds the source it should be running — `git show main:axshot.swift > axshot.swift`,
  `./build.sh`, restore the branch's file, then `release --keep` so the release does not undo it.
- **Do not build on main while another worktree holds the lock.** `install` refuses, so the build
  succeeds and the install does not — read the output rather than assuming it landed.

## Stale locks

A lock older than 30 minutes is reported `STALE` by `status`. Breaking it restores the snapshot
first:

```bash
./scripts/axshot-test-lock.sh break
```

Breaking a lock that is *not* stale requires confirming with the user that no test is in flight,
then `AXSHOT_LOCK_STALE=0 ./scripts/axshot-test-lock.sh break`. Never on a hunch — the holder is
mid-test.

If everything is wedged, the snapshot is a plain bundle at
`.claude/axshot-test.lock/Axshot.app.pre`; copy it over `/Applications/Axshot.app` by hand and
delete the lock directory.
