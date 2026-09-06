---
name: ship
description: "Finish a change in the axshot repo: release the test lock, build signed, commit, rebase on origin/main, squash, push to origin/main, fast-forward the local main, and extract the session's learnings. Use only when the user explicitly asks for the change to be shipped, landed, or pushed to main — never because a change looks finished."
---

# Ship (finish change → merge to main)

Solo-developer workflow. Take the current branch (possibly in a worktree), squash it to a single
commit, and push it to `origin/main`. No PR.

**Shipping is asked for, never inferred.** A change that is finished, tested and clean is a change
ready to ship, not one to ship — say so and stop. Only the user saying to ship, land, merge or push
it starts this procedure.

`origin/main` is the source of truth, not the local `main` ref: another session may have pushed
without the main checkout being able to fast-forward, so local `main` can be behind what you must
land on. Pushing from the worktree keeps shipping independent of whatever the main checkout is
doing.

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

Ship the change you *tested* — if the branch moved after the last test, re-test before shipping.

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

A change that never reached a running app -- the user asked for the ship, or the test lock was held
by another session for the whole of it -- says so in the body too, in a line of its own. It is the
one thing a later reader cannot recover: the diff is in the commit and the compile is implied, but
whether anybody looked at the thing is not written anywhere else.

A change that touches the bundle identifier, the signing identity, or how permissions are asked for
should say so plainly in the body: those are the ones that cost the user a re-grant, and the commit
is where that gets noticed later.

### 3. Rebase on origin/main

```bash
git fetch origin && git rebase origin/main
```

Resolve conflicts, preferring the branch changes unless clearly wrong, then `git add` and
`git rebase --continue`, repeating until it completes.

**A clean merge is not a working one, and the key handler is where that bites.** Git conflicts on
adjacent lines, not on meaning: a branch that landed first can have added an early guard that
returns before the code you are rebasing is ever reached — every chord under a modifier swallowed,
say — and yours then merges without a marker and does nothing. Read the whole function your change
lands in, not just the hunk, and re-test after any rebase that touched behaviour. The compile
proves nothing here; the change you tested is no longer the change you have.

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
- A doc added to `docs/` is listed in two places by hand — AGENTS.md's "Guides" and the line in
  `README.md` under "Command line" — and neither notices when it is not.
- The branch is now on `origin/main`. If this worktree is finished with, it and the branch can be
  cleaned up from the main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

  Only when the user confirms the worktree is no longer needed.

### 9. Extract the learnings

Invoke the `learn` skill — a real `Skill` tool skill, unlike the two files in `.github/skills/`. A
shipped change is the moment its lessons are worth writing down: the branch is landed, nothing is
pending, and whatever the session learned about the app, the tree or the workflow is still in
context — an hour later it is in nobody's. This is not optional and the user does not have to ask
for it; it is the last stage of shipping.

`learn` puts `📚 ` on the title, replacing the `🚀 `. Put `🚀 ` back when it finishes: the session
shipped, and that is the stage it rests at.

If `learn` finds nothing worth recording, that is a normal outcome — say so in one line and move on.

### 10. Print the completion message

Print `🚀 Shipped` as the last line of the response, after the learn report.
