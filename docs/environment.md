# Failures that are the environment, not the change

Each of these reads like a bug in the change, and each cost a session time before it was recognised as
the machine.

## The screen is locked or asleep

Check before concluding anything about the walk or a picture:

    ioreg -n Root -d1 -r | grep -o 'CGSSessionScreenIsLocked"=[A-Za-z]*'

An absent key is an unlocked session; `=Yes` means stop driving, capturing and installing. None of the
signatures is an error:

- **`--dump` reports `windows=0` for every app on the machine** — all of them, not one — which reads
  exactly like a tree that is never exposed. The window list is not empty: the lock screen is windows of
  its own, loginwindow's and the window server's at layer 2000 and above with an ordinary sharing state,
  and the cull counts them as cover like any other. So the whole desktop comes back culled, word for word
  what [a live overlay](#a-window-the-walk-does-not-see) answers too; the owner at the front of the window
  list tells the two apart, and so does the key above.
- **`screencapture` writes a file of uniform mid-grey** rather than failing, a driven capture leaves no
  file at all and says nothing, and `screencapture -v` never finalises its recording — it ignores its own
  `-V` limit and has to be killed. A *black* screenshot is the other case: the display is asleep, and
  anything visual is unverifiable until someone wakes it.
- **An empty window list** is what a locked screen reports for a window that is there, so "no settings
  window appeared" is a pass only on a machine that is awake.
- **`scripts/wait-idle.sh` passes in three seconds**, a locked screen being the quietest keyboard on the
  machine.
- **`release` strands the lock.** `open -a` fails under a locked session with
  `_LSOpenURLsWithCompletionHandler ... error -600` where a plain `open /Applications/Axshot.app`
  launches it, and the lock script relaunches with the first under `set -e`. So `release` quits the app,
  aborts before dropping the lock, and leaves exactly what the lock exists to prevent: no menu bar app,
  and a lock nobody is holding on purpose. Put the app back with the plain `open`, then release again —
  the live-app mismatch it now reports is your own half-done restore rather than somebody's build, which
  is the case `--force` is for.

Where the rest of the test is the session's own rather than a look the user was asked for, a locked
screen is a wait and not a hand-off: a bounded `run_in_background` loop on the key exits at the unlock,
and its notification is the signal to carry on — every burst after it still behind the idle gate, the
person who unlocked being back at the keyboard.

Reading the tree need not wait. `--focused --bundle <id>` answers `windows=0` there too, the disclaimed
re-spawn being handed no window by any app, but the same run with `--worker`, which skips the re-spawn
and so reads as the shell does, walks the whole window — so
[the region-list diff of a filter change](testing.md#a-filter-change-is-a-diff-of-region-lists) runs
during the lock, given the flag on both builds. A change to *which windows* are walked has nothing to
diff until the unlock: `--focused` never runs the cull, and every window is behind the lock screen on
both builds.

## A window the walk does not see

- **A live overlay culls the whole desktop, and the driving border is not what does it.** The overlay is
  a full-screen window with an ordinary sharing type, and the walk leaves it out of its *own* run only —
  it goes up after that walk has finished. To a second process it is a window covering everything, so a
  `--dump` typed in a shell while any session is up answers `windows=0` with every window culled, like a
  build that has stopped seeing the tree. The border looks guilty and is not: sharing state 0 keeps it
  out of the cull, measured either side of a `--driving on`. Take the dump outside the burst, and give an
  Escape a moment to land before believing the answer after it.
- **A covered window answers like an empty one.** The window server culls what has no pixels of its own
  before any accessibility message is sent, so a target behind another window answers
  `windows=0 culled=1` — the shape of an app that exposes nothing at all — and neither `--no-prune` nor a
  longer budget changes it, both being about elements rather than the window. Raising the window costs
  the foreground and so the lock; where the question is what the tree *contains*,
  [ask the tree directly](testing.md#asking-what-the-tree-says).
- **A window hinting nothing is usually covered, not broken.** `--dump` says so on the window line: a
  high `over` with `boxes=0` is a window whose elements all straddle something in front of it, and
  `culled=` counts the windows dropped before being walked at all. Move the window out from under the
  others before concluding anything about the tree.
- **`--focused` captures whatever is on top of the window.** It aims the walk and not the camera, so the
  outcome line names the region it meant while the pixels are of whatever was in front. Front the target
  again before *each* run, not once per test: a run that ends gives the foreground back, and the next one
  photographs a different app at the same coordinates and says nothing about it. The default has no such
  gap — a covered box is not offered — so reach for `--focused` deliberately rather than by habit.

## The build and the lock

- **A build that died with `Terminated: 15` was another session's lock operation.** `release` and
  `install` both quit the running app with `pkill -f Axshot.app/Contents/MacOS/axshot`, and `-f` matches
  the whole command line — so `swiftc -o <checkout>/Axshot.app/Contents/MacOS/axshot` carries that string
  too, and the compiler is killed alongside the app. Measured rather than reasoned about: `pgrep` of that
  pattern one second into a cold build returns the `swift-frontend` pid beside the running app's. Any
  worktree's build can be ended by any other session's release, and the signature is a SIGTERM with no
  compiler diagnostic above it. Re-run it, and read the pattern as the bug rather than the build.
- **The lock is in the main checkout, not the worktree.** `axshot-test-lock.sh` resolves it from the
  first entry of `git worktree list`, so a `.claude/axshot-test.lock` *inside* a worktree is a leftover
  whose contents say nothing about the lock in force — and a missing file in it reads exactly like the
  script failing to write one. The queue sits beside the lock at `.claude/axshot-test.queue` and outlives
  it on purpose: release deletes the lock directory and has to be able to wake whoever was waiting.
  `status` is the readout for both.
- **A build sitting at `==> Signing as` is waiting on a keychain dialog**, not compiling — see
  [the keychain prompt](permissions.md#the-keychain-prompt).
