#!/usr/bin/env bash
# nginx column. nginx wraps OpenSSL, so the question is whether its own
# certificate configuration layer preserves the behavior measured directly on
# s_server, or loses it.
#
# Runs in Docker because the host has no nginx, and because the image's OpenSSL
# version is then pinned and recorded per run. Stock distro nginx is frequently
# built against an OpenSSL that predates ML-DSA, which is a deployment fact
# worth knowing but a different measurement from this one.
#
# Two configurations:
#   single  only the pqissuer chain, matching the rustls and s_server cells
#   dual    classical and pq together, the real migration shape
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PROBE="$REPO/probe/tlspatch/build/probe"
EVID="$HERE/evidence/nginx"
IMG="${IMG:-nginx:alpine}"
PORT="${PORT:-4455}"
NAME="pqcs-nginx"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -f "$REPO/gen/chains/pqissuer/fullchain.crt" ]] || { echo "run gen/mint-chains.sh first" >&2; exit 1; }
mkdir -p "$EVID"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

conf_single=$(cat <<'EOF'
events {}
http {
  server {
    listen 443 ssl;
    ssl_protocols TLSv1.3;
    ssl_certificate     /chains/pqissuer/fullchain.crt;
    ssl_certificate_key /chains/pqissuer/leaf.key;
    location / { return 200 "ok"; }
  }
}
EOF
)

# Repeated ssl_certificate directives are nginx's documented multi-certificate
# form, and are what Red Hat's RHEL 10 post-quantum guidance points operators at.
conf_dual=$(cat <<'EOF'
events {}
http {
  server {
    listen 443 ssl;
    ssl_protocols TLSv1.3;
    ssl_certificate     /chains/classical/fullchain.crt;
    ssl_certificate_key /chains/classical/leaf.key;
    ssl_certificate     /chains/pq/fullchain.crt;
    ssl_certificate_key /chains/pq/leaf.key;
    location / { return 200 "ok"; }
  }
}
EOF
)

start() { # $1 config text
    cleanup
    printf '%s\n' "$1" > "$EVID/nginx.conf"
    docker run -d --name "$NAME" -p "127.0.0.1:$PORT:443" \
        -v "$REPO/gen/chains:/chains:ro" \
        -v "$EVID/nginx.conf:/etc/nginx/nginx.conf:ro" \
        "$IMG" >/dev/null
    for _ in $(seq 1 80); do
        docker exec "$NAME" true 2>/dev/null && \
          (exec 3<>/dev/tcp/127.0.0.1/"$PORT") 2>/dev/null && break
        sleep 0.25
    done
    sleep 0.5
    if ! docker ps --filter "name=$NAME" --filter status=running -q | grep -q .; then
        echo "nginx failed to start:" >&2
        docker logs "$NAME" 2>&1 | tail -5 >&2
        return 1
    fi
}

# $1 label, $2 SIGALGS, $3 SIGALGS_CERT
cell() {
    local label="$1" sa="$2" sac="$3"
    local out="$EVID/$label.probe"
    ( cd "$REPO" && PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" \
        "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    local hs served
    hs="$(head -1 "$out" | sed 's/^handshake: //')"
    served="$(grep -oE 'key=[A-Za-z]+|key=0' "$out" | head -1 || true)"
    [[ -n "$served" ]] || served="$(grep -oE 'NOTHING CAPTURED' "$out" | head -1 || echo '?')"
    printf '%-18s %-14s %-10s %-10s %s\n' "$label" "$sa" "$sac" "$served" "${hs:0:46}"
    redact < "$out" > "$EVID/$label.probe.txt"; rm -f "$out"
}

{
    echo "# nginx column, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# image $IMG"
    echo "# $(docker run --rm --entrypoint sh "$IMG" -c 'nginx -V 2>&1 | grep -oE "nginx/[0-9.]+|OpenSSL [0-9.]+" | tr "\n" " "')"
    echo "# 0x0403=ecdsa_secp256r1_sha256  0x0904=mldsa44"
    echo
    printf '%-18s %-14s %-10s %-10s %s\n' cell sigalgs sigalgs_cert served handshake
    printf '%-18s %-14s %-10s %-10s %s\n' ------------------ -------------- ---------- ---------- ---------

    echo "# single chain: pqissuer only. s_server REFUSED this, rustls SERVED it."
    start "$conf_single"
    cell single-excluded  0x0403        0x0403
    cell single-allowed   0x0403        0x0904
    echo
    echo "# dual chain: classical + pq, the migration shape"
    start "$conf_dual"
    cell dual-ecdsa-only  0x0904,0x0403 0x0403
    cell dual-pq-only     0x0904,0x0403 0x0904
    cell dual-suppressed  0x0904,0x0403 none
} 2>&1 | tee "$EVID/../nginx.txt"
