---
name: ship
description: "Finish a change in the axshot repo: release the test lock, build signed, commit, rebase on origin/main, squash, push to origin/main, and fast-forward the local main. Use when done with a change and want it landed without opening a PR."
---

# Ship (finish change → merge to main)

Solo-developer workflow. Take the current branch (possibly in a worktree), squash it to a single
commit, and push it to `origin/main`. No PR.

`origin/main` is the source of truth, not the local `main` ref: another session may have pushed
without the main checkout being able to fast-forward, so local `main` can be behind what you must
land on. Pushing from the worktree keeps shipping independent of whatever the main checkout is
doing.

## Before any of it: the user's own pass

**Anything the user sees or touches ships only after the user has tried it by hand.** The overlay and
its hints, the settings window, the menu bar menu, the hotkeys and what keys do, how permissions are
asked for, whether the app takes focus or shows up in the Dock or the App Switcher — a driven test
proves the path runs, not that the result is any good to use, and that judgement is the user's.

Automated testing is not the pass and neither is a screenshot. Hand them the build and wait:

1. Hold the test lock with this branch installed as `/Applications/Axshot.app` — the `test` skill's
   step 3 leaves it exactly there.
2. Tell the user it is live, name the chords or the window to look at, and say what changed.
3. **Wait for their answer.** Do not release the lock, do not restore anything, do not start step 0.
   The lock is what stops another session swapping the app out from under them mid-look.
4. Ship on a yes. On anything else, fix it and hand it back — the lock stays held across the loop.

Only a change with no visible surface at all — a comment, a doc, a refactor with identical behaviour
— skips this, and only if nothing about the run changed.

## Procedure

### 0. Prefix the session title with 🚀, then release the test lock

Read the session's title (`mcp__ccd_session_mgmt__get_session` with `"self"`) and set it back with a
`🚀 ` prefix (`mcp__ccd_session_mgmt__set_session_title`), replacing any existing lifecycle prefix
rather than stacking — a shipping session was usually `📦 ` a moment ago. Do this **now**, before any
of the work: the sidebar should say what the session is doing while it is doing it. Step 7 puts the
title back if the ship does not land. Do not report either. See AGENTS.md "Session titles".

```bash
./scripts/axshot-test-lock.sh release --if-mine
```

If this branch was tested via the `test` skill, its build is still installed as
`/Applications/Axshot.app` and the lock is still held. Releasing restores the app the user had.
`--if-mine` releases only a lock *this session* took: no lock means the branch needed no testing (a
comment fix) and is safe to ship, and another session's lock is theirs. Both are silent no-ops — do
not report them.

Ship the change you *tested* — if the branch moved after the last test, re-test before shipping, and
if the fix touched anything visible, hand it back for the pass above before releasing.

### 1. Build, and read the signing line (must run before committing)

```bash
./build.sh --no-install
```

The last line must read `signed by Axshot Local Signing`. `--no-install` is the point: shipping must
not put an untested build into the live slot as a side effect. This step is here to prove the source
still compiles and signs, nothing more.

There is no lint, type check or test suite. If behaviour changed, it should have gone through the
`test` skill already; a compile is not evidence that a capture still works.

Build output — `Axshot.app/`, `bin/`, `.claude/` — is generated and ignored. Never commit any of it,
and never commit anything from the save folder.

### 2. Commit all staged and unstaged changes

Generate the message from the diff. This repo uses Conventional Commits — `feat:`, `fix:`, `docs:` —
with a lower-case subject under about 60 characters, and a body that says why rather than what.

A change that touches the bundle identifier, the signing identity, or how permissions are asked for
should say so plainly in the body: those are the ones that cost the user a re-grant, and the commit
is where that gets noticed later.

### 3. Rebase on origin/main

```bash
git fetch origin && git rebase origin/main
```

Resolve conflicts, preferring the branch changes unless clearly wrong, then `git add` and
`git rebase --continue`, repeating until it completes.

Skip this step and step 4 if you are already on `main` in the main checkout; commit there and go
straight to step 5.

### 4. Squash all commits into one

```bash
git reset --soft origin/main && git commit -m "subject" -m "body"
```

Use a single message that describes the overall diff.

### 5. Push to origin/main

```bash
git push origin HEAD:main
```

This is the ship. It runs from the worktree and touches no other working tree.

**If the push is rejected as non-fast-forward:** someone else landed first. Nothing was lost. Go back
to **step 3**, redo **step 4** to re-squash onto the new base, and push again. Because `origin/main`
only advances by fast-forward, at most one branch wins each round and the others rebase and retry —
no merge commits, no clobbering.

### 6. Fast-forward the local main, then install from it

```bash
MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" merge --ff-only origin/main
```

Unlike a config repo, this does not put the change in front of the user by itself — the local ref
moving is not a build. If the shipped change should be the app they are running, build from the main
checkout afterwards:

```bash
(cd "$MAIN" && ./build.sh)
```

That installs `/Applications/Axshot.app`, which is what the user actually runs. **If `install`
refuses**, another session holds the lock and is mid-test; the ship has still happened, only the
installed app lags. Say so in the report, with the command, since until someone runs it the app on
the user's machine lacks what was just shipped.

**If the fast-forward fails** with local changes, leave them — never `checkout --` someone's work
away. Whoever fast-forwards next picks up every commit that accumulated, so a skipped one costs
nothing but the delay.

### 7. Correct the title if the ship did not land

The push in step 5 is what counts as shipped, whether or not step 6 could fast-forward or install.
If it succeeded, the `🚀 ` from step 0 stays — through the report and after it, until the session
starts something else and that stage's prefix replaces it. Never clear it to leave a bare title. If
the push failed, or the ship was abandoned before it, put the title back to the prefix that is true
now (`📦 ` for a tested branch, none otherwise). Do not report this step.

### 8. Post-ship

- If the change altered the settings window, the hotkeys, or how permissions are asked for, check
  that `README.md` and `docs/` still describe what the app does. They are hand-written; nothing
  regenerates them.
- The branch is now on `origin/main`. If this worktree is finished with, it and the branch can be
  cleaned up from the main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

  Only when the user confirms the worktree is no longer needed.

### 9. Print the completion message

Print `🚀 Shipped` as the last line of the response.
