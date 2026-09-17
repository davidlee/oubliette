# Review RV-006 — reconciliation of SL-002

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

The closure audit of `SL-002` *volume-verbs-and-a-scrubbed-clone*: six phases
`completed`, lifecycle moved `started → audit`, head `d39f4d6`, tree clean.

**Surface reviewed.** The main worktree at `d39f4d6` — this slice was driven
solo, not by `/dispatch`, so there is no candidate branch. The subject is what
PHASE-01..05 plus the `RV-004` remediation built: `host/volume-root.nix`,
`vm/reset-home.nix`, `vm/guest-path.nix`, `host/cli.nix`'s `volume` verb,
`resetHomeRefusal`, `scrubPending`, `alloc`/`volumes`, the three new suites,
`capsules.nix`'s `volumeLock`/`volumeReserve`, the tmpfiles rule, and
`docs/contract-assignment.md` / `docs/probes.md`. PHASE-06 produced evidence
only.

**Gate, run before raising.** `just check` ok (parse + `alejandra -c`); `just`
exit 0 (build, `hostModuleUnits`, all fourteen `*Cases` suites, fmt);
`doctrine slice verify-vt SL-002` passes every `VT` on PHASE-01..05.
`doctrine check gate` did **not** run — see `F-12`.

### Lines of attack

1. **Does the registry tell the truth?** `slice conformance` is read as a lead,
   not a verdict: which paths shipped that no `design-target` selector declares,
   which selectors matched nothing, and — the question conformance itself cannot
   ask — whether each phase's recorded commit range is the range that phase
   actually landed. Two of the six rows are wrong in opposite directions.
2. **Does the design text still describe the program?** Every deviation carried
   forward from PHASE-03/04/05 and PHASE-06, re-read against the code rather
   than against the note that recorded it, plus sec-8's code-impact table as a
   closed list of what shipped.
3. **Does the contract still describe the target's obligations?** `POL-002`'s
   surface is `docs/contract-target.md` and `docs/contract-assignment.md`, and
   CLAUDE.md requires them to move in the same commit as anything that moves the
   boundary. `vm/guest-path.nix` added an enforced constraint on a `target.nix`
   value; that is the test.
4. **Is the attestation the audit leans on sound?** `design show --format
   status` reports `review_pass STALE` on a run locked at revision 75 with zero
   outstanding sections and zero changes since baseline. Three readings that
   disagree are settled against the run's own attestation and act records before
   anything is inferred from the lock.
5. **Is each claim's evidence the claim's own?** `STD-001`: a `VH` satisfied by
   a weaker exercise than its text describes, a guarantee held by a suite and
   read as live, and a guard pinned in isolation from its call site are three
   shapes of the same rounding-up. Each is stated at the strength its evidence
   carries.
6. **What was found and never filed?** The notes' Open leg is the declared
   worklist; anything reasoned-about-and-dropped in a phase section without a
   record is treated as unfiled rather than closed.

### Invariants the slice is held to

- `POL-002` — nothing generic learns what the target is, and everything beyond
  the contract is declared with a working absent path.
- `POL-003` — one declaration per axis; a volume verb never resolves a name
  implicitly.
- `POL-004` — a program that needs testing takes as an argument the one thing
  that ties it to this host.
- `DEC-001`..`DEC-011`, the design's own rulings, and `ASM-001`/`ASM-002` as
  validated rather than assumed.
- The marker invariant: no inject the front end runs can reach a clone whose
  scrub has not finished, however the clone ended.

## Synthesis

**Verdict: closeable.** Thirteen findings, no blockers, one fixed in the audit,
four to the reconciliation brief, four to the backlog, four tolerated or
aligned. The thing the slice was built to make safe — that no inject the front
end runs can reach a clone whose scrub has not finished — held under every
reading it was given, including a live one.

### The closure story

`SL-002` set out to replace a hand-typed `sudo rm -rf /var/lib/microvms/<slot>`
with three verbs, and to make a warm start possible without carrying the source
capsule's identity onto the destination. Both shipped. The marker invariant is
pinned by `volumeCases` at every status the guest can return, and PHASE-06 ran
it live: two clones back to back kept the first marker's timestamp, and the gate
ran scrub, marker removal and inject in one invocation on a real guest, with the
host key's fingerprint changing and the credentials becoming this host's.
`ASM-001` and `ASM-002` were both **validated** rather than carried, and the one
STOP condition the plan armed — `VH-7`, whether the front end's own ssh traffic
makes the gate refuse its own clone — was probed in isolation with a control
that proved the read discriminates, and did not fire.

The audit found nothing wrong with the deleting. Every finding that touches
behaviour is about a **check** rather than a delete: a guard whose call site
nothing pins (`F-6`), a `fuser` test that fails open when it cannot answer
(`F-11`), and a probe that answered half the question it was asked (`F-9`).
That distribution is worth noticing — the phases that built the destructive
paths were audited hardest during execution, on `RV-003` and `RV-004`, and it
shows.

### What the mechanical signal was worth, and what it could not see

`slice conformance` pointed at one real lead out of fifteen cells:
`host/policy-cases.nix`, edited in PHASE-05 and declared by no `design-target`
selector. Eleven of its fourteen `undeclared` paths are `.doctrine` bookkeeping
that no source selector should ever claim, and its single `undelivered` entry,
`vm/guest-path.nix`, is a registry gap rather than dropped work.

The registry's two actual defects were invisible to it. `slice conformance`
compares recorded ranges against selectors; it cannot ask whether a *range* is
the range its phase landed. Reading `boundaries.toml` against
`git log --reverse` over the slice's span found both in one pass: the eight
`RV-004` remediation commits belong to no phase (`F-3`, known and parked), and
PHASE-06's row covers an unrelated chore while excluding PHASE-06's own commit
(`F-4`, new). **That read is cheap and should be standard**: a wrong range is a
silent class, and the current tooling has no signal for it.

The same shape appeared a third time, one level up. `design show --format
status` reported `review_pass STALE` against a run locked at revision 75 with
zero outstanding sections and zero changes since baseline — three readings that
could not all be right. The flag is computed correctly from
`[review.pass].covered`, which the revision-72 disposal left at the revision-58
attestation set while updating the review id beside it. What the audit actually
leans on — eight current attestations and a human acceptance act naming `F-1`,
`F-2` and `F-6` by their fixes — covers the design's current text exactly. The
lock is what it looks like.

### Standing risks

- **`RSK-008`** — the eval guard over target-derived paths spliced into a root
  `rm` is pinned; the call site that reaches it is not. Dropping the call from
  `vm/capsule.nix` reddens nothing, because the suite imports the function
  directly and this host's values are plain either way. Closing it needs `mkVm`
  parameterised by target and a second NixOS eval in `just build`.
- **`ISS-010`** — `notHeld` reads any `fuser` failure as "nothing holds it", in
  the check design sec-2 calls *the real guarantee*. Bounded by the existence
  test above it and by a host whose `/proc` root can read; wrong direction for
  what it guards.
- **`CHR-014`** — `RV-004` `F-5` is half-answered. `setup`'s `provisionSlot`
  push is the heavier probe and the only remaining path that could reproduce it,
  and it is the path `DEC-006`'s warm start takes. Fail-safe if real: a warm
  start that cannot complete without a stop.
- Carried, not this audit's: `RSK-004` (the two copies of the front end are one
  store path by construction, unchecked) is the same unverified-by-construction
  shape as `RSK-008`, and PHASE-03 recorded that nothing compares them.

### Tradeoffs consciously accepted

- **`VH-5`'s reset half is a weaker claim than `VH-5`'s text.** The `start` half
  raced a real 6.7 GiB clone; the `reset` half raced a lock held by `flock -x`,
  because the clone gives about 17 seconds and `sudo -k` puts a password prompt
  in front of the reset. Same lock, same branch, same refusal — and the
  difference is written into the record rather than rounded away (`F-8`).
- **The clone trap is a suite-only guarantee.** `cp` refuses before creating
  anything, so no live failed copy reaches the `EXIT` trap; a post-copy failure
  case does. Already stated in sec-8 and the notes, and dispositioned here so a
  passing `VH-6` beside it is not read as covering it (`F-10`).
- **Two seams diverge from the design text because a sandbox cannot stub what is
  in `runtimeInputs`.** `volumeControl` carries `vmmState`, and `reset-home`
  tests for a door rather than an answer. Both are the boundary CLAUDE.md says
  to respect; the text moves to them, not the other way (`F-7`).
- **The registry repair over-attributes, and says so.** Widening PHASE-04 to
  `6d101b0..8cb44df` is the only shape `record-delta` accepts and sweeps in six
  unrelated commits. The alternative leaves conformance red with no record of
  why. Choosing the first with the cost written down beats choosing the second
  by default.

### What this audit did not exercise

No live host work: the fleet was left as PHASE-06 left it, `a` a scrubbed-pending
clone of `d`, `c` untouched and driving `SL-251`. Nothing was re-run against a
real guest, so every live claim here rests on PHASE-06's readings as recorded.
The gate was run (`just check` ok, `just` exit 0 over build, `hostModuleUnits`,
fourteen `*Cases` suites and fmt) and `verify-vt` passes every `VT` on
PHASE-01..05 — but `doctrine check gate` itself does not run in this repo
(`F-12`, `CHR-015`), so the cadence alias is untested rather than green.

## Reconciliation Brief

Four findings write. `F-1` was fixed in the audit; `F-5`, `F-8`, `F-10` and
`F-13` are terminal with no write; `F-6`, `F-9`, `F-11` and `F-12` left the slice
as `RSK-008`, `CHR-014`, `ISS-010` and `CHR-015`.

### Per-slice (direct edit)

- **`design.md` sec-8, code-impact table** (`F-2`) — add two rows:
  `vm/guest-path.nix` | **new**: the eval guard over target-derived paths
  spliced unquoted into the guest's root `rm` (`RV-004` `F-4`); and
  `host/policy-cases.nix` | the absent-image-root guard, so `status` does not die
  under `set -e` on a host with no image root.
- **`design.md` sec-7, seam table** (`F-7`.1) — add the `vmmState` row beside
  `volumeControl`'s: `vmmState() { unitState "$(unitOf "$1")"; }`, substituted by
  a suite for the slot's `microvm@` unit state, because `pkgs.systemd` is in the
  front end's `runtimeInputs` and a sandbox reads every unit as `--`.
- **`design.md` sec-2, flowchart node A and the prose above it** (`F-7`.2) —
  "admin door answers?" becomes "has a door"; the front end runs
  `door "$name" probe`, a `-S` test on the socket. A guest that does not answer
  behind a live door fails the ssh call and is reported with its status.
- **`design.md` sec-2, the `ASM-001` bullet** (`F-7`.3) — a detached baseline
  leaves **two** `agent` sessions: the run, in `closing`, and a log tail over a
  second ssh that stays `active` after its host client dies. Both refuse, so the
  rule is unchanged.
- **`design.md` sec-6, the sample free line** (`F-7`.4) — drop "images":
  `(2 outside the pool: capsule, capsule-b)`, matching the section's own rule
  sentence and `host/cli.nix:1109`. A leftover with no image must still be seen
  (`CHR-013`).
- **`design.md` sec-6** (`F-7`.5) — one sentence that the free figure is a
  whole-filesystem `df` and moves with any capsule on the host, so it is not
  stable between two readings taken around a clone.
- **`design.md` sec-4, step 5** (`F-7`.6) — the config links land under
  `volumePath` beside `$HOME`, not in it (`vm/capsule.nix:71-76`; for this target
  `/work/.cargo/config.toml`). This settles `notes.md`'s "unverified sub-claim":
  the reset `$HOME` held no symlinks because none were ever there.
- **`notes.md`, `## PHASE-06` exercise 5** (`F-8`) — state `VH-5`'s reset half at
  its evidence: *refuses while `capsules.volumeLock` is held exclusively*, not
  *while a clone is running*. The `start` half keeps the stronger claim.
- **`notes.md`, beside the registry repair** (`F-3`) — record that PHASE-04's
  widened range over-attributes six unrelated commits, so the next reader of
  `boundaries.toml` is not misled.

### Structured (slice registry — the load-bearing half)

- **`doctrine slice selector add`** (`F-2`) — `host/policy-cases.nix` as
  `design-target`. Conformance reads `design-target` only; `host/*-cases.nix` is
  `scope-relevant` and does not count. The sec-8 row above is its mirror, not the
  fix.
- **`doctrine slice record-delta SL-002 PHASE-04 --start 6d101b0 --end 8cb44df`**
  (`F-3`) — brings the eight `RV-004` remediation commits into the registry and
  moves `vm/guest-path.nix` from `undelivered` to `conformant`. Cost, stated:
  `README.md`, `docs/contract-doctrine.md` and `flake.lock` join the `undeclared`
  cell from the six unrelated commits in the window, each dispositionable as
  exactly that.
- **`doctrine slice record-delta SL-002 PHASE-06 --start 0ab598b --end fdfad31`**
  (`F-4`) — replaces a row covering an unrelated chore's `justfile` change with
  the phase's own evidence commit. No conformant cell moves; `justfile` is
  already delivered by PHASE-01..03.

### Governance/spec (REV)

None. `SL-002` carries no `specs` and no `requirements`; `POL-001`..`POL-004`,
`STD-001` and `ADR-001`..`ADR-003` were all confirmed at the design run's
`cpa-governance-confirmed` act and none is contradicted by what shipped. The
`POL-002` surface that did need updating is `docs/contract-target.md`, a repo
document, fixed under `F-1`.

### Not reconcile's, recorded so it is not lost

`F-5` — the doctrine CLI's `review_disposed` write leaves `[review.pass].covered`
at the previous disposal's snapshot, which is why a locked, fully-attested design
run reports `review_pass STALE`. Another repo's defect; this run
(`dr-01a0a2ae-bcb8-7b80-a3f3-53dcbaf0706e`, revisions 58 → 72) is a clean
reproduction if it is ever reported upstream.
