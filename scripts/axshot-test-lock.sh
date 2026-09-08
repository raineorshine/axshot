#!/bin/sh
# Mutex for the live app: /Applications/Axshot.app.
#
# There is one installed app. A worktree can compile freely, but *testing* means
# putting its build in that slot and driving it -- and while the hint overlay is
# up it swallows every keystroke on the machine. One installed app, one keyboard:
# editing is parallel, testing is serial.
#
# The slot is not what makes the grants persist -- TCC pins those to the signing
# identity, not a path, so any build signed with the same certificate satisfies
# them wherever it sits. What is single is the running instance, which owns the
# global hotkeys, and the login item, which names one bundle path.
#
# The pre-test bundle is snapshotted inside the lock, so release puts back
# byte-exactly whatever was installed before -- committed or not -- and a lock
# abandoned by a dead session is still recoverable by `break`.
#
# Whether the app was running is recorded too. A test must not end with the
# user's menu bar app missing, or with a stray instance holding their hotkeys.
#
#   acquire [label] [session]
#                     take the lock and snapshot the live app; `session` names
#                     the Claude session holding it, so a denied request can say
#                     which chat to go to (falls back to $AXSHOT_SESSION)
#   wait [label] [session]
#                     acquire if it is free, otherwise take a ticket and block
#                     until it is. No polling and no loop to write: the release
#                     wakes the oldest waiter through a fifo. Run it in the
#                     background and the session is told the moment it holds the
#                     lock; interrupting it leaves the queue. It is bounded:
#                     after $AXSHOT_WAIT_STALE (30m) it gives up and reports
#                     what it was waiting on, whatever the reason.
#   install <app>     replace the live app with this build and relaunch it;
#                     refused while another session holds the lock
#   release           restore the snapshot and drop the lock
#                     --keep     drop the lock, leave the live app as it is
#                     --force    restore even if the live app changed
#                     --if-mine  no-op unless this session took the lock
#   status            who holds it, since when, whether stale, who is queued
#   break             force-release a lock left behind by a dead session
#   dequeue           clear the queue; the recovery for a ticket that cannot be
#                     pruned, which `break` does not touch
# The handoff is only as good as the holder's copy of this script: a worktree on
# a branch from before the queue releases the lock without waking anyone, and a
# waiter behind it sleeps until some other session releases. Rebasing a worktree
# on main is what fixes that, not anything the waiting session can do.
set -eu

ROOT=${AXSHOT_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
LIVE=${AXSHOT_LIVE:-/Applications/Axshot.app}
LOCK="$ROOT/.claude/axshot-test.lock"
BACKUP="$LOCK/Axshot.app.pre"
# Outside the lock directory, which release deletes: the queue has to outlive
# the handoff it exists to order.
QUEUE="$ROOT/.claude/axshot-test.queue"
STALE_SECONDS=${AXSHOT_LOCK_STALE:-1800}
# How long a `wait` waits before giving up. Its own value, not STALE_SECONDS:
# `break` documents AXSHOT_LOCK_STALE=0 for forcing a live lock open, and a
# shell that exports that must not turn every wait into an instant refusal.
WAIT_STALE=${AXSHOT_WAIT_STALE:-1800}
APP_PROCESS="Axshot.app/Contents/MacOS/axshot"

SELF=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
NOW=$(date +%s)
# The worktree identifies the owner, but the user's question when a request is
# denied is "which of my chats is that?" -- so record the session too. The id is
# in the environment; the human-readable title is not, so the caller passes it.
SESSION_ID=${CLAUDE_CODE_HOST_SESSION_ID:-${CLAUDE_SESSION_ID:-}}

die() { printf '%s\n' "$*" >&2; exit 1; }
field() { cat "$LOCK/$1" 2>/dev/null || printf '(unknown)'; }
age() {
  held=$(cat "$LOCK/acquired" 2>/dev/null || printf '%s' "$NOW")
  # Fresh, not $NOW: a waiting session asks this from a loop it entered hours
  # ago, and a lock that never appears to age is a lock `break` never reaches.
  printf '%s' $(( $(date +%s) - held ))
}
holder_report() {
  printf 'held by   %s\n' "$(field label)"
  printf 'session   %s\n' "$(field session)"
  if [ -s "$LOCK/session_id" ]; then printf 'session id %s\n' "$(field session_id)"; fi
  printf 'worktree  %s\n' "$(field worktree)"
  printf 'branch    %s\n' "$(field branch)"
  printf 'age       %sm (stale after %sm)\n' "$(( $(age) / 60 ))" "$(( STALE_SECONDS / 60 ))"
}
# The worktree says who owns the lock, and when both sides know their session
# it has to be the same session too: two chats can share a worktree, and one of
# them holding the lock is not the other one's turn. Either side missing an id
# falls back to the worktree alone -- an older lock, or a plain shell.
owned() {
  [ "$(field worktree)" = "$SELF" ] || return 1
  [ -n "$SESSION_ID" ] && [ -s "$LOCK/session_id" ] || return 0
  [ "$(field session_id)" = "$SESSION_ID" ]
}
# STALE_SECONDS=0 means "treat any lock as abandoned" -- the documented override
# for breaking a live lock once the user has confirmed nobody is mid-test.
is_stale() { [ "$(age)" -ge "$STALE_SECONDS" ]; }

app_running() { pgrep -f "$APP_PROCESS" >/dev/null 2>&1; }


# --- the queue ---------------------------------------------------------------
#
# A session that found the lock held used to have nothing to do but ask again
# later. It takes a ticket instead and blocks on a fifo, so the kernel wakes it
# the moment the holder releases: a waiting session costs nothing while it
# waits, and the handoff has no gap for a third session to walk into.
#
# The order is arrival order and the handoff is addressed. A release signals
# exactly one ticket -- the oldest whose session is still alive -- and `take_lock`
# refuses anyone who is not at the head, so waiters neither race for the freed
# lock nor overtake each other. Nothing wedges if a signal misses: the woken
# session re-checks the lock rather than trusting the wake, and a lock taken by
# someone else just means waiting for that session's release to signal again.
#
# A ticket is identified by the process waiting on it, so a session killed
# mid-wait is pruned by the next scan instead of stalling everyone behind it.

# Tickets in arrival order, dropping any whose waiter is gone. A ticket is named
# `<position>.<pid>`, so it is complete the instant it exists: a directory
# claimed by a session that dies before it can describe itself is recognisably
# dead rather than a head everyone else has to queue behind forever.
queue_prune() {
  [ -d "$QUEUE" ] || return 0
  for t in $(ls "$QUEUE" 2>/dev/null | sort -t. -k1,1n -k2,2n); do
    # Anything not shaped `<position>.<pid>` is not a ticket -- a leftover from
    # an older version of this script, or a directory made by hand. Reading its
    # name as a pid would have it look alive whenever some unrelated process
    # owns that number, and it would sit at the head refusing everyone.
    case $t in *.*) ;; *) rm -rf "$QUEUE/$t"; continue ;; esac
    kill -0 "${t#*.}" 2>/dev/null && printf '%s\n' "$t" || rm -rf "$QUEUE/$t"
  done
}
# Not `queue_prune | head -1`: closing that pipe early leaves a broken-pipe
# error in the middle of an otherwise clean wait.
queue_head() { set -- $(queue_prune); printf '%s\n' "${1:-}"; }
queue_report() {
  for t in $(queue_prune); do
    printf 'waiting   #%s  %s [%s]\n' \
      "${t%%.*}" "$(cat "$QUEUE/$t/session" 2>/dev/null)" "$(cat "$QUEUE/$t/label" 2>/dev/null)"
  done
}

# Wake one ticket. The fifo is opened read-write (`1<>`), which for a fifo never
# blocks -- so a release can never be held up by a waiter that died between the
# liveness check and the write, and a byte written just before a waiter blocks
# is still there when it reads.
wake_ticket() {
  [ -p "$QUEUE/$1/fifo" ] || return 0
  printf 'go\n' 1<>"$QUEUE/$1/fifo" 2>/dev/null || true
}

queue_signal() { wake_ticket "$(queue_head)"; }

# Send everyone home. The marker is what a waiter acts on: unlinking a fifo
# gives the process blocked on it no end-of-file, so a ticket that is only
# deleted leaves its session asleep for good, and the wake has to reach the
# waiter whether it gets there before or after the tickets go.
queue_dismiss() {
  for t in $(queue_prune); do
    : > "$QUEUE/$t/cleared" 2>/dev/null || true
    wake_ticket "$t"
  done
}

# Become the holder, or return 1 having changed nothing. The caller reports the
# denial, which differs between `acquire` and `wait`. $3 is the caller's own
# ticket if it has one: only the head of the queue may take a free lock, so an
# unticketed acquire falls in behind sessions that are already waiting rather
# than jumping them.
take_lock() {
  if [ -d "$LOCK" ]; then
    owned || return 1
    # Re-acquiring must not re-snapshot: the backup would capture the build
    # under test and the real pre-test app would be lost.
    printf 'already held by this worktree (snapshot preserved)\n'
    return 0
  fi
  head=$(queue_head)
  [ -z "$head" ] || [ "$head" = "${3:-}" ] || return 1
  mkdir -p "$(dirname "$LOCK")"
  mkdir "$LOCK" 2>/dev/null || return 1
  # Who owns it and when it was taken go in before the snapshot, which is the
  # long part of this. A lock interrupted mid-copy is then still one its owner
  # can release and one that ages into `break`'s reach, rather than an
  # anonymous directory that wedges the queue behind it for good.
  printf '%s\n' "$SELF" > "$LOCK/worktree"
  printf '%s\n' "$NOW" > "$LOCK/acquired"
  printf '%s\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(detached)')" > "$LOCK/branch"
  printf '%s\n' "$1" > "$LOCK/label"
  printf '%s\n' "$2" > "$LOCK/session"
  printf '%s\n' "$SESSION_ID" > "$LOCK/session_id"
  if app_running; then printf 'yes\n'; else printf 'no\n'; fi > "$LOCK/app_was_running"
  # The marker goes on only once the copy has finished. A snapshot cut short --
  # this process killed mid-copy -- is a bundle that looks restorable and is
  # not, and putting it back would leave a broken app where the working one was.
  [ -d "$LIVE" ] && cp -R "$LIVE" "$BACKUP" && : > "$LOCK/snapshot_ok" || true
  printf 'acquired -- live app snapshotted (was %srunning)\n' \
    "$([ "$(field app_was_running)" = yes ] || printf 'not ')"
}

# A build is identified by its executable's hash: same bytes, same app.
build_id() { shasum -a 256 "$1/Contents/MacOS/axshot" 2>/dev/null | cut -d' ' -f1; }
same_build() { [ -d "$1" ] && [ -d "$2" ] && [ "$(build_id "$1")" = "$(build_id "$2")" ]; }

# The overlay owns the keyboard while it is up, so quitting is also how a wedged
# test is undone. It cancels itself after 15s, but not soon enough for someone
# waiting to type.
quit_app() {
  app_running || return 0
  pkill -f "$APP_PROCESS" || true
  n=0
  while app_running && [ "$n" -lt 20 ]; do sleep 0.2; n=$(( n + 1 )); done
  ! app_running || printf 'warning: an axshot instance is still running\n' >&2
}

# Swap the bundle wholesale rather than writing into it, so a half-copied app is
# never the one that gets launched. The running instance has to go first: macOS
# keeps using the old binary otherwise, and the test would measure it.
#
# Deliberately does NOT check the signature: restoring a snapshot must always be
# possible, and the snapshot is whatever was live before. Validation belongs on
# the forward install, where a bad bundle is the caller's doing.
replace_live() {
  src=$1
  was_running=$2
  if same_build "$src" "$LIVE"; then
    printf 'live app already identical -- nothing to reinstall\n'
    return 0
  fi
  quit_app
  tmp="$(dirname "$LIVE")/.Axshot.app.tmp.$$"
  rm -rf "$tmp"
  cp -R "$src" "$tmp"
  rm -rf "$LIVE"
  mv "$tmp" "$LIVE"
  if [ "$was_running" = "yes" ]; then
    open -a "$LIVE"
    printf 'installed and relaunched\n'
  else
    printf 'installed\n'
  fi
}

cmd=${1:-status}
LABEL=${2:-$(basename "$SELF")}
SESSION=${3:-${AXSHOT_SESSION:-(unnamed session)}}
case "$cmd" in

  acquire)
    take_lock "$LABEL" "$SESSION" && exit 0
    if [ -d "$LOCK" ]; then
      printf 'LOCKED -- the session "%s" is testing.\n' "$(field session)" >&2
      holder_report >&2
      is_stale && printf '\nLock is stale; `break` it after confirming with the user.\n' >&2
    else
      printf 'QUEUED AHEAD -- the lock is free but older waiters have it promised.\n' >&2
      queue_report >&2
    fi
    printf '\n`%s wait` takes it as soon as it is your turn.\n' "$0" >&2
    exit 1
    ;;

  wait)
    take_lock "$LABEL" "$SESSION" && exit 0

    # Take the ticket before looking again: enqueued first, a release racing
    # this can only signal a fifo nobody is reading yet, and the byte waits in
    # the pipe. Enqueued after, the signal would have gone to whoever was ahead
    # and this session would sleep through its own turn.
    mkdir -p "$QUEUE"
    STAGE="$QUEUE/.new.$$"
    TICKET="$STAGE"
    WAKE=
    ALARM=
    CANCEL=
    # However this ends, the ticket goes and the turn is passed on: a wait that
    # simply disappears leaves the sessions behind it asleep on a lock nobody
    # holds. `|| true` throughout, because set -e is in force inside a trap too
    # and the kills fail whenever the children were already reaped.
    trap 'st=$?; rm -rf "$TICKET" || true; kill $WAKE $ALARM 2>/dev/null || true; \
          [ -d "$LOCK" ] || queue_signal || true; \
          rmdir "$QUEUE" 2>/dev/null || true; exit $st' EXIT
    # A signal raises a flag rather than exiting where it lands. A trap runs
    # only between commands, and the command in progress is either a blocking
    # read -- which is why the read is a child, so the wait on it is
    # interruptible -- or an acquire that must not be abandoned half-made.
    trap 'CANCEL=1' INT TERM HUP

    rm -rf "$STAGE"
    mkdir "$STAGE"
    printf '%s\n' "$SELF" > "$STAGE/worktree"
    printf '%s\n' "$LABEL" > "$STAGE/label"
    printf '%s\n' "$SESSION" > "$STAGE/session"
    mkfifo "$STAGE/fifo"
    # Held open read-write for the whole wait, so a signal has somewhere to land
    # even in the moment between two blocking reads.
    exec 3<>"$STAGE/fifo"

    last=$(queue_prune | tail -1); last=${last%%.*}
    # Not `n`: the functions here have no locals, and `n` is quit_app's counter.
    TICKET_N=$(( ${last:-0} + 1 ))
    # The ticket arrives complete, fifo and all, in one rename: it can never be
    # the head of the queue in a state where a release finds nothing to signal.
    # The name carries this pid, so the only way the target is taken is two
    # sessions asking for the same position at once.
    tries=0
    while ! mv "$STAGE" "$QUEUE/$TICKET_N.$$" 2>/dev/null; do
      # `dequeue` takes the whole directory, this ticket in the making with it.
      [ -d "$STAGE" ] || die 'the queue was cleared while this ticket was being made -- run `wait` again'
      mkdir -p "$QUEUE" || die "cannot create the queue at $QUEUE"
      TICKET_N=$(( TICKET_N + 1 ))
      tries=$(( tries + 1 ))
      [ "$tries" -lt 100 ] || die "cannot claim a place in the queue at $QUEUE"
    done
    TICKET="$QUEUE/$TICKET_N.$$"

    printf 'queued at #%s behind:\n' "$TICKET_N" >&2
    [ -d "$LOCK" ] && holder_report >&2 || true
    queue_report >&2

    # The wait is bounded, and one alarm is what makes the bound arrive. Every
    # way this could hang -- a holder whose session died, a signal that reached
    # nobody, a queue that stopped moving -- ends here instead of in a session
    # parked for good. Killing the waiter outright leaves the alarm to sleep out
    # its interval; it holds nothing, and a stray `sleep` afterwards is this.
    DEADLINE=$(( $(date +%s) + WAIT_STALE ))
    ( exec 3<&-; sleep "$WAIT_STALE"; printf 'go\n' 1<>"$TICKET/fifo" ) & ALARM=$!

    while :; do
      had_lock=; [ -d "$LOCK" ] && had_lock=1 || true
      if take_lock "$LABEL" "$SESSION" "$TICKET_N.$$"; then
        # A cancelled wait must not walk off holding the lock it was handed: the
        # app slot would be parked on a session that is no longer doing
        # anything. A lock it was already holding is not this wait's to drop.
        [ -n "$CANCEL" ] && [ -z "$had_lock" ] || exit 0
        rm -rf "$LOCK"
        printf 'cancelled -- dropped the lock it had just been handed\n' >&2
        exit 130
      fi
      [ -z "$CANCEL" ] || exit 130
      if [ "$(date +%s)" -ge "$DEADLINE" ]; then
        printf 'GAVE UP -- %sm at #%s in the queue.\n' "$(( WAIT_STALE / 60 ))" "$TICKET_N" >&2
        [ -d "$LOCK" ] && holder_report >&2 \
          || printf 'the lock is free and the queue is not moving\n' >&2
        printf '\nTake it to the user: `%s status`, then `break` or `dequeue`.\n' "$0" >&2
        exit 1
      fi
      # `dequeue` cleared the queue: nothing will be written to this fifo again,
      # so say so rather than sleep on it for good.
      [ -p "$TICKET/fifo" ] && [ ! -e "$TICKET/cleared" ] \
        || die 'this ticket was cleared -- run `wait` again to requeue'
      # Blocks in the kernel until a release hands this ticket the lock. A wake
      # is a prompt to try, not a promise: the loop re-checks and waits again.
      #
      # The child closes fd 3 and opens the fifo for reading only, so the write
      # end stays with the parent alone. Inheriting it would leave the child
      # blocked for good on a fifo it was itself keeping open, every time a
      # waiter is killed outright.
      ( exec 3<&-; read _ < "$TICKET/fifo" ) & WAKE=$!
      wait "$WAKE" || true
    done
    ;;

  install)
    # No lock is the ordinary case: building on main installs. A lock held by
    # someone else is the case this exists to refuse -- their test is driving
    # the app right now, and replacing it would have them measuring this build.
    if [ -d "$LOCK" ] && ! owned; then
      printf 'REFUSED -- the session "%s" is testing the installed app.\n' "$(field session)" >&2
      holder_report >&2
      exit 1
    fi
    # No lock and a queue means the handoff itself: the lock is released and
    # the session it was promised to is a moment from snapshotting the live app.
    # Installing into that gap makes this build the app its release restores.
    if [ ! -d "$LOCK" ] && [ -n "$(queue_head)" ]; then
      printf 'REFUSED -- a queued session is being handed the lock right now.\n' >&2
      queue_report >&2
      printf '\nIf that queue is wedged rather than moving, `%s dequeue` clears it.\n' "$0" >&2
      exit 1
    fi
    [ -n "${2:-}" ] || die 'usage: install <app>'
    [ -d "$2" ] || die "no such app bundle: $2"
    [ -x "$2/Contents/MacOS/axshot" ] || die "no executable in $2 (did build.sh run?)"
    # An ad-hoc bundle would satisfy neither permission grant, so installing one
    # replaces a working app with one that cannot capture anything. Refuse it
    # here rather than let a test conclude the change is broken.
    codesign -dv "$2" 2>&1 | grep -q 'Signature=adhoc' \
      && die "$2 is ad-hoc signed; both grants would be dead. Fix signing and rebuild."
    if [ -d "$LOCK" ]; then was=$(field app_was_running); else
      if app_running; then was=yes; else was=no; fi
    fi
    replace_live "$2" "$was"
    # Only a held lock needs to remember what it put there, for drift detection.
    [ -d "$LOCK" ] && { rm -rf "$LOCK/installed"; cp -R "$2" "$LOCK/installed"; } || true
    ;;

  release)
    mode=${2:-}
    # `ship` releases only a lock this session took. A branch that was never
    # tested holds no lock, and another session's lock is theirs to restore --
    # neither is worth a message, so both exit quietly.
    if [ "$mode" = "--if-mine" ]; then
      [ -n "$SESSION_ID" ] && [ -d "$LOCK" ] && [ "$(field session_id)" = "$SESSION_ID" ] || exit 0
      mode=
    fi
    [ -d "$LOCK" ] || { printf 'no lock held\n'; exit 0; }
    owned || { printf 'lock held by another session; refusing to release:\n' >&2; holder_report >&2; exit 1; }
    [ -d "$BACKUP" ] || die 'snapshot missing -- refusing to release; rebuild from main by hand'

    if [ "$mode" = "--keep" ]; then
      rm -rf "$LOCK"
      queue_signal
      printf 'lock dropped; live app left as it is\n'
      exit 0
    fi

    # Everything below restores the snapshot, so it has to be a whole one.
    # `--keep` above is the way out and needs none.
    [ -f "$LOCK/snapshot_ok" ] || die "the snapshot at $BACKUP was never finished (the acquire was
interrupted); restoring it would break the live app. Drop the lock and leave the
app alone with: $0 release --keep"

    # What the live slot should hold right now: the last thing installed, or the
    # snapshot if nothing was. Anything else means someone rebuilt into the live
    # slot underneath us, and restoring blindly would throw that build away.
    if [ -d "$LOCK/installed" ]; then expected=$LOCK/installed; else expected=$BACKUP; fi
    if [ "$mode" != "--force" ] && ! same_build "$expected" "$LIVE"; then
      printf 'The live app changed since this lock was taken.\n' >&2
      printf 'Restoring the snapshot would discard that build.\n\n' >&2
      printf '  keep the current live app:  %s release --keep\n' "$0" >&2
      printf '  restore anyway:             %s release --force\n' "$0" >&2
      printf '\nSnapshot of the pre-test app: %s\n' "$BACKUP" >&2
      exit 1
    fi

    was_running=$(field app_was_running)
    if same_build "$BACKUP" "$LIVE"; then
      printf 'live app already matches the snapshot\n'
      [ "$was_running" = "yes" ] || quit_app
    else
      replace_live "$BACKUP" "$was_running"
    fi
    rm -rf "$LOCK"
    queue_signal
    printf 'released\n'
    ;;

  dequeue)
    # `break` recovers the lock; this recovers the queue. Needed when a ticket
    # cannot be pruned -- a pid the waiter no longer owns, reused across a
    # reboot -- which otherwise refuses every acquire and blocks every wait.
    [ -d "$QUEUE" ] || { printf 'queue is empty\n'; exit 0; }
    queue_report
    queue_dismiss
    rm -rf "$QUEUE"
    printf 'queue cleared -- the sessions that were waiting have been told to requeue\n'
    ;;

  status)
    if [ -d "$LOCK" ]; then
      owned && printf 'LOCKED by this worktree\n' || printf 'LOCKED by another session\n'
      holder_report
      is_stale && printf 'STALE -- presumed abandoned\n'
    else
      printf 'unlocked\n'
    fi
    queue_report
    exit 0
    ;;

  break)
    [ -d "$LOCK" ] || { printf 'no lock held\n'; exit 0; }
    if ! is_stale; then
      printf 'Lock is only %sm old and may still be in use:\n' "$(( $(age) / 60 ))" >&2
      holder_report >&2
      printf 'Confirm with the user, then re-run with AXSHOT_LOCK_STALE=0.\n' >&2
      exit 1
    fi
    # An abandoned lock may have left an overlay up, holding the keyboard now.
    if [ -d "$BACKUP" ] && [ ! -f "$LOCK/snapshot_ok" ]; then
      # Exactly the case this command exists for -- a session killed mid-acquire
      # -- and the one where its snapshot must not be trusted.
      printf 'the snapshot was never finished; leaving the live app alone\n' >&2
      printf 'it is at %s if it is worth looking at by hand\n' "$BACKUP" >&2
      quit_app
    elif [ -d "$BACKUP" ] && ! same_build "$BACKUP" "$LIVE"; then
      replace_live "$BACKUP" "$(field app_was_running)"
      printf 'restored the abandoned snapshot\n'
    else
      quit_app
    fi
    rm -rf "$LOCK"
    queue_signal
    printf 'lock broken\n'
    ;;

  *) die "unknown command: $cmd (acquire|wait|install|release|status|break|dequeue)" ;;
esac
