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
- [ ] Zenodo DOI, which requires the first GitHub release
- [ ] Upstream reports. **`SCOPE.md` calls these "upstream issues against
      whichever stacks get it wrong", and that wording is now wrong.** `MATRIX.md`
      and `runners/FINDINGS-rustls.md` both establish that Caddy, rustls, and Envoy
      are conformant: RFC 8446 section 4.4.2.2 makes the constraint a SHOULD, and
      its fallback clause tells a server with no acceptable chain to send one
      anyway. Filing bug reports against conformant behavior would be wrong and
      would get the whole result dismissed. What is left is narrower and still
      worth doing:
      - **rustls, a feature request rather than a bug. Drafted 2026-08-12, awaiting
        Danny's approval before posting to a third-party repo.**
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
- [ ] Envoy's dual-chain cell is UNRESOLVED and stays that way. Decide whether v1
      ships with that hole documented, which `MATRIX.md` already does honestly, or
      whether it is settled first. `MATRIX.md` argues the clean fix is a small
      purpose-built BoringSSL server rather than more Envoy debugging.
