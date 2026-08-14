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

This collided with a standing rule: no AI co-author trailers on Danny's commits,
sole author of record. **Resolved 2026-08-13: use the trailer.** `Assisted-by:` is
not `Co-Authored-By:`. It discloses tooling rather than assigning authorship, so
the sole-author position survives it intact, and OpenSSL's policy governs
contributions to OpenSSL.

### Standing rule for this project: disclose the tooling, own the writing

Both halves apply to every commit message, PR description, issue comment, code
comment, and doc that leaves this machine.

1. **`Assisted-by: Claude:{model}` on any commit where a non-trivial portion was
   assisted.** Required by OpenSSL, and the honest answer. Not negotiable and not
   something to be cute about.
2. **All prose goes out in Danny's voice**, per `~/.rocky/steering/writing-style.md`,
   and gets a `de-ai-pass` before it ships. Cold open on the concrete thing, numbers
   where an adjective would go, short flat verdict after a long build, no banned
   vocabulary, no em dashes. The trailer discloses the tooling; the voice is what
   makes the writing his. Those are not in tension and doing both is the point.

   **"Prose" means everything, not just the public-facing parts.** Commit messages,
   PR descriptions, issue comments, **comments inside scripts and source files**,
   README and doc files in any repo this project creates, sprint notes, design notes,
   and anything generated along the way. If it has sentences in it and Danny's name
   is on the repo, it reads like him. The default failure here is that the public
   artifacts get the voice pass and the working files quietly keep the machine
   register, which is how a repo ends up sounding like two different people.

   **The one exception, and it is theirs not ours: comments inside OpenSSL's own C
   source follow OpenSSL's house style, not this one.** Their coding-style document
   governs their tree, and a patch whose comments read differently from the
   surrounding 200 lines draws a style review before anyone looks at the logic. In
   their code, write plain technical English that matches the file it sits in. The
   voice rule owns everything that is Danny's: our repos, our notes, commit messages,
   PR text, and issue comments. Their code is theirs.
3. **The reasoning has to be his, not just the sentences.** This is the half that
   matters and it is not a style rule. A maintainer will ask why a design choice was
   made, in a thread, and the answer has to come back live and correct. Voice-matched
   prose sitting on top of reasoning Danny cannot defend is worse than plain prose he
   can, because the first kind fails in public at the worst moment.

   OpenSSL says the same thing in their own `CONTRIBUTING.md`: "contributors should
   personally evaluate potential patches generated by automated tools." So this is
   their requirement as much as our preference.

Practical consequence for how we work: I draft and explain, Danny reads until he
could defend it cold, and anything he would not defend gets cut rather than
shipped. That is also why sprints 1 and 2 are reading and local experiment rather
than code generation. Fluency first, then a patch he owns.

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

## Sprint plan

**The CLA question went into the Gary email on 2026-08-13 and goes out the next
working day.** The useful thing about the ordering below is that **sprints 1 and 2
need no clearance at all**, because nothing leaves this machine: no comment, no
account, no signature, no code sent anywhere. They are private reading and local
experimentation, which is the same category as any other lab work here. So the
waiting period is not dead time, and by the time an answer arrives the upstream
conversation is much better prepared.

Each sprint states what it is worth if the project stops there, because two of the
gates could genuinely close.

### Sprint 1: build it, and re-verify the issue against current master

**Unblocked. Start any time.**

`#32028` was written 2026-07-21 and cites two specific commits (`a44ba221`,
`63afe639`) with line numbers. Master has moved since. This repo has already been
burned once by an entry that described a source two revisions stale
(`2026-08-11_prior-art-entry-cited-a-two-revision-stale-ietf-draft`), so the first
move is to check that all four claims still hold where `romen` said they do.

- Clone and build OpenSSL master. Record the commit.
- Re-locate each of the four claims in current source. Line numbers will have
  drifted; the question is whether the *behaviour* still does.
- **Re-run the `pqissuer` deciding cell against master-built OpenSSL rather than
  3.5.5.** This repo measured 3.5.5. Nobody has measured what master does, and the
  answer could differ.
- Read `test/recipes/70-test_sslsigalgs.t` lines 308-369 and confirm they really do
  only exercise the filter reading.

**Done when:** a short verification note exists saying which of the four parts are
still true at a named commit, with the re-run cell's output.

**Worth if we stop here:** a current, citable status of a live OpenSSL issue, plus
a second data point for this repo on a newer OpenSSL. That is publishable on its
own and it is the material for the sprint 3 comment either way.

### Sprint 2: map the configuration surface

**Unblocked.**

Work out the smallest honest shape of the patch before proposing anything.

- Read `ssl/ssl_conf.c` and trace how `sigalgs` and `client_sigalgs` are plumbed
  from `SSL_CONF_cmd()` down to the setters.
- Establish precisely what `client_sigalgs` **is** (client certificate
  authentication) so the docs fix can separate three concepts instead of blurring
  two. This is the conflation the issue complains about and it needs to be right.
- Find where a certificate-signature-algorithms setter attaches, and what the
  receiving side already has: `s->s3.tmp.peer_cert_sigalgs` exists, so the read
  path is there and the write path is what is missing.
- Trace how `s_client` and `s_server` options reach the config layer.
- Prototype locally. Do not push anywhere.

**Done when:** a design note describing the minimal patch: which functions, which
new option names, what the docs need to say, what the tests need to prove.

**Worth if we stop here:** OpenSSL codebase fluency in the exact area of the day
job, and a design note that makes the sprint 3 question specific rather than vague.

### Sprint 3: engage upstream

**GATED on the Gary answer.**

`CONTRIBUTING.md` explicitly asks for an issue conversation before a large
contribution, so this is their preferred route and not an imposition.

- Comment on `#32028` with the sprint 1 verification and the measured `pqissuer`
  cell, linking the DOI.
- Ask whether a PR scoped to parts 3 and 4 would be welcome, and whether the
  sprint 2 design matches what they have in mind.
- Sign the CLA only once the answer is yes. **Sign a v1.1 or later**, which any
  CLA signed after June 2026 is, so the AI-assistance clauses are included.
- Decide the `Assisted-by:` question before the first commit.

**Done when:** a maintainer has responded on scope and design.

**Worth if we stop here:** the measured finding is on the record in the place it
matters most, attributed, whether or not any code follows.

### Sprint 4: implement parts 3 and 4

**GATED on sprint 3.**

Setter, `SSL_CONF_cmd()` exposure, `s_client` and `s_server` options,
documentation separating the three concepts, and tests that exercise the extension
as an **independent list** rather than only as a filter.

Build the whole thing against whatever design sprint 3 agreed. If they wanted
something different, this is their call and the scope changes to match.

### Sprint 5: PR and review

Two committer approvals, then a 24-hour hold. Reviewers can ask for changes at any
phase and anything beyond a rebase needs re-approval. **Treat the merge date as
unknown.** Budget for a review cycle measured in months, not the writing.

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
