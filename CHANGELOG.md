# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For a measurement corpus, a breaking change is one that would alter a published
number or retract a claim. Those are recorded here as prominently as additions.

## [1.0.0] - 2026-08-13

First public release. Measured behaviour of TLS 1.3 server software choosing which
certificate chain to send when the client constrains acceptable certificate signature
algorithms.

### Added

- **Probe client** (`probe/`) on a forked Go `crypto/tls`, emitting
  `signature_algorithms` and `signature_algorithms_cert` independently. Stock
  tooling cannot vary the two separately, which is why the client is purpose-built.
- **Chain generation** (`gen/`) for the measured chain shapes, minted and pinned.
- **Server harnesses** (`runners/`) for five stacks: `openssl s_server`, nginx,
  Caddy, rustls across three provider builds, and Envoy. One harness per stack, each
  cell producing a script plus captured output under `runners/evidence/`.
- **`MATRIX.md`**, the results table with the exact version of every stack recorded
  per cell rather than assumed.
- **Per-column findings** in `runners/FINDINGS.md`, `FINDINGS-controls.md`,
  `FINDINGS-mixed.md`, and `FINDINGS-rustls.md`, each claim stamped Verified where
  measured here or Reported where cited.
- **`runners/selfcheck.sh`**, a gate on the suite. Passed 12 of 12 on the clean
  re-run recorded in `runners/RERUN-2026-08-10.md`.
- **`PRIOR-ART.md`**, which governs every published claim and records, per claim,
  what existing work already covers.
- **`PREPUBLICATION-AUDIT.md`**, the leak scan run across the working tree and all
  commit history before this repository changed visibility.
- **`SCOPE.md`**, the phase gates the project was built against.

### Measured

- With one configured chain that the client excluded, `openssl s_server` and nginx
  refuse with `handshake_failure`; Caddy, rustls, and Envoy serve it and the
  handshake completes. All five outcomes are conformant with RFC 8446 section
  4.4.2.2. See `MATRIX.md`.
- The rustls result reproduces across three provider builds, so it is not specific
  to one cryptographic provider. See `runners/FINDINGS-rustls.md`.
- On OpenSSL, the client's advertised preference decides which chain is served and
  the server's configuration order does not. See `runners/FINDINGS-controls.md`.

### Known limitations

- **Envoy's dual-chain behaviour is unresolved and withdrawn.** Envoy appears on the
  single-chain cells only. The runner and ad-hoc probes disagreed, and two of the
  harnesses used to investigate were themselves defective. Nothing is claimed in
  either direction. Reasoning in `MATRIX.md`.
- **Apache httpd and HAProxy are untested.** Both wrap OpenSSL and answer a separate
  question about whether a wrapper overrides its library.
- **This is a bench measurement of server software, not a survey of deployed sites.**
  See `README.md` under "What this is not".

### Retracted before release

- Three claims were withdrawn by self-audit on 2026-08-10 after measuring a single
  configuration and describing it as a property of the library. Recorded in
  `PRIOR-ART.md` so the correction travels with the corpus.
- Two framing points are cited to prior work rather than claimed here: that
  multiple-chain deployment selected by `signature_algorithms_cert` is established
  practice, and that OpenSSL already supports it. Both cite Frauenschläger and
  Mottok. See `PRIOR-ART.md`.

[1.0.0]: https://github.com/DannyBCarrJr/pqc-chain-selection/releases/tag/v1.0.0
