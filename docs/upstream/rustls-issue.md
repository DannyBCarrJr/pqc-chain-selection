# Upstream report: rustls

**Status: the issue must be written by Danny, in his own words. Not by an assistant.**

`rustls/CONTRIBUTING.md` carries an AI policy and it is explicit: "AI should not be used to
generate comments when communicating with maintainers ... Comments that are believed to be
written by AI may be hidden without notice. If you are opening an issue, you should be able
to describe the problem in your own words." Posting a drafted issue would break the host
project's stated policy in the one community whose behaviour this project documents. The
facts below are verified and are his to draw on; the sentences have to be his.

Use their **feature request template** (`.github/ISSUE_TEMPLATE/feature_request.md`), which
has a checklist plus four sections: the problem, the solution, alternatives considered, and
additional context. Discussions are not enabled, so an issue is the right venue.

## Tracker search, 2026-08-12: the checklist item is honestly tickable

No prior request exists for exposing `signature_algorithms_cert`. The only hit on that
string is #2420, about inverting `SignatureScheme::supported_in_tls13`, which is unrelated.

**Two closed issues matter a great deal, and both are precedents rather than blockers.**

**#2235, "Support `certificate_authorities` extension in ClientHello"** (Nov 2024, closed
in three weeks, landed). This is the accessor already on `ClientHello` and it is the
strongest argument available. Read how it went:

- `ctz` pushed back immediately on practicality: the extension means about 15KB in the
  ClientHello for the WebPKI, "pretty impractical".
- The requester did not argue the point. They narrowed the ask: "I'm not proposing for
  rustls to start sending this extension by default. The proposal is to let custom cert
  verifiers and cert resolvers propose/check this extension."
- `ctz`: "Ah, yes that would be acceptable ... so adding it for server auth seems
  reasonable."
- Requester: "I'll work on the PR then." It landed.

**#2484, "Need more data in the ClientHello struct to choose best cert/key for
connection"** (June 2025). Someone asked for a missing field needed for certificate
selection, and `named_groups` is now one of the eight fields. Same category of ask, and it
succeeded. The thread also shows the maintainers' opening moves: `djc` asked "Can you be
more explicit about what exactly it is that you're trying to achieve concretely?" and `ctz`
asked "Is that a real use case? If so, why are you doing that to yourself?" before
accepting it with a caution that the logic is complex.

Worth knowing: in that same thread `ctz` discusses walking chains and reasoning about
"the certificate it names in its `certificate_authorities` extension". Chain selection is
already territory he has thought about.

## What that means for how this gets written

1. **Lead with a concrete operator scenario, not with the RFC.** Both threads open with a
   maintainer asking what you are actually trying to do. Answer that in the first
   paragraph: an operator holding a classical chain and a post-quantum chain during a
   migration, with clients that cannot validate post-quantum certificate signatures.
2. **Narrow the ask before anyone has to narrow it for you.** Expose it to custom
   resolvers; do not change any rustls default. That single move is what turned #2235 from
   a pushback into an approval.
3. **Bring the measurement, because it answers "is that a real use case?" better than an
   assertion.** Five stacks, three provider builds, published and archived.
4. **Pre-empt the complexity caution.** RFC 8446 section 4.2.3 lets the extension be
   omitted when it would duplicate `signature_algorithms`, so `None` has to mean "fall
   back to `signature_schemes`" and not "no constraint". Saying that first shows the work.
5. **On offering a PR: the evidence says offer it.** Both prior requests were carried by a
   requester who engaged on implementation, and #2235 landed because the requester said
   "I'll work on the PR then." This reverses the earlier advice in the notes below. Offer it
   only if the intent is real, because not delivering is worse than not offering.

## Verified facts, for drawing on rather than pasting

Filed as a feature request against `rustls/rustls`, before the article publishes rather
than after. The article names rustls behaviour, and telling the project first is the
courteous order even though nothing here is a vulnerability.

Suggested title: **Expose `signature_algorithms_cert` to `ResolvesServerCert::resolve`**

Everything below is verified source material, not text to paste. Record the filed issue URL
here once it exists.

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
