#!/usr/bin/env bash
# Envoy column. Envoy links BoringSSL, whose ssl.h documents that by default it
# does not check whether the peer supports the signature algorithms in the
# certificate chain, and that it selects the first usable credential from the
# list. So the prediction is that Envoy joins Caddy and rustls rather than nginx.
#
# The second half of that doc comment predicts something nginx and s_server do
# not do: with two usable credentials, CONFIG ORDER decides. The dual cells test
# both orders to see whether the served chain follows the file rather than the
# client.
#
# Live config is written outside evidence/ and only a redacted copy is kept,
# because it holds absolute paths. That is the standing rule in AGENTS.md, and
# the caddy runner learned it the hard way.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PROBE="$REPO/probe/tlspatch/build/probe"
EVID="$HERE/evidence/envoy"
IMG="${IMG:-envoyproxy/envoy:v1.36-latest}"
PORT="${PORT:-4477}"
NAME="pqcs-envoy"

redact() { sed -e "s#${REPO}#<REPO>#g" -e "s#${HOME}#<HOME>#g"; }

[[ -x "$PROBE" ]] || { echo "run probe/tlspatch/build.sh first" >&2; exit 1; }
[[ -f "$REPO/gen/chains/pqissuer/fullchain.crt" ]] || { echo "run gen/mint-chains.sh first" >&2; exit 1; }
mkdir -p "$EVID"
WORK="$(mktemp -d)"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap 'cleanup; rm -rf "$WORK"' EXIT

# gen/mint-chains.sh sets keys to 600, which is correct for the repo and fatal
# here: this container cannot read them, and Envoy reports that as "Failed to
# load incomplete private key", which sends you hunting a format problem that
# does not exist. Stage a throwaway readable copy instead of loosening the
# originals. Lab material only: self-signed, 30 days, gitignored, regenerated
# by the mint script.
cp -r "$REPO/gen/chains" "$WORK/chains"
chmod -R a+rX "$WORK/chains"

# $@ = one or more "chainname" values, in configuration order
mkconf() {
    {
        cat <<'EOF'
static_resources:
  listeners:
  - name: l
    address: { socket_address: { address: 0.0.0.0, port_value: 443 } }
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress
          route_config:
            name: r
            virtual_hosts:
            - name: v
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                direct_response: { status: 200, body: { inline_string: "ok" } }
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            tls_params: { tls_minimum_protocol_version: TLSv1_3 }
            tls_certificates:
EOF
        for c in "$@"; do
            printf '            - certificate_chain: { filename: /chains/%s/fullchain.crt }\n' "$c"
            printf '              private_key: { filename: /chains/%s/leaf.key }\n' "$c"
        done
    } > "$WORK/envoy.yaml"
}

start() { # $@ chain names in order
    cleanup
    mkconf "$@"
    redact < "$WORK/envoy.yaml" > "$EVID/envoy-$(IFS=-; echo "$*").yaml"
    # --user 0 because the mounted private keys are mode 600 on the host and the
    # image runs as an unprivileged user. Throwaway container, lab material only.
    docker run -d --name "$NAME" --user 0 -p "127.0.0.1:$PORT:443" \
        -v "$WORK/chains:/chains:ro" \
        -v "$WORK/envoy.yaml:/etc/envoy/envoy.yaml:ro" \
        "$IMG" -c /etc/envoy/envoy.yaml --log-level warn >/dev/null
    for _ in $(seq 1 80); do
        (exec 3<>/dev/tcp/127.0.0.1/"$PORT") 2>/dev/null && break
        sleep 0.25
    done
    sleep 0.5
    if ! docker ps --filter "name=$NAME" --filter status=running -q | grep -q .; then
        echo "  envoy did not start:" >&2
        docker logs "$NAME" 2>&1 | tail -4 | redact >&2
        return 1
    fi
}

cell() { # $1 label, $2 SIGALGS, $3 SIGALGS_CERT
    local label="$1" sa="$2" sac="$3"
    local out="$EVID/$label.probe"
    ( cd "$REPO" && PROBE_SIGALGS="$sa" PROBE_SIGALGS_CERT="$sac" \
        "$PROBE" -addr "127.0.0.1:$PORT" ) > "$out" 2>&1 || true
    local hs served
    hs="$(head -1 "$out" | sed 's/^handshake: //')"
    served="$(grep -oE 'key=[A-Za-z0-9]+' "$out" | head -1 || true)"
    [[ -n "$served" ]] || served="$(grep -oE 'NOTHING CAPTURED' "$out" | head -1 || echo '?')"
    printf '%-20s %-14s %-10s %-10s %s\n' "$label" "$sa" "$sac" "$served" "${hs:0:44}"
    redact < "$out" > "$EVID/$label.probe.txt"; rm -f "$out"
}

{
    echo "# envoy column, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# image $IMG"
    echo "# $(docker run --rm --entrypoint envoy "$IMG" --version 2>&1 | tr '\n' ' ' | cut -c1-120)"
    echo "# 0x0403=ecdsa_secp256r1_sha256  0x0904=mldsa44"
    echo
    printf '%-20s %-14s %-10s %-10s %s\n' cell sigalgs sigalgs_cert served handshake
    printf '%-20s %-14s %-10s %-10s %s\n' -------------------- -------------- ---------- ---------- ---------

    echo "# single chain: pqissuer. s_server and nginx REFUSED; caddy and rustls SERVED."
    if start pqissuer; then
        cell single-excluded 0x0403 0x0403
        cell single-allowed  0x0403 0x0904
    fi
    echo
    echo "# dual chain, and whether CONFIG ORDER decides (BoringSSL: first usable)"
    if start classical pq; then
        cell dual-classical-first-ecdsa 0x0904,0x0403 0x0403
        cell dual-classical-first-pq    0x0904,0x0403 0x0904
    fi
    if start pq classical; then
        cell dual-pq-first-ecdsa        0x0904,0x0403 0x0403
        cell dual-pq-first-pq           0x0904,0x0403 0x0904
    fi
} 2>&1 | tee "$EVID/../envoy.txt"
