# Cross-signed intermediate findings: the check never reaches it

Run 2026-10-17. OpenSSL 3.5.5 (27 Jan 2026). Probe binary built 2026-08-14 against
go1.26.0 (`probe/tlspatch/evidence/gate.txt`); the Go toolchain on the machine on
run day was go1.26.8, printed in the run header, and the probe was not rebuilt.
Reproduce: `gen/mint-chains.sh && runners/cross-signed-ica.sh`. Evidence in
`evidence/cross-signed-ica/`, one server capture and one probe capture per cell.

**Stamp: Verified.** The served intermediate is identified by its DER bytes inside
the server's own `-msg` dump of the Certificate message, matched against each
intermediate file. The two extensions the client sent are read from the ClientHello
bytes in the same dump.

## The shape

Kampanakis and Dukhovni's appendix B (`PRIOR-ART.md`, "Stated from the implementer
side"): one ML-DSA-44 intermediate key holding two certificates, one from the
ML-DSA-44 root (`pq/int.crt`, their PQ ICA 2ii) and one from the EC root
(`pq/int-xsign-ec.crt`, their PQ ICA 2i), and an ML-DSA-44 leaf issued under that
key. The leaf and its signature are identical in both chains. Only the intermediate's
signature differs. `openssl verify` passes the leaf under each
(`gen/evidence/mint-chains.txt`).

The server gets one intermediate at a time. The prediction from source is that
`check_cert_usable()` never reads the intermediate, and a prediction about a
certificate the function never reads is tested by configuring the one the client
excluded.

## Result

| cell | intermediate configured | `sigalgs` | `sigalgs_cert` | Certificate | CertVerify | outcome | served intermediate | RFC 8446 4.4.2.2 |
|---|---|---|---|---|---|---|---|---|
| pq-ica-mldsa | ML-DSA-signed | `0x0904` | `0x0904` | 8100 | 2428 | served | ML-DSA-signed | served |
| pq-ica-xsign | ECDSA-signed | `0x0904` | `0x0904` | 5753 | 2428 | **served** | **ECDSA-signed** | refused |
| pq-ica-mldsa-ec | ML-DSA-signed | `0x0904` | `0x0403` | - | - | refused | none | refused |
| pq-ica-xsign-ec | ECDSA-signed | `0x0904` | `0x0403` | - | - | refused | none | refused |

**The second row is the cell.** The client said it would accept ML-DSA signatures on
certificates and nothing else. The configured intermediate carries an ECDSA
signature. OpenSSL sent it. The prediction held: the function receives the leaf
alone, the leaf's ML-DSA signature passes, and the intermediate is never examined.

The bottom two rows are the negative controls: the same two server configurations
under a client that excluded ML-DSA signatures on certificates. Both refused,
because the leaf's own signature is ML-DSA and that one the function does check. So
the serve in row two is not a check that is off. It is a check that stops one
certificate short of where the cross-sign lives.

## The checks on the measurement itself

- The Certificate message shrank by 2347 bytes between rows one and two. The
  ML-DSA-44 signature on the intermediate is 2420 bytes and the ECDSA one 70; the
  rest of the difference is the issuer name (the EC root's is seven bytes longer),
  the algorithm identifiers, and DER length encoding. Length and bytes agree on which
  intermediate went out.
- The byte match searches for the ML-DSA-signed intermediate first in every cell. In
  row two it did not appear and the ECDSA-signed one did. A matcher that could not
  tell the two files apart would have reported the first one.
- `sent=sa:ok,sac:ok` on every row: extension 13 carrying `00 02 09 04` and
  extension 50 carrying the cell's list, found in the ClientHello bytes of the same
  capture. The probe sent what the cell says it sent.

## What this does and does not say

- Measured on `openssl s_server` with `-cert_chain`, one intermediate per run. Not
  nginx and not s2n-tls. The paper measured those; this repo has not.
- The paper says a relying party "advertising support for ECDSA only" could receive
  the ML-DSA-signed intermediate. On this bench a client that sent
  `signature_algorithms_cert` with ECDSA alone was refused at the leaf (rows three
  and four), as the August deciding cell was. So their client either omitted the
  extension or listed ML-DSA in it, and the paper does not say which. What their
  client sent stays Proposed. The depth of the check is Verified.
- Conformance, never a bug. RFC 8446 4.4.2.2 is a SHOULD, and the one-certificate
  check is documented in the function's own comment.
