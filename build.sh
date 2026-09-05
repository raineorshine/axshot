#!/bin/sh
# Build axshot.swift into Axshot.app, signed with the local identity so the permission grants
# survive the rebuild.
#
# The app is a menu bar accessory (LSUIElement) holding two global hotkeys. The same binary is the
# command line tool when it is given arguments, so bin/axshot links to it for --dump.
#
# Signing: create-signing-cert.sh makes a stable self-signed identity the first time it runs, which
# is what keeps Accessibility and Screen Recording granted across rebuilds. Without it the build
# falls back to ad-hoc and both permissions have to be granted again after every build.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
APP="$HERE/Axshot.app"
BUNDLE_ID="com.raine.axshot"
VERSION="0.1"

# AXSHOT_ADHOC=1 skips the identity entirely, for a build that must not block on a keychain dialog.
if [ -n "${AXSHOT_ADHOC:-}" ]; then
	IDENTITY="-"
else
	IDENTITY=$("$HERE/create-signing-cert.sh" 2>/dev/null || true)
	[ -n "$IDENTITY" ] || IDENTITY="-"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>axshot</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleName</key><string>axshot</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/axshot" "$HERE/axshot.swift"

# The first build with a new identity puts up a keychain dialog asking to let codesign use the key.
# Wait for it, but not forever: an unattended build should end up ad-hoc rather than hanging.
if [ "$IDENTITY" != "-" ]; then
	printf '==> Signing as "%s" (approve the keychain dialog if one appears)\n' "$IDENTITY" >&2
	codesign --force --sign "$IDENTITY" "$APP" >/dev/null 2>&1 &
	SIGNER=$!
	WAITED=0
	while kill -0 "$SIGNER" 2>/dev/null && [ "$WAITED" -lt 120 ]; do
		sleep 1
		WAITED=$((WAITED + 1))
	done
	if kill -0 "$SIGNER" 2>/dev/null; then
		kill "$SIGNER" 2>/dev/null || true
		printf 'warning: signing timed out waiting for the keychain dialog; falling back to ad-hoc.\n' >&2
		IDENTITY="-"
	elif ! wait "$SIGNER"; then
		printf 'warning: codesign failed; falling back to ad-hoc.\n' >&2
		IDENTITY="-"
	fi
fi

if [ "$IDENTITY" = "-" ]; then
	codesign --force --sign - "$APP" >/dev/null 2>&1 || true
	printf 'note: ad-hoc signed. Accessibility and Screen Recording must be granted again after every build.\n' >&2
fi

mkdir -p "$HERE/bin"
ln -sf "$APP/Contents/MacOS/axshot" "$HERE/bin/axshot"

printf 'built %s (signed by %s)\n' "$APP" "$IDENTITY"
