#!/usr/bin/env bash
# Harness self-check. Run this BEFORE trusting any matrix run.
#
# Three bugs in this harness on 2026-08-10 produced plausible wrong output
# instead of errors:
#
#   1. `grep -oE 'Handshake \[length ([0-9a-f]+)\]' | grep -oE '[0-9a-f]+'`
#      matched the "a" in "Handshake" and reported every length as 10.
#   2. A pipeline ending in `head -1` under `pipefail` took SIGPIPE, the `&&`
#      short-circuited, and `set -e` killed the run silently. Two sections
#      never executed and the output merely looked truncated.
#   3. An unquoted `$2` meant `docker run` never executed, while the script
#      printed a pass for every cell.
#
# Each is a known-answer test below. Every check must also be able to FAIL:
# the meta-test at the end deliberately breaks one and requires a failure,
# because a checker that cannot fail is decoration.
set -uo pipefail   # deliberately NOT -e: this script reports, it does not abort

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PASS=0; FAIL=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; printf '       %s\n' "${2:-}"; FAIL=$((FAIL+1)); }

# The extraction used by every runner, in one place so the check tests the
# real thing rather than a copy that can drift.
extract_len() { # stdin = s_server -msg output, $1 = Certificate|CertificateVerify
    local hex
    hex="$(grep -E "Handshake \[length [0-9a-f]+\], $1" | sed -E 's/.*length ([0-9a-f]+).*/\1/' | head -1)"
    [[ -n "$hex" ]] && printf '%d' "$((16#$hex))" || printf '%s' "-"
}

echo "== 1. length extraction, known answer =="
FIXTURE='>>> TLS 1.3, Handshake [length 1fa4], Certificate
>>> TLS 1.3, Handshake [length 097c], CertificateVerify'
got="$(extract_len Certificate <<<"$FIXTURE")"
[[ "$got" == 8100 ]] && ok "Certificate 0x1fa4 -> 8100" || bad "Certificate length" "got '$got', want 8100"
got="$(extract_len CertificateVerify <<<"$FIXTURE")"
[[ "$got" == 2428 ]] && ok "CertificateVerify 0x097c -> 2428" || bad "CertificateVerify length" "got '$got', want 2428"
# regression guard for bug 1 specifically
got="$(extract_len Certificate <<<'>>> TLS 1.3, Handshake [length 000a], Certificate')"
[[ "$got" == 10 ]] && ok "0x000a -> 10 (real 10, not the 'a' in Handshake)" || bad "hex regression" "got '$got'"

echo "== 2. absent input must yield '-', never a number =="
got="$(extract_len Certificate <<<'no handshake here')"
[[ "$got" == "-" ]] && ok "no match -> '-'" || bad "empty handling" "got '$got'"

echo "== 3. required tooling present and the versions we claim =="
for t in openssl go docker ss python3; do
    command -v "$t" >/dev/null && ok "$t on PATH" || bad "$t missing"
done
[[ -x "$REPO/probe/tlspatch/build/probe" ]] && ok "patched probe built" \
    || bad "probe missing" "run probe/tlspatch/build.sh"

echo "== 4. the probe patch is actually active (bug 3 class: did it really run?) =="
if [[ -x "$REPO/probe/tlspatch/build/probe" ]]; then
    # PROBE_SIGALGS_CERT=none must suppress ext 50; if the binary is unpatched
    # (e.g. built with `go run`, which ignores -overlay) it will send it anyway.
    P=4487
    openssl s_server -accept $P -naccept 1 -cert "$REPO/gen/chains/classical/leaf.crt" \
        -key "$REPO/gen/chains/classical/leaf.key" -tls1_3 -tlsextdebug -www >/tmp/sc.log 2>&1 &
    s=$!
    for _ in $(seq 1 50); do ss -ltnH "sport = :$P" 2>/dev/null | grep -q . && break; sleep 0.1; done
    PROBE_SIGALGS_CERT=none "$REPO/probe/tlspatch/build/probe" -addr "127.0.0.1:$P" >/dev/null 2>&1
    wait $s 2>/dev/null
    if grep -q 'id=50' /tmp/sc.log; then
        bad "patch inactive" "ext 50 still sent with PROBE_SIGALGS_CERT=none; rebuild with build.sh, never go run"
    else
        ok "PROBE_SIGALGS_CERT=none suppresses extension 50"
    fi
    rm -f /tmp/sc.log
fi

echo "== 5. meta-test: the checker must be able to fail =="
got="$(extract_len Certificate <<<'>>> TLS 1.3, Handshake [length 0001], Certificate')"
if [[ "$got" == 8100 ]]; then bad "meta" "extractor returns a constant; every check above is meaningless"
else ok "extractor varies with input (got $got, not a constant)"; fi

echo
printf 'self-check: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || { echo "DO NOT TRUST MATRIX RESULTS UNTIL THIS PASSES"; exit 1; }
