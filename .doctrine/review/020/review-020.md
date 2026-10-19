# Review RV-020 — reconciliation of SL-007

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Conformance audit of SL-007, self-audit (one agent, both roles), on the primary
tree at `495b43c`; no dispatch, so no candidate branch. Subject: PHASE-01..05,
commits `7ce98a2..71f141b`, against design sec-2..sec-7 (sec-4 is the
verification table) and `plan.toml`'s EX/VT.

Lines of attack:
1. **Behaviour vs design sec-2/sec-3.** `session`'s `PATH` order and refusal
   order; `vm/room.nix` renders the base for every room with no
   `ignoreCollisions`; `rooms.nix` refuses bad `extras` with its reason and never
   forces `fragmentNames` for a room without extras; every reader `jq` call is a
   store path and `profile.inputs` is gone.
2. **The suites can fail** (CLAUDE.md "check the suite can fail"): each phase's
   mutation is recorded with the FAIL lines it produced, and the red is the
   suite's, not an eval or shellcheck abort.
3. **Evidence verbs (STD-001).** What each suite proves and does not: case (2)
   proves the text, case (1) runs it; the live rung covers `session`, not the
   three host programs.
4. **Conformance.** `slice conformance` registry and `--against` delta vs
   design sec-7 and the selectors.
5. **Binding sources say one thing** (scope 4, design sec-5): contracts,
   `CLAUDE.md`, `DEC-043`, `DEC-044`'s supersession, `CON-001`, README.
6. **Gate.** `doctrine check gate` (`just check` + full `just build`) at HEAD.

## Synthesis

**The code matches the design; the drift is in the records.** Every line of
attack on behaviour came back aligned, so nothing was raised against code:

- `session` (`vm/session.nix`) builds `PATH` as `[tools/bin:]<base>/bin${PATH:+:$PATH}`,
  refuses a missing `<base>/bin` with exit 2 after the usage, name and repo
  checks, and keeps `runtimeInputs = []` (design sec-2).
- `vm/room.nix` renders `room-base` for every room from `fragments.compose`
  with no `ignoreCollisions`, links it at `/etc/room/base` and puts it in
  `systemPackages` in place of `pkgs.git`; `roomChecks` in `mkfleet.nix` throws at
  eval if either half is missing (mutated both ways at PHASE-03).
- `rooms.nix` checks shape before content, so a non-list or `[1]` is a reason,
  not a type-error abort; `fragmentNames` is never forced for a room with no
  extras (`roomsCases` case 22, `fragmentNames = throw`).
- `host/profile.nix` calls `${jq}` in all seven reader calls; `inputs` is gone
  and nothing reads it. `profileCases` (1) runs the text with no `jq` on `PATH`
  and checks a value from each reader call, since errexit is off inside
  `profileRead`; (2) checks the reader's `<jq> -e` in all seven shipped splicers.
- Each phase recorded a mutation red that came from the suite (FAIL lines), not
  from an eval or shellcheck abort. The design sec-4 `hostModuleUnits` row was
  correctly placed in `profileCases`: `hostModuleUnits` only evaluates and cannot
  read a built program's text.
- `doctrine check gate` at `495b43c`: `just check` and the full `just build`
  (every suite, `roomImages`) rc 0, zero FAIL lines. `doctrine slice verify-vt 7`:
  14/14 VT pass.
- Live (PHASE-05): `env -i … session doctrine -- sh -c …` printed
  `PATH=/etc/room/repo/doctrine/tools/bin:/etc/room/base/bin:/no-such-path` and
  `git` and `rg` under `/etc/room/base/bin`; before the refresh, no `git` at all —
  IMP-017's defect, seen live and then gone.

**Standing risks, accepted, not findings** (STD-001: what the evidence does not cover):
- No suite runs `capsule-refresh`/`-brief`/`-baseline`, and none ran live with no
  system `jq`. Case (2) proves each one's text holds the reader's call; case (1)
  proves that text runs. Together they leave only "the program reaches the
  reader", which is the program's own pre-existing behaviour.
- Two extras colliding is not cased; it is the same `buildEnv` behaviour the
  floor collision showed by hand (PHASE-03 EX-5; the first conflict was under
  `libexec/`, not `bin/git`).
- Collisions between the base and the rest of `system-path` are unchecked
  (`ISS-025`'s mechanism); `session` does not depend on it.
- `emacs` is built only in the consumer, never in a fixture; it brings mailutils
  binaries into the base. Image size, not correctness.
- `search` overlaps `agents` (`ripgrep`, `fd`); identical store paths, so
  `buildEnv` accepts them if one room selects both.

**Findings.** F-1 (major) and F-2 are governance drift for reconcile: DEC-044
still reads accepted with no supersede edge, and CON-001 overstates for rooms.
F-3 is selector/sec-7 lag over in-scope edits. F-4 and F-5 were fixed in the
audit (PHASE-05's delta row; a README paragraph). F-6: the user accepted the
live outputs (VH-1) on 2026-10-19.

## Reconciliation Brief

### Per-slice (direct edit)
- **F-3** — selector registry (load-bearing): `doctrine slice selector add` as
  `design-target` for `fabric-cases.nix`, `host/guard-cases.nix`,
  `host/netns-cases.nix`, `host/room-verbs-cases.nix`, `docs/plan-f-assistant.md`,
  `README.md`. Mirror: design.md sec-7 gains rows — the four fixture appliers
  "pass `fragmentNames = []`", `docs/plan-f-assistant.md` "re-point DEC-044 to
  DEC-052", `README.md` "§ Rooms names the base and `extras`".

### Governance/spec (REV / knowledge verb)
- **F-1** — `DEC-044`: status → superseded, with a `supersedes` edge from
  `DEC-052`. `doctrine supersede DEC-052 DEC-044` was a no-op at PHASE-04, so use
  the verb that actually records it (`doctrine knowledge status`/`edit`, or
  `doctrine link`), then confirm with `doctrine inspect DEC-052`.
- **F-2** — `CON-001`: statement narrowed to slots ("One extras list for the
  fleet's slots…; a room selects its own, DEC-052"), and a relation to `DEC-052`.

## Reconciliation Outcome

The user agreed all three items (2026-10-19). Knowledge records are not REV
targets (a REV row takes a spec, requirement or ADR), so F-1 and F-2 went
through the knowledge verbs, as PHASE-04 did for DEC-043. No REV.

### Direct edits applied
- **F-3**: `doctrine slice selector add 7 … --intent design-target` for
  `fabric-cases.nix`, `host/guard-cases.nix`, `host/netns-cases.nix`,
  `host/room-verbs-cases.nix`, `docs/plan-f-assistant.md`, `README.md`.
  design.md sec-7 gains the three mirror rows. `slice conformance 7 --against
  8f55b0b..HEAD`: undelivered 0, conformant 27, undeclared only `.doctrine/`
  records. The registry view lists `README.md` undelivered, correctly: its edit
  landed in the audit commit (F-5), which no phase row covers.

### Governance records
- **F-1**: `doctrine knowledge status DEC-044 superseded`. Correction to the
  finding: the supersede edge was never missing. DEC-052 `supersedes =
  ["DEC-044"]` and DEC-044 `superseded_by = ["DEC-052"]` have been in the
  `[relationships]` table since the design; `doctrine inspect` does not render
  that table. Only the status was stale.
- **F-2**: CON-001's statement narrowed to slots, with a sentence that a room
  selects its own extras (DEC-052); `doctrine link CON-001 references --role
  concerns DEC-052`.

Reconcile pass complete; handoff to /close.
