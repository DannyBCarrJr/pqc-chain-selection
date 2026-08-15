#!/usr/bin/env bash
# Which chain does your server actually send, and to whom?
#
# Five connections against one endpoint, each a different client story told
# through signature_algorithms and signature_algorithms_cert. The bench matrix
# in this repo measured five server stacks; this points the same probe at YOUR
# server, because the failure mode is silent: the handshake completes, the page
# loads, and a chain the client excluded ships anyway. RFC 8446 4.4.2.2 makes
# that conformant, so no error will ever tell you. An active probe is the only
# detection there is: the constraint travels in a plaintext ClientHello, the
# answer is encrypted under the handshake keys, and an on-path observer never
# sees both.
#
# Usage: tools/which-chain.sh HOST:PORT [-n SNI] [-c HEX] [-p HEX]
#   -n  SNI name                 (default: the host part of the target)
#   -c  classical code point     (default 0x0403, ecdsa_secp256r1_sha256)
#   -p  post-quantum code point  (default 0x0904, mldsa44)
#
# Needs the patched probe (probe/tlspatch/build.sh) and openssl in PATH to
# describe the captured leaf; openssl 3.5+ names ML-DSA fields natively. The
# probe completes the capture even when the handshake fails, so a chain the
# client cannot use is still identified rather than reported as "no data".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PROBE="${PROBE:-$REPO/probe/tlspatch/build/probe}"

TARGET="${1:-}"
[[ -n "$TARGET" && "$TARGET" != -* ]] || { sed -n 's/^# \(Usage.*\|  -.*\)/\1/p' "$0" >&2; exit 2; }
shift

SNI="${TARGET%%:*}"
CLASSICAL="0x0403"
PQ="0x0904"
while getopts ":n:c:p:" opt; do
  case "$opt" in
    n) SNI="$OPTARG" ;;
    c) CLASSICAL="$OPTARG" ;;
    p) PQ="$OPTARG" ;;
    *) echo "unknown option; see the usage block at the top of $0" >&2; exit 2 ;;
  esac
done

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first (no probe at $PROBE)" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

declare -A LEAF HS

# One probe connection. Chain identity comes from the CLIENT side here, unlike
# the bench runners: no server log exists for a remote target, but the probe
# holds the handshake keys, captures the raw DER, and openssl describes what Go
# cannot parse. Identity is the leaf's public key algorithm.
attempt() {
  local label="$1" sa="$2" sac="$3"
  local out="$TMP/$label.out" dump="$TMP/$label"
  PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" PROBE_TOLERATE_UNKNOWN_PUBKEY=1 \
    "$PROBE" -addr "$TARGET" -servername "$SNI" -dump "$dump" > "$out" 2>&1 || true

  local hs leaf
  hs="$(sed -n 's/^handshake: //p' "$out" | head -1)"
  [[ -n "$hs" ]] || hs="no output from probe"
  if [[ -f "$dump/cert0.der" ]]; then
    leaf="$(openssl x509 -inform DER -in "$dump/cert0.der" -noout -text 2>/dev/null \
            | sed -n 's/^ *Public Key Algorithm: //p' | head -1)"
    [[ -n "$leaf" ]] || leaf="unidentified ($(stat -c %s "$dump/cert0.der") bytes DER)"
  else
    leaf="none"
  fi
  LEAF[$label]="$leaf"
  HS[$label]="$hs"
  printf '%-20s %-16s %-16s %-18s %s\n' "$label" "$sa" "$sac" "$leaf" "${hs:0:44}"
}

echo "which-chain: probing $TARGET (SNI $SNI)"
echo "classical=$CLASSICAL  post-quantum=$PQ"
echo
printf '%-20s %-16s %-16s %-18s %s\n' case sigalgs sigalgs_cert "served leaf" handshake
printf '%-20s %-16s %-16s %-18s %s\n' -------------------- ---------------- ---------------- ------------------ ---------

# The two preference cases order BOTH extensions the same way, because that is
# what a real client does; on OpenSSL the chain follows the handshake-signature
# preference, so splitting the two lists would contradict the case's own label.
# The two exclusion cases keep signature_algorithms wide (the client can verify
# either handshake signature) and constrain only signature_algorithms_cert,
# mirroring the bench cells in runners/s_server.sh.
attempt classical-today     "$CLASSICAL"      "$CLASSICAL"
attempt pq-preferred        "$PQ,$CLASSICAL"  "$PQ,$CLASSICAL"
attempt classical-preferred "$CLASSICAL,$PQ"  "$CLASSICAL,$PQ"
attempt exclude-pq          "$PQ,$CLASSICAL"  "$CLASSICAL"
attempt exclude-classical   "$PQ,$CLASSICAL"  "$PQ"

echo
echo "verdicts:"

# How many distinct chains showed up at all.
distinct="$(printf '%s\n' "${LEAF[@]}" | grep -v '^none$' | sort -u | grep -c . || true)"
if [[ "$distinct" -le 1 ]]; then
  echo "  - One chain observed across all five probes. Either a single chain is"
  echo "    configured, or selection never engaged for these code points."
else
  echo "  - $distinct distinct chains observed: selection is happening."
fi

# Does client preference order steer the choice.
if [[ "${LEAF[pq-preferred]}" != "none" && "${LEAF[classical-preferred]}" != "none" ]]; then
  if [[ "${LEAF[pq-preferred]}" != "${LEAF[classical-preferred]}" ]]; then
    echo "  - Client preference order decides which chain is served. During a"
    echo "    migration the client population decides, one connection at a time."
  elif [[ "$distinct" -gt 1 ]]; then
    echo "  - Preference order did not change the served chain."
  fi
fi

# The finding this repo exists for: what happens to an excluded chain.
xp="${LEAF[exclude-pq]}" xc="${LEAF[exclude-classical]}"
if [[ "$xp" == "none" || "$xc" == "none" ]]; then
  echo "  - At least one exclusion probe got no Certificate message: the server"
  echo "    fails closed (alert) rather than sending an unusable chain."
elif [[ "$xp" == "$xc" ]]; then
  echo "  - The same chain ($xp) was served in both exclusion cases, so one of"
  echo "    those connections received a chain its signature_algorithms_cert"
  echo "    excluded. That is conformant (RFC 8446 4.4.2.2 is a SHOULD), and it"
  echo "    is silent: the client sees a normal handshake and a chain it cannot"
  echo "    validate. No monitoring signal separates this from working."
else
  echo "  - The excluded chain was withheld in both directions: this server"
  echo "    honors signature_algorithms_cert."
fi
