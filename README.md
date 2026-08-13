# pqc-chain-selection

Three of five TLS server stacks sent a certificate chain the client had said it
would not accept. All three are conformant. That is the finding.

RFC 8446 makes the chain-signature constraint a SHOULD, and when a server holds no
chain the client will accept, section 4.4.2.2 tells it to "continue the handshake
by sending the client a certificate chain of its choice". So if you are planning a
post-quantum migration and expect `signature_algorithms_cert` to keep the wrong
chain off the wire, the specification does not promise you that. Two of the five
behave as though it does. Three do not, correctly.

Nothing measured here is a standards violation, and this repo will not describe it
as one.

**Released: v1.0.0, MIT.** All measurements are in and re-run from a clean build.
Results per cell are in `MATRIX.md`, limitations and corrections in `CHANGELOG.md`,
and `PRIOR-ART.md` governs every claim published from here. `CONTRIBUTING.md` has
the standards a patch has to meet.

The prior-art gate that could have stopped this project closed on 2026-08-12, when
the Springer chapter (10.1007/978-3-032-16089-8_30) turned out to propose a mechanism
rather than measure chain selection. It cost two framing claims, both recorded in
`PRIOR-ART.md` and credited in this file.

## The question

When a server holds a classical chain and a post-quantum chain, does it send the
right one to each client?

The failure is silent. The handshake completes, the client validates, the page
loads, and the server has been handing the classical chain to
post-quantum-capable clients for months. No monitoring signal separates that from
a migration that worked.

That silence is not hypothetical, and it is not ours to claim first. OpenSSL issue
[#32221](https://github.com/openssl/openssl/issues/32221), filed 2026-08-06 by
`LiD0209`, records a dual-chain server completing a handshake on a chain it had
already reported as `CA signature: NOT OK` while a compatible chain sat configured
beside it, with captured output in the issue. That case is classical, ECDSA
against RSA, on one implementation and on the `s_server -xcert` path. What was
missing was the same question asked across implementations, with real
post-quantum chains.

## What was measured

Five server stacks, on one machine, all runs 2026-08-10. Versions were recorded
per run rather than assumed, because OpenSSL #32028 is being actively worked and a
fix would move the ground underneath these numbers.

| stack | version | TLS library |
|---|---|---|
| `openssl s_server` | 3.5.5 (27 Jan 2026) | OpenSSL |
| nginx | 1.31.3, `nginx:alpine` | OpenSSL 3.5.7 |
| Caddy | built from source, go1.26.0 | Go `crypto/tls` |
| rustls | 0.23.43, tag `v/0.23.43` | three builds: `ring`, default `aws_lc_rs`, and `rustls-post-quantum` 0.2.4 |
| Envoy | 1.36.9, `envoyproxy/envoy:v1.36-latest` | BoringSSL |

The client is a purpose-built probe on a forked Go `crypto/tls`, because it has to
emit `signature_algorithms` and `signature_algorithms_cert` independently and
stock tooling will not do that. Every cell ships a script and captured output
under `runners/evidence/`, and chain identity is read from server-side handshake
message lengths rather than inferred from the client's error text.

## The deciding cell

One configured chain, `pqissuer`: an EC leaf key under an ML-DSA-44-signed
intermediate. The client offers `0x0403` in both extensions, so it can use the
leaf's EC key and has stated it will not accept ML-DSA signatures on
certificates. The only chain available is exactly that.

| stack | outcome |
|---|---|
| `openssl s_server` | refused, `handshake_failure` before sending a certificate |
| nginx | refused, `handshake_failure` |
| Caddy | served the excluded chain, handshake OK |
| rustls | served the excluded chain, handshake OK |
| Envoy | served the excluded chain, handshake OK |

The rustls result reproduces on all three builds, including the post-quantum one,
so it is not an artifact of one cryptographic provider.

## Conformance, stated before anything else is read

RFC 8446 section 4.4.2.2 makes the chain-signature constraint a SHOULD, not a MUST,
and it goes further: a server that cannot produce a chain signed only with the
client's advertised algorithms SHOULD send a chain of its choice anyway. In the
cell above there is one configured chain and the client excluded it, so the
fallback clause applies directly.

**Caddy, rustls, and Envoy are conformant.** Go's `crypto/tls` declines the check
in a source comment that cites that SHOULD explicitly, so in Caddy's case it is a
documented decision rather than an oversight. Under the same clause, refusing with
`handshake_failure` is the behavior that sits less comfortably with the text, not
serving.

The finding is not that anyone is broken. It is that an operator running a mixed
fleet through a migration cannot rely on `signature_algorithms_cert` to keep a
chain off the wire, because two thirds of the stacks measured here do not treat it
as binding and the specification does not require them to. Writing that up as a
standards violation would be wrong, and would also be the fastest way to have the
whole result dismissed.

## Why rustls cannot honor it

Source reading, not a handshake, and stamped Reported for that reason.
`ResolvesServerCert::resolve` receives a `ClientHello` carrying eight fields:
`server_name`, `signature_schemes`, `alpn`, `server_cert_types`,
`client_cert_types`, `cipher_suites`, `certificate_authorities`, and
`named_groups`. `signature_algorithms_cert` is not among them, in released
0.23.43 or on dev HEAD. A resolver cannot filter on an extension it never
receives. The prediction was written down before the handshake confirmed it.

## The operator consequence

On OpenSSL, the client decides and the config does not. Same two chains, same
server, only the order changed:

| what changed | chain served |
|---|---|
| `ssl_certificate` order swapped on nginx | pq, both ways |
| client sends `0x0904,0x0403` | ML-DSA |
| client sends `0x0403,0x0904` | ECDSA |

That is correct under RFC 8446, and it has a consequence worth saying plainly: an
operator cannot steer which chain goes out by reordering the configuration file.
During a migration the client population decides, one connection at a time.

## What OpenSSL does, and who documented it first

OpenSSL treated `signature_algorithms_cert` as binding in all six dual-chain
cells, and it was the deciding variable: two cells differing in nothing but that
extension received different chains. One cell carries more weight than the rest. A
client asking for ML-DSA `CertificateVerify` while sending the stock Go certificate
list received no chain at all, which is a deliberate refusal rather than a lucky
pass.

Where both chains are configured the fallback clause does not apply, because the
server is "able to provide such a chain", so honoring the extension there is the
stronger reading of the text. That is a different situation from the deciding cell
above, and the two should not be quoted as one result.

None of that is presented here as a discovery. Frauenschläger and Mottok describe
multiple-chain deployment selected by `signature_algorithms_cert` as "the simplest
and already practically used approach", and name OpenSSL as already supporting it.
The configuration is established practice and the OpenSSL result is theirs. The
cross-implementation measurement is what this repo adds.

## What this is not

Not a scan of the deployed web. Dubey and Varshney (arXiv:2606.16473) found 0%
hybrid post-quantum certificate adoption across 32,011 domains in 2026, so there
is no deployed dual-chain population to survey. This measures server software on
a bench, and the wording throughout is "server software" for that reason.

Not complete on Envoy. Envoy appears on the single-chain cells only. Whether it
can hold a classical and a post-quantum chain at once went unresolved when two of
the diagnostic harnesses used to answer it turned out to be defective, one of them
printing a pass while `docker run` never executed. Nothing is claimed about
Envoy's dual-chain behavior in either direction. Settling it takes a BoringSSL
harness, not more YAML.

Not a claim about httpd or HAProxy, which are untested. Both wrap OpenSSL and
answer a different question about whether a wrapper overrides its library.

And not a passive detection method, because there cannot be one. The client's
`signature_algorithms_cert` travels in a plaintext ClientHello while the
`Certificate` message is encrypted under the handshake traffic secret, so an
on-path observer sees the constraint and never the response. Detecting this needs
an active client, the handshake keys, or instrumentation on the server. That is
why a fleet-wide scan for it does not exist.

## Layout

- `probe/` the forked-`crypto/tls` client, emitting the two extensions independently
- `gen/` the chain shapes, minted and pinned
- `runners/` one harness per stack, plus `selfcheck.sh` and the evidence tree
- `runners/FINDINGS*.md` per-column results, each stamped Verified or Reported
- `MATRIX.md` the table, with versions per cell
- `PRIOR-ART.md` what may and may not be claimed, per claim
- `PREPUBLICATION-AUDIT.md` the leak scan run before the visibility change

## Reproduce

```
gen/mint-chains.sh && probe/tlspatch/build.sh && runners/s_server.sh
```

`runners/selfcheck.sh` gates the suite and passed 12 of 12 on the clean re-run of
2026-08-10. Every passing cell has a negative control, because a check that cannot
fail is not a check. Three claims were retracted from this project by self-audit
on 2026-08-10, and one server result is still recorded as unresolved. Both facts
are in the repo on purpose.

Part of Carr Digital LLC.
