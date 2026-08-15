#!/usr/bin/env bash
# Phase 1 gate: prove the patched probe controls signature_algorithms_cert.
#
# Three cells against the same dual-chain s_server, read from the SERVER side so
# the evidence is what went on the wire, not what the client believes it sent.
#
#   stock       env unset            extension present, stock contents
#   restricted  two code points      extension present, len shrinks to 6
#   suppressed  "none"               extension absent entirely
#
# Six bytes is the arithmetic: a 2-byte list length plus two 2-byte code points.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE="$HERE/../smoke"
EVID="$HERE/evidence"
PROBE="$HERE/build/probe"
PORT="${PORT:-4433}"
REPO="$(cd "$HERE/../.." && pwd)"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run ./build.sh first" >&2; exit 1; }
[[ -f "$SMOKE/certs/rsa.crt" ]] || { echo "run ../smoke/gen-classical-pair.sh first" >&2; exit 1; }
mkdir -p "$EVID"

cell() { # name, env-spec
    local name="$1" spec="$2" raw="$EVID/$1.raw"

    openssl s_server -accept "127.0.0.1:$PORT" -naccept 1 \
        -cert "$SMOKE/certs/rsa.crt" -key "$SMOKE/certs/rsa.key" \
        -dcert "$SMOKE/certs/ec.crt" -dkey "$SMOKE/certs/ec.key" \
        -tls1_3 -tlsextdebug -www > "$raw" 2>&1 &
    local srv=$!
    for _ in $(seq 1 50); do
        ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
        sleep 0.1
    done

    local out="$EVID/$name.probe"
    # -addr, not positional: the probe ignores positional arguments, and the old
    # positional call only ever connected because PORT and the probe's default
    # happened to both be 4433.
    if [[ "$spec" == "stock" ]]; then
        ( cd "$SMOKE" && env -u PROBE_SIGALGS_CERT "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    else
        ( cd "$SMOKE" && PROBE_SIGALGS_CERT="$spec" "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    fi
    wait "$srv" 2>/dev/null || true

    local ext served
    ext="$(grep -E 'extension "unknown" \(id=50' "$raw" | tr -s ' ' || true)"
    # What the server actually chose, which is the measurement the extension
    # exists to influence. An error here is itself a result: a server that
    # aborts rather than downgrade is behaving differently from one that
    # silently serves an excluded chain.
    # Matches the probe's CURRENT print format. The old pattern kept matching
    # the Phase 1 format after a887616 changed the probe to cn/key/sig, so this
    # column read NO CHAIN for two phases while the gate looked green.
    served="$(grep -oE 'cn="[^"]*" key=[A-Za-z0-9]+ sig=[A-Za-z0-9-]+' "$out" | head -1 || true)"
    [[ -n "$served" ]] || served="NO CHAIN: $(head -1 "$out" | cut -c1-60)"

    printf '%-11s %-16s %-46s %s\n' "$name" "$spec" "${ext:-<ext 50 ABSENT>}" "$served"
    redact < "$raw" > "$EVID/$name.txt"; rm -f "$raw"
    redact < "$out" > "$EVID/$name.probe.txt"; rm -f "$out"
}

{
    echo "# Phase 1 gate, $(openssl version), $(go version)"
    echo
    cell stock      stock
    cell restricted 0x0403,0x0804
    cell suppressed none
} | tee "$EVID/gate.txt"

# The served column is the measurement. Every cell here uses a classical server
# pair the probe can always read, so a NO CHAIN fallback means the probe or the
# extraction broke, and the gate must say so instead of printing it in green.
if grep -q 'NO CHAIN' "$EVID/gate.txt"; then
    echo "GATE FAILURE: a cell served no readable chain; see $EVID" >&2
    exit 1
fi
