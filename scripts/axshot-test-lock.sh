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
#   install <app>     replace the live app with this build and relaunch it;
#                     refused while another session holds the lock
#   release           restore the snapshot and drop the lock
#                     --keep     drop the lock, leave the live app as it is
#                     --force    restore even if the live app changed
#                     --if-mine  no-op unless this session took the lock
#   status            who holds it, since when, whether stale
#   break             force-release a lock left behind by a dead session
set -eu

ROOT=${AXSHOT_ROOT:-$(git worktree list --porcelain | head -1 | sed 's/^worktree //')}
LIVE=${AXSHOT_LIVE:-/Applications/Axshot.app}
LOCK="$ROOT/.claude/axshot-test.lock"
BACKUP="$LOCK/Axshot.app.pre"
STALE_SECONDS=${AXSHOT_LOCK_STALE:-1800}
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
  printf '%s' $(( NOW - held ))
}
holder_report() {
  printf 'held by   %s\n' "$(field label)"
  printf 'session   %s\n' "$(field session)"
  if [ -s "$LOCK/session_id" ]; then printf 'session id %s\n' "$(field session_id)"; fi
  printf 'worktree  %s\n' "$(field worktree)"
  printf 'branch    %s\n' "$(field branch)"
  printf 'age       %sm (stale after %sm)\n' "$(( $(age) / 60 ))" "$(( STALE_SECONDS / 60 ))"
}
owned() { [ "$(field worktree)" = "$SELF" ]; }
# STALE_SECONDS=0 means "treat any lock as abandoned" -- the documented override
# for breaking a live lock once the user has confirmed nobody is mid-test.
is_stale() { [ "$(age)" -ge "$STALE_SECONDS" ]; }

app_running() { pgrep -f "$APP_PROCESS" >/dev/null 2>&1; }

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
case "$cmd" in

  acquire)
    mkdir -p "$(dirname "$LOCK")"
    if mkdir "$LOCK" 2>/dev/null; then
      [ -d "$LIVE" ] && cp -R "$LIVE" "$BACKUP" || true
      printf '%s\n' "$SELF" > "$LOCK/worktree"
      printf '%s\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(detached)')" > "$LOCK/branch"
      printf '%s\n' "${2:-$(basename "$SELF")}" > "$LOCK/label"
      printf '%s\n' "${3:-${AXSHOT_SESSION:-(unnamed session)}}" > "$LOCK/session"
      printf '%s\n' "$SESSION_ID" > "$LOCK/session_id"
      printf '%s\n' "$NOW" > "$LOCK/acquired"
      if app_running; then printf 'yes\n'; else printf 'no\n'; fi > "$LOCK/app_was_running"
      printf 'acquired -- live app snapshotted (was %srunning)\n' \
        "$([ "$(field app_was_running)" = yes ] || printf 'not ')"
    elif owned; then
      # Re-acquiring must not re-snapshot: the backup would capture the build
      # under test and the real pre-test app would be lost.
      printf 'already held by this worktree (snapshot preserved)\n'
    else
      printf 'LOCKED -- the session "%s" is testing.\n' "$(field session)" >&2
      holder_report >&2
      is_stale && printf '\nLock is stale; `break` it after confirming with the user.\n' >&2
      exit 1
    fi
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
      printf 'lock dropped; live app left as it is\n'
      exit 0
    fi

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
    printf 'released\n'
    ;;

  status)
    [ -d "$LOCK" ] || { printf 'unlocked\n'; exit 0; }
    owned && printf 'LOCKED by this worktree\n' || printf 'LOCKED by another session\n'
    holder_report
    is_stale && printf 'STALE -- presumed abandoned\n'
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
    if [ -d "$BACKUP" ] && ! same_build "$BACKUP" "$LIVE"; then
      replace_live "$BACKUP" "$(field app_was_running)"
      printf 'restored the abandoned snapshot\n'
    else
      quit_app
    fi
    rm -rf "$LOCK"
    printf 'lock broken\n'
    ;;

  *) die "unknown command: $cmd (acquire|install|release|status|break)" ;;
esac
