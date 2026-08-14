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

## Verified facts, mapped to the template

Filed as a feature request against `rustls/rustls`, before the article publishes rather
than after. The article names rustls behaviour, and telling the project first is the
courteous order even though nothing here is a vulnerability.

Suggested title: **Expose `signature_algorithms_cert` to `ResolvesServerCert::resolve`**

**These are facts and source pointers, laid out under the headings they belong to. They are
not sentences to paste.** The AI policy at the top of this file is the reason, and bullets
are the safer form: a paste-ready paragraph is a trap when the project can hide the comment
without notice. Write each section in your own words from the material under it.

The live template, fetched from `rustls/rustls` on 2026-08-13, is a one-item checklist plus
four bold headings. Verify it again if this sits for a while.

---

### Checklist: `I've searched the issue tracker for similar requests`

Tickable honestly. See the tracker search above: no prior request exists for exposing this
extension, and the one string match (#2420) is unrelated.

### Is your feature request related to a problem? Please describe.

Lead with the operator scenario. In both precedent threads a maintainer's first move was
asking what you concretely want to do, so answer it before anything else.

- An operator holds a classical chain and a post-quantum chain during a migration, serving
  both from one rustls server on **one hostname**.
- Some clients cannot validate post-quantum signatures on certificates and say so, in
  `signature_algorithms_cert`.
- A rustls resolver has no way to see that, so it cannot send those clients the classical
  chain. The two chains are indistinguishable from inside `resolve`.
- The mechanism: `ResolvesServerCert::resolve` receives a `ClientHello` that carries eight
  fields, at `rustls/src/server/server_conn.rs:139`, tag `v/0.23.43`:
  `server_name`, `signature_schemes`, `alpn`, `server_cert_types`, `client_cert_types`,
  `cipher_suites`, `certificate_authorities`, `named_groups`. Eight matching accessors.
  `signature_algorithms_cert` is not among them, in the release or on dev HEAD.
- `signature_schemes` is `signature_algorithms`, which constrains the **handshake**
  signature. There is no equivalent for signatures **on the chain**. Those are different
  questions and a migration puts them in opposition.

**Say plainly that this is not a bug report.** RFC 8446 section 4.4.2.2 makes the
chain-signature constraint a SHOULD, and where a server cannot produce a conforming chain
it says the server SHOULD "continue the handshake by sending the client a certificate chain
of its choice". rustls is conformant. Saying so first is what keeps this a feature request
instead of an argument.

### Describe the solution you'd like

Narrow it here, before anyone narrows it for you. That single move is what turned #2235
from a pushback into an approval.

- A `signature_algorithms_cert` accessor on `ClientHello`, populated when the extension is
  present.
- **No change to any rustls default.** Not proposing rustls enforce the constraint, and not
  proposing it send the extension as a client. Expose it to custom resolvers, nothing more.
- `None` when the extension is absent has to mean **"fall back to `signature_schemes`"**,
  not "no constraint". RFC 8446 section 4.2.3 permits omitting the extension when it would
  duplicate `signature_algorithms`. Worth documenting on the accessor, and saying it here
  pre-empts the complexity caution `ctz` raised on #2484.

### Describe alternatives you've considered

The section the earlier draft of this file skipped entirely. Each of these is a real
alternative that was tried or reasoned through, and each fails for a stated reason.

- **`ResolvesServerCertUsingSni`.** Selects on hostname. A dual-stack migration serves both
  chains on the same hostname, so SNI cannot express the distinction. `SingleCertAndKey`
  selects on nothing: its `resolve` takes `_client_hello` and returns the one key.
  (`server/handy.rs:210` and `crypto/signer.rs:124`.)
- **A custom resolver selecting on `signature_schemes` alone.** That is the leaf **key**
  type, not the signatures on the chain. Measured: a chain with an EC leaf key under an
  ML-DSA-44-signed intermediate looks acceptable on `signature_schemes` and is exactly the
  chain the client excluded.
- **Waiting for post-quantum support to mature in rustls.** Does not close this. Measured
  on `rustls-post-quantum` 0.2.4 with `aws-lc-rs-unstable`, where the resolver correctly
  reports `signature_schemes = [ML_DSA_44]` and serves an ML-DSA chain, and there is still
  no accessor. The gap is independent of post-quantum maturity.
- **Terminating TLS on OpenSSL or nginx instead.** Works, since both honour the extension,
  and it means not using rustls for the job. Worth naming rather than hiding.
- **Having rustls enforce the constraint by default.** Explicitly not the ask. It changes
  behaviour for everyone and sits further from the fallback clause than today's behaviour
  does.

### Additional context

The measurement, and the `certificate_authorities` precedent. That precedent is the
strongest sentence available: it is their own design decision, in their own source,
arguing for the change.

- **`certificate_authorities` is already on `ClientHello`**, with a doc comment linking RFC
  8446 section 4.2.4, and on dev HEAD it has a deliberate carve-out hiding it from the
  resolver on TLS 1.2 per the RFC. It exists for one purpose, guiding server certificate
  selection. `signature_algorithms_cert` is the other extension in that same job, and it is
  the one a post-quantum migration turns on.
- **What was measured.** One configured chain, EC leaf key under an ML-DSA-44-signed
  intermediate. Client advertising `ecdsa_secp256r1_sha256` (0x0403) in both
  `signature_algorithms` and `signature_algorithms_cert`. rustls serves that chain.
- **Reproduced on three builds of `v/0.23.43`**: `ring`, default `aws_lc_rs`, and
  `rustls-post-quantum` 0.2.4 with `aws-lc-rs-unstable`. Not provider-specific.
- **Cross-stack, same cell.** `openssl s_server` 3.5.5 and nginx 1.31.3 refuse with
  `handshake_failure`. Caddy and Envoy serve it, as rustls does. That is a different
  reading of the same SHOULD, not a more correct one, and the issue should say so.
- **Evidence.** https://github.com/DannyBCarrJr/pqc-chain-selection, archived at
  https://doi.org/10.5281/zenodo.21911032. The rustls column is
  `runners/FINDINGS-rustls.md`. Every cell ships the script that produced it beside the
  output.
- **The offer.** Testing a change against the existing harness is deliverable today. Add
  the PR offer in one sentence only if the intent is real: #2235 landed because the
  requester said "I'll work on the PR then."

## FILED

**rustls/rustls#3214, "Expose signature_algorithms_cert to ResolvesServerCert::resolve",
opened 2026-08-13 by `DannyBCarrJr`, state OPEN.**
https://github.com/rustls/rustls/issues/3214

Written by Danny in his own words, per the AI policy at the top of this file. Every version
string, field name, RFC section, code point, and path in it was checked against this
repository before posting.

**The article gate is now open.** `docs/article-draft.md` may move into
`carr-digital/src/pages/writing/`, and it names rustls behaviour, so the courteous order has
been kept.

Watch the thread. Both precedents opened with a maintainer asking what the concrete use
case is (#2484) or pushing back on practicality (#2235), and #2235 turned on the requester
narrowing the ask in their next comment. That narrowing is already in the issue body here,
so the likelier first move is a question about the use case.

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
