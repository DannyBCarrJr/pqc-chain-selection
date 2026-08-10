# The matrix

All runs 2026-08-10 on one machine. Each cell has a script and captured output
under `runners/evidence/`. Versions are recorded per run, never assumed.

| stack | version | TLS library |
|---|---|---|
| `openssl s_server` | 3.5.5 (27 Jan 2026) | OpenSSL |
| nginx | 1.31.3, `nginx:alpine` | OpenSSL 3.5.7 |
| Caddy | built from source, go1.26.0 | Go `crypto/tls` |
| rustls | 0.23.43 (`v/0.23.43`, 2026-07-29) | rustls, `ring` provider |

Not covered: Envoy (BoringSSL), Apache httpd, HAProxy. httpd and HAProxy wrap
OpenSSL and answer a different question about whether a wrapper overrides its
library.

## The headline cell

Chain: `pqissuer`, an EC leaf key under an ML-DSA-44-signed intermediate.
Client: `signature_algorithms = 0x0403`, `signature_algorithms_cert = 0x0403`.

The client can use the leaf's EC key, and has said it will not accept ML-DSA
signatures on certificates. The only configured chain has exactly those.

| stack | outcome |
|---|---|
| `openssl s_server` | **refused**, handshake_failure before sending a certificate |
| nginx | **refused**, handshake_failure |
| Caddy | **served** the excluded chain, handshake OK |
| rustls | **served** the excluded chain, handshake OK |

**Two and two, split by TLS library rather than by server.** The OpenSSL family
honors `signature_algorithms_cert` and declines when it cannot satisfy it. The Go
and Rust stacks send the chain regardless, because neither consults the
extension: Go's `SupportsCertificate` says so in a source comment, and rustls
never parses it into `ClientHello` at all.

nginx inherits its library's behavior exactly. That is worth stating, because it
was not guaranteed: a wrapper with its own certificate configuration layer could
have lost it.

## Full results

### OpenSSL `s_server`, dual chain (`runners/s_server.sh`)

Six cells, all correct. `signature_algorithms_cert` is the deciding variable:
two cells differ in nothing else and receive different chains. Where no
configured chain satisfies both constraints, it fails closed.

### OpenSSL `s_server`, mixed shapes (`runners/single-chain.sh`)

Six cells, all matching RFC 8446 4.4.2.2. Includes the case OpenSSL #32028 might
predict would fail, `pqissuer` with `sigalgs_cert` accepting ML-DSA while
`signature_algorithms` does not. It was served, so on this path the two
extensions are treated as independent lists rather than one filtering the other.

### nginx (`runners/nginx.sh`)

| cell | `sigalgs` | `sigalgs_cert` | result |
|---|---|---|---|
| single-excluded | `0403` | `0403` | refused |
| single-allowed | `0403` | `0904` | served, ECDSA leaf |
| dual-ecdsa-only | `0904,0403` | `0403` | served classical |
| dual-pq-only | `0904,0403` | `0904` | served pq |
| dual-suppressed | `0904,0403` | none | served pq |

Identical to `s_server` throughout, using the repeated `ssl_certificate`
directives that Red Hat's RHEL 10 guidance points operators at.

### Caddy (`runners/caddy.sh`)

| cell | `sigalgs` | `sigalgs_cert` | result |
|---|---|---|---|
| single-excluded | `0403` | `0403` | **served**, handshake OK |
| single-allowed | `0403` | `0904` | served, handshake OK |
| dual | n/a | n/a | **config rejected, would not start** |

### rustls (`runners/rustls-server/`, `FINDINGS-rustls.md`)

Served the excluded chain. A resolver printout from inside `resolve` shows it
received `signature_schemes` and has no accessor for the other list.

## The finding that outranks selection

**Go 1.26 cannot load an ML-DSA private key, so a Go server cannot serve a
post-quantum leaf certificate at all.**

`crypto/tls.LoadX509KeyPair` against each minted chain:

| chain | leaf key | result |
|---|---|---|
| classical | EC P-256 | loaded ok |
| pqissuer | EC P-256 | loaded ok |
| pqleaf | ML-DSA-44 | `tls: failed to parse private key` |
| pq | ML-DSA-44 | `tls: failed to parse private key` |

That is why Caddy rejected the dual configuration: not a Caddyfile problem, and
not a selection problem. Its error is `tls: failed to parse private key`, raised
while loading the `pq` chain.

So for a Go server the dual-stack migration is blocked before selection is
reached. The only post-quantum shape it can serve today is `pqissuer`, a
classical leaf key issued by a post-quantum CA, which is precisely the shape it
then serves to clients that have excluded it.

## Fairness

RFC 8446 section 4.4.2.2 makes the chain-signature constraint a SHOULD, not a
MUST. Caddy and rustls are conformant. Go's source comment declines the check
citing that SHOULD explicitly. Nothing in this matrix is a standards violation,
and writing it up as one would be wrong. The finding is what happens to an
operator running a mixed fleet during a migration.

## Owed

- Envoy and BoringSSL, the remaining planned column.
- A deliberate negative control: a broken chain that must be rejected.
- Repeat runs. Every cell here is a single run.
- The PMC and MDPI prior-art re-sweep, before anything publishes.
