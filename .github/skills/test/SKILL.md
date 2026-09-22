---
name: test
description: "Test an axshot change by installing this branch's build into the live app under a mutex, so parallel sessions do not clobber each other or fight over the keyboard. Use for any change the user would see or touch -- the walk, the filter, the overlay, the hotkeys, the settings window, the menu bar menu, or how permissions are asked for -- and invoke it as part of delivering that change, not only when asked to test."
---

# Test (drive this branch's build as the installed app)

There is one installed app, `/Applications/Axshot.app`, and one keyboard. A worktree compiles its own
bundle freely, but testing means putting that build in the live slot and driving it — and while the
hint overlay is up it swallows every keystroke on the machine. **Editing is parallel, testing is
serial.**

`scripts/axshot-test-lock.sh` is that mutex. It snapshots the installed app *inside the lock* before
overwriting it, so release puts back byte-exactly whatever was there, and records whether the app was
running so a test never ends with the user's menu bar app missing.

**None of it needs the user.** The overlay reads posted events, so a shell drives the whole path. Ask
for a human only when the question is how something *looks* and you have already captured it and
cannot judge. Step 7 is the separate matter of not releasing a visible change out from under them.

This skill is the order and what passes. The mechanics are [testing.md](../../../docs/testing.md) for
everything that needs no lock, [driving.md](../../../docs/driving.md) and
[seeing.md](../../../docs/seeing.md) for the live app, and
[environment.md](../../../docs/environment.md) for failures that are the machine.

## Division of labor

| Where | What it holds | Rule |
|---|---|---|
| `/Applications/Axshot.app` | the app the user runs; owns the hotkeys and the login item | Never edited directly. Written only through `install`. |
| `<checkout>/Axshot.app` | this branch's build, gitignored | Where `build.sh` compiles. Free, parallel, lock-free. |
| `<main checkout>/.claude/axshot-test.lock/` | the mutex and the pre-test snapshot | Held only while actually testing. |

**Acquire late, release fast.** Compiling with `--no-install`, `--dump`, photographing a rect it
printed and rendering a drawing into a PNG all need no lock, and most of a filter change is judged
there ([testing.md](../../../docs/testing.md#what-needs-no-lock)). Take the lock only once you are
about to put a build in the live slot.

## Procedure

### 1. Check the lock before starting

```bash
./scripts/axshot-test-lock.sh status
```

It prints the holder and everyone queued behind them.

### 2. Acquire

Set the title's prefix to `🔓 ` first (AGENTS.md "Session titles"), then take the lock with `wait`,
in the background (`run_in_background`), whether or not it looked free:

```bash
./scripts/axshot-test-lock.sh wait "what you are testing" "<this session's title>"
```

A free lock is taken at once. A held one gives this session a ticket, and the run exits — notifying
the session — the moment it holds the lock; waiting sessions are served in arrival order. **Never wait
in a loop instead:** `wait` blocks in the kernel, a polling loop only burns turns, and a plain
`acquire` refuses to jump the queue anyway.

The last line says how it ended:

- **`acquired`** — swap the prefix to `🔒 ` and go to step 3. It has snapshotted the installed app and
  recorded whether it was running. Re-running from the same session is a no-op that keeps the
  snapshot, so an interrupted session can resume; a *second* session on the same worktree is queued
  like any other, not handed the first one's lock.
- **The wait does not expire**, so there is no giving-up line to read. The holder is usually parked
  on the user's own look at an installed build, and a lock held for hours means the user is away —
  asleep, most often — so the queue is what carries the handoff across that, and a wait that expired
  would cost its place minutes before they come back and release. Cancelling the background task is
  the only way out, and it leaves the queue.
- **`this ticket was cleared`** — someone ran `dequeue`; run `wait` again to take a new place.

While queued, the session stays `🔓 ` and says which session is ahead. Do the lock-free work meanwhile,
but do not run a plain `build.sh`: it installs, and the install is what the lock exists to serialise.
Cancelling the background task leaves the queue.

### 3. Rebase on origin/main, then build and install

Fetch and rebase every time, not only when the branch looks behind: several ships can land during a
single test, and `build.sh` compiles what the worktree holds, so an install without the rebase puts
superseded code in the live slot and everything after this step measures code that main replaced.
Commit first if the tree is dirty — a rebase refuses one, and the stash is shared with every other
worktree.

```bash
git fetch origin && git rebase origin/main && ./build.sh
```

The `&&` is load-bearing: a rebase that stops on a conflict fails the chain, so `build.sh` never puts
a half-merged tree in the live slot. Resolve the conflicts the way
[`ship` step 3](../ship/SKILL.md#3-rebase-on-originmain) says — its traps are about the rebase, not
the ship — and re-run the line. Then read what the rebase brought in before trusting anything measured
after it, since a conflict that resolved cleanly can still leave the change doing nothing:

```bash
git log --oneline $(git merge-base ORIG_HEAD origin/main)..origin/main
```

Take the range from `ORIG_HEAD`, not from what the fetch printed or from `origin/main` as it stood a
moment ago: remote-tracking refs are shared by every worktree, another session's fetch has often moved
them already, and a range from that snapshot comes back empty over a rebase that brought in a feature.

The signing line must read `signed by Axshot Local Signing`. `signed by -` means the build fell back
to ad-hoc: **both permission grants are dead for that bundle**, `install` refuses it, and any result
from it is meaningless. Fix the signing first
([permissions.md](../../../docs/permissions.md#the-keychain-prompt)).

### 4. Confirm the grants survived

The app opens its settings window **only** when a permission is missing or a hotkey was refused, so no
window is the pass — on a screen that is awake and unlocked
([environment.md](../../../docs/environment.md#the-screen-is-locked-or-asleep)). If one appears, stop
and read [permissions.md](../../../docs/permissions.md) before granting anything by hand: a row that
is listed and switched on can still be denied.

### 5. Test

Check what the filter would hint, against at least two apps, one Chromium-based:

```bash
bin/axshot --dump --bundle <some.bundle.id> | head -30
```

Read the list, not the count. You want regions a person would ask for — a sidebar, a message, a panel
— and not a run of near-identical boxes at increasing depth, which is the nesting collapse failing, and
not an empty list on a window with obvious content, which is the tree never being exposed or
[the window being covered](../../../docs/environment.md#a-window-the-walk-does-not-see).

Everything past this point takes the user's keyboard, so every burst is bracketed the way AGENTS.md
"Driving the app on a live machine" lays out — the gate immediately before each burst, not once for
the test. A gate that does not pass parks this step and says the keyboard is busy. **Keep the lock
while parked**, and stay `🔒 `: releasing puts the user's own app back and costs the whole test, and
the gate is expected to pass as soon as they stop typing.

Then drive a real capture through the hotkey, not just the CLI, and confirm three things: a file
appeared with the timestamped name; its pixel dimensions are twice the rect of the region aimed at, on
a Retina display; and **the overlay is not in the image**. That last one is the regression that would
otherwise ship quietly.

After any change to the filter, the hint alphabet or the drawing, photograph the overlay itself
([seeing.md](../../../docs/seeing.md#photographing-the-overlay)) and look at hint density and
placement.

### 6. Iterate without releasing

Edit, re-run `./build.sh`. The lock stays held, so a debugging loop costs one acquire and one release
however many rounds it takes.

### 7. Hand it to the user if it is visible

**Do not release yet if the change is one the user sees or touches** — the overlay, the settings
window, the menu, the hotkeys, focus, permission prompts. Releasing restores the app they had, so the
moment the lock drops there is nothing of the change left to try. Keep it held, tell them this branch
is live and what to look at, stay `🔒 `, and iterate under the same lock until they are happy. That
wait is this step's own and gates nothing else: the user saying to ship is the answer it was waiting
for, whether or not they looked.

### 8. Release

Swap the prefix to `🔓 `, then:

```bash
./scripts/axshot-test-lock.sh release
```

It restores the snapshot, puts the app back the way it was found — running or not — and drops the
lock. Do it as soon as the last capture is done, or as soon as step 7 has been answered where it
applies; do not hold the lock while writing up results or shipping.

"The way it was found" can be behind `origin/main`: the snapshot is the app as of the acquire, so a
release after something else landed installs an app older than what has shipped. The next ship by
anyone heals it, since `ship` step 6 builds from the main checkout. Releasing is not what puts a change
on the user's machine; shipping is.

Then retitle: `📦 ` if the change passed and is worth shipping without re-testing; otherwise the prefix
for what comes next, `⏳ ` to keep working or `🚙 ` if it waits on the user.

Release refuses rather than guess in two cases:

- **The installed app changed underneath the lock** — someone built on main mid-test. `--keep` drops
  the lock and leaves that build, the answer if it was intentional; `--force` restores the snapshot
  anyway. The snapshot path is printed either way.
- **The snapshot is unusable.** The acquire prints "live app snapshotted" whether or not the copy
  behind it finished, and only the release finds out. `--keep` is the answer and `--force` is not:
  there is nothing to restore, and the live app is a real build where the snapshot is half of one. The
  branch's build stays installed until the next install replaces it, so the report says the lock is
  open and the app updates then, and nothing about the snapshot.

### 9. Ship

`ship` runs when the user asks for it, and not before.

## Hazards

- **The overlay owns the keyboard while it is up.** A stuck session releases itself after 15 seconds
  — 30 from the moment a hint holds a region under the mask — and Escape cancels, but do not start one
  and walk away.
- **The clipboard is the user's, and releasing does not restore it.** Ask what is on it before driving
  anything that writes it;
  [driving.md](../../../docs/driving.md#leaving-the-machine-as-you-found-it) has what can be put back
  and how to test a clipboard path without the write.
- **Some paths spend the user's money.** The transcription key sends a picture to the Claude API on
  every press that is not served from the held region's cached answer, and each one is billed to the
  key in `~/.config/axshot/.env`. Drive it deliberately, on a small region, and reuse one session's
  answer rather than re-running the whole path to check a later step.
- **Never change the bundle identifier or the signing certificate to make a test pass.** Either costs
  a full re-grant of both permissions, which needs the user.
- **The acquire snapshots whatever is installed, this branch's own out-of-lock build included**, so an
  install that happened before it cannot be undone by releasing (AGENTS.md "Layout" is the rule). Put
  the app back with a second lock cycle that builds the source it should be running —
  `git fetch origin && git show origin/main:axshot.swift > axshot.swift`, `./build.sh`, restore the
  branch's file — then `release --keep`, so the release does not undo it. That is `origin/main`'s build
  and not necessarily the one the user had, which is gone; say so.
- **A build while another session holds the lock compiles and does not install.** `install` refuses;
  read the output rather than assuming it landed.
- **A worktree older than the queue releases without handing over.** The wake comes from the
  *holder's* copy of the lock script, so a session on a branch from before the queue drops the lock
  silently, and whoever is queued sleeps through their turn until some other release signals. `status`
  showing the lock free with the queue still standing is this; rebase that worktree on main.

## A lock held for hours

**Age is not abandonment, at any age.** `status` prints how long the lock has been held and the clock
time it was taken, and draws no conclusion from either. A holder at step 7 keeps the lock for as long
as the user takes to look, which is routinely past the small hours, and breaking it pulls the build
out from under their hands. Nor is the title `status` prints current — it is the one the holder passed
to `wait`. Read the live one with the host's own session tool (`get_session` in the desktop app) and
the session id `status` printed: `🔒 ` on a session that is not running is a hand-off waiting on the
user, not an abandoned lock, and the answer is to queue behind it. With no such tool, treat a `🔒 `
holder as live and queue.

So `break` is never something to reach for from the age alone. It refuses on its own, and takes the
user's word that nobody is mid-test — restoring the snapshot first:

```bash
./scripts/axshot-test-lock.sh break --confirmed
```

Ask before running it, and say what it costs: the build the holder installed for the user goes away,
and their session is left believing it still holds the lock. `wait` is the alternative that costs
nothing — it keeps its place for as long as the process lives.

`break` recovers the lock and not the queue. A ticket whose waiting session is gone is pruned on sight,
but one whose recorded pid has been reused — across a reboot, say — looks alive forever, and while it
sits at the head every `acquire` is refused and every `wait` blocks behind a session that does not
exist. Read the list, then clear it:

```bash
./scripts/axshot-test-lock.sh dequeue
```

It wakes the sessions it clears, so each exits saying its ticket was cleared rather than sleeping on a
queue that is gone — but they lose their place.

If the acquire itself was interrupted, the snapshot inside the lock is half a copy; `release` and
`break` both say so and leave the live app alone, and `release --keep` is how that lock comes off. If
everything is wedged, the snapshot is a plain bundle at `.claude/axshot-test.lock/Axshot.app.pre` in
the main checkout: copy it over `/Applications/Axshot.app` by hand and delete the lock directory.
