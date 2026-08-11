#!/usr/bin/env bash
# Control column: openssl s_server holding a classical and a post-quantum chain
# at once, probed with varying signature_algorithms and signature_algorithms_cert.
#
# This is the `-cert`/`-dcert` dual-certificate path. It is NOT the `-xcert`
# Extended-certificates path that OpenSSL #32221 reports as broken, so nothing
# here confirms or refutes that issue.
#
# Verdicts:
#   correct              server sent a chain satisfying both client constraints
#   wrong-chain-silent   server sent a chain the client excluded, handshake ok
#   fail-closed          server sent an alert rather than an unusable chain
#   no-selection         server had no chain and did not attempt one
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
C="$REPO/gen/chains"
PROBE="$REPO/probe/tlspatch/build/probe"
EVID="$HERE/evidence/s_server"
PORT="${PORT:-4433}"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -f "$C/pq/leaf.crt" ]] || { echo "run gen/mint-chains.sh first" >&2; exit 1; }
mkdir -p "$EVID"

# $1 label, $2 PROBE_SIGALGS, $3 PROBE_SIGALGS_CERT ("-" means leave unset)
cell() {
    local label="$1" sa="$2" sac="$3"
    local raw="$EVID/$label.server" out="$EVID/$label.probe"

    openssl s_server -accept "127.0.0.1:$PORT" -naccept 1 \
        -cert "$C/classical/leaf.crt" -key "$C/classical/leaf.key" -cert_chain "$C/classical/int.crt" \
        -dcert "$C/pq/leaf.crt"       -dkey "$C/pq/leaf.key"       -dcert_chain "$C/pq/int.crt" \
        -tls1_3 -tlsextdebug -msg -www > "$raw" 2>&1 &
    local srv=$!
    for _ in $(seq 1 50); do
        ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
        sleep 0.1
    done

    if [[ "$sac" == "-" ]]; then
        ( cd "$REPO" && env -u PROBE_SIGALGS_CERT PROBE_SIGALGS="$sa" "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    else
        ( cd "$REPO" && PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    fi
    wait "$srv" 2>/dev/null || true

    # Server-side ground truth. The client cannot parse an ML-DSA chain, so
    # message LENGTH is what identifies which chain went out: an ML-DSA-44
    # CertificateVerify carries a 2420-byte signature, an ECDSA one about 72.
    local hs served certlen cvlen
    # sed extracts the captured group. A second grep -oE would match the "a"
    # in "Handshake" first and silently report every length as 0xa.
    certlen="$(grep -E 'Handshake \[length [0-9a-f]+\], Certificate$' "$raw" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1 || true)"
    cvlen="$(grep -E 'Handshake \[length [0-9a-f]+\], CertificateVerify' "$raw" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1 || true)"
    [[ -n "$certlen" ]] && certlen="$((16#$certlen))" || certlen="-"
    [[ -n "$cvlen" ]] && cvlen="$((16#$cvlen))" || cvlen="-"
    hs="$(head -1 "$out")"
    served="$(grep -oE 'key=[A-Za-z]+' "$out" | head -1 || true)"
    [[ -n "$served" ]] || served="$(grep -oE 'NOTHING CAPTURED|go-parse: FAILED' "$out" | head -1 || echo '?')"

    printf '%-22s %-14s %-10s %7s %7s  %s\n' "$label" "$sa" "$sac" "$certlen" "$cvlen" "${hs#handshake: }"
    redact < "$raw" > "$EVID/$label.server.txt"; rm -f "$raw"
    redact < "$out" > "$EVID/$label.probe.txt"; rm -f "$out"
}

{
    echo "# s_server control column, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# $(openssl version)"
    echo "# $(go version)"
    echo "# server holds: classical (EC root/int/leaf) and pq (ML-DSA-44 root/int/leaf), depth 3 each"
    echo "# 0x0403=ecdsa_secp256r1_sha256  0x0904=mldsa44 (code point read off the wire, not assumed)"
    echo
    printf '%-22s %-14s %-10s %7s %7s  %s\n' cell sigalgs sigalgs_cert Cert CertVfy handshake
    printf '%-22s %-14s %-10s %7s %7s  %s\n' ---------------------- -------------- ---------- ------- ------- ---------
    cell classical-only        0x0403        0x0403
    cell pq-only-cert-stock    0x0904        -
    cell pq-only-cert-pq       0x0904        0x0904
    cell both-cert-ecdsa-only  0x0904,0x0403 0x0403
    cell both-cert-pq-only     0x0904,0x0403 0x0904
    cell both-cert-suppressed  0x0904,0x0403 none
} 2>&1 | tee "$EVID/../s_server.txt"
