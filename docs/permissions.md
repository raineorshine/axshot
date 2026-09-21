# Permissions

Axshot needs Accessibility, Screen Recording and Input Monitoring. Getting them granted is the
roughest part of first use, and almost all of the roughness is TCC's, not the app's. [The README](../README.md#permission)
says what a user does; this says what a maintainer needs to know before touching anything that
changes the app's identity.

## What TCC thinks "this app" is

A grant is recorded against a **code signing identity**, not a path or a name. The record keeps the
requirement the binary satisfied when the row was created, and re-checks it on every use.

`codesign -d -r-` prints that requirement. For a self-signed build it reads:

    designated => identifier "com.raine.axshot" and certificate leaf = H"…"

Two things follow, and both cost a full re-grant of both permissions:

- **Changing the bundle identifier breaks it.** The identifier is half the requirement.
- **Changing the signing certificate breaks it.** The leaf hash is the other half. Deleting and
  recreating the identity — to rename it, or because the key was lost — is a new certificate.

Editing the source and recompiling is free: the requirement still matches and the grants hold, which
is worth confirming after any change that touches signing. That is the whole reason `build.sh` signs
with a stable identity rather than ad-hoc, where the requirement pins a code hash that changes with
every compile.

## One binary, two identities

The CLI is the app's own executable, reached through `bin/axshot`, a symlink into the bundle — the
same bytes, and not the same identity to everything that asks:

- **To Foundation, the CLI has no bundle.** dyld reports the symlink rather than what it points at,
  so on the command line `Bundle.main` is `bin/` and carries no identifier. Anything that would ask
  the bundle who this is — the preferences domain, the identifier handed to `tccutil` — names what it
  wants instead.
- **To TCC, the CLI is the app.** A run re-spawns itself with its responsibility disclaimed, so TCC
  resolves it to the bundle and it inherits the app's grants: `bin/axshot --dump` works as soon as the
  app is granted, and stops the moment the bundle's identity changes. Without the disclaim, a run from
  a terminal is judged as the terminal and inherits whatever it has — which is how a check passes in a
  shell and fails everywhere else. Keep the CLI inside the bundle and keep the disclaim.
- **A loose binary is nobody.** Signed with the same identity, it still answers `trusted=false`
  however it was built: the requirement names the bundle identifier, and a bare Mach-O carries none.
  A second build that has to be trusted, such as a comparison build, goes inside a copy of
  `Axshot.app`.

[Asking who the process is](testing.md#asking-who-the-process-is) is how to see which identity a run
picked up.

## Two ways granting looks like it failed when it did not

- **The dialog opened on another Space.** macOS puts it where it likes. Nothing appears to happen,
  the request returns false, and the app stays denied — because nobody answered it.
- **The row is listed and switched on, and every check still says no.** The row was created against
  a different signature, so its stored requirement no longer matches. There is no API that
  distinguishes this from never having been asked, which is why the settings window offers
  "Reset & ask again" once a request has visibly failed rather than trying to detect it.

`tccutil reset <service> <bundle-id>` clears a record so it can be asked for cleanly. It is the only
escape from the second case, and it is what the app's own reset button runs.

## A grant takes effect immediately

**There is nothing to relaunch for.** Measured with a throwaway app of its own bundle identifier,
polling once a second while a switch was flipped under it:

| | |
|---|---|
| Accessibility | denied at launch; one second after the switch, `AXIsProcessTrusted()` true and a real `AXUIElementCopyAttributeValue` read of another app's windows returning 0 |
| Input Monitoring | denied for the first seven minutes of the same process; one second after the switch, `CGEvent.tapCreate` succeeding where it had failed every second before |

The app used to carry a Relaunch button saying otherwise. It was wrong about both.

Two traps come with this, and both are about believing an answer instead of trying the thing:

- **`CGPreflightListenEventAccess()` caches its denial for the life of the process.** It went on
  returning false on the same log lines where both taps were being created successfully. This is the
  same trap as `CGPreflightScreenCaptureAccess()` below, and the same rule applies: let the attempt
  decide. A permission row driven by that preflight would read "Not granted" over a working app.
- **`com.apple.accessibility.api` covers Accessibility only, and arrives early.** It is the
  distributed notification Hammerspoon observes, which is how its preferences window turns green
  with no restart. It did not fire at all for the Input Monitoring change, and when it did fire it
  was delivered in the same second that `AXIsProcessTrusted()` still answered false. An observer
  must re-read rather than believe the state it wakes up with — which is why the settings window
  polls at 1 Hz instead.

## Input Monitoring, the third grant

The hint tap is a keyboard `CGEvent.tapCreate`, and on this macOS Accessibility does not carry it:
a process with Accessibility granted and Input Monitoring denied creates no keyboard tap, of either
`.defaultTap` or `.listenOnly` kind.

**Nothing in the app asks for it, and nothing should.** macOS puts up its own "would like to receive
keystrokes" dialog the first time a tap fails, and adds axshot to the list by itself — confirmed by
a probe that never called `CGRequestListenEventAccess` and was listed anyway. So the first capture
on a fresh machine fails once, the dialog explains why, and the next press works. What the app owes
that moment is a sentence rather than a row: the failure alert says what the dialog is about and
that pressing the shortcut again is the whole fix.

It is also why the settings window lists two grants and the app needs three. A row for the third
could not be drawn honestly without creating a throwaway tap every second, since the preflight lies.

## Asking for Screen Recording

`CGRequestScreenCaptureAccess()` on its own did not add Axshot to the Screen Recording list at all —
no row, granted or denied. What registers a client is touching the capture path, so the request also
makes a throwaway `SCShareableContent` query.

`CGWindowListCreateImage` is not an option: it is **removed**, not merely deprecated, and fails to
compile. ScreenCaptureKit is the only way in.

Do not gate the tool on `CGPreflightScreenCaptureAccess()`. It answers for *this* process going
through CoreGraphics, while the capture runs through `screencapture(1)`, which is judged separately
and can succeed where the preflight says no. A wrong refusal is a tool that will not work at all;
let the capture attempt be what decides, and report the preflight only as a hint on failure.

## The keychain prompt

The first build after the identity is created asks whether `codesign` may use the key. **Always
Allow** stores the decision; plain **Allow** authorises one invocation and the next build asks
again. Passing the login password to `create-signing-cert.sh` sets this up front instead.

The key's label in that dialog comes from the filename `security import` read, which is why the
script writes the key to a file named after the identity. A key already in the keychain cannot be
relabelled — only replaced, which means a new certificate, which means re-granting both permissions.
`security dump-keychain` lists passwords and not keys, so the dialog is the only readout of that
label.

A build sitting at `==> Signing as` is waiting on this dialog — a `SecurityAgent` process — and not
compiling. `build.sh` gives it two minutes, then falls back to ad-hoc, which `install` refuses. A
scripted build that must never prompt runs `AXSHOT_ADHOC=1 ./build.sh --no-install`, and installs
nothing.
