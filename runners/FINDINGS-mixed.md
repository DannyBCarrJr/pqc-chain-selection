# Mixed-shape findings: the two axes are separate, and OpenSSL treats them that way

Run 2026-08-10. OpenSSL 3.5.5 (27 Jan 2026), go1.26.0 linux/amd64.
Reproduce: `runners/single-chain.sh`. Evidence in `evidence/single-chain/`.

**Stamp: Verified.** Chain identity from server-side handshake message lengths.

## Why these two shapes

`signature_algorithms` constrains CertificateVerify, so it is about the **leaf's
key**. `signature_algorithms_cert` constrains signatures on certificates, so it
is about the **issuers**. Every other shape lets those move together. These two
put them in opposition.

| shape | root, int | leaf key | signatures on chain |
|---|---|---|---|
| `pqleaf` | EC | ML-DSA-44 | ECDSA |
| `pqissuer` | ML-DSA-44 | EC | ML-DSA-44 |

One chain per server, so nothing is masked by a fallback.

## Result: six cells, six matches

| chain | `sigalgs` | `sigalgs_cert` | Certificate | CertVerify | outcome | expected |
|---|---|---|---|---|---|---|
| pqleaf | `0x0904` | `0x0403` | 2163 | 2428 | served | served |
| pqleaf | `0x0904` | `0x0904` | - | - | refused | refused |
| pqleaf | `0x0403` | `0x0403` | - | - | refused | refused |
| pqissuer | `0x0403` | `0x0904` | 6875 | 79 | **served** | served |
| pqissuer | `0x0403` | `0x0403` | - | - | refused | refused |
| pqissuer | `0x0904` | `0x0904` | - | - | refused | refused |

CertificateVerify confirms the leaf key independently of anything the client
claims: 2428 for an ML-DSA-44 leaf, 79 for an EC one. Both mixed shapes report
the value their construction predicts, which is an internal consistency check on
the harness as much as on OpenSSL.

## The cell that mattered

**`pqissuer` with `sigalgs=0x0403` and `sigalgs_cert=0x0904` was served.** The
client accepted ML-DSA signatures on certificates while offering only ECDSA for
CertificateVerify, and OpenSSL sent the chain.

OpenSSL #32028 records a maintainer's statement that parts of the code apply
`signature_algorithms_cert` "as a filter further restricting the set of
`signature_algorithms` rather than as a separate list". Under that behavior this
cell would fail, because intersecting `{0x0904}` with `{0x0403}` is empty. It
did not fail. **On the server-side certificate selection path, with these
shapes, OpenSSL 3.5.5 treats the two extensions as independent lists.**

State that narrowly. #32028 says *some portions* of the code, and the issue is
principally about SLH-DSA and about configurability, neither of which this
touches. Nothing here refutes it. What this shows is that one specific path a
reader might assume is affected is not.

## A size decomposition that belongs to pqc-chain-budget

Certificate message, same depth 3, same harness:

| chain | Certificate | vs classical |
|---|---|---|
| classical | 929 | 1.0x |
| pqleaf (PQ key, classical signatures) | 2163 | 2.3x |
| pqissuer (classical key, PQ signatures) | 6875 | 7.4x |
| pq (both) | 8100 | 8.7x |

**The signature axis carries far more weight than the key axis.** Moving the leaf
key to ML-DSA costs about 1.2KB; moving the chain signatures to ML-DSA costs
about 6KB.

One caveat, and it stops this from being a clean orthogonal decomposition:
`pqissuer`'s intermediate carries an ML-DSA public key as well as an ML-DSA
signature, because an ML-DSA-signing CA necessarily holds an ML-DSA key. So the
6875 figure includes a key-side contribution that cannot be separated out by
construction. The direction is sound, the split is not exact, and any figure
quoted elsewhere needs that sentence attached.

## On the negative-control debt

Not discharged, but partly addressed. Three cells produce `served` and three
produce `refused` on the same harness, so a passing cell is demonstrably capable
of failing and the verdict is not a constant. A real negative control still owes
a deliberately broken chain that must be rejected.
