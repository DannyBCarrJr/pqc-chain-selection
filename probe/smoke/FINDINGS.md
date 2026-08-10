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
