#!/usr/bin/env bash
# Build the probe against a patched crypto/tls, without vendoring Go's source.
#
# crypto/tls imports internal/godebug, so it cannot be copied out of GOROOT and
# compiled as an ordinary package. `go build -overlay` is the way in: it swaps
# file contents at build time. This repo therefore stores the INJECTION, not a
# copy of Go's BSD-licensed source, which keeps the diff small and the licensing
# clean.
#
# The patch is two inserted lines in common.go plus one added file. With the
# environment unset the resulting binary produces a byte-identical ClientHello
# to stock Go, so the instrument has exactly one knob.
#
# NOTE: `go run` and `go test` IGNORE -overlay (documented in `go help build`).
# Anything using this patch must `go build` and then execute the binary.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCDIR="$HERE/../smoke"
BUILD="$HERE/build"
GOROOT_SRC="$(go env GOROOT)/src/crypto/tls"
OUT="${1:-$BUILD/probe}"

rm -rf "$BUILD"; mkdir -p "$BUILD"

# 1. common.go with a guard inserted at the top of each function body.
#    Anchored on the exact function signatures, and the run fails loudly if
#    either anchor is missing, which is what happens when Go refactors.
awk '
/^func supportedSignatureAlgorithms\(minVers uint16\) \[\]SignatureScheme \{$/ {
    print; print "\tif v, ok := probeSigAlgOverride(\"PROBE_SIGALGS\"); ok { return v }"; hit1++; next
}
/^func supportedSignatureAlgorithmsCert\(\) \[\]SignatureScheme \{$/ {
    print; print "\tif v, ok := probeSigAlgOverride(\"PROBE_SIGALGS_CERT\"); ok { return v }"; hit2++; next
}
{ print }
END {
    if (hit1 != 1 || hit2 != 1) {
        printf("ANCHOR FAILURE: supportedSignatureAlgorithms=%d supportedSignatureAlgorithmsCert=%d\n", hit1, hit2) > "/dev/stderr"
        exit 1
    }
}' "$GOROOT_SRC/common.go" > "$BUILD/common.go"

# 2. The helper, carrying its own imports so common.go needs no import surgery.
cp "$HERE/override.go.in" "$BUILD/zz_probe_override.go"

# 3. Overlay map. Absolute paths are unavoidable here, which is why build/ is
#    gitignored: this file is a build artifact, never evidence.
cat > "$BUILD/overlay.json" <<EOF
{"Replace": {
  "$GOROOT_SRC/common.go": "$BUILD/common.go",
  "$GOROOT_SRC/zz_probe_override.go": "$BUILD/zz_probe_override.go"
}}
EOF

( cd "$SRCDIR" && go build -overlay "$BUILD/overlay.json" -o "$OUT" ./probe.go )

echo "built: ${OUT/#$HOME/\~}"
echo "go:    $(go version)"
echo "patch: 2 guards in common.go + zz_probe_override.go"
