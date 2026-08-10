#!/usr/bin/env bash
# Mint the classical control pair for the Phase 1 smoke test: one RSA chain and
# one ECDSA chain, self-signed, with distinct CNs so the probe can tell which
# one the server chose. Lab material only. Never leaves this repo.
set -euo pipefail

OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/certs"
mkdir -p "$OUT"

# RSA-2048 chain
openssl req -x509 -newkey rsa:2048 -noenc \
    -keyout "$OUT/rsa.key" -out "$OUT/rsa.crt" \
    -subj "/CN=control-rsa" -days 30 \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null

# ECDSA P-256 chain
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
    -keyout "$OUT/ec.key" -out "$OUT/ec.crt" \
    -subj "/CN=control-ecdsa" -days 30 \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null

chmod 600 "$OUT"/*.key

for f in rsa ec; do
    printf '%s: %s / %s\n' \
        "$f" \
        "$(openssl x509 -in "$OUT/$f.crt" -noout -subject | sed 's/^subject=//')" \
        "$(openssl x509 -in "$OUT/$f.crt" -noout -text | awk '/Public Key Algorithm/{print $4; exit}')"
done
