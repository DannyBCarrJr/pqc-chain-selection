#!/usr/bin/env bash
# Separate the two axes.
#
#   signature_algorithms       constrains CertificateVerify, so it is about the
#                              LEAF'S KEY
#   signature_algorithms_cert  constrains signatures ON certificates, so it is
#                              about the ISSUERS
#
# The mixed shapes put those in opposition:
#
#   pqleaf     EC root -> EC int -> ML-DSA leaf   PQ key, classical signatures
#   pqissuer   ML-DSA root/int -> EC leaf         classical key, PQ signatures
#
# pqissuer is the interesting one. Serving it requires accepting ML-DSA in
# signature_algorithms_cert while NOT needing it in signature_algorithms.
# OpenSSL #32028 states that parts of the code apply signature_algorithms_cert
# "as a filter further restricting the set of signature_algorithms rather than
# as a separate list". If that holds here, the cell that should succeed fails.
#
# One chain per server, so nothing is masked by a fallback.
#
# Length key: CertificateVerify is 2428 for an ML-DSA-44 leaf key and 79 for an
# EC one, which identifies the leaf independently of anything the client says.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
C="$REPO/gen/chains"
PROBE="$REPO/probe/tlspatch/build/probe"
EVID="$HERE/evidence/single-chain"
PORT="${PORT:-4433}"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -f "$C/pqissuer/leaf.crt" ]] || { echo "run gen/mint-chains.sh first" >&2; exit 1; }
mkdir -p "$EVID"

# $1 chain, $2 PROBE_SIGALGS, $3 PROBE_SIGALGS_CERT, $4 expectation
cell() {
    local chain="$1" sa="$2" sac="$3" want="$4"
    local tag="$chain-${sa//,/+}-${sac//,/+}"
    local raw="$EVID/$tag.server" out="$EVID/$tag.probe"

    openssl s_server -accept "127.0.0.1:$PORT" -naccept 1 \
        -cert "$C/$chain/leaf.crt" -key "$C/$chain/leaf.key" -cert_chain "$C/$chain/int.crt" \
        -tls1_3 -msg -www > "$raw" 2>&1 &
    local srv=$!
    for _ in $(seq 1 50); do
        ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
        sleep 0.1
    done
    ( cd "$REPO" && PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    wait "$srv" 2>/dev/null || true

    local certlen cvlen got
    certlen="$(grep -E 'Handshake \[length [0-9a-f]+\], Certificate$' "$raw" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1 || true)"
    cvlen="$(grep -E 'Handshake \[length [0-9a-f]+\], CertificateVerify' "$raw" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1 || true)"
    [[ -n "$certlen" ]] && certlen="$((16#$certlen))" || certlen="-"
    [[ -n "$cvlen" ]] && cvlen="$((16#$cvlen))" || cvlen="-"

    if [[ "$certlen" == "-" ]]; then got="refused"; else got="served"; fi
    local flag="  "; [[ "$got" == "$want" ]] || flag="<-"

    printf '%-9s %-14s %-10s %7s %7s  %-8s want=%-8s %s\n' \
        "$chain" "$sa" "$sac" "$certlen" "$cvlen" "$got" "$want" "$flag"
    redact < "$raw" > "$EVID/$tag.server.txt"; rm -f "$raw"
    redact < "$out" > "$EVID/$tag.probe.txt"; rm -f "$out"
}

{
    echo "# single-chain axis separation, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# $(openssl version) | $(go version)"
    echo "# 0x0403=ecdsa_secp256r1_sha256  0x0904=mldsa44"
    echo "# want= is what RFC 8446 4.4.2.2 requires given the chain and the client constraints"
    echo
    printf '%-9s %-14s %-10s %7s %7s  %-8s %-13s %s\n' chain sigalgs sigalgs_cert Cert CertVfy got expected ""
    printf '%-9s %-14s %-10s %7s %7s  %-8s %-13s %s\n' --------- -------------- ---------- ------- ------- -------- ------------- ""

    echo "# pqleaf: ML-DSA leaf key, ECDSA signatures on the chain"
    cell pqleaf   0x0904 0x0403 served    # both axes satisfied
    cell pqleaf   0x0904 0x0904 refused   # chain is ECDSA-signed, excluded
    cell pqleaf   0x0403 0x0403 refused   # leaf key is ML-DSA, cannot sign CertVerify
    echo
    echo "# pqissuer: EC leaf key, ML-DSA signatures on the chain"
    cell pqissuer 0x0403 0x0904 served    # both axes satisfied. THE #32028 CELL
    cell pqissuer 0x0403 0x0403 refused   # chain is ML-DSA-signed, excluded
    cell pqissuer 0x0904 0x0904 refused   # leaf key is EC, cannot sign with mldsa
} 2>&1 | tee "$EVID/../single-chain.txt"
