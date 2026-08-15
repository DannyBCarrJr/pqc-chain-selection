# Article outline: chain selection

Target: `carrdigital.dev/writing/`, the eighth article. Deliberately **not** in
`carr-digital/src/pages/writing/` yet, because that directory has no draft flag and Astro
publishes whatever it finds there.

`SCOPE.md` required this be written after the matrix was populated rather than before. It
is, so this is unblocked. File the rustls issue first: the article names their behaviour and
they should hear it from me before they read it.

## Working title

**"The chain you configured is not the chain you serve."**

Alternatives, in case that reads too much like a threat: "Nobody is broken and it still
does not work." "What your server sends when the client says no."

## The claim, and its limits

Three of five server stacks sent a certificate chain the client had explicitly excluded,
and every one of those handshakes completed. All three are conformant with RFC 8446.

That last sentence goes in the first paragraph, not the last. The temptation is to hold it
back for a reveal, and doing so would earn a correction in the comments and deserve it.

## Structure

**Cold open on the measurement.** One configured chain, an EC leaf under an ML-DSA-44
intermediate. A client saying `ecdsa_secp256r1_sha256` in both signature algorithm
extensions, which means it will not accept ML-DSA signatures on certificates. openssl and
nginx refuse with `handshake_failure`. Caddy, rustls, and Envoy serve it anyway and the
handshake completes. Five stacks, versions pinned, every cell a script plus its output.

**The reader's stake, one sentence, second person.** If you are planning a post-quantum
migration and expect `signature_algorithms_cert` to keep the wrong chain off the wire, the
specification does not promise you that.

**Then the part that makes it interesting rather than a bug report.** Section 4.4.2.2 makes
the constraint a SHOULD, and its fallback clause goes further: a server that cannot produce
an acceptable chain SHOULD send one of its choice regardless. With one chain configured and
the client excluding it, that clause applies directly, so serving is the behaviour the text
recommends and refusing is the one that sits less comfortably. Go's `crypto/tls` declines
the check in a source comment citing that SHOULD by name, so Caddy's behaviour is a
documented decision rather than an oversight.

Flat verdict lands here. Something close to: **Nobody is broken. That is the problem.**

**Why rustls cannot honour it even if you want it to.** The eight fields a certificate
resolver receives, and `signature_algorithms_cert` not among them. A resolver cannot filter
on an extension it never sees. This is the concrete mechanism, and it is the section that
earns the article among engineers rather than executives.

**What decides selection, and it is not your config.** Same two chains, order swapped in
`ssl_certificate`, nginx served the post-quantum chain both ways. Change only the order
inside the client's `signature_algorithms` and the served chain follows the client: a
2,428-byte `CertificateVerify` for ML-DSA first, 79 bytes for ECDSA first. So an operator
cannot steer this from a configuration file. During a migration the client population
decides, one connection at a time.

**Why we found no scan for this.** The asymmetry, and this is the strongest structural
idea in the piece. The client's constraint rides in a plaintext ClientHello. The
Certificate message is encrypted under the handshake traffic secret. A passive on-path
observer therefore sees what the client asked for and never sees what came back, so the
failure is invisible to the standard observation method. Detection needs an active client,
the handshake keys, or instrumentation on the server, and none of those is a fleet scan.

This also explains a number worth quoting: Dubey and Varshney measured 49.3% of 32,011
domains supporting hybrid post-quantum key exchange and 0% using hybrid post-quantum
certificates. The half the industry can watch moved. The half it cannot did not.

**Credit where it is owed, and do not bury it.** Frauenschläger and Mottok call
multiple-chain deployment selected by `signature_algorithms_cert` "the simplest and already
practically used approach" and name OpenSSL as already supporting it, so neither the
configuration nor the OpenSSL result is mine. OpenSSL issue #32221 already demonstrated the
silent wrong-chain failure with captured output, in the classical case on one
implementation. What this adds is the same question across five implementations with real
post-quantum chains.

**The limits, stated rather than buried.** Envoy appears on single-chain cells only; its
dual-chain behaviour is withdrawn as unresolved because the runner and ad-hoc probes
disagreed and two of the diagnostic harnesses turned out to be broken, one printing a pass
while the container never started. httpd and HAProxy are untested. Three claims were
retracted from the project by self-audit before release.

**Where this is heading, because a reviewer will raise it otherwise.** Merkle Tree
Certificates are not a proposal any more. Cloudflare serves them to 1000 proxied domains
with Chrome as the client on 50% of Beta 146+, measured 9% faster at P50 even with classical
signatures. Google Trust Services is scheduled for 2028 and Let's Encrypt targets 2027
production, calling MTC "the path forward for the post-quantum Web PKI". So the drop-in
migration this article measures may be a road the Web PKI does not take, and saying so is
stronger than being told.

**Close on the sharpest line.** Candidate: the reason nobody found this is not that nobody
looked. It is that the request is in the clear and the answer is encrypted.

## Every number, with its source

Nothing goes in the article that is not in this table.

| claim | stamp | source |
|---|---|---|
| 3 of 5 served an excluded chain | Verified | `MATRIX.md`, this repo |
| rustls reproduces on 3 provider builds | Verified | `runners/FINDINGS-rustls.md` |
| 8 fields on `ClientHello` | Reported | `server_conn.rs:139` at tag `v/0.23.43` |
| client order decides, config order does not | Verified | `runners/FINDINGS-controls.md` |
| 2,428 and 79 byte `CertificateVerify` | Verified | same |
| Certificate message is encrypted | Reported | RFC 8446 section 4.4 and Figure 1 |
| `signature_algorithms_cert` is a ClientHello extension | Reported | RFC 8446 section 4.2 table |
| 0% certs, 49.3% KEX, 32,011 domains | Reported | arXiv:2606.16473 abstract |
| "already practically used approach" | Reported | Frauenschläger and Mottok, 10.1007/978-3-032-16089-8_30 |
| MTC: 1000 domains, 50% Chrome Beta, 9% P50 | Reported | Valenta, IETF 125 slides |
| Let's Encrypt 2027, GTS 2028 | Reported | letsencrypt.org/2026/06/03/pq-certs; Google Cloud roadmap |

Every one of these was verified against its source on 2026-08-12. `PRIOR-ART.md` carries
the detail and the two claims that are cited rather than made.

## Status: PUBLISHED 2026-08-13

**Live at https://carrdigital.dev/writing/three-of-five-sent-it-anyway/**

Canonical source is `carr-digital/src/pages/writing/three-of-five-sent-it-anyway.md`. The
draft that lived at `docs/article-draft.md` was **deleted on publication, deliberately**:
this repo is public, so a second copy here would be a second public copy of the same
article with nothing keeping the two in step. Everything below is the design record of how
it was written, which is worth keeping. The article itself is not.

Verified live by content rather than status code, with a negative control confirming a
bogus slug does not return the article. Listing, RSS, and sitemap all picked it up.

**The rustls gate closed 2026-08-13**: `rustls/rustls#3214` is filed and open. The draft is
clear to publish.

**Title settled 2026-08-13: "Three of five sent it anyway", slug
`three-of-five-sent-it-anyway`.** The working title below was 50 characters and the house OG
card holds about 40 at its 88px title size, so it wrapped to three lines and collided with
the dek. Rather than bend the card geometry for one article, the title moved to the finding
itself. **Any future title for this site has a hard ceiling of roughly 40 characters**, which
is worth knowing before falling in love with a long one. OG card rendered and committed at
`carr-digital/public/og/three-of-five-sent-it-anyway.png`.

**Citations closed 2026-08-13.** Both primary sources downloaded and grepped. The Valenta
slides verified clean, every figure verbatim. The DigiCert report corrected two claims that
had already reached the draft, recorded in `PRIOR-ART.md`. **Nothing is blocking
publication.**

## Before it ships

- **A Provenance section**, matching the other seven articles, separating measured from
  cited.
- **An OG image** at `public/og/<slug>.png`. Every existing article has one and a new one
  without it will look broken when shared.
- **Frontmatter**: `layout`, `title`, `description`, `date`, `kind: Measurement`, `ogImage`.
- **Link the DOI**, 10.5281/zenodo.21911032, so the article points at the archive rather
  than only at a moving repository.
- **Re-read `PRIOR-ART.md` first.** It has demoted this project's framing twice, including
  once on the day the gate closed.
- **File the rustls issue before publishing.** See `docs/upstream/rustls-issue.md`.
