# When there is no Mac

Some sessions run in a trusted cloud environment: a Linux container holding a fresh clone and
nothing else. `test` is impossible from the `build.sh` it starts with and `ship` from the
`build.sh --no-install` it starts with, and neither is partly possible — `--dump`, the lock-free half
of testing, still needs a compiled binary. So the `uname -s` check in AGENTS.md comes before the
change is written, not after a build has failed; the harness will also have said it is running in a
managed remote environment.

**The lock looks free, and is not this session's to take.** `scripts/axshot-test-lock.sh status` is
shell over a directory, so it answers `unlocked` in a container exactly as it would on an idle Mac.
Reading `status` is harmless; an acquire records a mutex over nothing — there is no installed app to
snapshot — and tells a session on the user's real machine that a test is in flight when none is.

Everything up to the compile is unchanged: read the tree, change the code, keep `axshot.swift`'s
header comment and `README.md` current, commit, push to the branch the harness designates and open
the pull request it asks for. The clone is ephemeral, so anything not committed and pushed is gone
with the container.

Then, at the point the `test` skill would have been invoked, queue a handoff task card
(`spawn_task`) for a session on the user's machine, and park at `🚙 `. That card opens a session with
none of this conversation, so its prompt stands on its own: the branch to fetch, what changed and
where, the checks in the order they would fail, which assumptions were never verified and the
fallback if one is wrong, and that fixes go to the same branch and pull request rather than a new
one.

Say it is untested everywhere it will be read later — in the response, in the pull request body, and
in a line of its own in the commit body, the convention step 2 of `ship` carries. That the code never
reached a running app is the one thing a later reader cannot recover from the diff.

`ship` is not a cloud session's to run even for a docs-only change that would have compiled: it
releases a lock it should never have held, and pushes straight to `origin/main`, where the cloud
harness requires a branch and a pull request.
