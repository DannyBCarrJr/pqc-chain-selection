# Chain selection under dual-stack deployment, v1 scope

Drafted 2026-08-10. Status: **PHASE 0 IN PROGRESS.** Repo is private and stays
private until Phase 6. Prior art is seeded in `PRIOR-ART.md` and governs every
public sentence this project produces.

Sibling repos, same evidence discipline: `pqc-cert-matrix` (what clients do with
a chain they receive) and `pqc-chain-budget` (whether the chain fits). This one
asks whether the right chain is sent at all.

## The question v1 answers

When a TLS server is configured with both a classical and a post-quantum
certificate chain, does it serve the right one to each client?

The failure that matters is silent. The handshake completes, the client
validates, the page loads, and the server has been handing the classical chain
to post-quantum-capable clients for months. No monitoring signal distinguishes
that from a migration that worked. Configuration says done; the wire says
nothing happened.

Every cell in this matrix is a script plus captured output, or it does not ship.

## Phase 0. Prior art and go/no-go

Half a day. `PRIOR-ART.md` is seeded. Remaining work is the honest logging of
open items and one decision.

Deliverable: this file, `PRIOR-ART.md`, and a populated `AGENTS.md`.

**Gate:** does the claim survive what we already know? If the Springer chapter
(10.1007/978-3-032-16089-8_30) surfaces as a measurement rather than a mechanism
proposal, narrow the claim or stop here. Try author contact and institutional
repositories before treating it as unobtainable.

Model call: sonnet + medium. This is transcription of a sweep already run.

## Phase 1. The probe client

**Revised down on 2026-08-10 from one to two weekends to roughly one evening,
after reading the installed Go source.** See the CORRECTED section in
`PRIOR-ART.md`. Still the critical path, still runs first, but the risk is much
smaller than the sweep implied.

The instrument has to emit `signature_algorithms` and `signature_algorithms_cert`
independently. OpenSSL never sends the second one, so `s_client` cannot be the
probe, and OpenSSL #32028 records that there is no way to exercise these
combinations from the command line tools.

**Do not hand-roll a ClientHello.** In TLS 1.3 the `Certificate` message is
encrypted under handshake keys, so a raw socket buys nothing without a full key
schedule.

Primary route: patch Go `crypto/tls`. **Go 1.26 already emits the extension**
(`handshake_client.go:123`); what it lacks is any way to set the contents, which
come from the package-level `supportedSignatureAlgorithmsCert()` at
`common.go:1798`. Make that list settable, and `ConnectionState.PeerCertificates`
returns the served chain with no packet capture at all.

**A stock Go client is already a partial probe.** Because Go always sends the
extension, a plain Go client exercises OpenSSL's `check_cert_usable()` path that
an OpenSSL client cannot reach. Use that as the smoke test before patching
anything.

Fallback and cross-check: patch the OpenSSL construct callback for the
extension, which the source read shows is NULL by design with a comment saying
so, then decrypt with `SSLKEYLOGFILE` and tshark. That path reuses the capture
harness already built for `pqc-cert-matrix` Phase 3, so it costs less than it
looks. Build both if the Go route lands quickly: two independent probes guard
against the probe itself being the bug, which is the same instinct behind the
negative controls in Phase 4.

**Validation before anything post-quantum happens.** Point the probe at a
classical dual-certificate server, RSA plus ECDSA, which is a long-solved
configuration, and confirm that changing the extension flips which chain comes
back. A probe that cannot reproduce the classical case cannot measure the
quantum one.

Deliverable: `probe/`, with the classical control run captured as evidence.

**Smoke test PASSED 2026-08-10** (`probe/smoke/FINDINGS.md`). Verified on the
wire that a stock Go 1.26 client sends extension 50 at 26 bytes, that OpenSSL
labels it "unknown" because it has no name for an extension it never generates,
and that the probe reads the served chain from
`ConnectionState.PeerCertificates` with verification on against a real root
pool. The remaining Phase 1 work is the patch that makes
`supportedSignatureAlgorithmsCert()` settable.

**GATE MET 2026-08-10** (`probe/tlspatch/FINDINGS.md`). Built via
`go build -overlay`, two inserted lines in `common.go` plus one added file, no
fork and no vendored Go source. Three cells measured server-side: stock sends
extension 50 at 26 bytes, `0x0403,0x0804` shrinks it to 6, and `none` suppresses
it. The restricted set excludes the RSA leaf's own `0x0401`, and **OpenSSL
switched to the ECDSA chain**, so the probe demonstrably changes server
behavior on the classical control.

That last cell is also the first real finding. OpenSSL's chain check is live and
correct when the client sends the extension, so the "dead code" reading holds
only against clients that never populate it. Whether a server enforces the check
is a property of the client talking to it. `PRIOR-ART.md` now carries that as
measurement rather than inference.

**Phase 1 is closed.** Phases 2, 3, and 4 followed on 2026-08-10: four chain
shapes minted, four stacks measured, results in `MATRIX.md`. The check does
survive depth and a production wrapper (nginx matches its library exactly), and
it is absent in both non-OpenSSL stacks. Remaining: Envoy, negative controls,
repeat runs, and the prior-art re-sweep.

Model call: opus + high.

## Phase 2. Chain minting

Half a weekend, and it runs parallel with Phase 1 because nothing couples them.
Reuse `gen/` from `pqc-cert-matrix`.

Five shapes:

1. classical only (control)
2. pure ML-DSA leaf, intermediate, and root
3. ML-DSA leaf under a classical intermediate (mixed)
4. classical leaf under an ML-DSA intermediate (mixed, reverse)
5. both full chains configured at once (the actual dual-stack case)

Pin every version. Record the minting toolchain per chain.

**Gate:** every chain validates under a permissive verifier before it is used,
so that any later failure is selection rather than a malformed chain.

Model call: sonnet + medium. Mechanical, and the machinery exists.

## Phase 3. Server harness

One weekend. Four distinct TLS stacks, not seven servers, because httpd and
HAProxy are both OpenSSL and answer a different question.

| Column | Stack | Why it is here |
|---|---|---|
| nginx | OpenSSL 3.5 | Largest install base, chain check unreachable per source |
| Caddy | Go `crypto/tls` | Documents that it does not check chain algorithms |
| Envoy | BoringSSL | Selects first usable credential, so config order decides |
| rustls proxy | rustls | **The unknown.** Selection path never traced |
| `openssl s_server` | OpenSSL | Control, and the path #32221 already broke |

The first real finding probably lands here rather than in Phase 4. OpenSSL holds
at most one certificate per key type, so some dual configurations may be
impossible to express. That is a result. Write it down when it happens rather
than after.

**Gate:** every server serves the classical control correctly before anything
interesting is attempted.

Model call: sonnet + medium, escalating when a configuration refuses and the
reason matters.

## Phase 4. Run the matrix

One weekend. Every cell captures the decoded ClientHello, which chain came back,
whether the client would have accepted it, and a verdict of `correct`,
`wrong-chain-silent`, `abort`, or `no-selection-attempted`.

Negative control on every passing cell, following the composite precedent in
`pqc-cert-matrix`: prove a cell can fail before believing that it passed.

**Order the runs by information value.** rustls and the mixed chains first,
because that is where the unknowns are. The OpenSSL and Go cells will confirm
what their own source already says. Confirming documented behavior is worth
doing and it is not worth doing first.

Deliverable: `MATRIX.md`, `results/`, and `runners/`.

Model call: sonnet + medium for the runs, opus + high to interpret anything
surprising.

## Phase 5. Isolate anything surprising

Variable, and triggered only by a cell that produces a causal claim.

Replicate against a second implementation and decode the wire before the claim
is publishable. This is the schannel precedent from `pqc-cert-matrix`: the
causal claim did not ship until it reproduced against a second server and the
decoded ClientHello showed the missing signature scheme.

Deliverable: `isolation/FINDINGS.md`.

Model call: opus + xhigh. Adversarial verification of something publishable.

## Phase 6. Public flip

**Pre-publication audit runs first.** The `pqc-cert-matrix` flip found the
checkout path baked into 25 places across 11 evidence files and into git
history. The fix was redaction at collection time. Build the harness that way
from Phase 4 onward so this phase has nothing to scrub.

Then MIT, `CITATION.cff`, Zenodo DOI, `README.md`, upstream issues against
whichever stacks get it wrong, and the article.

**Write the article after the matrix is populated.** With `pqc-cert-matrix` the
article published first and converted a later phase from an option into a
commitment. It worked out. It also left a public promise outstanding while
measurements were still open. Do not repeat that here, or at least keep the
promise out of the text.

Model call: opus + high for the article, sonnet + low for packaging.

## The cut

**Lean v1** is the four stacks above and the five chain shapes above.

**Stretch:** httpd and HAProxy columns, which test whether a wrapper changes its
library's behavior. That is a real question and it is a second one. More chain
shapes only if Phase 4 produces a reason.

## Exits

Three places to stop cheaply, each leaving something usable behind.

- After Phase 0: a prior-art file that is worth having regardless.
- After Phase 1: a probe client that fills the gap an OpenSSL committer named on
  2026-07-21.
- After Phase 3: a reproducible dual-chain harness across four TLS stacks.

## Honest expectation

Three of the five columns are predictable from source already read, so
confirming them is replication rather than discovery. Two cells are genuinely
open: rustls, and the mixed chains across all stacks. If a surprise exists, it
is there.

The contribution is assembly. Five scattered source comments, two open bug
reports, and one vendor document do not help an operator who cannot read five
codebases. One table does, and TLS-Anvil declined the job in writing.
