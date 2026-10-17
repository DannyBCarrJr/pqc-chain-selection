#!/usr/bin/env bash
# The Kampanakis and Dukhovni appendix B shape (PRIOR-ART.md, "Stated from the
# implementer side"): one ML-DSA-44 intermediate KEY with two certificates,
#
#   pq/int.crt           signed by the ML-DSA-44 root   (their "PQ ICA 2ii")
#   pq/int-xsign-ec.crt  signed by the EC root          (their "PQ ICA 2i")
#
# and the ML-DSA-44 leaf issued under it. The server is given one intermediate
# at a time, and the client sends signature_algorithms_cert with mldsa44 alone,
# which excludes the ECDSA signature on the cross-signed intermediate.
#
# Source prediction, check_cert_usable() at the openssl-3.5.5 tag: the function
# receives the leaf alone and never reads the intermediate's signature, so the
# cross-signed intermediate is served whichever certificate is configured.
# The ECDSA-only cells are the negative controls: the leaf's own ML-DSA
# signature is excluded there, and that check the function does make.
#
# The served intermediate is identified by its DER bytes, read out of the
# server's own -msg dump of the Certificate message and matched against each
# intermediate file. Length is printed as well, for continuity with the other
# runners, but the byte match is the verdict.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
C="$REPO/gen/chains"
PROBE="$REPO/probe/tlspatch/build/probe"
EVID="$HERE/evidence/cross-signed-ica"
PORT="${PORT:-4433}"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }
derhex() { openssl x509 -in "$1" -outform DER | od -An -v -tx1 | tr -d ' \n'; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -f "$C/pq/int-xsign-ec.crt" ]] || { echo "run gen/mint-chains.sh first" >&2; exit 1; }
mkdir -p "$EVID"

ICA_PQ="$(derhex "$C/pq/int.crt")"
ICA_EC="$(derhex "$C/pq/int-xsign-ec.crt")"

# $1 label, $2 intermediate file, $3 PROBE_SIGALGS, $4 PROBE_SIGALGS_CERT, $5 expectation
cell() {
    local label="$1" ica="$2" sa="$3" sac="$4" want="$5"
    local raw="$EVID/$label.server" out="$EVID/$label.probe"

    openssl s_server -accept "127.0.0.1:$PORT" -naccept 1 \
        -cert "$C/pq/leaf.crt" -key "$C/pq/leaf.key" -cert_chain "$C/pq/$ica" \
        -tls1_3 -msg -www > "$raw" 2>&1 &
    local srv=$!
    for _ in $(seq 1 50); do
        ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && break
        sleep 0.1
    done
    ( cd "$REPO" && PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    wait "$srv" 2>/dev/null || true

    local certlen cvlen msghex served got
    certlen="$(grep -E 'Handshake \[length [0-9a-f]+\], Certificate$' "$raw" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1 || true)"
    cvlen="$(grep -E 'Handshake \[length [0-9a-f]+\], CertificateVerify' "$raw" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1 || true)"
    [[ -n "$certlen" ]] && certlen="$((16#$certlen))" || certlen="-"
    [[ -n "$cvlen" ]] && cvlen="$((16#$cvlen))" || cvlen="-"

    # Bytes of the Certificate handshake message: the hex lines that follow its
    # header, up to the next message marker.
    msghex="$(awk '/Handshake \[length [0-9a-f]+\], Certificate$/{f=1;next} f&&/^[<>]{3}/{f=0} f' "$raw" | tr -d ' \n')"
    served="none"
    if [[ "$msghex" == *"$ICA_PQ"* ]]; then served="int.crt(ML-DSA-signed)"
    elif [[ "$msghex" == *"$ICA_EC"* ]]; then served="int-xsign-ec.crt(ECDSA-signed)"
    elif [[ "$certlen" != "-" ]]; then served="UNMATCHED"; fi

    if [[ "$certlen" == "-" ]]; then got="refused"; else got="served"; fi
    local flag="  "; [[ "$got" == "$want" ]] || flag="<-"

    # What the client actually sent, read from the ClientHello bytes in the same
    # dump: extension 13 (signature_algorithms) and 50 (signature_algorithms_cert),
    # each a 2-byte list length followed by one 2-byte scheme.
    local hello wire sa_hex sac_hex
    hello="$(awk '/Handshake \[length [0-9a-f]+\], ClientHello$/{f=1;next} f&&/^[<>]{3}/{f=0} f' "$raw" | tr -d ' \n')"
    sa_hex="${sa#0x}"; sac_hex="${sac#0x}"
    wire="sent="
    [[ "$hello" == *"000d00040002${sa_hex}"* ]] && wire+="sa:ok" || wire+="sa:MISSING"
    [[ "$hello" == *"003200040002${sac_hex}"* ]] && wire+=",sac:ok" || wire+=",sac:MISSING"

    printf '%-16s %-18s %-8s %-10s %7s %7s  %-8s want=%-8s %-32s %-20s %s\n' \
        "$label" "$ica" "$sa" "$sac" "$certlen" "$cvlen" "$got" "$want" "$served" "$wire" "$flag"
    redact < "$raw" > "$EVID/$label.server.txt"; rm -f "$raw"
    redact < "$out" > "$EVID/$label.probe.txt"; rm -f "$out"
}

{
    echo "# cross-signed intermediate, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# $(openssl version) | $(go version)"
    echo "# server: pq/leaf.crt (ML-DSA-44 key, ML-DSA-44 signature) plus ONE intermediate certificate"
    echo "# 0x0403=ecdsa_secp256r1_sha256  0x0904=mldsa44"
    echo "# want= is what RFC 8446 4.4.2.2 asks for given the chain and the client constraints"
    echo "# served= the intermediate whose DER bytes appear in the Certificate message"
    echo
    echo "# sent= the two extensions as found in the ClientHello bytes of the same dump"
    printf '%-16s %-18s %-8s %-10s %7s %7s  %-8s %-13s %-32s %s\n' cell intermediate sigalgs sigalgs_cert Cert CertVfy got expected served wire
    printf '%-16s %-18s %-8s %-10s %7s %7s  %-8s %-13s %-32s %s\n' ---------------- ------------------ -------- ---------- ------- ------- -------- ------------- -------------------------------- ----
    echo "# client accepts ML-DSA signatures on certificates and nothing else"
    cell pq-ica-mldsa   int.crt          0x0904 0x0904 served    # every signature in the chain is ML-DSA: control
    cell pq-ica-xsign   int-xsign-ec.crt 0x0904 0x0904 refused   # THE CELL: the intermediate's ECDSA signature is excluded
    echo
    echo "# client accepts ECDSA signatures on certificates and nothing else (negative controls)"
    cell pq-ica-mldsa-ec int.crt          0x0904 0x0403 refused  # the leaf's own ML-DSA signature is excluded
    cell pq-ica-xsign-ec int-xsign-ec.crt 0x0904 0x0403 refused  # same leaf, same exclusion
} 2>&1 | tee "$EVID/../cross-signed-ica.txt"
