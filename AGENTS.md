# pqc-chain-selection — repo facts

Canonical per-repo context for agents (Claude Code).
Workspace map: ~/Workspace/AGENTS.md  |  Shared steering: ~/.rocky/steering/

- Stack: Go (probe client, forked `crypto/tls`), OpenSSL 3.5.5, Docker Compose
  (server harness), shell runners
- Remote: `github.com/DannyBCarrJr/pqc-chain-selection`, **PRIVATE**. Goes
  public at Phase 6, after the pre-publication audit.
- Branch: main
- License at flip: MIT, matching `pqc-cert-matrix` and `pqc-chain-budget`

## Read these before writing anything

1. **`PRIOR-ART.md` governs every public sentence.** The words "first", "only",
   and "no one has" are banned. The one defensible form is "we found no
   published X, searching [list] on [date]". That file has already demoted this
   project's framing once.
2. **`SCOPE.md`** carries the phase gates. Do not skip ahead. Phase 1 is the
   risk, so it runs before Phase 3 and Phase 4.
3. Sibling repos with the same evidence discipline: `pqc-cert-matrix` and
   `pqc-chain-budget`. Reuse `gen/` for chain minting and the Phase 3 key-log
   capture harness rather than rebuilding either.

## Standing rules for this repo

- **Every cell is a script plus captured output.** A claim without a runnable
  artifact does not ship.
- **Negative control on every passing cell.** Prove it can fail before believing
  it passed.
- **Redact the checkout path at collection time, not afterward.** The
  `pqc-cert-matrix` flip found the path in 25 places across 11 evidence files
  and in git history. Build the harness so Phase 6 has nothing to scrub.
- **Pin and record versions per cell**, including the exact OpenSSL, Go, rustls,
  and BoringSSL commits. OpenSSL #32028 is being actively worked and a fix would
  change measured behavior underneath us.
- Say "server software", never "production servers". There is no deployed
  dual-chain population to survey.
- No employer data, no vendor accounts, no work-laptop material. Open tooling
  only.
