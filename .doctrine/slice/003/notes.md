# Notes SL-003: A slot boots its own image, so a second target runs beside doctrine

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-01 · PHASE-01 complete · 412b77f

### Produced
- `design.md` sec-1..sec-6 (locked 2026-10-01; human-attested)
- DEC-017, DEC-018, DEC-019, DEC-020, DEC-021, DEC-022, DEC-023, DEC-024 (accepted)
- RV-009 (agent pass; F-1, F-2 fixed and verified)
- RV-010 (external pass, gpt-6-sol; F-1..F-6 fixed and verified)
- ISS-016 (filed, then resolved fixed in 412b77f)
- IMP-015 (filed; needs SL-003)
- mem.fact.oubliette.booted-is-the-running-runner
- plan.toml/plan.md (five phases); PHASE-01: host/own-vms.nix, perimeter/root.nix, vm's booted link (412b77f)
- CHR-016 (filed: root spellings left in probes/justfile)

### Learned
- mem.fact.oubliette.booted-is-the-running-runner
- user preference (session memory, not corpus): don't design around live capsules

### Open
- DEC-016 supersession — at reconcile
- POL-002 / POL-003 / CON-001 revisions — at reconcile (design sec-2, sec-6)
- ISS-011 — closed by DEC-023 refusal once built (PHASE-02)
- PHASE-02 EN-2: user replied "ok, begin" to "build PHASE-01 and PHASE-02 now, you switch when SL-251 can take a restart" (2026-10-01)
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

### After RV-010 (2026-10-01)

The external pass covered all four probes above. It confirmed from the locked
microvm.nix source that `microvm-run` names `--config-file` on its one `exec`
line, that `kernelParams` land in `boot-source.boot_args`, and that
`microvm.kernelParams` stays out of the guest toplevel. Those are *read*, not
*taken*: sec-6's `take` row still stands. It found nothing missing from the
consumer sweep. Its six findings were all about the devshell path and the
test mechanics, which is where RV-009 had also found the gap.

**No further pass is needed before human section review.** The remaining
unknowns are empirical (the `take` and `start` rows in sec-6), and another
reading pass cannot settle them.

## Baselines (PHASE-02 EN-3, taken at 7989a87, before any PHASE-02 edit)

The oracles for PHASE-02 VA-2, PHASE-03 EX-8 and PHASE-04 EX-8. Taken with
`nix eval --raw`.

- guest toplevel (`nixosConfigurations.capsule.config.system.build.toplevel.drvPath`):
  `/nix/store/jk300x5gblhb28lliz7i3lnvfxsj8x1z-nixos-system-capsule-26.11.20260925.e94cb15.drv`
- runner (`packages.x86_64-linux.<n>.drvPath`, identical for `capsule` and every
  slot a–j): `/nix/store/k5vj289vfjmxh45534871lyfzp61p2wz-microvm-firecracker-capsule.drv`

## The take (PHASE-02 EX-6 / VA-2, 2026-10-01, at 7df94bd)

`nix build .#capsule` → `/nix/store/hqvm649jhskys2q4mv12abgycifjj4wm-microvm-firecracker-capsule`.

- `bin/microvm-run` line 21: `exec -a "microvm@capsule" …/firecracker-1.16.1/bin/firecracker --config-file /nix/store/l17x74m9p9001213kq194gzrj40m64ym-firecracker-capsule.json --api-sock capsule.sock --enable-pci ${runtime_args:-}`.
  bootedTarget's sed picks out the config path. This matches the shape of the
  policyCases fixture.
- `boot-source.boot_args` ends `… init=/nix/store/qldhwhj3…-nixos-system-capsule-…/init regInfo=… capsule.target=doctrine`.
  bootedTarget's pipeline over it prints `doctrine`.
- The guest toplevel drvPath is unchanged from the baseline (`jk300x5…`); the
  runner drvPath moved `k5vj289…` → `ds4b4vw…`, as expected. DEC-021's premise
  is compared, not just read.

Not taken: the reader run through the shipped front end against a live slot.
That is VH-1, at the user's switch.

## Findings carried to reconcile

- design sec-3 says `profileNameOk` rules out whitespace. It does not (space is
  allowed). vm/capsule.nix now also requires a `[A-Za-z0-9._-]+` token (7df94bd).
  Amend sec-3's sentence at reconcile.
- design sec-6's third mutation (drop bootedTarget's final `|| true` → case 9
  red) does not hold. imageServes runs under `|| exit 1`, which suspends
  errexit, so the guard is defensive. Amend sec-6 at reconcile.
- host/cli.nix gained a `bootedControl` seam, which is not in the design's
  code-impact table (see 7df94bd). Add it to sec-6 at reconcile.
- policyCases case 8 reads the record case 4 wrote, so the cases are ordered.
