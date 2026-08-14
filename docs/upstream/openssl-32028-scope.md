# Scope: OpenSSL #32028, making `signature_algorithms_cert` configurable

**Status: SCOPED, not started. Two gates below have to close before any code.**
Written 2026-08-13, downstream of this repo's measurement and the rustls issue in
`rustls-issue.md`.

**Why this one.** The reason nobody has measured server-side chain selection is
that the standard tool cannot ask the question. This project had to fork Go's
`crypto/tls` to build a client that emits the two extensions independently. Close
that gap in OpenSSL and every operator, vendor, and researcher can test this with
the thing already on their machine. That is worth more than any standalone tool,
and it is the only item on the list whose value does not depend on post-quantum
certificate adoption arriving first.

## The issue, verified 2026-08-13

**openssl/openssl#32028**, "TLS 1.3: `signature_algorithms_cert` handling", opened
2026-07-21 by `romen`, **still OPEN**, labels `branch: master` and
**`triaged: feature`**. Two comments, untouched since 2026-07-21.

`triaged: feature` matters: maintainers have already accepted this as legitimate
work rather than rejected it. And three weeks of silence means nobody is visibly
working it. Both good, and neither permanent.

The issue is four distinct problems, not one. Read from the body rather than from
this repo's earlier summary of it:

| # | Problem | Where |
|---|---|---|
| 1 | OpenSSL never *emits* the extension as a client, on the stated assumption that "we are the same implementation as our X.509 stack". Not true for SLH-DSA, where a user wants to accept it on certificates but not for `CertificateVerify`. | `ssl/statem/extensions.c` L339-345 |
| 2 | When handling a received `signature_algorithms_cert`, some code applies it as a **filter narrowing** `signature_algorithms` rather than as a **separate list**. | `ssl/t1_lib.c` L4617-4674, L4676-4683 |
| 3 | No way to control it via `SSL_CONF_cmd()` or `openssl.cnf`. Docs for `sigalgs` and `client_sigalgs` conflate handshake signatures with certificate signatures. | config layer |
| 4 | No way to exercise sigalgs / sigalgs_cert combinations from `s_client` or `s_server`. | `apps/` |

The existing tests in `test/recipes/70-test_sslsigalgs.t` L308-369 also only
exercise it as a filter, so the test suite encodes the same assumption.

## Proposed first contribution: parts 3 and 4, together

They are one piece of work. `s_client` and `s_server` options route through the
config layer, so exposing the CLI without the `SSL_CONF_cmd` plumbing is backwards.

Deliverable, roughly:

- A setter for the certificate signature algorithm list, distinct from the
  existing `sigalgs` (handshake signatures) and `client_sigalgs` (client
  certificate authentication). Note that **neither existing knob is this**, which
  is exactly the conflation the issue complains about in the docs.
- `SSL_CONF_cmd()` exposure, which brings `openssl.cnf` along.
- `s_client` and `s_server` options.
- Documentation that separates the three concepts instead of blurring two of them.
- Tests that exercise it as an **independent list**, not only as a filter.

Parts 1 and 2 are deliberately out of scope for a first contribution. Part 2 is a
behaviour change in libssl core with compatibility risk, and part 1 is an API
design question. Both become far easier to test once 3 and 4 exist, which is the
argument for this ordering.

## What we bring that nobody else in that thread has

Measured evidence, already published and archived under a DOI.

And one measurement that **complicates the issue's own part 2**, which is worth
posting whether or not any code follows. From `runners/FINDINGS-mixed.md`: the
`pqissuer` cell with `sigalgs=0x0403` and `sigalgs_cert=0x0904` was **served** by
OpenSSL 3.5.5. Under a strict filter reading it should have failed, because
intersecting `{0x0904}` with `{0x0403}` is empty. It did not fail.

So on the server-side certificate selection path, with these chain shapes, OpenSSL
3.5.5 already treats the two extensions as independent lists. That does not refute
`romen`, who wrote "some portions" of the code, and whose concern is principally
SLH-DSA and configurability. It does narrow where the problem actually lives, and
narrowing a maintainer's open question with a reproducible cell is the cheapest
possible way to earn standing before proposing a patch.

## Gates. Both are real and neither is technical.

### 1. The CLA, and the employer question it opens

Anything beyond a spelling fix requires a **Contributor License Agreement**. The
`CLA: trivial` shortcut is explicitly scoped to things like typo fixes and does
not cover this.

**This is not covered by anything currently cleared.** The book clearance covered
publishing. The outside-activity email drafted for Gary covers paid or unpaid
speaking and recorded training. Signing a legal instrument with a third party to
contribute code, in the subject area closest to the day job, is a third category
and the email going out does not ask about it.

Options, and this is Danny's call: add a sentence to the Gary email before sending,
or keep that email narrow and raise this separately once it has an answer. The
second is more consistent with the escalation logic already written down, which is
to not let a harder ask drag down an easier one.

**Nothing here should start before that is settled.** A signed CLA is not something
to unwind.

### 2. AI disclosure, which cuts the opposite way from rustls

rustls says AI-written comments may be hidden without notice. **OpenSSL permits AI
assistance and requires disclosure**, verified in their `CONTRIBUTING.md` on
2026-08-13:

> if a non-trivial portion of a contribution was created using an AI tool, you
> must declare which agent and model were used. This is done by adding
> `Assisted-by: {agent}:{model}` below the commit message

with a hard prerequisite:

> You will need to have signed a v1.1 or later CLA in order to include
> AI-generated content in your contribution. CLAs signed after June 2026 will have
> the requisite clauses.

Two consequences. **Sign the CLA after June 2026 and the AI clauses are included
automatically**, so there is nothing extra to do beyond signing current paperwork.

And this collides with a standing rule: no AI co-author trailers on Danny's
commits, sole author of record. Worth noting that `Assisted-by:` is **not**
`Co-Authored-By:`. It discloses tooling rather than assigning authorship, so the
sole-author position survives it. But OpenSSL's policy governs contributions to
OpenSSL, so the choice is a real one: write it unassisted, or disclose. Decide
before the first commit, not at push time.

## Honest difficulty

**This is C, in OpenSSL, and C is not on the skills list.** Python, PowerShell,
Dart, and full-stack work are. That does not kill this, and parts 3 and 4 are the
most approachable region of the codebase (config plumbing, CLI options, and
documentation rather than crypto internals or state machine work). It does mean any
estimate has to carry it.

- Fluent in the codebase: a week of evenings.
- Learning the codebase while doing it: several times that, and the first two weeks
  are reading, not writing.

Add OpenSSL's review process on top: two committer approvals, then a 24-hour hold,
and PRs can sit. Treat the merge date as unknown and the learning as the guaranteed
return.

## First moves, in order

1. **Settle the CLA question with Gary.** Gate, not a step.
2. **Comment on #32028 with the measured `pqissuer` cell**, linking the DOI. Narrows
   part 2, establishes standing, costs an hour, and is worth doing even if no code
   ever follows. Ask in the same comment whether a PR scoped to parts 3 and 4 would
   be welcome, since `CONTRIBUTING.md` explicitly asks for an issue conversation
   before a large contribution.
3. **Wait for a maintainer response before writing code.** They may have a design in
   mind, and `romen` opened this deliberately.
4. Only then: build, read `ssl/ssl_conf.c` and the `sigalgs` plumbing, and scope the
   patch against what they say.

## What would kill this

- **`romen` or another committer starts it.** Mitigated by commenting early. Check
  the issue before any work resumes.
- **The CLA question coming back no**, or coming back with conditions that make a
  third-party legal agreement not worth it.
- **A maintainer preferring a different design** for the configuration surface, which
  is their call and would reduce this to whatever they want implemented.
- **Realising the C is the whole project.** That is a legitimate outcome to name up
  front rather than discover in month two. Step 2 above delivers value regardless,
  which is why it is sequenced first.
