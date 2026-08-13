#!/usr/bin/env bash
# Caddy column. Caddy is Go, so it inherits crypto/tls, whose SupportsCertificate
# carries a source comment saying it does not support signature_algorithms_cert
# and does not check the algorithms of the signatures on the chain.
#
# The prediction is therefore that Caddy behaves like rustls and unlike
# nginx/OpenSSL on the single-excluded cell. Caddy also runs its own certificate
# selection above crypto/tls, so this is not a foregone conclusion, which is why
# it is measured rather than asserted.
#
# Built from source with the same Go the probe uses, so one toolchain version
# covers both ends of the measurement.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PROBE="$REPO/probe/tlspatch/build/probe"
CADDY="${CADDY:-$(go env GOPATH)/bin/caddy}"
C="$REPO/gen/chains"
EVID="$HERE/evidence/caddy"
PORT="${PORT:-4466}"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -x "$CADDY" ]] || { echo "caddy not found at $CADDY" >&2; exit 1; }
mkdir -p "$EVID"

# The live Caddyfile holds absolute paths, so it is written OUTSIDE evidence/
# and only a redacted copy is kept. Same for caddy's own log. Redaction happens
# at collection, which is the standing rule in CONTRIBUTING.md.
WORK="$(mktemp -d)"
PID=""
stop() { [[ -n "$PID" ]] && kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null || true; PID=""; }
trap 'stop; [[ -f "$WORK/caddy.log" ]] && redact < "$WORK/caddy.log" > "$EVID/caddy.log"; rm -rf "$WORK"' EXIT

start() { # $1 Caddyfile text
    stop
    printf '%s\n' "$1" > "$WORK/Caddyfile"
    redact < "$WORK/Caddyfile" > "$EVID/Caddyfile"
    "$CADDY" run --config "$WORK/Caddyfile" --adapter caddyfile > "$WORK/caddy.log" 2>&1 &
    PID=$!
    for _ in $(seq 1 80); do
        ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
        sleep 0.25
    done
    sleep 0.5
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "caddy failed to start:" >&2; tail -5 "$WORK/caddy.log" >&2; return 1
    fi
}

cell() { # $1 label, $2 SIGALGS, $3 SIGALGS_CERT
    local label="$1" sa="$2" sac="$3"
    local out="$EVID/$label.probe"
    ( cd "$REPO" && PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" \
        "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    local hs served
    hs="$(head -1 "$out" | sed 's/^handshake: //')"
    served="$(grep -oE 'key=[A-Za-z0-9]+' "$out" | head -1 || true)"
    [[ -n "$served" ]] || served="$(grep -oE 'NOTHING CAPTURED' "$out" | head -1 || echo '?')"
    printf '%-18s %-14s %-10s %-10s %s\n' "$label" "$sa" "$sac" "$served" "${hs:0:46}"
    redact < "$out" > "$EVID/$label.probe.txt"; rm -f "$out"
}

single="{
    auto_https off
    admin off
}
:$PORT {
    tls $C/pqissuer/fullchain.crt $C/pqissuer/leaf.key
    respond \"ok\"
}"

dual="{
    auto_https off
    admin off
}
:$PORT {
    tls $C/classical/fullchain.crt $C/classical/leaf.key
    tls $C/pq/fullchain.crt $C/pq/leaf.key
    respond \"ok\"
}"

{
    echo "# caddy column, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# $("$CADDY" version 2>&1 | head -1) built with $(go version | awk '{print $3}')"
    echo "# 0x0403=ecdsa_secp256r1_sha256  0x0904=mldsa44"
    echo
    printf '%-18s %-14s %-10s %-10s %s\n' cell sigalgs sigalgs_cert served handshake
    printf '%-18s %-14s %-10s %-10s %s\n' ------------------ -------------- ---------- ---------- ---------

    echo "# single chain: pqissuer only. s_server and nginx REFUSED, rustls SERVED."
    start "$single"
    cell single-excluded 0x0403 0x0403
    cell single-allowed  0x0403 0x0904
    echo
    echo "# dual chain: classical + pq"
    if start "$dual" 2>/dev/null; then
        cell dual-ecdsa-only  0x0904,0x0403 0x0403
        cell dual-pq-only     0x0904,0x0403 0x0904
        cell dual-suppressed  0x0904,0x0403 none
    else
        echo "dual config REJECTED by caddy, see evidence/caddy/caddy.log"
    fi
} 2>&1 | tee "$EVID/../caddy.txt"
