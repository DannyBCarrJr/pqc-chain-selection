# Phase 1 smoke test findings

Run 2026-08-10. OpenSSL 3.5.5 (27 Jan 2026), go1.26.0 linux/amd64.
Reproduce with `./gen-classical-pair.sh && ./run.sh`. Evidence in `evidence/`.

**Stamp: Verified.** Both results below are captured output from this machine,
not inference from source.

## 1. A stock Go client sends signature_algorithms_cert

Server-side extension dump, `openssl s_server -tlsextdebug`, against an
unmodified `crypto/tls` client:

```
TLS client extension "signature algorithms" (id=13), len=16
TLS client extension "unknown" (id=50), len=26
```

Extension 50 is `signature_algorithms_cert` (RFC 8446 section 4.2.3). Go sends it
unconditionally for TLS 1.2 and above, from `handshake_client.go:123`, with
contents from `common.go:1798`.

**OpenSSL labels it "unknown".** Its debug table has no name for the extension,
which matches the source finding that OpenSSL never generates it
(`ssl/statem/extensions.c`, NULL construct callbacks). The stack that does not
send it also cannot name it.

This confirms the correction recorded in `PRIOR-ART.md`: the sweep's claim that
Go does not implement `signature_algorithms_cert` was true of the server half
only.

## 2. The probe reads the served chain without packet capture

```
version:  TLS 1.3
cipher:   TLS_AES_128_GCM_SHA256
chain[0]: cn="control-rsa" pubkey=RSA sigalg=SHA256-RSA
```

Read from `ConnectionState.PeerCertificates`. **Certificate verification was
on**, against a root pool holding the two control certificates, so the served
chain validated rather than merely arriving.

## What this means for Phase 1

The probe does not need a fork of the marshalling layer, and it does not need a
hand-rolled ClientHello. Go already puts the extension on the wire. The only
missing capability is control over its **contents**, which come from the
package-level `supportedSignatureAlgorithmsCert()` with no `Config` knob.

Phase 1 is therefore a patch that makes one list settable. Estimate stands at
roughly one evening, revised down from one to two weekends.

## Two things deliberately not concluded

The server chose the RSA chain while holding an ECDSA chain under `-dcert`. Go
offered 7 signature schemes (id=13, len=16). **Whether that selection was correct
is a Phase 4 question, not a smoke-test result**, and one control run is not
evidence about `s_server` selection behavior. Recorded so it is not rediscovered
as a surprise.

`-quiet` suppresses `-tlsextdebug` entirely, which produced a silent empty
capture on the first run. Any runner in this repo that needs extension output
must not pass `-quiet`.

## Addendum 2026-08-31: the same two lists from a default Config

Run 2026-08-31, same toolchain (`evidence/stock-versions.txt`). Reproduce with
`./run-stock.sh` (certs from `./gen-classical-pair.sh`). Evidence in
`evidence/stock-client-extensions.txt`.

**Stamp: Verified.** Captured output, same `-tlsextdebug` instrument as above.

The probe above pins MinVersion to TLS 1.3, and that pin changes the handshake
list: at min 1.3 Go drops PKCS#1 v1.5 and SHA-1 (the 7 schemes behind len=16 in
finding 1), at the default minimum it drops SHA-1 only. A client with a default
`tls.Config` sends:

```
TLS client extension "signature algorithms" (id=13), len=22
0000 - 00 14 08 04 04 03 08 07-08 05 08 06 04 01 05 01   ................
0010 - 06 01 05 03 06 03                                 ......
TLS client extension "unknown" (id=50), len=26
0000 - 00 18 08 04 04 03 08 07-08 05 08 06 04 01 05 01   ................
0010 - 06 01 05 03 06 03 02 01-02 03                     ..........
```

10 schemes against 12, and the hex says which: extension 50 is extension 13
byte for byte plus `02 01` (rsa_pkcs1_sha1) and `02 03` (ecdsa_sha1) appended.
The mechanism is `isDisabledSignatureAlgorithm` in `crypto/tls/common.go`
(go1.26.0): its `isCert` branch filters nothing in a default (non-FIPS) build,
with a source comment explaining the intent. So the cert list is a superset
either way, by SHA-1 alone at the default minimum, by SHA-1 plus PKCS#1 v1.5
at min 1.3.

The extension-13 length moving with the config (16 in finding 1, 22 here) is
also the control: the instrument tracks the client rather than echoing a stale
format.

Recorded because rustls #3214 asked whether differing lists are a practical
concern. A default Go client sends them on every TLS 1.2+ dial.
