# pqc-chain-selection

Measured behavior of TLS server software choosing between a classical and a
post-quantum certificate chain when both are configured.

**Status: pre-publication, Phase 0.** Private until the matrix is populated and
the pre-publication audit has run. See `SCOPE.md` for phases and `PRIOR-ART.md`
for what this project may and may not claim.

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

Part of Carr Digital LLC. Workspace map: ~/Workspace/AGENTS.md
