#!/usr/bin/env bash
# Runnable check for which-chain.sh, under the house rule: prove the tool can
# tell the behaviors apart before believing anything it reports.
#
# Scenario A, dual-chain s_server: expects "preference order decides" and
# "honors signature_algorithms_cert" (measured for OpenSSL in FINDINGS.md).
# Scenario B, classical-only s_server: expects one chain observed and the
# fail-closed verdict, because OpenSSL refuses rather than serving an excluded
# chain (FINDINGS.md). The serves-anyway branch is measured on Caddy, rustls,
# and Envoy in the bench and is not reproducible with s_server, so it stays
# covered by the matrix rather than by this check.
#
# Usage: tools/which-chain.test.sh   (PORT overridable, default 14433)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
C="$REPO/gen/chains"
PORT="${PORT:-14433}"

[[ -x "$REPO/probe/tlspatch/build/probe" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -f "$C/pq/leaf.crt" ]] || { echo "run gen/mint-chains.sh first" >&2; exit 1; }

wait_port() {
  for _ in $(seq 1 50); do
    ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q . && return 0
    sleep 0.1
  done
  echo "server never opened port $PORT" >&2
  return 1
}

pass=0; fail=0
check() {  # $1 description, $2 output, $3 required substring
  if grep -q "$3" <<< "$2"; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1 (missing: $3)"; fail=$((fail+1)); fi
}

echo "# scenario A: dual-chain (classical + pq)"
openssl s_server -accept "127.0.0.1:$PORT" -naccept 5 \
  -cert "$C/classical/leaf.crt" -key "$C/classical/leaf.key" -cert_chain "$C/classical/int.crt" \
  -dcert "$C/pq/leaf.crt"       -dkey "$C/pq/leaf.key"       -dcert_chain "$C/pq/int.crt" \
  -tls1_3 -www > /dev/null 2>&1 &
SRV=$!
wait_port
OUT_A="$("$HERE/which-chain.sh" "127.0.0.1:$PORT" -n localhost)"
wait "$SRV" 2>/dev/null || true

check "sees two distinct chains"        "$OUT_A" "2 distinct chains"
check "preference order decides"        "$OUT_A" "preference order decides"
check "honors signature_algorithms_cert" "$OUT_A" "honors signature_algorithms_cert"
check "identifies the ML-DSA leaf"      "$OUT_A" "ML-DSA"

echo "# scenario B: classical chain only"
openssl s_server -accept "127.0.0.1:$PORT" -naccept 5 \
  -cert "$C/classical/leaf.crt" -key "$C/classical/leaf.key" -cert_chain "$C/classical/int.crt" \
  -tls1_3 -www > /dev/null 2>&1 &
SRV=$!
wait_port
OUT_B="$("$HERE/which-chain.sh" "127.0.0.1:$PORT" -n localhost)"
wait "$SRV" 2>/dev/null || true

check "single chain reported"           "$OUT_B" "One chain observed"
check "fail-closed on exclusion"        "$OUT_B" "fails closed"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
