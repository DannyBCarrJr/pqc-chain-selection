#!/usr/bin/env bash
# Phase 1 smoke test runner.
#
# Starts `openssl s_server` holding BOTH classical chains (-cert/-key is the RSA
# chain, -dcert/-dkey is the ECDSA chain), runs the Go probe against it, and
# captures the server-side extension dump plus the probe output as evidence.
#
# Every captured path is redacted at collection time, not afterward. That is a
# standing rule in AGENTS.md and it exists because the pqc-cert-matrix flip
# found the checkout path in 25 evidence files and in git history.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CERTS="$HERE/certs"
EVID="$HERE/evidence"
PORT="${PORT:-4433}"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

mkdir -p "$EVID"
[[ -f "$CERTS/rsa.crt" ]] || { echo "run gen-classical-pair.sh first" >&2; exit 1; }

{
    echo "# Phase 1 smoke test"
    echo "openssl: $(openssl version)"
    echo "go:      $(go version)"
} | redact > "$EVID/versions.txt"

openssl s_server \
    -accept "$PORT" -naccept 1 \
    -cert "$CERTS/rsa.crt"  -key "$CERTS/rsa.key" \
    -dcert "$CERTS/ec.crt"  -dkey "$CERTS/ec.key" \
    -tls1_3 -tlsextdebug -no_dhe -www \
    > "$EVID/server.raw" 2>&1 &
SRV=$!
trap 'kill "$SRV" 2>/dev/null || true' EXIT

# Wait for the listener without opening a connection, since -naccept 1 means a
# readiness probe would consume the only slot.
for _ in $(seq 1 50); do
    ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
    sleep 0.1
done

( cd "$HERE" && go run ./probe.go "127.0.0.1:$PORT" ) 2>&1 | redact | tee "$EVID/probe.txt"
wait "$SRV" 2>/dev/null || true

redact < "$EVID/server.raw" > "$EVID/server-extensions.txt"
rm -f "$EVID/server.raw"

echo
echo "--- did the Go client send signature_algorithms_cert (type 50)? ---"
grep -iE "signature algorithms cert|extension.*\b50\b" "$EVID/server-extensions.txt" \
    || echo "NOT FOUND (inspect $(echo "$EVID/server-extensions.txt" | redact))"
