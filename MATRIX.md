# The matrix

All runs 2026-08-10 on one machine. Each cell has a script and captured output
under `runners/evidence/`. Versions are recorded per run, never assumed.

| stack | version | TLS library |
|---|---|---|
| `openssl s_server` | 3.5.5 (27 Jan 2026) | OpenSSL |
| nginx | 1.31.3, `nginx:alpine` | OpenSSL 3.5.7 |
| Caddy | built from source, go1.26.0 | Go `crypto/tls` |
| rustls | 0.23.43 (`v/0.23.43`, 2026-07-29) | rustls; tested on both `ring` and the default `aws_lc_rs` |
| Envoy | 1.36.9, `envoyproxy/envoy:v1.36-latest` | BoringSSL |

Not covered: Apache httpd and HAProxy. Both wrap OpenSSL and answer a different
question about whether a wrapper overrides its library.

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
| Envoy | **served** the excluded chain, handshake OK |

**Three of five serve a chain the client excluded, split by TLS library rather
than by server.** The OpenSSL family
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

### Envoy (`runners/envoy.sh`)

| cell | `sigalgs` | `sigalgs_cert` | result |
|---|---|---|---|
| single-excluded | `0403` | `0403` | **served**, handshake OK |
| single-allowed | `0403` | `0904` | served, handshake OK |
| dual, either order | n/a | n/a | **UNRESOLVED, see below** |

**The dual-chain result is withdrawn as UNRESOLVED, 2026-08-10.** `runners/envoy.sh`
reports that Envoy will not start with a classical and a post-quantum chain
configured together, and it reproduces on rerun. Ad-hoc probes of what looked
like the same configuration reported the opposite. Attempts to isolate the
difference across mount style, run mode, port publishing, `tls_params`, and YAML
formatting did not converge, and the last attempt failed with an unrelated
`Invalid path` error from Envoy's own config loader.

**Two of the probe harnesses used in that diagnosis were themselves buggy**, one
through an unquoted variable that made `docker run` never execute while the
script printed a pass, so several intermediate "loads fine" results were false.
Nothing about Envoy's dual-chain behavior should be claimed from any of it.

What survives is the single-chain result above, which ran through the full
runner with probe output on both cells and reproduced. What does not survive is
any statement about whether Envoy can hold both chains at once, or about
config-order selection on Envoy.

**The clean way to settle it is not more Envoy debugging.** A small server built
against upstream BoringSSL using `SSL_CTX_add1_credential` tests the documented
behavior directly, against the API the documentation describes, with no YAML,
no container, and no config-loading layer in between. Upstream BoringSSL has
ML-DSA (`ssl/ssl_privkey.cc`), so that harness also answers whether the library
can serve a post-quantum chain when it is not Envoy's build.

### Caddy (`runners/caddy.sh`)

| cell | `sigalgs` | `sigalgs_cert` | result |
|---|---|---|---|
| single-excluded | `0403` | `0403` | **served**, handshake OK |
| single-allowed | `0403` | `0904` | served, handshake OK |
| dual | n/a | n/a | **config rejected, would not start** |

### rustls (`runners/rustls-server/`, `FINDINGS-rustls.md`)

Served the excluded chain. A resolver printout from inside `resolve` shows it
received `signature_schemes` and has no accessor for the other list.

## RETRACTED: "only OpenSSL can serve a post-quantum certificate"

**Retracted 2026-08-10 by self-audit, the same day it was written. It is false.**

`rustls-post-quantum` 0.2.4 with the `aws-lc-rs-unstable` feature loads and
serves the ML-DSA chain that core rustls rejects. Measured, not inferred:

```
loaded 2 certificate(s) from gen/chains/pq/fullchain.crt
listening on 127.0.0.1:4457
resolver.signature_schemes = [ML_DSA_44]
```

The handshake in that run failed with `UnsupportedCertificate`, and that failure
is **the Go probe's**, not the server's. rustls served it correctly.

### What is actually true about post-quantum certificate support

| stack | serves an ML-DSA leaf? | detail |
|---|---|---|
| OpenSSL 3.5.5 | yes | native, no flags |
| rustls + `rustls-post-quantum` + `aws-lc-rs-unstable` | **yes** | experimental crate, unstable feature |
| rustls core, `ring` or default `aws_lc_rs` | no | `failed to parse private key as RSA, ECDSA, or EdDSA`, rustls's own key parser |
| Go 1.26 `crypto/tls` | no | primitive exists at `crypto/internal/fips140/mldsa`, not wired to x509/tls |
| Envoy 1.36.9 | UNRESOLVED | see the Envoy section |

### Why the original claim was wrong, recorded so it does not recur

Three times today a result measured on **one configuration** of a library was
written up as a property of **the library**: the ring provider standing for
rustls, Envoy's bundled build standing for BoringSSL, and an unexported internal
package standing for "Go has no ML-DSA anywhere". The generalization is the bug,
not the measurement. Name the exact build in every claim.

## The finding that survives, and is stronger for the correction

**Even in rustls's most post-quantum-capable configuration, the extension never
reaches the certificate resolver.**

```
resolver.signature_schemes         = [ML_DSA_44]
resolver.signature_algorithms_cert = <NO ACCESSOR EXISTS>
```

The resolver understands the ML-DSA code point and can act on it. It still has
no way to learn which signatures the client will accept **on certificates**. So
the selection gap is not a side effect of immature post-quantum support that
will close when support lands. It is independent of it, and it is the same in
the `ring` build, the default `aws_lc_rs` build, and the post-quantum build.

## Fairness

RFC 8446 section 4.4.2.2 makes the chain-signature constraint a SHOULD, not a
MUST. Caddy and rustls are conformant. Go's source comment declines the check
citing that SHOULD explicitly. Nothing in this matrix is a standards violation,
and writing it up as one would be wrong. The finding is what happens to an
operator running a mixed fleet during a migration.

## What decides selection

Answered 2026-08-10 in `runners/FINDINGS-controls.md`. On nginx, **server
configuration order does not decide**: the same two chains in either order both
served the post-quantum one. **The client's preference order decides**: with both
chains configured and only the order inside the client's `signature_algorithms`
changed, the served chain follows the client, 2428-byte CertificateVerify for
ML-DSA first and 79-byte for ECDSA first.

An operator therefore cannot steer which chain goes out by reordering the
config. During a migration the client population decides, one connection at a
time.

## Controls

- **Negative control passes.** One flipped byte inside the leaf signature is
  rejected by a verifying client while the untampered chain passes, so the OK
  verdicts in this matrix carry information.
- **Repeatable.** The deciding cell ran five consecutive times with identical
  results.
- **Prior art re-swept** 2026-08-10 through the PubMed Central and Crossref
  APIs. See `PRIOR-ART.md`.

## Owed

- BoringSSL's "first usable credential" behavior, which implies server config
  order matters there and would differ from OpenSSL. **Not blocked, mis-scoped.**
  The ordering question is algorithm-agnostic and can be answered today with an
  RSA and ECDSA pair, both of which Envoy loads. Answering it with post-quantum
  chains needs a small server built against upstream BoringSSL using
  `SSL_CTX_add1_credential`, which is the API the documented behavior describes.
- Apache httpd and HAProxy, if the wrapper question is worth a second answer.
- The Springer chapter (10.1007/978-3-032-16089-8_30), still unread, required
  before Phase 6.
