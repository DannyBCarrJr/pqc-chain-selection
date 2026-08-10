# Phase 1 gate findings

Run 2026-08-10. OpenSSL 3.5.5 (27 Jan 2026), go1.26.0 linux/amd64.
Reproduce: `./build.sh && ./verify.sh`. Evidence in `evidence/`.

**Stamp: Verified.** Every line below is captured output from this machine.
Extension observations are read from the SERVER side, so they are what went on
the wire rather than what the client believes it sent.

## The gate

| cell | `PROBE_SIGALGS_CERT` | extension 50 | chain served |
|---|---|---|---|
| stock | unset | present, len=26 | `control-rsa`, RSA, SHA256-RSA |
| restricted | `0x0403,0x0804` | present, len=6 | `control-ecdsa`, ECDSA, ECDSA-SHA256 |
| suppressed | `none` | **absent** | `control-rsa`, RSA, SHA256-RSA |

len=6 is a 2-byte list length plus two 2-byte code points. The stock length is
unchanged from unpatched Go, which is the check that the patch is inert when the
environment is unset.

**Phase 1 gate is met.** The probe emits `signature_algorithms_cert`
independently, controls its contents, can suppress it entirely, and
demonstrably changes server behavior on the classical control.

## The finding, and it is not the one the sweep predicted

The restricted set omits `0x0401` (rsa_pkcs1_sha256). The RSA leaf is signed
`sha256WithRSAEncryption`, so that set excludes it, while the ECDSA leaf's
`ecdsa-with-SHA256` is `0x0403` and is included. OpenSSL switched chains.

**So OpenSSL 3.5.5's certificate chain check is live and correct when the client
sends the extension.** The earlier reading, that `check_cert_usable()` is dead
code because it gates on `peer_cert_sigalgs != NULL`, is true only against
clients that never populate it. OpenSSL clients never do; Go clients always do.

This upgrades the reframing in `PRIOR-ART.md` from inference to measurement:
**whether a server enforces the certificate chain check at all is a property of
the client talking to it, not of the server.** An operator who tests a migration
with `openssl s_client` and an operator who tests it with a Go client are
exercising different code paths on the same server, and only one of them
exercises the check.

## What this run does NOT show

- **Depth 1 only.** These are self-signed leaves, not chains with intermediates.
  The cell the matrix actually cares about is a mixed chain where the leaf and
  the intermediate carry different signature algorithms, and nothing here speaks
  to that.
- **`s_server`, not nginx.** This is the `-dcert` path, which is also the family
  that OpenSSL #32221 broke on `-xcert`. A production server may wrap the same
  library differently.
- **One run per cell**, and no negative control yet. Phase 4 owes both.
- Nothing post-quantum has been touched. This is the classical control by
  design, because a probe that cannot reproduce the classical case cannot
  measure the quantum one.

## Method note worth keeping

`go run` and `go test` silently IGNORE `-overlay`, which is documented in
`go help build` and easy to miss. Anything using this patch must `go build` and
then execute the binary. A `go run` here would have produced stock behavior with
no error and no warning, which is the worst possible failure for an instrument.
