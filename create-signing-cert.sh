#!/usr/bin/env bash
#
# Creates a stable, self-signed code-signing certificate for axshot, then prints its identity name
# on stdout.
#
# Why this exists: an ad-hoc signature's code hash changes on every build, and TCC pins both the
# Accessibility and the Screen Recording grant to that hash -- so after each rebuild macOS treats
# the binary as a stranger and both permissions have to be granted again. A self-signed certificate
# gives a stable Designated Requirement, pinned to the certificate rather than the hash, and the
# grants survive.
#
# Idempotent: if the identity already exists this is a no-op. Progress goes to stderr; only the
# identity name reaches stdout, so callers can capture it:
#
#     IDENTITY="$(./create-signing-cert.sh)"
#
# It never prompts. codesign needs permission to use the new key, which macOS asks for with a
# one-time "Always Allow" dialog on the first build. To skip that dialog, pass the login password:
#
#     AXSHOT_KEYCHAIN_PASSWORD='…' ./create-signing-cert.sh
set -euo pipefail

CERT_NAME="${AXSHOT_SIGN_IDENTITY:-axshot Local Signing}"
KEYCHAIN="${AXSHOT_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

log() { printf '%s\n' "$*" >&2; }

# Self-signed certs are untrusted, so they only appear under the default (X.509 Basic) policy, not
# `-p codesigning`. Match on the identity name.
if security find-identity "$KEYCHAIN" 2>/dev/null | grep -qF "$CERT_NAME"; then
	printf '%s\n' "$CERT_NAME"
	exit 0
fi

log "==> Creating self-signed code-signing certificate \"$CERT_NAME\" (valid 10 years)…"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions     = v3
prompt              = no
[ dn ]
CN = $CERT_NAME
[ v3 ]
basicConstraints     = critical,CA:FALSE
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
	-keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
	-days 3650 -config "$TMP/cert.cnf" >/dev/null 2>&1

# Import key and cert separately -- more reliable than a PKCS#12 across OpenSSL versions.
# -T /usr/bin/codesign puts codesign on the key's access list.
security import "$TMP/key.pem"  -k "$KEYCHAIN" -T /usr/bin/codesign >/dev/null
security import "$TMP/cert.pem" -k "$KEYCHAIN" -T /usr/bin/codesign >/dev/null

if [ -n "${AXSHOT_KEYCHAIN_PASSWORD:-}" ]; then
	if security set-key-partition-list -S apple-tool:,apple: -s -k "$AXSHOT_KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null 2>&1; then
		log "==> codesign authorised to use the signing key."
	else
		log "warning: could not authorise the key; expect a one-time keychain prompt on first build."
	fi
else
	log "note: no password given, so expect a one-time \"Always Allow\" prompt on the first build."
fi

log "==> Certificate ready."
printf '%s\n' "$CERT_NAME"
