# Permissions

Axshot needs Accessibility and Screen Recording. Getting them granted is the roughest part of first
use, and almost all of the roughness is TCC's, not the app's. [The README](../README.md#permission)
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

Editing the source and recompiling is free — the requirement still matches and the grants hold,
which is worth confirming after any change that touches signing. This is the entire reason `build.sh` signs with a stable identity
rather than letting the linker sign ad-hoc, where the requirement pins a code hash that changes with
every compile.

## The CLI shares the app's grants, by construction

Axshot's CLI is the app's own binary, invoked from inside `Axshot.app`, and it re-spawns itself with
its responsibility disclaimed — so TCC resolves it to the bundle and the CLI inherits the app's
grants. `bin/axshot --dump` works as soon as the app is granted, and stops the moment the bundle's
identity changes.

Neither half of that is incidental. Without the disclaim, a run from a terminal is judged as the
terminal, and inherits whatever the terminal happens to have — which is how a check can pass in a
shell and fail everywhere else. Outside the bundle it would be a separate client with separate
grants. Keep the CLI inside the bundle and keep the disclaim, or the two stop agreeing.

## Three ways granting looks like it failed when it did not

- **The dialog opened on another Space.** macOS puts it where it likes. Nothing appears to happen,
  the request returns false, and the app stays denied — because nobody answered it.
- **The row is listed and switched on, and every check still says no.** The row was created against
  a different signature, so its stored requirement no longer matches. There is no API that
  distinguishes this from never having been asked, which is why the settings window offers
  "Reset & ask again" once a request has visibly failed rather than trying to detect it.
- **Accessibility was granted while the app was running.** Trust is decided for a process when it
  starts. Relaunch. Screen Recording, by contrast, applies at once.

`tccutil reset <service> <bundle-id>` clears a record so it can be asked for cleanly. It is the only
escape from the second case, and it is what the app's own reset button runs.

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

An unattended build must not block on this dialog. `build.sh` waits, then falls back to ad-hoc; if
you are scripting a build that must never prompt, use `AXSHOT_ADHOC=1`.
