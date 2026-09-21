---
name: ship
description: "Finish a change in the axshot repo: release the test lock, build signed, commit, rebase on origin/main, squash, push to origin/main, fast-forward the local main, and extract the session's learnings. Use only when the user explicitly asks for the change to be shipped, landed, or pushed to main — never because a change looks finished."
---

# Ship (finish a change → land it on origin/main)

Solo-developer workflow: squash the current branch, possibly in a worktree, to a single commit and
push it to `origin/main`. No PR, and no merge commits.

**Shipping is asked for, never inferred.** A change that is finished, tested and clean is a change
ready to ship, not one to ship — say so and stop. Only the user saying to ship, land, merge or push it
starts this procedure, or a skill the user invoked whose own procedure ends in one, `learn` and
`learn-organize` among them: there the ask arrived with the invocation, and putting it again is what
those skills say not to do.

`origin/main` is the source of truth, not the local `main` ref, which can be behind what another
session pushed. Pushing from the worktree keeps shipping independent of the main checkout.

## Procedure

### 0. Prefix the title with 🚀, then release the test lock

Put `🚀 ` on the title now, before any of the work (AGENTS.md "Session titles"); step 7 corrects it if
the ship does not land.

```bash
./scripts/axshot-test-lock.sh release --if-mine
```

If this branch was tested, its build is still installed and the lock still held, and releasing
restores the app the user had. `--if-mine` is a silent no-op with no lock — the branch needed no
testing — and with another session's lock, which is theirs.

Ship the change you *tested*: if the branch moved after the last test, re-test before shipping.

### 1. Build, and read the signing line (must run before committing)

```bash
./build.sh --no-install
```

The last line must read `signed by Axshot Local Signing`. `--no-install` keeps an untested build out
of the live slot; this step proves only that the source compiles and signs. There is no lint, type
check or test suite, and a compile is not evidence that a capture still works — behaviour goes through
`test`.

### 2. Commit all staged and unstaged changes

Generate the message from the diff: Conventional Commits — `feat:`, `fix:`, `docs:` — with a
lower-case subject under about 60 characters, and a body that says why rather than what. The body also
says, each in a line of its own, the two things nothing else will record:

- **The change never reached a running app** — the user asked for the ship untested, or another
  session held the test lock the whole time.
- **It touches the bundle identifier, the signing identity, or how permissions are asked for** — the
  changes that cost the user a re-grant.

### 3. Rebase on origin/main

```bash
git fetch origin && git rebase origin/main
```

Resolve conflicts, preferring the branch's changes unless clearly wrong, then `git add` and
`git rebase --continue`, repeating until it completes.

**Prefer the branch's changes, not its copy of whole files.** A worktree cut before something landed
holds the old copy of every file that change touched, and a session that rewrote one of those files
from its own context hands the rebase a pre-feature version of the lot rather than a hunk. Preferring
that side reverts the other change with no marker and no mention in the message — which is how a
commit about the `?` key list came to delete the test lock queue. Before resolving a conflict in a file
this branch did not set out to change, list what landed in it:

```bash
git log --oneline $(git merge-base HEAD origin/main)..origin/main -- <file>
```

Anything listed there that your side does not contain is about to be undone.

**A clean rebase is not a working one, and the key handler is where that bites.** Git conflicts on
adjacent lines, not on meaning: a branch that landed first can have added an early guard that returns
before your code is reached — every chord under a modifier swallowed, say — and yours then applies
without a marker and does nothing. Read the whole function your change lands in, not just the hunk,
and re-test after any rebase that touched behaviour. The compile proves nothing here.

**A rebase that changes what a key means changes what the request meant.** A branch is specified in
the vocabulary the app had when it was asked for — "Shift and the left arrow adds the previous node" —
and `main` can have moved that meaning onto another chord, so the conflict-free resolution implements
the old sentence rather than the one that was wanted. After a rebase brings behaviour in, re-read the
header comment on what the branch touches, then re-read the request against it.

**A field kept in step with an existing one needs every assignment checked.** The branch that landed
first can have added assignments of the old field that your side has never seen; each applies cleanly
and the compiler is content, since nothing in the language ties the two together. Grep the old field's
assignments in the rebased file and look for the new one beside every one of them.

**A fix is read against the docs the rebase brought in.** The session that met a bug is the likeliest
to have written it up, and a write-up made before the fix describes the bug as how the app behaves —
and can land after this branch was cut. Grep `docs/` and the skills for the symptom the branch removes,
and correct what the fix made untrue in the same ship.

Re-run `./build.sh --no-install` after any rebase that brought code in: step 1 signed off on a
different tree, and resolving a conflict is the one moment in this procedure where a person writes
Swift. Re-testing takes the lock again — `🔒 ` while it is held, `🚀 ` once it is released.

Already on `main` in the main checkout: skip the rebase and step 4, but not the fetch —
`git pull --ff-only`, commit, and go straight to step 5. Skipping the pull only moves the collision to
the push.

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

**If the push is rejected as non-fast-forward,** someone else landed first and nothing was lost: go
back to step 3, redo step 4 onto the new base, and push again. `origin/main` only advances by
fast-forward, so at most one branch wins each round and the others rebase and retry.

### 6. Fast-forward the local main, then install from it

```bash
MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" merge --ff-only origin/main
```

The local ref moving is not a build. If the shipped change should be the app the user is running,
build from the main checkout:

```bash
(cd "$MAIN" && ./build.sh)
```

**If `install` refuses**, another session holds the lock and is mid-test: the ship has still happened,
and the installed app lags until the next install, which picks up everything that accumulated. That is
one line in the report — not whose lock, not what the snapshot did, and not a command for the user to
run.

**If the fast-forward fails** on local changes, leave them — never `checkout --` someone's work away.
Whoever fast-forwards next picks up every commit that accumulated.

**A branch holding commits the main checkout also has diverges it by being shipped.** Step 4 rewrote
them into one, so the local `main` is now ahead by the originals and behind by the squash, and the
fast-forward refuses although nothing is unshipped —
`git -C "$MAIN" diff HEAD origin/main` shows only this ship's own files. The trap is the line after
it: `build.sh` in that checkout then compiles a tree without the change and installs it, reporting
success. Install from the worktree instead, which is what was pushed, and leave the main checkout's
ref to whoever resets it:

```bash
./build.sh
```

### 7. Correct the title if the ship did not land

The push in step 5 is what counts as shipped, whatever step 6 managed; `🚀 ` then stays through the
report and after it, until the session starts something else. If the push failed, or the ship was
abandoned before it, set the prefix that is true now: `📦 ` for a tested branch, otherwise `⏳ ` to keep
working or `🚙 ` if it waits on the user.

### 8. Post-ship

- If the change altered the settings window, the hotkeys, or how permissions are asked for, check that
  `README.md` and `docs/` still describe what the app does. Nothing regenerates them.
- A doc added to `docs/` is listed by hand in AGENTS.md's "Guides", and nothing notices when it is not.
- If the user confirms this worktree is no longer needed, it and the branch can be removed from the
  main checkout:

  ```bash
  BRANCH=$(git branch --show-current) && MAIN=$(git worktree list | head -1 | awk '{print $1}') && git -C "$MAIN" worktree remove <this-worktree-path> && git -C "$MAIN" branch -d "$BRANCH"
  ```

### 9. Extract the learnings

Invoke the `learn` skill — a real `Skill` tool skill, unlike the two files in `.github/skills/`.
Whatever the session learned about the app, the tree or the workflow is still in context now and in
nobody's an hour later, so this is the last stage of shipping and needs no ask. Skip it when the ship
was itself the last step of `learn` or `learn-organize`: what those found is what just shipped.

`learn` puts `📚 ` on the title; put `🚀 ` back when it finishes. If it finds nothing worth recording,
say so in one line.

### 10. Print the completion message

Print `🚀 Shipped` as the last line of the response, after the learn report.
