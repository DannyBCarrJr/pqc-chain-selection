# Pre-publication audit, Phase 6

Run 2026-08-12, before any visibility change. `SCOPE.md` Phase 6 requires this
first, because the `pqc-cert-matrix` flip found the build machine's checkout path
baked into 25 places across 11 evidence files **and into git history**, where
fixing the working tree does not fix it.

**Result: clean. No redaction required.** Recorded here so the next repo's audit
starts from a checklist that has actually been run rather than from memory.

## What was scanned

Both the working tree and **all 25 commits reachable from every ref**. Working-tree
grep alone would have passed the cert-matrix flip too, which is the whole lesson.

**The literal search strings are deliberately not written out below, and that is
not squeamishness.** An earlier draft of this table spelled them, which would have
published the build machine's checkout path and a handle that is kept separate
from this author's name, inside the very file certifying they do not appear. The
audit artifact would have become the leak. Categories only; the exact patterns
live in `~/.rocky` on the build machine.

| category scanned | working tree | all history |
|---|---|---|
| build-machine home directory path, specific and generic | 0 | 0 |
| build-machine account name, any case | 0 | 0 |
| the author's separate online handle | 0 | 0 |
| WSL host mount prefixes | 0 | 0 |
| employer names, past and present | 0 | 0 |
| PEM private key headers, all key types | 0 | 0 |
| AI co-author trailers and generation markers | 0 | 0 |
| RFC 1918 addresses | 0 | 0 |

Commit authorship across all history is a single identity, `Danny B. Carr Jr.`,
the same public identity as the other public repos. Nothing to change, but note
it is permanent once the repo is public.

`git ls-files` tracks 99 files, largest 52K (`s_server` evidence captures).
`.gitignore` covers `*.pem` and `*.key`, and **no key material is tracked**;
generators recreate it.

## Two hits investigated and cleared, written down so they are not re-investigated

1. **The employer-name scan matched once**, in `PRIOR-ART.md`, on the word
   "charter" capitalised at the start of a sentence describing the IETF PLANTS
   working group's charter. A collision with an ordinary English word, not a
   reference to any employer. The sentence was reworded so the word falls
   mid-sentence and stays lowercase, because **an audit grep that reliably hits a
   legitimate word trains the reader to wave the hit through**, which is worse
   than the false positive itself.

   Deliberately not spelling the name here either. This file ships publicly, and
   a public repo containing the string inside a sentence explaining that it is
   not a reference is still a public repo containing the string. The rule is zero
   occurrences, not zero unexplained occurrences.
2. **An email-shaped match** in
   `runners/evidence/s_server/both-cert-pq-only.server.txt`. It is an `@`
   character inside the ASCII column of a hexdump of TLS wire bytes. Not an
   address.

## Two accepted, and why

- **`~/Workspace/AGENTS.md` and `~/.rocky/steering/`** appear in `README.md` and
  `AGENTS.md`. These are tilde-relative, so they leak no username, and the
  identical two lines are already public in `pqc-cert-matrix`,
  `pqc-chain-budget`, and `post-quantum-measured-lab`. Changing this repo alone
  would create inconsistency across four repos to no benefit. Either it is fine
  in all four or it should be fixed in all four, and that is a separate decision.
- **The harness redacted correctly at collection time.** Zero absolute paths in
  99 files is the direct result of `SCOPE.md` requiring redaction from Phase 4
  onward, after cert-matrix. The instruction worked, and this table is the
  evidence.

## Still open before the flip

The audit is the gate this file closes. These remain, per `SCOPE.md` Phase 6:

- [x] Pre-publication audit
- [x] MIT `LICENSE`
- [x] `CITATION.cff`, with DOI, url, version, and date deliberately absent until
      the release exists. A placeholder DOI is a fabricated identifier.
- [x] `README.md` rewritten to past tense with the findings, 2026-08-12. The old
      version also promised a `results/` directory that was never built, and
      omitted the byte counts, the rustls root cause, and every scope limit. Style
      and claim checks run against it: zero em or en dashes, zero curly quotes,
      zero banned vocabulary, and the surviving instances of "first" and "only" are
      a novelty disclaimer, a credit to prior work, and three uses meaning "sole".
- [ ] **Zenodo DOI. Order matters here and getting it wrong costs a release.
      Confirmed 2026-08-12 from Danny's Zenodo account: the enabled-repository list
      is `DannyBCarrJr`, `Etergis-Docs`, `post-quantum-measured-lab`,
      `pqc-cert-matrix`, and `pqc-chain-budget`. `pqc-chain-selection` is NOT
      enabled**, which is expected, since Zenodo's GitHub integration only lists
      repositories it can see and this one is private.

      Zenodo archives releases created **after** a repository is switched on. It
      does not backfill. So the sequence is:

      1. Flip the repo public.
      2. Refresh the repository list in Zenodo and enable `pqc-chain-selection`.
      3. **Then** create the first GitHub release.

      Cut the release before step 2 and no DOI is minted, no archive is made, and
      the only repair is tagging a second release, which leaves a v1.0.0 in the
      history that is permanently uncited. Both sibling public repos went through
      this and both carry concept plus version DOIs, so the pattern to match is
      already established.

      After the DOI exists, fill in `CITATION.cff`: `doi`, the two `identifiers`
      (concept and version), `version`, and `date-released`. They are deliberately
      absent right now because a placeholder DOI is a fabricated identifier.
- [ ] Upstream reports. **`SCOPE.md` calls these "upstream issues against
      whichever stacks get it wrong", and that wording is now wrong.** `MATRIX.md`
      and `runners/FINDINGS-rustls.md` both establish that Caddy, rustls, and Envoy
      are conformant: RFC 8446 section 4.4.2.2 makes the constraint a SHOULD, and
      its fallback clause tells a server with no acceptable chain to send one
      anyway. Filing bug reports against conformant behavior would be wrong and
      would get the whole result dismissed. What is left is narrower and still
      worth doing:
      - **rustls, a feature request rather than a bug. Drafted 2026-08-12.
        Decision: post it AFTER the repo is public and the DOI exists, not before.**
        Danny delegated the call, so the reasoning is recorded.

        The draft's weakest sentence is the one offering to share evidence from "a
        repository I am preparing to publish". Posted before publication, the issue
        asserts a measurement nobody can check, which is the one thing this project's
        whole discipline is built against. Posted after, the same issue links a
        DOI-bearing archive, and the strongest claim in it becomes verifiable in one
        click.

        There is also a reason that serves Danny's stated goal directly. An issue on
        a widely-read repository that cites a DOI is a durable attribution path back
        to the work. Filed early it is a question; filed with the archive attached it
        is a citation. There is no priority race to lose by waiting, because the
        source-reading half is discoverable by anyone who opens
        `server_conn.rs`, and `PRIOR-ART.md` claims no novelty for it anyway.

        Two edits to make before it goes out, both noted in the draft: replace the
        "preparing to publish" paragraph with the repository and DOI links, and keep
        the offer of a patch only if Danny intends to write one.
        `signature_algorithms_cert` is not among the eight fields
        `ResolvesServerCert::resolve` receives, so a custom resolver cannot
        implement the check even when the operator wants it.

        **Re-verified against the source, not the 2026-08-10 reading.** Fetched
        `rustls/src/server/server_conn.rs` at tag `v/0.23.43` on 2026-08-12: the
        `ClientHello` struct at line 139 has exactly eight fields with eight
        matching public accessors, and none is `signature_algorithms_cert`.
        `signature_schemes` is `signature_algorithms`, which governs the handshake
        signature only. Also confirmed `0.23.43` is still the newest stable release
        on crates.io, so the finding is against current code rather than a stale
        version.

        **The strongest argument found while verifying:** `certificate_authorities`
        *is* exposed on `ClientHello`, with a doc comment linking RFC 8446 section
        4.2.4. That extension exists solely to guide server certificate selection,
        so rustls already surfaces one selection extension by deliberate design.
        `signature_algorithms_cert` is the other extension doing that job. Their own
        source argues for the change, which is a far better opening than a
        measurement does.
      - **Go `crypto/tls`, optional and lower priority.** The check is declined by a
        source comment citing the SHOULD, so it is a documented decision. Any ask
        belongs upstream in Go, not in Caddy.
      - **Envoy, nothing to file.** Its dual-chain behavior is unresolved, and a
        report resting on a withdrawn result would be indefensible.
- [ ] The article, which `SCOPE.md` requires be written **after** the matrix is
      populated, not before. cert-matrix published the article first and turned a
      later phase into a commitment; do not repeat that.
- [x] **Envoy: decided 2026-08-12. v1 ships with the hole documented.** Danny
      delegated the call; the reasoning is recorded here so it can be argued with
      later.

      Four reasons, in order of weight:

      1. **The headline result does not depend on it.** The deciding cell is a
         single configured chain the client excluded, and Envoy is measured there:
         it served the excluded chain, through the full runner, on both cells,
         reproduced. What is withdrawn is only the dual-chain and config-order
         behaviour. Losing that costs one column of a secondary question, not the
         finding.
      2. **The withdrawal is an asset, not a blemish.** `MATRIX.md` records that
         two of the diagnostic harnesses used to investigate were themselves
         defective, one printing a pass while `docker run` never executed, and
         refuses to claim anything from them. A repo that shows its own retractions
         is more credible than one that shows none, and this project already
         retracted three claims by self-audit on 2026-08-10. Publishing that
         discipline is part of the contribution.
      3. **It is a second project, and `MATRIX.md` says so.** The clean way to
         settle it is a purpose-built BoringSSL server with ML-DSA support, not more
         Envoy YAML. That is a build, not an afternoon, and bundling it converts a
         finished v1 into an open-ended one.
      4. **The framing has a shelf life.** Cloudflare is serving MTC in production,
         Google Trust Services is scheduled for 2028, Let's Encrypt targets 2027,
         and the PLANTS standards document is due 2026-11-30. The drop-in-versus-MTC
         context this work speaks into is moving. Publishing a complete v1 with one
         documented hole beats publishing a marginally more complete v2 later.

      **What this obliges.** The gap is named in `README.md` under "What this is
      not", in `MATRIX.md` with the reason, and in `CITATION.cff`'s abstract. Do not
      soften any of the three. The BoringSSL harness becomes the natural v1.1, which
      is also a reason to publish twice rather than once.
