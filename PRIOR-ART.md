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

   **Verified against the arXiv abstract 2026-08-12**, fetched and grepped. Full
   title "Measurement Study of Post-Quantum Readiness of Internet: 2026", authors
   Vanishka Mohan Dubey and Gaurav Varshney. The count and the zero are exact:
   "32,011 domains" and "Notably, 0% adoption of hybrid post-quantum certificates
   was observed".

   **Cite the 49.3% alongside the 0%, always. It is the better half of the
   result.** The same abstract reports that "49.3% of domains support hybrid
   post-quantum key exchange mechanisms (e.g., MLKEM768 with X25519), whereas 50.7%
   continue to use classical key exchange". So the deployed web is roughly half
   migrated on key exchange and at exactly zero on certificates.

   That asymmetry is this project's subject stated in someone else's numbers, and it
   lines up with the mechanism recorded further down this file: key exchange is
   negotiated in the plaintext ClientHello and ServerHello, so it is measurable by
   any passive observer and every readiness tool reports it, while the Certificate
   message is encrypted and no passive tool can see it. The half the industry can
   watch is the half that moved. Quoting 0% alone reads as "nobody has started";
   quoting both reads as "the visible half moved and the invisible half did not",
   which is true, stronger, and harder to argue with.

   **Have the answer to the survey rebuttal ready, because it exists and it is
   public. Added 2026-08-12. VERIFIED AGAINST THE PRIMARY SOURCE 2026-08-13**, PDF
   downloaded and grepped, replacing the postquantum.com summary this arrived
   through.

   The document is **"The Quantum Execution Gap: Key findings from DigiCert's
   Quantum Readiness Outlook", Research Report 2026**.
   https://www.digicert.com/content/dam/digicert/pdfs/report/quantum-readiness-outlook.pdf
   Its methodology page records an independent survey by Propeller Insights on
   behalf of DigiCert in May 2026, of 1,001 IT and cybersecurity decision-makers
   across the United States (500), the United Kingdom (251), and Australia (250).
   All of that matches what the summary said.

   **The quote in this file was wrong, by one word, and it is fixed.** The report
   says "Only 7% report that more than half of their **certificates** currently use
   quantum-safe or hybrid cryptography, an increase of less than two percentage
   points since last year." This file had "their **digital** certificates". The
   word was not in the source. Small, and it is exactly the class of drift that
   the download-and-grep rule exists to catch.

   **A second correction, and this one mattered more.** This file previously said
   the 7% "covers an organization's whole certificate estate including private and
   internal PKI". **The report never says that.** It says "certificates",
   unqualified, and contains no discussion of public versus private or internal
   PKI anywhere. That was an inference presented as a property of the source, and
   it had already reached the article draft before it was caught.

   The defensible reconciliation, all of it from the text: the 7% is
   **self-reported**, it **never defines** "quantum-safe or hybrid", and it counts
   an organization's own certificates **without scoping them to publicly trusted
   ones**. The 0% is **measured**, and scoped to hybrid post-quantum certificates
   on public web domains. Different populations, different methods, and one of them
   is a vendor surveying its own market. Neither number is evidence against the
   other. The absence of scoping is the stronger point anyway, because it needs no
   assumption about what the estate contains.

   **Note for anyone re-fetching it: the PDF sits behind Incapsula and returns a
   1KB interstitial to `curl` and other non-browser clients.** Send a browser
   User-Agent and it serves the real 638KB PDF. Same class of trap as zenodo.org's
   403, recorded here so it is not mistaken for a dead link.

   **A second, smaller number points the same way and should be handled the same
   way. Added 2026-08-12.** An IETF 126 PLANTS talk by Nalini Elkins
   (`slides-126-plants-measuring-deployment-characteristics-of-pq-tls-authentication-mechanisms-00.pdf`,
   2026-07-19, read in full) has one measured slide, "Internet Sites (top 27)",
   reporting observed algorithm sets as RSA 14 (51.9%), EC 9 (33.3%), and **EC +
   RSA 4 (14.8%)**.

   That last figure is the classical analogue of the configuration this project
   measures: a site presenting two algorithm families rather than one. It does
   **not** contradict the 0% above, because that is specifically about *hybrid
   post-quantum* chains and this is EC and RSA, both classical. Used carefully it
   helps, because it is independent support for Frauenschläger's "already
   practically used": multi-algorithm serving is real practice, and the
   post-quantum version of it is what has not deployed.

   Caveats that must travel with it if it is ever cited: n is 27, no methodology is
   stated, and "observed algorithm set" is not defined as two configured chains.
   It is a conference slide, not a paper. Treat it as directional, never as a
   population estimate.
2. **Cite OpenSSL #32221 in the same paragraph that describes the failure mode,
   never in a footnote.** A reviewer who finds it afterward will assume we did
   not look.
3. **Never present the two-chain setup as novel, and never present OpenSSL's
   compliance as a discovery.** Frauenschläger and Mottok call multiple-chain
   deployment selected by `signature_algorithms_cert` "the simplest and already
   practically used approach", and name OpenSSL as already supporting it. Both
   points cite that chapter. The measurement is ours; the configuration and the
   OpenSSL result are not. Added 2026-08-12 on reading the full text.

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
conformance testing.

**Re-verified 2026-08-12 against the file itself**, fetched raw from
`tls-attacker/TLS-Anvil` on `main`. The claim holds and the wording here was
imprecise in two ways that a reviewer checking the file would have caught, so both
are fixed.

`TLS-Testsuite/annotations/out_of_scope/8446.txt` is 118 lines. The section 4.4.2.2
requirements marked out of scope sit at **lines 63, 65, 67, and 69**, not 65 to 71:

| line | requirement marked out of scope |
|---|---|
| 63 | certificate type MUST be X.509v3 |
| 65 | end-entity public key MUST be compatible with the selected algorithm from `signature_algorithms` |
| 67 | key MUST be usable for signing with a scheme indicated in `signature_algorithms`/`signature_algorithms_cert` |
| 69 | "All certificates provided by the server MUST be signed by a signature algorithm advertised by the client if it is able to provide such a chain" |

**Do not say "all four".** Section 4.4.2.2 has four bulleted rules plus three
normative paragraphs. Three of the four bullets are out of scope; the fourth, that
`server_name` and `certificate_authorities` guide certificate selection, is **not**
in the file. Four items are listed, they are not "all four" of anything, and the
count invites a correction that costs more than the precision does. Say instead:
TLS-Anvil marks the certificate-selection requirements out of scope, including the
one that matters most here, and quote line 69.

Line 69 is the one to lead with. It is the dual-chain MUST, and it is the exact
requirement this project measures.

Two more things in the same file, both worth knowing. Lines 71 and 73 also mark the
SHA-1 fallback constraint and the client's abort obligation out of scope. And the
sentence that carries the fallback permission this project now leans on, that a
server which "cannot produce a certificate chain" SHOULD continue by sending a chain
of its choice, **does not appear in the out-of-scope file at all**. Draw no
conclusion from that beyond its absence: it is not evidence that they test it.

The paper itself returned zero occurrences of `signature_algorithms`, "certificate
selection", and "quantum" on a full-text grep.

A citable admission from the incumbent is stronger than any number of empty
searches. Lead with it.

**The newest IETF Working Group chartered on post-quantum signature cost in Web
PKI does not take this up either. Added 2026-08-12, and the precision below is
deliberate.**

**IETF PLANTS WG**, "PKI, Logs, And Tree Signatures", active, group record
timestamped 2026-04-02. Chairs Russ Housley and Thom Wiggers, AD Deb Cooley.
The charter goal, verbatim from the datatracker group API:

> The goal of the PLANTS Working Group is to trim the costs of large post-quantum
> signatures on PKIs with Certificate Transparency (CT; RFC 6962 and RFC 9162),
> when used in interactive protocols like TLS (RFC 8446).

Its scope statement, also verbatim:

> The PLANTS Working Group's scope is to explore mechanisms for CAs and
> transparency ecosystems to certify key/identifier bindings in a publicly
> monitor-able way. Alternate trust models and changes to how TLS uses the
> end-entity key are not in scope for the Working Group.

**State this accurately or not at all.** That exclusion is about *changing* how
TLS uses the end-entity key. It is **not** a statement that server-side chain
selection is out of scope, and it must never be quoted as though it were. What is
defensible is the weaker and still useful reading: a working group chartered in
2026 specifically to reduce post-quantum signature cost in CT-based PKI with TLS
has deliverables about certifying bindings compactly, and **which chain a server
sends when it holds more than one is not among them**, neither as a deliverable
nor as a stated exclusion. It is simply not addressed.

That is a weaker claim than the TLS-Anvil annotation, which is an explicit
admission. Lead with TLS-Anvil and use this as support, not the reverse. The
2026-08-10 retraction in this repo happened by reading one measurement as a
statement about a whole library; quoting this charter as "PLANTS says chain
selection is out of scope" would be the same error in a new costume.

Milestones to re-check before Phase 6, because either could change this: an
informational architecture document due **2026-07-31**, already passed, and a
standards document due **2026-11-30**. The WG may also "define extensions to ACME
and TLS to integrate its certificate constructions", which is the clause most
likely to touch this project's subject if it ever does.

**No PQC readiness tool found so far checks this either, and one now names the
gap by omission.** Wiz's PQC readiness offering inventories by code scanning, IaC
and host configuration, cloud service inspection, and certificate and SSH key
parsing, and it publishes no limitations. It ships a separate PQC Tester that does
perform a live check, described as scanning "your domain ... to see if your server
supports PQC key exchanges". Key exchange, not certificates, and not which chain
is served. Reported, from the vendor page read 2026-08-12.

Be careful with this one too. It supports "the tooling measures key exchange
rather than chain behavior", which is a claim about published capability on a
given date. It does not support any statement about what their product detects
internally, and vendor pages go stale, so re-read it before publication rather
than citing this line.

### Why no scanner reports this: the request is visible and the response is not. Added 2026-08-12.

This is the mechanism behind every empty search in this file, and it is a better
answer to "why has nobody found this?" than any number of negative results.

**TLS 1.3 puts the client's constraint in the clear and encrypts the server's
answer.** Both halves come from RFC 8446, fetched and grepped on 2026-08-12 rather
than recalled:

- `signature_algorithms_cert` is a **ClientHello** extension. The extension table
  at RFC 8446 section 4.2 lists it as `signature_algorithms_cert (RFC 8446) | CH,
  CR`, and Figure 1 shows `ClientHello` with no braces around it.
- The **Certificate** message is encrypted. Figure 1 writes it `{Certificate*}`,
  the legend defines `{}` as "messages protected using keys derived from a
  [sender]_handshake_traffic_secret", and section 4.4 states it in prose:
  Certificate, CertificateVerify, and Finished "are encrypted under keys derived
  from the [sender]_handshake_traffic_secret."

So a passive on-path observer reads exactly which certificate algorithms the client
was willing to accept, and cannot read which chain came back. **The constraint is
observable and compliance with it is not.** The failure this project measures,
a server returning a chain the client excluded, is therefore invisible to passive
observation by construction.

**State the limits of that, because it is not "undetectable".** Three parties can
see it, and the claim must not imply otherwise:

1. **An active client**, which both sets the constraint and inspects what it
   receives. That is this project's method.
2. **Anyone holding the handshake keys**, including a TLS-terminating interception
   proxy or an endpoint agent. An enterprise doing TLS inspection could see this
   today.
3. **The server operator**, who could instrument which chain their own software
   selected.

What none of those is: a fleet-scale passive scan. That is why the DigiCert-style
survey and the passive-telemetry tooling both miss it, and why the population
argument in travelling sentence 1 above holds. It is also the honest reason nobody
has published this, and a far more respectful account of the field than implying
nobody thought to look.

**Stamps.** The RFC 8446 quotations and the extension-table row are Reported from
the RFC text. That an active client handshake does reveal the served chain is
Verified here, across five stacks. That this asymmetry is *why* the behavior went
unreported is **Proposed**: it is an argument from the mechanism, and no author has
said this is what stopped them.

Cross-reference: the same mechanism, developed for the inventory-tool case, is in
`pqc-cert-matrix` under "Why the parse-based path is structural rather than lazy".
Keep the two in step if either is edited.

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

**Status: READ IN FULL, 2026-08-12. The Phase 0 gate is closed.** Tobias
Frauenschläger sent a private author copy by email after the ResearchGate request
of 2026-08-10, and asked to see our results when they are ready. 20 pages, 8,183
words of extracted text.

**The copy is private and does not enter this repository, or any other.** It is
not committed, not redistributed, and not quoted at length in anything public. The
citation above is to the published DOI, which is what a reader can reach. Anything
public cites the DOI and paraphrases.

**The 2026-08-10 prediction held. This is a citation, not a preemption of the core
finding.** Verified against the full text rather than the abstract:

- The contributions are a TLS negotiation mechanism for dual algorithm
  certificates (C1), implementations of it (C2), and a performance evaluation
  (C3). A dual algorithm certificate carries both algorithms in one certificate,
  which is a different object from two separate chains.
- Implemented in **WolfSSL and OpenSSL only**, and evaluated on a
  resource-constrained microcontroller.
- **nginx, Caddy, rustls, and Envoy do not appear anywhere in the paper.** Four of
  the five stacks this project measures are absent, and so is any measurement of
  which chain a server sends when it holds two.
- Nothing in it addresses whether client preference order or server configuration
  order decides the chain.

**Two framing points are now preempted, and both must be demoted to Reported.**
This is the part that costs us something, so it is written down plainly:

1. **The setup is not novel.** Section 2.3 calls multiple-chain deployment "the
   simplest and already practically used approach", with the chain selected "based
   on the lists within the signature_algorithms and signature_algorithms_cert
   extensions". So this project measures a configuration that the literature
   already treats as established practice. It may not be presented as new.
2. **"OpenSSL honors signature_algorithms_cert" is prior art, and cites here.**
   Section 2.3 states that "Some TLS implementations already support this approach
   when provided with multiple chains (e. g., OpenSSL)." That is the OpenSSL half
   of this project's result, stated qualitatively and published before this
   project began. Cite it. (The chapter's PDF was typeset 2025-07-30 and appeared
   online 2026-05-01; this project started 2026-08-10.)

**What survives, and it is the larger half.** The paper's "Some" is doing
unmeasured work: it implies support is uneven, names no implementation that lacks
it, and measures nothing. Its only stated reason for uneven support is that "many
resource-constrained embedded devices do not support multiple chain handling",
which is a claim about embedded devices, not about mainstream server stacks. That
Caddy, rustls, and Envoy serve a chain the client excluded is not in this paper,
was not predicted by it, and is the opposite of what a reader would infer from
"e. g., OpenSSL" plus an embedded-device caveat. Measuring which stacks fail, and
that the failure is not confined to constrained devices, remains this project's
contribution.

**Two new references surfaced that this file has never assessed.** Both are cited
by Section 2.3 as the sources for "more detailed descriptions of the different
approaches", which is exactly the territory of this project:

- **[37] Scheible, P., "Quantum Resistant Authenticated Key Exchange for OPC UA
  using Hybrid X.509 Certificates", master's thesis, Universitat Politècnica de
  Catalunya, April 2020.** https://upcommons.upc.edu/handle/2117/191775
- **[26] Lytle, J., "Performance of Hybrid Signatures for Public Key
  Infrastructure Certificates", master's thesis, Naval Postgraduate School, June
  2021.** https://apps.dtic.mil/sti/citations/trecms/AD1204814

**Both read in full on 2026-08-12. Neither is a preemption, and this is now
Verified rather than judged from a title.**

- **Scheible, 155 pages, 40,154 words of extracted text.** Proposes two
  quantum-resistant variants of the OPC UA authenticated key establishment
  (Kyber plus RSA, with Falcon or Dilithium for signatures), implemented against
  open62541 and mbedTLS. **Zero occurrences of `signature_algorithms_cert`,
  "multiple chains", or "chain selection".** Only mbedTLS and OpenSSL are named;
  nginx, Caddy, rustls, and Envoy never appear. Its one overlapping passage is
  Section 3.1.1, a taxonomy of four hybrid X.509 designs whose "Dual
  Certificates" entry notes that systems "have to know when to use only a
  conventional certificate for legacy systems and when they have to use both."
  That is design-space analysis of a certificate format, not a measurement of
  what a server sends, and it is about OPC UA rather than TLS.
- **Lytle, 148 pages, 38,793 words.** Claims "the first test implementation of
  true hybrid signature algorithms", evaluated as standalone cryptographic
  operations and then integrated into X.509 and TLS 1.3 for performance. **Only
  OpenSSL (25 mentions) and liboqs (5) appear**; none of the other four stacks
  do. It does discuss `signature_algorithms` and `signature_algorithms_cert`, but
  strictly as RFC 8446 background on page 67: which message each extension
  governs, and that the server must abort if they are absent. It never addresses
  choosing between two configured chains.

Neither thesis measures more than one implementation, so neither touches the
"across more than one implementation" scope of the verbatim claim. Both were
downloaded and grepped rather than assessed from a search summary, which on this
pass mattered twice: DTIC serves 403 to non-browser clients on every path
tried, and the Lytle full text had to be reached through the NPS DSpace REST API
(handle 10945/72090, item 3b15b1b7-35bb-4eab-9154-6f1a9c34dd8b). A search
summary offered a confident description of its scope; it was not used.

Paul et al. and draft-yusef-tls-pqt-dual-certs, the two references from this
chapter that carried real preemption risk, are already assessed below.

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

**draft-yusef-tls-pqt-dual-certs-03**, 3 July 2026, expires 4 January 2027, by
Shekh-Yusef (Ciena), Reddy (Nokia), Tschofenig (UniBw M.), Ounsworth (Cryptic
Forest), and Rosomakho (Zscaler).
https://www.ietf.org/archive/id/draft-yusef-tls-pqt-dual-certs-03.txt

An individual submission, not working-group adopted. The filename says so: an
adopted draft would be `draft-ietf-tls-`. Four revisions exist, 00 through 03.

**Re-read at `-03` on 2026-08-11 by downloading the text and grepping it
locally.** The entry here previously described `-01` and was two revisions
stale. Read the current revision before citing this, because the mechanism
changed.

**What changed between `-01` and `-03`.** The `dual_signature_algorithms`
extension is gone. `-03` carries the negotiation in new SignatureScheme code
points inside the existing `signature_algorithms` extension instead (Section
5.1). The document also shrank from 58,381 to 44,974 bytes. The outcome is
unchanged: two independent certificates producing one `Certificate` and one
`CertificateVerify`, which remains adjacent to the Springer chapter without
being proven identical. The chapter is still UNREAD, and the belief that it uses
X.509 alternative key extensions rests on its abstract, not its text.

**`-03` makes `signature_algorithms_cert` load-bearing, which is why this
project matters to it.** Section 5.2:

> when either chain contains CA-issued certificates, the peer MUST advertise the
> acceptable certificate signature algorithms in signature_algorithms_cert

The authors note one limitation ten lines later, that the extension "cannot
enforce this, as it is a single list that does not distinguish the two chains".
They do not consider the possibility that an implementation ignores the
extension outright. This project's measurement says three of five stacks do
exactly that. **That is a gap in the design's deployability, not a preemption of
the measurement.**

**Verified, by grep on the downloaded `-03` text rather than a page summarizer:
it proposes and does not measure.** Occurrences of OpenSSL, nginx, rustls,
Envoy, BoringSSL, "measure", and "measured": zero for every one. It cites no
prior measurement study of certificate selection. This replaces the earlier
Reported-and-weakly-held assessment.

**Do not cite the `-01` appendix, even though it is tempting.** `-01` carried an
"Open Design Issues" appendix stating that `signature_algorithms_cert` is
"extremely rarely used in the wild" and that one design option has "bad
alignment with TLS implementations in the wild". Five vendors asserting this
project's premise without measuring it. `-03` deleted that appendix. Quoting a
withdrawn statement from a superseded revision to support our own framing is
exactly what an audit of this file should catch.

Five vendors built a new TLS authentication mechanism because phased migration
across mixed peers is hard. That is this project's premise arriving as support.

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
open and closed: no results for that exact string, which is weak evidence and
not proof. A broader search the same day DID find relevant rustls issues; see
the PREEMPTED section above before citing this negative.

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
