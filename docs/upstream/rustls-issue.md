# Upstream report: rustls

**Status: final, ready to file. Not yet filed.**

Filed as a feature request against `rustls/rustls`, before the article publishes rather
than after. The article names rustls behaviour, and telling the project first is the
courteous order even though nothing here is a vulnerability.

The text below is what gets posted, kept verbatim so the repository records exactly what
was said upstream.

**Title:** Expose `signature_algorithms_cert` to `ResolvesServerCert::resolve`

---

`ResolvesServerCert::resolve` receives a `ClientHello`, and that struct does not carry the
client's `signature_algorithms_cert` extension. As of `v/0.23.43`,
`rustls/src/server/server_conn.rs:139` defines eight fields:

```rust
server_name  signature_schemes  alpn  server_cert_types
client_cert_types  cipher_suites  certificate_authorities  named_groups
```

with eight matching accessors. `signature_schemes` is `signature_algorithms`, which
constrains the handshake signature. There is no equivalent for the certificate chain.

The practical effect is that a custom resolver cannot implement RFC 8446 section 4.4.2.2's
certificate-signature preference even when the operator wants it, because the input needed
to make the decision never reaches the resolver.

**This is a feature request, not a bug report.** Section 4.4.2.2 makes the chain-signature
constraint a SHOULD, and where a server cannot produce a chain signed only with the
client's advertised algorithms it explicitly says the server SHOULD "continue the handshake
by sending the client a certificate chain of its choice". rustls is conformant, and I am
not suggesting otherwise.

## Why it is worth exposing anyway

`certificate_authorities` is already on `ClientHello`, with a doc comment linking RFC 8446
section 4.2.4. That extension exists for exactly one purpose, guiding server certificate
selection, and rustls surfaces it so a resolver can act on it.
`signature_algorithms_cert` is the other extension in that same job, and it is the one that
a post-quantum migration turns on.

The case gets sharper during a migration. An operator holding a classical chain and a
post-quantum chain has no way, in rustls, to write a resolver that respects a client saying
it cannot validate post-quantum certificate signatures. The two chains are
indistinguishable from inside `resolve`.

## What I measured

Configuring a single chain whose intermediate carries an ML-DSA-44 signature, then
connecting with a client advertising `ecdsa_secp256r1_sha256` (0x0403) in both
`signature_algorithms` and `signature_algorithms_cert`, rustls serves that chain and the
handshake completes.

Reproduced on three builds of `v/0.23.43`: the `ring` provider, the default `aws_lc_rs`
provider, and `rustls-post-quantum` 0.2.4 with `aws-lc-rs-unstable`. So it is not a
provider-specific behaviour. openssl `s_server` 3.5.5 and nginx 1.31.3 refuse the same
configuration with `handshake_failure`, which is a different reading of the same SHOULD
rather than a more correct one.

Scripts, captured output, and the version-pinned matrix are here:
https://github.com/DannyBCarrJr/pqc-chain-selection, archived at
https://doi.org/10.5281/zenodo.21911032. The rustls column is
`runners/FINDINGS-rustls.md`, and every cell ships the script that produced it alongside
the output.

## Shape of the ask

Adding a `signature_algorithms_cert` accessor to `ClientHello`, populated when the
extension is present and `None` when it is absent, would let a resolver implement the
preference without changing any default behaviour. RFC 8446 section 4.2.3 says the
extension may be omitted when it would duplicate `signature_algorithms`, so `None` needs to
mean "fall back to `signature_schemes`" rather than "no constraint", and that distinction is
probably worth documenting on the accessor.

Happy to test a change against the harness above, or to add the rustls cells to the
published matrix once an accessor exists.

---

## Notes, not part of the issue

- **The patch offer was cut.** An earlier draft ended "happy to send a patch if the
  direction is welcome." Offering a patch and then not writing one is worse than not
  offering, so it now offers testing against the existing harness, which is already built
  and therefore deliverable. Add the patch line back in one sentence if the intent is real.
- **Everything factual here was verified on 2026-08-12** against the source at tag
  `v/0.23.43`, fetched and grepped rather than recalled, and crates.io confirmed `0.23.43`
  as the newest stable release so the finding is not against stale code.
- **The `certificate_authorities` precedent is the strongest sentence in the issue.** It is
  their own design decision, in their own source, arguing for the change. It was found while
  verifying the eight-field claim, not while writing the argument.
- After filing, record the issue URL here and in `PREPUBLICATION-AUDIT.md`.
