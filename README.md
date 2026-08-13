# pqc-chain-selection

Measured behavior of TLS server software choosing between a classical and a
post-quantum certificate chain when both are configured.

**Status: pre-publication, Phase 6.** The matrix is populated across five server
stacks and re-run from a clean build; Phases 1 through 5 are done. **Phase 0's
prior-art gate closed on 2026-08-12**, when the Springer chapter that could have
stopped this project (10.1007/978-3-032-16089-8_30) was read in full and turned
out to propose a mechanism rather than measure chain selection. It cost two
framing claims, which are recorded in `PRIOR-ART.md`.

Still private, and the remaining gate is the pre-publication audit rather than
any measurement. See `SCOPE.md` for the phases and `PRIOR-ART.md` for what this
project may and may not claim.

> This line read "Phase 0" until 2026-08-12, which was defensible while the
> prior-art gate could still have killed the project and wrong the moment it
> closed. A status line that lags the work is how a repo ends up published on a
> claim nobody rechecked.

## The question

When a server holds both chains, does it serve the right one to each client?

The failure that matters is silent. The handshake completes, the client
validates, the page loads, and the server has been handing the classical chain
to post-quantum-capable clients for months. No monitoring signal separates that
from a migration that worked.

## What this will contain

- `probe/`: a TLS client that emits `signature_algorithms` and
  `signature_algorithms_cert` independently, which stock tooling cannot do
- `gen/`: the five chain shapes, minted and pinned
- `runners/`: one per server stack
- `results/`: captured output, one directory per cell
- `MATRIX.md`: the table

## What it is not

Not a scan of the deployed web. Dubey and Varshney (arXiv:2606.16473) found 0%
hybrid post-quantum certificate adoption across 32,011 domains in 2026, so there
is no fleet to survey. This measures server software on a bench.

Not complete on Envoy. Envoy appears on the single-chain cells only. Whether it
can hold a classical and a post-quantum chain at the same time went unresolved
when two of the diagnostic harnesses used to answer it turned out to be buggy,
and v1 claims nothing about it in either direction. Settling that takes a
BoringSSL harness, not more YAML.

Part of Carr Digital LLC. Workspace map: ~/Workspace/AGENTS.md
