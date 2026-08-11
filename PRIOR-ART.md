# Prior art, per claim

Seeded 2026-08-10 from a five-agent adversarial sweep run before any code was
written. The sweep was aimed at killing the project, not confirming it, and it
succeeded against the original framing twice before this one survived.

The style rules of `pqc-cert-matrix/PRIOR-ART.md` apply here unchanged. The words
"first", "only", and "no one has" are banned from every public artifact of this
project. The single defensible form is "we found no published X, searching [list]
on [date]".

**Provenance warning.** Everything below was collected by a verification subagent
that reported cloning the repositories and grepping full text rather than reading
search summaries. It is stamped **Reported**, not Verified. Every line number and
every quoted comment is version-pinned to whatever the subagent checked out on
2026-08-10. Re-verify each one against the versions this repo actually pins
before it appears in anything public. Source comments move.

## The claim this project may make, verbatim

> We found no published measurement of how TLS server software selects between a
> classical and a post-quantum certificate chain when both are configured, across
> more than one implementation. The mechanism is documented and two stacks
> document that they do not enforce it at the chain level, but the cross-stack
> behavior with real post-quantum and hybrid chains has not been measured, and
> TLS-Anvil, the leading cross-library TLS 1.3 conformance suite, lists the RFC
> 8446 section 4.4.2.2 selection requirements in its out-of-scope annotations.

Two sentences travel with that claim permanently, or they become the rebuttal.

1. **Say "server software", never "production servers".** Dubey and Varshney
   (arXiv:2606.16473) scanned 32,011 domains in 2026 and found 0% hybrid
   post-quantum certificate adoption. There is no deployed dual-chain population
   to survey, so any phrasing that implies a fleet scan promises something this
   project cannot deliver.
2. **Cite OpenSSL #32221 in the same paragraph that describes the failure mode,
   never in a footnote.** A reviewer who finds it afterward will assume we did
   not look.

## PREEMPTED, cite instead of claim

**The silent wrong-chain failure is already on the record with runtime
evidence.** OpenSSL issue #32221, filed 2026-08-06 by `LiD0209`, open as of
2026-08-10. https://github.com/openssl/openssl/issues/32221

A dual-chain server completed a handshake using a chain it had already reported
as `CA signature: NOT OK` while a compatible chain sat configured beside it. The
client had advertised only `ecdsa_secp256r1_sha256`. Captured output is in the
issue.

This is classical (ECDSA versus RSA), single-implementation, and on the
`s_server -xcert` path rather than libssl core. It does not preempt a
cross-stack post-quantum measurement. It absolutely preempts any sentence
claiming the failure has never been demonstrated.

Companion issues from the same 2026-08-06 batch: #32222 (aborts instead of
sending a fallback chain) and #32223 (ignores the `signature_algorithms`
fallback for certificate signatures). All three are part of an automated
RFC-conformance campaign that also filed against Mbed-TLS the same day. **That
campaign is live and generating findings in this exact area. Watch it.**

**The post-quantum defect was named by an OpenSSL committer first.** Issue
#32028, 2026-07-21, author `romen`, with `t8m`, `davidben`, `tomato42`, and
`vdukhovni` participating. https://github.com/openssl/openssl/issues/32028

The committer states the `signature_algorithms_cert` implementation rests on
assumptions that no longer hold under PQC, gives SLH-DSA as the case where a
user wants to signal certificate support without `CertificateVerify` support,
and records that portions of the code apply the extension as a filter narrowing
`signature_algorithms` rather than as a separate list.

The same issue records the tooling gap this project has to solve: there is no
way to configure `signature_algorithms_cert` through `SSL_CONF_cmd()` or
`openssl.cnf`, and no way to exercise the combinations from `s_client` or
`s_server`. **That is why Phase 1 exists.** Cite it as the reason, not as our
discovery.

## Documented, therefore not claimable as a finding

Documentation existing does not preempt a measurement, but it does mean the
behavior cannot be presented as a surprise. These were read in source, not in
release notes.

- **Go `crypto/tls`**, `common.go` lines 1371 to 1374, inside
  `SupportsCertificate`: a comment stating it does not currently support
  `certificate_authorities` or `signature_algorithms_cert`, and does not check
  the algorithms of the signatures on the chain, citing RFC 8446 4.4.2.2 as a
  SHOULD. **This is the server side only.** See the correction below.
- **BoringSSL** `ssl.h`, Credentials section: documents that by default it does
  not check whether the peer supports the signature algorithms in the
  certificate chain, that it does check for a compatible signature algorithm,
  and that it selects the first usable credential from the list. **Config order
  decides.** That consequence is worth stating in deployment terms even though
  the behavior is documented.
- **OpenSSL 3.5**, `ssl/t1_lib.c` around lines 4449 to 4474: `check_cert_usable()`
  inspects the issuer signature only when `s->s3.tmp.peer_cert_sigalgs != NULL`.
  And `ssl/statem/extensions.c` around lines 273 to 278 carries a comment saying
  the extension is not generated at present, with NULL construct callbacks. Read
  together: **against an OpenSSL client the chain check is unreachable.**
- **OpenSSL certificate slots**, `ssl/ssl_local.h` around lines 319 to 328 and
  `ssl/ssl_cert.c` around lines 1303 to 1355: nine fixed `SSL_PKEY_*` slots with
  no ML-DSA entry, extended by one slot per provider-supplied signature
  algorithm. Consequence: at most one certificate per key type, so two ML-DSA
  chains from different roots is not a configurable state. This is a structural
  constraint on what Phase 3 can even build, and it is the deployment reason
  Trust Anchor IDs exists as a draft.
- **Red Hat**, post-quantum cryptography in RHEL 10: documents that the server
  chooses a certificate from the client's `signature_algorithms` or
  `signature_algorithms_cert`, and that httpd and nginx enable this by repeating
  the certificate and key directives.
- **Chromium**, Post-Quantum HTTPS Authentication Roadmap: states that every PQ
  transition requires sending different certificates to different clients, that
  `signature_algorithms` determines classical versus PQ, and immediately
  afterward that some of these capabilities are new and that servers not yet
  supporting them need updating.
- **Cloudflare**, "The state of the post-quantum Internet", 2024-03-05: states
  that servers must be configured to serve either a small traditional chain or a
  larger post-quantum chain.
- **draft-ietf-tls-trust-anchor-ids-04**, May 2026, section 8.1: notes that
  detecting PQ-capable relying parties through `signature_algorithms` and
  `signature_algorithms_cert` relies on all post-quantum CAs being added at
  roughly the same time and being interchangeable enough to negotiate.

## CORRECTED: a claim of the sweep that was wrong

**Stamp: Verified.** Read in the installed source, `go version go1.26.0
linux/amd64`, `GOROOT=/usr/lib/go-1.26`, on 2026-08-10.

The sweep reported that Go does not implement `signature_algorithms_cert` at
all. That conflated two sides of the library, and the client half is false.

**Go 1.26 emits `signature_algorithms_cert` as a client, unconditionally, for
TLS 1.2 and above.** `handshake_client.go` line 123 sets
`hello.supportedSignatureAlgorithmsCert = supportedSignatureAlgorithmsCert()`,
and `handshake_messages.go` lines 219 to 227 marshal it into the ClientHello.
The contents come from `common.go` line 1798, which derives the list from
`defaultSupportedSignatureAlgorithms()` and filters it. There is no `Config`
knob, so the list is fixed at compile time, but the extension is on the wire.

Only the **server** half of the original claim holds: `SupportsCertificate` does
not consume the extension for selection.

Two consequences, both of which change the project rather than damage it.

1. **Phase 1 gets smaller.** The probe does not have to add the extension. It
   has to control the contents of one package-level function. That is a patch,
   not a fork of the marshalling layer.
2. **OpenSSL's chain check is not universally dead code.** `check_cert_usable()`
   is unreachable when the client is OpenSSL, because OpenSSL never sends the
   extension. It is reachable when the client is Go, because Go always does. So
   **whether a server enforces the chain check at all depends on which client
   stack is talking to it.** That is a sharper framing than "the check is dead"
   and it belongs in the matrix design and probably in the article.

Re-verify both halves against the versions this repo pins before publishing.

## PREEMPTED: the library gaps are known, tracked, and in one case deliberate

Found 2026-08-10 by self-audit, after the matrix was already written. **Any
framing that presents "Go and rustls cannot serve post-quantum certificates" as
a discovery is preempted and must not ship.**

**rustls#2417**, "Load/validate and parse Quantum certificates generated by
oqsprovider", opened 2025-04-07, closed 2025-07-16. Maintainers state the
position directly. `ctz`: *"Likely we won't support this in the core crate's
providers for quite some time, as it's not well motivated by a reasonable threat
model."* He then lists what would change it, including *"any publicly-trusted
post-quantum roots accepted into any root program"* following CA/Browser Forum
ballots. `djc`: *"for signatures using ML-DSA or SLH-DSA it seems the overhead is
too large to support substantial usage."*

**This is a stated policy with reasoning, not an oversight.** Writing it up as a
gap would misrepresent the maintainers. Cite the issue and their reasoning.

**rustls#2577**, "Can't seem to load ML-DSA private key with
rustls-post-quantum 0.2.3", opened 2025-07-26, closed 2025-09-23. **This is the
same result this project measured, reported thirteen months earlier.**

**rustls#2419**, "TLS 1.3 SignatureSchemes are not extendable on the server",
opened and closed 2025-04-08. A researcher wiring liboqs ML-DSA into a custom
`CryptoProvider` hit a server-side extensibility limit. Adjacent to this
project's axis; read it before writing about rustls server behavior.

**golang/go#64537**, "crypto: post-quantum support roadmap", open since
2023-12-04. Go's post-quantum status is publicly tracked.

### What survives

None of these is about **server selection between two configured chains**, which
is this project's actual question. The selection finding is untouched. What is
preempted is the certificate-support inventory, which is now context to be cited
rather than a contribution.

Stamp: Reported. Issue bodies and maintainer comments read via `gh` on
2026-08-10, not full thread archaeology.

## The strongest evidence that this is nobody's job

**TLS-Anvil** (Maehren et al., USENIX Security 2022), covering 13 TLS
implementations, is the state of the art in cross-implementation TLS 1.3
conformance testing. Its `TLS-Testsuite/annotations/out_of_scope/8446.txt`,
around lines 65 to 71, lists all four RFC 8446 section 4.4.2.2 certificate
selection requirements as untested, including the requirement that server
certificates be signed by a client-advertised algorithm where possible. The
paper itself returned zero occurrences of `signature_algorithms`, "certificate
selection", and "quantum" on a full-text grep.

A citable admission from the incumbent is stronger than any number of empty
searches. Lead with it.

## Adjacent work that proposes rather than measures

**Frauenschläger, T. and Mottok, J., "Using Dual Algorithm Certificates in TLS:
Enabling Rapid Transition to Post-Quantum Cryptography with Backward
Compatibility", in *Computer Security. ESORICS 2025 International Workshops*,
Lecture Notes in Computer Science vol. 16231, Springer Nature Switzerland, Cham,
pages 503 to 522, online 2026-05-01. DOI 10.1007/978-3-032-16089-8_30. ISBN
978-3-032-16088-1 print, 978-3-032-16089-8 electronic. ORCIDs 0009-0009-8063-1526
and 0000-0002-7727-2448.**

Metadata verified against the Crossref API on 2026-08-10, not against a search
summary. See the fabrication note below for why that distinction is written down.

**Status: UNREAD, paywalled at $30.** Full-text request submitted through
ResearchGate on 2026-08-10. Springer gives LNCS authors a free SharedIt link, so
direct author contact is the fallback.

**Assessed as a citation rather than a preemption, and here is the reasoning so a
reviewer can check it.** The published abstract describes a transition mechanism
using certificates that embed both a traditional and a post-quantum public key
and signature, plus a new handshake negotiation mechanism. The motivation is
stated as OT and IoT: long device lifetimes, limited update capability, and
backward compatibility with legacy devices. The same group's prior work is
"Fully Hybrid TLSv1.3 in WolfSSL on Cortex-M4", so constrained-device
benchmarking in wolfSSL is their established method. A design proposal evaluated
on a microcontroller is a different contribution from a cross-implementation
measurement of how nginx, Envoy, and rustls choose among configured chains.

**This assessment is Reported, from the abstract and the group's publication
record. It is not Verified.** If the full text turns out to contain an
interoperability study across server implementations, this project narrows. Read
it before Phase 6 without exception.

### Fabrication note, recorded because it will happen again

On 2026-08-10 an AI research assistant was asked to determine this paper's
empirical scope. It returned a structured report whose bibliographic table gave
DOI 10.1007/978-3-031-71785-5_27 and ISBNs 978-3-031-71784-8 and
978-3-031-71785-5, and labeled that table "the only concrete evidence that can be
assessed with certainty". Every one of those identifiers is wrong. The real
values are above. It also declined to name the two authors, on the stated grounds
of avoiding invented names, while inventing the identifiers in the same table.
The page range, which it had been given, was the one field it preserved.

The failure mode is new and worth naming: **a research assistant can overwrite
correct input metadata with plausible-looking fabrications and present them as
the verified layer.** Crossref settles DOI, ISBN, authors, and pagination for
free. Use it before accepting any secondhand bibliographic record.

**draft-yusef-tls-pqt-dual-certs-01**, 17 December 2025, by Shekh-Yusef (Ciena),
Tschofenig (H-BRS), Ounsworth (Entrust), Reddy (Nokia), and Rosomakho (Zscaler).
https://www.ietf.org/archive/id/draft-yusef-tls-pqt-dual-certs-01.html

Public, free, and adjacent to the Springer chapter without being proven
identical: the draft carries two independent certificates producing one
`Certificate` and `CertificateVerify`, while the chapter uses X.509 alternative
key extensions. Read on 2026-08-10, it proposes an additive mechanism, reports
no measurement of existing server selection, and cites no prior measurement
study of certificate selection. That reading came from a page summarizer rather
than a local grep, so it is Reported and weakly held.

Five vendors built a new TLS extension because phased migration across mixed
peers is hard. That is this project's premise arriving as support.

**IETF Hackathon `pqc-certificates`** is provider-to-provider artifact interop,
already logged in `pqc-cert-matrix/PRIOR-ART.md` as not a handshake matrix. Same
verdict here.

## Searched, so the claim can carry a scope

2026-08-10. arXiv full-text grep of 2605.17955, 2605.02978, 2606.16473, and
2604.06100, each returning zero hits for `signature_algorithms_cert`,
"certificate selection", and dual or multi-certificate phrasing. arXiv API for
`all:"signature_algorithms_cert"` and `all:"certificate selection" AND
all:"post-quantum"`, both empty, and weakly held because the API searches
metadata rather than full text. Cloned and grepped bc-java, esig/dss, and
pyHanko during the wider sweep. Read Go `crypto/tls`, BoringSSL `ssl.h`, OpenSSL
`t1_lib.c`, `extensions.c`, `ssl_local.h`, and `ssl_cert.c` in source. GitHub
issue search across the OpenSSL, nginx, HAProxy, Caddy, Envoy, and rustls
trackers. Vendor engineering blogs: Cloudflare, Google, AWS, Mozilla, Red Hat,
nginx, and DigiCert. DigiCert's `LABS-mldsa-testserver`, which is single-chain
and returned zero hits for dual, fallback, and `signature_algorithms`.

**RE-SWEEP COMPLETED 2026-08-10.** The venue gap flagged earlier was real but
mis-diagnosed. Re-run against PubMed Central (E-utilities) and Crossref
(bibliographic query, MDPI member 1968 and all publishers), using structured
APIs rather than web search so nothing passed through a summarizer.

**The framing was wrong: it was a METHOD gap more than a venue gap.** MDPI and
PMC yielded nothing preempting. What the re-sweep actually surfaced came from a
Crossref bibliographic query, which indexes every publisher with a DOI including
ACM, and it is an ACM paper that four earlier sweeps missed. A structured
Crossref query is a better prior-art net than web search plus arXiv plus ePrint,
and it should lead every future sweep in all three repos.

**PMC findings.** Exact-phrase `"certificate selection" AND post-quantum`
returns **0 hits**. That negative is usable, because the same phrase alone
returns 6 sensible hits, so the phrase search demonstrably works. Do NOT quote
PMC counts for underscored terms: `"signature_algorithms_cert"` returns 519 hits
consisting of cancer biology and federated learning, because PMC tokenizes and
ORs. Those numbers are noise, not evidence.

**MDPI via Crossref.** Nothing preempting. Closest items are performance
analyses of post-quantum signature algorithms in *Cryptography*, *Algorithms*,
and *Applied Sciences*, plus "A Readiness and Maturity Framework for
Post-Quantum TLS Adoption" (2026). None measures server-side selection.

### MUST CITE, and it was missing from all three repos

**Paul, S., Kuzovkova, Y., Lahr, N., and Niederhagen, R. "Mixed Certificate
Chains for the Transition to Post-Quantum Authentication in TLS 1.3." AsiaCCS
2022, pages 727 to 740. DOI 10.1145/3488932.3497755. Also IACR ePrint
2021/1447.**

They named the concept. From the abstract: their strategy "is based on the
concept of 'mixed certificate chains' which use different signature algorithms
within the same certificate chain", and their result is that chains "containing
hash-based signature schemes only at the root certificate authority level lead
to feasible connection establishment times".

**This project has been using that framing uncited.** `FINDINGS-mixed.md` and
the `pqleaf` and `pqissuer` shapes are instances of their concept, arrived at
independently for a different purpose. Cite them for the concept every time.

**It does not preempt the measurement.** They evaluate handshake time,
communication size, code size, and peak memory using custom client and server
programs on embedded targets. Their axis is chain position, with hash-based
schemes at the root for trust-anchor conservatism. This project's axis is leaf
key versus issuer signature, measured against production server software, to see
which chain gets selected. Neither `signature_algorithms_cert` nor server
certificate selection appears in the abstract or in Paul's 2023 PKI Consortium
deck on the same work, which was downloaded and grepped: zero hits for
`signature_algorithms_cert`, certificate selection, nginx, or OpenSSL.

Stamp: Reported. Abstract and slides read, ACM full text not obtained.

**Also relevant, already cited in the sibling repos but not here:** Sikeridis,
Huntley, Ott, and Devetsikiotis, "Intermediate certificate suppression in
post-quantum TLS", CoNEXT 2022, DOI 10.1145/3555050.3569127.

### Owed in the public repos

`pqc-cert-matrix` mints a chain shape it calls `mixed` and is public with a DOI.
It does not cite Paul et al. Adding that citation is a correctness fix a reviewer
could otherwise raise, and it is Danny's call whether to do it now or at the next
release.

**Not obtained.** The Springer chapter above. `mailarchive.ietf.org` served a
Cloudflare interstitial throughout, worked around through the mail-archive.com
mirror. **The rustls selection path is now traced. CLOSED 2026-08-10**, see
`runners/FINDINGS-rustls.md`. Read in released 0.23.43 (tag `v/0.23.43`,
2026-07-29) and dev HEAD `2cd5cc1` (2026-08-10). The `ClientHello` struct handed
to `ResolvesServerCert::resolve` has eight fields and `signature_algorithms_cert`
is not one of them, in either tree. In the release the identifier appears twice
in the whole crate, both in `msgs/enums.rs`, as the code point and as an
ECH-compressible extension. It is never parsed into a payload struct, so a custom
resolver cannot honor it either. The `handshake.rs:1127` site the sweep found is
the `CertificateRequest` direction, which is client authentication, not server
selection. Searched the rustls issue tracker the same day for the extension name,
open and closed: no results, which is weak evidence and not proof.

## What would kill this project

- **The Springer chapter turning out to contain a measurement** of existing
  selection logic across implementations. Read it before Phase 1 if possible,
  before Phase 6 without exception.
- **The automated conformance campaign getting there first.** It is filing
  issues in this area now. It works one implementation at a time, so a
  cross-stack table stays a different artifact, but if it broadens, re-read this
  file before continuing.
- **romen's fix to #32028 landing mid-project.** It would close the tooling gap
  that justifies Phase 1 and change the measured behavior underneath Phase 4.
  Pin every version and record the commit each cell ran against.
- **Every cell confirming its own documentation.** Survivable, since assembly is
  the contribution and TLS-Anvil declined the job. But if rustls and the mixed
  chains both come back boring, the article is a reference table rather than a
  finding, and it should be written and priced as one.
