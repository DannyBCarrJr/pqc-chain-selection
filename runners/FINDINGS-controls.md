# Controls, repeatability, and what actually decides selection

Run 2026-08-10. OpenSSL 3.5.5, go1.26.0, nginx:alpine (1.31.3 / OpenSSL 3.5.7).
Reproduce: `runners/controls.sh`. Evidence in `evidence/controls/`.

**Stamp: Verified.** Closes the three debts recorded in `MATRIX.md`.

## 1. Negative control: verification is genuinely happening

Every "handshake OK" verdict in this repo is worth nothing unless a verifying
client would actually have rejected a bad chain. One byte inside the leaf's
signature BIT STRING is flipped, leaving the structure parseable so the failure
is cryptographic rather than a decode error.

| chain | client with real roots | expected |
|---|---|---|
| untampered classical | pass | pass |
| one flipped signature byte | **reject** | reject |

The paired result is the point. The instrument distinguishes a good chain from a
bad one, so the OK verdicts elsewhere carry information.

## 2. What decides selection, and it is not the config

The open question was whether configuration order decides, as BoringSSL's
documentation implies for its own "first usable credential" behavior.

**Server config order does not decide on nginx.** Same two chains, order
swapped, client accepting both:

| `ssl_certificate` order | chain served |
|---|---|
| classical then pq | pq |
| pq then classical | pq |

**Client preference order decides.** Same server, both chains configured, only
the order inside the client's `signature_algorithms` changed:

| client order | CertificateVerify | chain served |
|---|---|---|
| `0x0904,0x0403` (ML-DSA first) | 2428 | ML-DSA |
| `0x0403,0x0904` (ECDSA first) | 79 | ECDSA |

So OpenSSL honors the client's stated preference and ignores the order the
operator wrote in the config. That is the correct behavior under RFC 8446, and it
has a deployment consequence worth stating plainly: **an operator cannot steer
which chain goes out by reordering the config.** During a migration the client
population decides, one connection at a time.

**Untested, and now recorded as permanently blocked rather than owed.**
BoringSSL's "first usable credential" behavior implies server config order
matters there, which would differ from this. Envoy cannot be used to check it,
because it will not load a post-quantum chain at all. That test needs either a
BoringSSL build with ML-DSA support or a different mixed shape.

## 3. Repeatability

The deciding cell, `pqissuer` with both extensions restricted to ECDSA, run five
consecutive times:

```
run 1: FAILED remote error: tls: handshake failure
run 2: FAILED remote error: tls: handshake failure
run 3: FAILED remote error: tls: handshake failure
run 4: FAILED remote error: tls: handshake failure
run 5: FAILED remote error: tls: handshake failure
```

Five for five. The verdict is stable, not a flake.

## A harness bug worth keeping

The first version of this script died silently mid-run under `set -euo pipefail`:

```sh
served="$(grep -oE 'key=' <<<"$out" | head -1 && echo '(pq)')"
```

`head -1` closes the pipe, grep takes SIGPIPE, `pipefail` propagates the
non-zero status, `&&` short-circuits, the assignment inherits the failure, and
`set -e` exits with no message. Two sections of the run simply never happened
and the output looked merely truncated.

The fix is to end such pipelines with `|| true` and test separately. This is the
second silent-failure bug in this harness, after `grep -oE '[0-9a-f]+'` matching
the `a` in "Handshake" and reporting every length as 10. **Both produced
plausible output rather than an error**, which is the failure mode a measurement
harness has to be built against.
