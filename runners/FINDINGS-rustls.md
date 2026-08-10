# rustls: the extension never reaches the resolver

Source trace 2026-08-10. Two trees read:

- **released `0.23.43`**, tag `v/0.23.43`, dated 2026-07-29
- **dev HEAD `2cd5cc1`**, `0.24.0-dev.1`, dated 2026-08-10

**Stamp: Reported.** This is source reading, not a handshake. Verifying it needs
a running rustls server, which is Phase 3. Recorded now because it predicts the
column divergence this project was built to find.

## What a rustls certificate resolver can see

`ResolvesServerCert::resolve` receives a `ClientHello`. In released 0.23.43,
`rustls/src/server/server_conn.rs:139`, that struct has eight fields:

```
server_name  signature_schemes  alpn  server_cert_types
client_cert_types  cipher_suites  certificate_authorities  named_groups
```

Eight accessors, matching. **`signature_algorithms_cert` is not among them**, in
either tree. Dev HEAD moves the struct to `server/config.rs:416` and keeps the
same eight fields.

In released 0.23.43 the identifier `SignatureAlgorithmsCert` appears **twice in
the whole crate**, both in `msgs/enums.rs`: the code point `0x0032`, and
membership in the list of extensions compressible in an ECH inner ClientHello.
It is never read into a ClientHello payload struct and never surfaced upward.

Dev HEAD adds one more site, `msgs/handshake.rs:1127`, in a constant named
`UNPROCESSED` carrying the comment that rustls does not process these and ignores
them if received. That list is for **CertificateRequest**, which is the server
asking the client for a certificate, so it is the client-authentication
direction and not server selection.

## Why this is stronger than a selection bug

The data never reaches the resolver, so **a custom `ResolvesServerCert`
implementation cannot honor the extension either**. This is not a policy an
application can override. It is an absence in the parser.

It is also not a blanket posture toward selection hints.
`certificate_authorities`, from the same RFC 8446 section 4.4.2.2 neighbourhood,
**is** parsed, exposed, carries a documentation comment with an RFC link, and in
dev HEAD has a deliberate carve-out hiding it from the resolver on TLS 1.2 per
the RFC. Someone thought carefully about this area and implemented the adjacent
extension.

## The predicted divergence

A rustls server holding two chains selects on `signature_schemes` alone, which is
the **leaf key type**. It has no input describing which **signatures on
certificates** the client will accept.

That is precisely the axis the mixed shapes isolate, and precisely where OpenSSL
3.5.5 was measured correct in all six cells (`FINDINGS-mixed.md`). The cell to
run first in Phase 3:

> `pqissuer` (EC leaf key, ML-DSA-signed chain) with `signature_algorithms` =
> ECDSA and `signature_algorithms_cert` = ECDSA. OpenSSL refuses, because the
> chain signatures are excluded. rustls has no way to know they were excluded.

If rustls serves that chain, it is the silent wrong-chain outcome: handshake
proceeds, client cannot validate, and no server-side signal says why.

## Prior disclosure

Searched the rustls issue tracker on 2026-08-10 for `signature_algorithms_cert`,
open and closed. **No results.** Scope limit worth stating: that search does not
cover pull requests, discussions, or the mailing list, and GitHub search does not
reliably index every issue body. Absence here is weak evidence, not proof, and
the Phase 6 re-sweep should redo it.

## What this does not say

Not measured. Not a bug report. rustls conforms to RFC 8446 here in the sense
that section 4.4.2.2 makes the chain-signature constraint a SHOULD rather than a
MUST, and Go's `crypto/tls` declines the same check in a source comment citing
exactly that. Three of the five stacks in this matrix now decline it in some
form. The finding is the operational consequence during a migration, not a
standards violation.
