# Notes SL-003: A slot boots its own image, so a second target runs beside doctrine

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: <yyyy-mm-dd> · <PHASE-NN | stage> · <head-commit>

### Produced

### Learned

### Open

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
