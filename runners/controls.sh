#!/usr/bin/env bash
# Controls and repeatability. Closes the three debts recorded in MATRIX.md.
#
# 1. NEGATIVE CONTROL. Every "handshake OK" in this repo is only meaningful if
#    the client would actually have rejected a bad chain. Serve a chain whose
#    leaf signature has one flipped byte and confirm a verifying client refuses
#    it, with the untampered chain as the paired positive control. If the
#    tampered chain passes, verification is not happening and every OK verdict
#    in the matrix is worthless.
#
# 2. CONFIG ORDER. BoringSSL documents selecting the first usable credential,
#    which implies configuration order decides. Envoy cannot be tested because
#    it will not load the post-quantum chain, so the question is put to nginx:
#    with two chains the client accepts equally, does swapping the order in the
#    config swap the chain on the wire?
#
# 3. REPEATABILITY. Every cell in the matrix so far is one run. Repeat the
#    deciding cells and confirm the verdicts are stable.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PROBE="$REPO/probe/tlspatch/build/probe"
C="$REPO/gen/chains"
EVID="$HERE/evidence/controls"
PORT="${PORT:-4488}"
NGPORT="${NGPORT:-4489}"
NAME="pqcs-nginx-order"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
mkdir -p "$EVID"
WORK="$(mktemp -d)"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap 'cleanup; rm -rf "$WORK"' EXIT

# Flip one byte inside the leaf's signature. The structure stays parseable, so
# the failure is cryptographic rather than a decode error, which is the point.
python3 - "$C/classical/leaf.crt" "$WORK/tampered.crt" <<'PY'
import base64, sys, textwrap
raw = open(sys.argv[1]).read()
body = "".join(l for l in raw.splitlines() if "-----" not in l)
der = bytearray(base64.b64decode(body))
der[-5] ^= 0xFF                     # inside the signature BIT STRING
out = base64.b64encode(bytes(der)).decode()
open(sys.argv[2], "w").write(
    "-----BEGIN CERTIFICATE-----\n" + "\n".join(textwrap.wrap(out, 64)) + "\n-----END CERTIFICATE-----\n")
PY
cat "$WORK/tampered.crt" "$C/classical/int.crt" > "$WORK/tampered-chain.crt"

serve_openssl() { # $1 chainfile, $2 keyfile
    openssl s_server -accept "$PORT" -naccept 1 -cert "$1" -key "$2" \
        -cert_chain "$C/classical/int.crt" -tls1_3 -www > "$WORK/s.log" 2>&1 &
    SRV=$!
    for _ in $(seq 1 50); do ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break; sleep 0.1; done
}

verify_cell() { # $1 label, $2 chainfile, $3 expectation
    serve_openssl "$2" "$C/classical/leaf.key"
    local out; out=$( ( cd "$REPO" && "$PROBE" -addr "127.0.0.1:$PORT" -roots "$C/classical/root.crt" ) 2>&1 || true )
    wait "$SRV" 2>/dev/null || true
    local got="pass"; grep -q "FAILED" <<<"$out" && got="reject"
    local flag="  "; [[ "$got" == "$3" ]] || flag="<- MISMATCH"
    printf '  %-22s %-8s want=%-8s %s\n' "$1" "$got" "$3" "$flag"
    redact <<<"$out" > "$EVID/$1.txt"
}

{
    echo "# controls, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# $(openssl version) | $(go version)"
    echo
    echo "1. NEGATIVE CONTROL: verification must actually be happening"
    verify_cell positive-untampered "$C/classical/fullchain.crt" pass
    verify_cell negative-tampered   "$WORK/tampered-chain.crt"   reject
    echo
    echo "2. CONFIG ORDER on nginx: same two chains, order swapped in the config"
    echo "   client accepts both leaf key types and both chain signature types"
    for order in "classical pq" "pq classical"; do
        set -- $order
        cat > "$WORK/nginx.conf" <<EOF
events {}
http {
  server {
    listen 443 ssl;
    ssl_protocols TLSv1.3;
    ssl_certificate     /chains/$1/fullchain.crt;
    ssl_certificate_key /chains/$1/leaf.key;
    ssl_certificate     /chains/$2/fullchain.crt;
    ssl_certificate_key /chains/$2/leaf.key;
    location / { return 200 "ok"; }
  }
}
EOF
        cleanup
        docker run -d --name "$NAME" -p "127.0.0.1:$NGPORT:443" \
            -v "$C:/chains:ro" -v "$WORK/nginx.conf:/etc/nginx/nginx.conf:ro" \
            nginx:alpine >/dev/null
        for _ in $(seq 1 60); do (exec 3<>/dev/tcp/127.0.0.1/"$NGPORT") 2>/dev/null && break; sleep 0.25; done
        sleep 0.5
        out=$( ( cd "$REPO" && PROBE_SIGALGS=0x0904,0x0403 PROBE_SIGALGS_CERT=0x0904,0x0403 \
            "$PROBE" -addr "127.0.0.1:$NGPORT" ) 2>&1 || true )
        # Do not chain these with && under pipefail: head -1 closing the pipe
        # makes the whole expression non-zero and set -e kills the run.
        served="$(grep -oE 'key=[A-Za-z0-9]+' <<<"$out" | head -1 || true)"
        if [[ -z "$served" ]] && grep -q "unsupported type of public key" <<<"$out"; then
            served="pq chain (ML-DSA, client cannot parse it)"
        fi
        printf '  config order: %-22s served: %s\n' "$1 then $2" "${served:-?}"
        redact <<<"$out" > "$EVID/order-$1-first.txt"
    done
    cleanup
    echo
    echo "3. REPEATABILITY: the deciding cell, five consecutive runs"
    for i in 1 2 3 4 5; do
        openssl s_server -accept "$PORT" -naccept 1 \
            -cert "$C/pqissuer/leaf.crt" -key "$C/pqissuer/leaf.key" \
            -cert_chain "$C/pqissuer/int.crt" -tls1_3 -www > "$WORK/s.log" 2>&1 &
        SRV=$!
        for _ in $(seq 1 50); do ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break; sleep 0.1; done
        out=$( ( cd "$REPO" && PROBE_SIGALGS=0x0403 PROBE_SIGALGS_CERT=0x0403 \
            "$PROBE" -addr "127.0.0.1:$PORT" ) 2>&1 || true )
        wait "$SRV" 2>/dev/null || true
        printf '  run %d: %s\n' "$i" "$(head -1 <<<"$out" | sed 's/^handshake: //' | cut -c1-46)"
    done
} 2>&1 | tee "$EVID/../controls.txt"
