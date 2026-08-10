#!/usr/bin/env bash
# Phase 2: mint the four chain shapes this project selects between.
#
# The mint_chain recipe is adapted from pqc-cert-matrix/gen/mint-corpus.sh,
# which already proved that stock OpenSSL 3.5.5 signs and verifies ML-DSA CA
# chains with no providers. Copied rather than sourced so this repo reproduces
# standalone.
#
# What differs from cert-matrix: the shapes. This project cares about the
# SIGNATURE on each certificate, because that is what signature_algorithms_cert
# filters on, and about the leaf's KEY, because that is what signature_algorithms
# filters on. Those two are independent, and the two mixed shapes below separate
# them deliberately.
#
#   classical   EC root    -> EC int    -> EC leaf         control
#   pq          ML-DSA-44  -> ML-DSA-44 -> ML-DSA-44       pure post-quantum
#   pqleaf      EC root    -> EC int    -> ML-DSA-44 leaf  PQ key, classical signature
#   pqissuer    ML-DSA-44  -> ML-DSA-44 -> EC leaf         classical key, PQ signature
#
# ML-DSA-44 throughout rather than 65 or 87: the question here is algorithm
# identity in selection logic, not size. pqc-cert-matrix and pqc-chain-budget
# own the size axis.
#
# Output: chains/, evidence/mint-chains.txt. chains/ is gitignored; rerun to
# regenerate. Certificates carry a 30-day life and a committed copy would go
# stale, so history keeps the recipe rather than the output.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
cd "$D"
mkdir -p evidence

run() { echo "\$ $*"; "$@"; }

ext_int='basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign'

leaf_ext='basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1'

genkey() { # $1 algorithm, $2 outfile
  if [ "$1" = "EC" ]; then
    run openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$2"
  else
    run openssl genpkey -algorithm "$1" -out "$2"
  fi
}

mint_chain() { # $1 name, $2 root_alg, $3 int_alg, $4 leaf_alg
  local name="$1" d="chains/$1"
  mkdir -p "$d"
  echo "== chain: $name (root=$2 int=$3 leaf=$4) =="

  genkey "$2" "$d/root.key"
  genkey "$3" "$d/int.key"
  genkey "$4" "$d/leaf.key"

  run openssl req -x509 -new -key "$d/root.key" -out "$d/root.crt" \
      -subj "/CN=Selection $name Root" -days 90 \
      -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
  run openssl req -new -key "$d/int.key" -out "$d/int.csr" -subj "/CN=Selection $name Intermediate"
  run openssl x509 -req -in "$d/int.csr" -CA "$d/root.crt" -CAkey "$d/root.key" \
      -out "$d/int.crt" -days 60 -extfile <(printf '%s\n' "$ext_int")
  run openssl req -new -key "$d/leaf.key" -out "$d/leaf.csr" -subj "/CN=localhost"
  run openssl x509 -req -in "$d/leaf.csr" -CA "$d/int.crt" -CAkey "$d/int.key" \
      -out "$d/leaf.crt" -days 30 -extfile <(printf '%s\n' "$leaf_ext")

  # Servers want leaf-then-intermediate in one file.
  cat "$d/leaf.crt" "$d/int.crt" > "$d/fullchain.crt"
  chmod 600 "$d"/*.key

  echo "-- verify (gate: a later failure must be selection, not a bad chain) --"
  run openssl verify -CAfile "$d/root.crt" -untrusted "$d/int.crt" "$d/leaf.crt"
  echo
}

sigalg() { openssl x509 -in "$1" -noout -text | awk '/Signature Algorithm/{print $3; exit}'; }
keyalg() { openssl x509 -in "$1" -noout -text | awk '/Public Key Algorithm/{print $4; exit}'; }

summary() {
  echo "== what each shape actually is =="
  printf '%-10s %-24s %-24s %-24s\n' chain "leaf key" "leaf signature" "int signature"
  printf '%-10s %-24s %-24s %-24s\n' ---------- ------------------------ ------------------------ ------------------------
  for c in classical pq pqleaf pqissuer; do
    printf '%-10s %-24s %-24s %-24s\n' "$c" \
      "$(keyalg chains/$c/leaf.crt)" "$(sigalg chains/$c/leaf.crt)" "$(sigalg chains/$c/int.crt)"
  done
}

{
  openssl version
  echo
  mint_chain classical EC        EC        EC
  mint_chain pq        ML-DSA-44 ML-DSA-44 ML-DSA-44
  mint_chain pqleaf    EC        EC        ML-DSA-44
  mint_chain pqissuer  ML-DSA-44 ML-DSA-44 EC
  summary
} 2>&1 | tee evidence/mint-chains.txt

echo
summary
