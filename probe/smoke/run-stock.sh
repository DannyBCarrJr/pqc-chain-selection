#!/usr/bin/env bash
# Stock-client capture runner.
#
# Same server, same instrument, different client. run.sh captures what the
# min-1.3 probe sends; this runs stock/main.go, a default-Config Go client,
# against the identical `openssl s_server -tlsextdebug` and keeps the
# extension dump as evidence. The point is the pair of signature extensions:
# at the default minimum the two lists differ by the SHA-1 schemes only, and
# the hex dump shows which codepoints sit in each list, not just the counts.
#
# Redaction at collection time, same rule and same reason as run.sh.
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
    echo "# Stock default-Config client capture"
    echo "openssl: $(openssl version)"
    echo "go:      $(go version)"
} | redact > "$EVID/stock-versions.txt"

openssl s_server \
    -accept "127.0.0.1:$PORT" -naccept 1 \
    -cert "$CERTS/rsa.crt"  -key "$CERTS/rsa.key" \
    -dcert "$CERTS/ec.crt"  -dkey "$CERTS/ec.key" \
    -tls1_3 -tlsextdebug -no_dhe -www \
    > "$EVID/stock.raw" 2>&1 &
SRV=$!
trap 'kill "$SRV" 2>/dev/null || true' EXIT

# Wait for the listener without opening a connection, since -naccept 1 means a
# readiness probe would consume the only slot.
for _ in $(seq 1 50); do
    ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
    sleep 0.1
done

( cd "$HERE" && go run ./stock -addr "127.0.0.1:$PORT" ) 2>&1 | redact
wait "$SRV" 2>/dev/null || true

redact < "$EVID/stock.raw" > "$EVID/stock-client-extensions.txt"
rm -f "$EVID/stock.raw"

echo
echo "--- the two signature lists, stock default Config ---"
grep -A2 -E "\(id=13\)|\(id=50\)" "$EVID/stock-client-extensions.txt" \
    || echo "NOT FOUND (inspect $(echo "$EVID/stock-client-extensions.txt" | redact))"
