# tlspatch

Builds the probe against a patched `crypto/tls` so the client's
`signature_algorithms` and `signature_algorithms_cert` contents are settable.
Stock Go already sends both; what it does not offer is any way to choose what
goes in them.

## Why an overlay and not a fork

`crypto/tls` imports `internal/godebug` and `crypto/tls/internal/fips140tls`,
which are importable only from inside GOROOT. Copying the package out of the
standard library and compiling it as an ordinary dependency does not work.

`go build -overlay` swaps file contents at build time, so the repo stores the
**injection** rather than a copy of Go's BSD-licensed source. The diff is two
inserted lines plus one added file, the licensing stays clean, and the patch
follows Go version bumps instead of freezing against one.

Rejected alternative: uTLS, which is purpose-built for ClientHello control and
would have worked. It was not chosen because it constructs a synthetic
ClientHello that differs from stock Go in more than one place. A measurement
instrument wants exactly one knob, and everything else byte-identical to the
client population being modelled.

## Use

```sh
./build.sh            # writes build/probe
./verify.sh           # the three-cell Phase 1 gate
```

With both environment variables unset the binary produces a byte-identical
ClientHello to unpatched Go.

| value | effect |
|---|---|
| unset | stock behavior |
| `none` or empty | empty list. For `signature_algorithms_cert` the marshaller gates on `len(...) > 0`, so this suppresses the extension |
| `0x0403,0x0804` | exactly these code points, in this order |

Code points are deliberately not validated and not filtered by
`isDisabledSignatureAlgorithm`. Sending unknown or policy-disabled values is a
measurement the matrix needs.

## Two ways this breaks

**`go run` and `go test` ignore `-overlay`.** Documented in `go help build`.
They fail silently, producing stock behavior with no warning. Always `go build`
then execute.

**The awk anchors are exact function signatures.** When Go refactors either
function, `build.sh` exits non-zero with `ANCHOR FAILURE` rather than producing
a quietly unpatched binary. That is deliberate. If it fires, re-read the
functions in `$(go env GOROOT)/src/crypto/tls/common.go` before touching the
anchors, because the surrounding logic may have changed too.
