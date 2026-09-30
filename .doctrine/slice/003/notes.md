# Notes SL-003: A slot boots its own image, so a second target runs beside doctrine

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-01 · design/reviewing (rev 35; RV-009 concluded) · 525dba1+

### Produced
- `design.md` sec-1..sec-6 (revised after RV-009; human section review outstanding)
- DEC-017, DEC-018, DEC-019, DEC-020, DEC-021, DEC-022, DEC-023, DEC-024 (accepted)
- RV-009 (agent pass; F-1, F-2 fixed and verified)
- IMP-015 (filed; needs SL-003)
- mem.fact.oubliette.booted-is-the-running-runner

### Learned
- mem.fact.oubliette.booted-is-the-running-runner
- user preference (session memory, not corpus): don't design around live capsules

### Open
- DEC-016 supersession — at reconcile
- POL-002 / POL-003 / CON-001 revisions — at reconcile (design sec-2, sec-6)
- ISS-011 — closed by DEC-023 refusal once built
- user preconditions for goad-walk (design sec-5)

## Design surface triage (2026-09-30, exploring)

Evidence: `research/research.md` (runtime tier). Questions are the design run's
`inq-*` nodes; this is the prose frame around them.

**Shaping decisions still open** (blocking set): `inq-2` slot→image binding
(`profile` vs separate field); `inq-3` one home for the target set; `inq-4`
tool-set input per target; `inq-5` image naming (hostName / attr / RSK-005);
`inq-6` what `image` holds and how a runner's target is known; `inq-7` record
vs beside-record; `inq-8` one refusal rule for IMP-012 + ISS-011; `inq-9`
proving the rollout does not move `c`. Non-blocking: `inq-10` check coverage.

**Constraining governance:** POL-002 (must be revised: its enumerated-name
list), POL-003 (one home, no default image, missing binding throws), POL-004
(wiring in `flake.nix`, one construction for any new cli argument, RSK-004),
POL-001 (identical guest shape; ruby capabilities in `vm/capsule.nix`),
STD-001 (compare / trigger / run / take / start / exercise named per claim),
ADR-002 (ledger frozen; supersede DEC-016 in prose), DEC-012 alt B (no
by-reference binding).

**Assumptions carried:**
- Doctrine's runner drvPath is unchanged if hostName, values and tool-set
  package are unchanged (reasoned; to be compared).
- goad-walk's absent values spelled as values work in `vm/capsule.nix`
  (researcher eval, not built).
- goad-walk needs no guest capability beyond the floor (unknown until booted;
  ruby stdlib only per the user).

**Risks:** doctrine image drift re-images `c` at its next restart; RSK-005
widened by a per-target attr; ISS-011 made reachable; +~3 GiB erofs and a
second guest eval in `just build`; `~/flakes` lock must fetch the new input.

**Dependencies:** user-owned fetchability of goad-walk and goad; a
never-created slot for goad-walk.

## Further review passes (2026-10-01, reviewing)

RV-009 was one agent pass. It found that the refusal broke the devshell path
(F-1, now DEC-024), which suggests the design's reach beyond the module path
had not been attacked. A further pass would probe:

- **The consumer sweep in sec-2/sec-3.** Is every reader of `target` in the
  seam table? Probe preludes, `hostPrograms`' two call sites and
  `host/services.nix` need a grep, not recall. A missed one fails at eval, so
  it is cheap to find but costs a phase if found late.
- **The runner layout sec-4 depends on.** The `take` row checks the
  firecracker config. It does not check that `bin/microvm-run` names
  `--config-file` in the form the regex expects, and it should.
- **DEC-020's claim** that `microvm.kernelParams` stays out of the guest
  toplevel, so that doctrine's guest system is unchanged apart from its runner.
  It rests on one line of microvm.nix's options and was never compared.
- **The devshell path's other state.** Beyond `booted`, does anything else in
  the design (sec-3's re-binding, sec-5's slot) assume `/var/lib/microvms`?

An external adversarial pass (gpt-6-sol, per the user's standing preference
for design reviews) aimed at those four would be proportionate. A full
inquisition would not: the governance picture has not moved since
`governance-confirmed`.
