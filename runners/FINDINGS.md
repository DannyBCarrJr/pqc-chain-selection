# s_server control column findings

Run 2026-08-10. OpenSSL 3.5.5 (27 Jan 2026), go1.26.0 linux/amd64.
Reproduce: `gen/mint-chains.sh && probe/tlspatch/build.sh && runners/s_server.sh`.
Evidence in `evidence/s_server/`, one server capture and one probe capture per cell.

**Stamp: Verified.** Chain identity is read from server-side handshake message
lengths, not inferred from the client's error text. See "how a chain is
identified" below.

## The result

Server holds both chains at once, depth 3 each: `classical` (EC root, int, leaf)
and `pq` (ML-DSA-44 root, int, leaf).

| cell | `signature_algorithms` | `signature_algorithms_cert` | Certificate | CertVerify | chain sent | verdict |
|---|---|---|---|---|---|---|
| classical-only | `0x0403` | `0x0403` | 929 | 79 | classical | correct |
| pq-only-cert-stock | `0x0904` | stock Go list | - | - | none | **fail-closed** |
| pq-only-cert-pq | `0x0904` | `0x0904` | 8100 | 2428 | pq | correct |
| both-cert-ecdsa-only | `0x0904,0x0403` | `0x0403` | 929 | 79 | classical | correct |
| both-cert-pq-only | `0x0904,0x0403` | `0x0904` | 8100 | 2428 | pq | correct |
| both-cert-suppressed | `0x0904,0x0403` | absent | 8100 | 2428 | pq | correct |

`0x0904` is mldsa44, read off the wire as `00 02 09 04` from an
`openssl s_client -sigalgs mldsa44` ClientHello rather than taken from the draft.

**OpenSSL 3.5.5 is correct in all six cells, and `signature_algorithms_cert` is
the deciding variable.** Rows 4 and 6 differ in nothing but that extension and
receive different chains. Row 2 is the strongest cell: the client needed an
ML-DSA leaf for CertificateVerify while refusing ML-DSA signatures on chain
certificates, no configured chain satisfied both, and the server sent a
handshake_failure alert rather than an unusable chain. It fails closed.

**This contradicts the working hypothesis this project started from.** The
sweep's framing predicted a silent wrong-chain failure. On this path, it does not
happen. That is a result, and it is the reason the matrix exists rather than an
argument for abandoning it.

## Scope, stated precisely so this is not over-read

- **`-cert`/`-dcert`, not `-xcert`.** OpenSSL #32221 reports a failure on the
  Extended-certificates path. Nothing here confirms or refutes that issue,
  because it is a different code path.
- **`s_server`, not a production server.** nginx, httpd, and HAProxy wrap the
  same library and are not measured yet.
- **One run per cell, no negative control.** The repo's own rule requires proving
  a passing cell can fail. Owed.
- **Two minted shapes unexercised.** `pqleaf` (ML-DSA key under ECDSA signatures)
  and `pqissuer` (EC key under ML-DSA signatures) separate the key axis from the
  signature axis and are the cells most likely to divide implementations. Not
  run yet.

## How a chain is identified, and why the client cannot do it

Go 1.26 **does not expose ML-DSA to `crypto/x509` or `crypto/tls`.** Corrected
2026-08-10: the ML-DSA primitive does exist in the standard library, at
`crypto/internal/fips140/mldsa/`, but it is internal and unexported, and
`crypto/x509` recognizes only ECDSA, Ed25519, and RSA signature algorithms. So
against an ML-DSA leaf a Go client fails with `unsupported type of public key`,
and it fails **before** `VerifyPeerCertificate` runs, so the raw-DER capture
designed for exactly this case never fires. `served: NOTHING CAPTURED` in those
cells means the client could not look, not that nothing arrived. The earlier
wording "no ML-DSA support anywhere" was wrong: the algorithm is present, the
X.509 and TLS wiring is not.

Server-side handshake message length is therefore the ground truth, via
`s_server -msg`:

| chain | Certificate | CertificateVerify |
|---|---|---|
| classical (EC) | 929 | 79 |
| pq (ML-DSA-44) | 8100 | 2428 |

An ML-DSA-44 signature is 2420 bytes and an ECDSA P-256 one is about 72, so the
CertificateVerify length alone separates them with no ambiguity. The Certificate
message is 8.7 times larger on the post-quantum chain.

## The split worth writing up

Go always sends `signature_algorithms_cert` and does not expose ML-DSA to X.509.
OpenSSL supports ML-DSA natively and never sends the extension. **The stack that
exercises the server's chain check cannot use post-quantum certificates, and the
stack that can use them never triggers the check.** Both halves are Verified on
this machine, from source and from the wire.

## One bug worth remembering

`grep -oE 'Handshake \[length ([0-9a-f]+)\], Certificate$' | grep -oE '[0-9a-f]+'`
reports every length as 10. The second grep matches the `a` in `Handshake`
first, and `0xa` is 10. Every cell produced a plausible, identical, wrong number.
Use `sed -E 's/.*length ([0-9a-f]+).*/\1/'` to take the captured group. A
measurement harness that returns the same number for every input is the failure
mode to watch for, not the one that errors.
