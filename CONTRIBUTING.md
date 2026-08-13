# Contributing

This is a measurement corpus, so the bar is different from a library. A patch that
adds a feature is easy to review. A patch that adds a *claim* has to arrive with the
thing that proves it.

Read `PRIOR-ART.md` before you write a sentence that will be published. It records,
per claim, what existing work already covers, and it has demoted this project's
framing more than once.

## The rules I hold myself to

**Every cell is a script plus captured output.** A claim without a runnable artifact
does not ship. If you cannot point at the command and the bytes it produced, it is an
opinion.

**Every passing cell gets a negative control.** Prove the check can fail before
believing it passed. Two harnesses in this repo once reported a pass while the
container never started, so this rule is not theoretical.

**Pin and record versions per cell.** The exact OpenSSL, Go, rustls, and BoringSSL
builds, in `MATRIX.md`, per cell rather than once at the top. OpenSSL #32028 is being
actively worked, and a fix would move measured behaviour underneath a number that
looks stable.

**Redact absolute paths at collection time, not afterward.** Scrubbing a corpus later
means scrubbing git history too, which is a different and worse job.

**Say "server software", never "production servers".** These measurements come from a
bench. Nothing here surveys deployed sites, and the wording should never imply
otherwise.

**Stamp every claim.** Verified means measured here, with the code and output shipping
alongside it. Reported means cited to a primary source someone actually opened.
Proposed means designed or reasoned, and not measured. Blurring the three is how a
corpus loses its value.

**Open tooling only.** No vendor accounts and no proprietary products, which is what
keeps every cell reproducible by a stranger.

## Words that do not appear here

"First", "only", and "no one has". The defensible form is narrower and it is the one
this project uses: we found no published X, searching a named list of sources, on a
stated date. If a claim needs a superlative to be interesting, it is not ready.

## Corrections

If a number here is wrong, open an issue with the command that shows it. Corrections
are recorded in `PRIOR-ART.md` and `CHANGELOG.md` rather than quietly edited, because
a corpus that hides its retractions is worth less than one that publishes them. Three
claims were withdrawn from this project by self-audit before it was released, and
those are in the record on purpose.

## Repository facts

- **Stack:** Go for the probe client, on a forked `crypto/tls` so the two signature
  algorithm extensions can be set independently. OpenSSL 3.5.5, Docker Compose for
  the server harness, and shell runners.
- **Branch:** `main`.
- **License:** MIT.
- **Reproducing:** `gen/mint-chains.sh && probe/tlspatch/build.sh && runners/s_server.sh`,
  with `runners/selfcheck.sh` as the gate on the suite.
