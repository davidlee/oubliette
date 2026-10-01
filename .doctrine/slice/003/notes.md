# Notes SL-003: A slot boots its own image, so a second target runs beside doctrine

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-01 · closed (done) · 8652a48

### Produced
- `design.md` sec-1..sec-6 (locked 2026-10-01; human-attested)
- DEC-017, DEC-018, DEC-019, DEC-020, DEC-021, DEC-022, DEC-023, DEC-024 (accepted)
- RV-009 (agent pass; F-1, F-2 fixed and verified)
- RV-010 (external pass, gpt-6-sol; F-1..F-6 fixed and verified)
- ISS-016 (resolved, 412b77f); ISS-011 (resolved, 7df94bd)
- IMP-015 (filed; needs SL-003)
- mem.fact.oubliette.booted-is-the-running-runner
- plan.toml/plan.md (five phases); PHASE-01: host/own-vms.nix, perimeter/root.nix, vm's booted link (412b77f)
- CHR-016 (filed: root spellings left in probes/justfile)
- PHASE-02: marker + bootedOf/bootedTarget/imageServes + bootedControl seam (7df94bd); take recorded below
- PHASE-03: targets/, profile.nix over a set, renderDocs (ff412b1); docs (0b6ca11); guestConfig string re-baseline (7034b86)
- PHASE-04: fleet.nix + fleet-cases.nix, targetFlake, image-<target>, resetHomeCases per image (7229a9d); docs (d116b50)
- PHASE-05: targets/goad-walk.nix, inputs.goad-walk, j bound (77dfbe8); VH-1/VH-2 passed (### PHASE-05)
- RV-011 (audit, done): F-6/F-8 fixed (77310cc); Reconciliation Brief in review-011.md
- REV-002 (done): POL-002, POL-003, CON-001 revised; DEC-016 superseded by DEC-017; IMP-006, IMP-012 resolved, RSK-002 mitigated (8652a48)
- closed: slice `done`

### Learned
- mem.fact.oubliette.booted-is-the-running-runner
- user preference (session memory, not corpus): don't design around live capsules
- mem.fact.oubliette.stubbing-a-vmm-process-in-a-case-suite

### Open
- c's runner is still unmarked (VH-1 was observed on j instead; RV-011 F-10 aligned). Until the user runs `just refresh-build c`, a profile verb on c refuses as unmarked. This is operator action, not slice work; c drives SL-251, so the user picks when.
- Everything else is closed. Reconcile items are in RV-011's `## Reconciliation Outcome` and REV-002. The errexit memory candidate was rejected because it is already in the corpus.

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

### Re-baselined at the end of PHASE-03 (the oracle for PHASE-04 EX-8 / VA-2)

targets/doctrine.nix's `guestConfig` comment now says `targets/doctrine.nix`
instead of `target.nix`. That moves the toplevel on purpose, in its own commit.
`nix-diff` from the old to the new toplevel: the only change is the `text` of
`capsule-.cargo-config.toml` (`←target.nix←→targets/doctrine.nix→`), which
reaches the toplevel through seed-start, unit, system-units, etc and activate.

- guest toplevel: `/nix/store/7mf2xavmzlxvfgz0fgmd2k4n5b587i2l-nixos-system-capsule-26.11.20260925.e94cb15.drv`
- runner (`capsule` and every slot a–j, the same for all 11):
  `/nix/store/6alppgz5z2kx7ifhrb9jbcq91mpib55b-microvm-firecracker-capsule.drv`

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

### PHASE-04 (fleet.nix)

- **The reason is asserted, not just the throw.** This was the user's call on
  2026-10-01, because nix's own errors are hard to read. fleet.nix exposes
  `reasons.{images,slotImages}`, the exact string each attribute throws (or
  `null`), and fleetCases checks that it names the slot or the key. design sec-3's
  sketch has no `reasons`. Add it there at reconcile.
- **VA-1's mutations go red at eval for the missing half, not by name.** Dropping
  the unbound check or the key check makes the next lookup an
  `attribute 'gamma'/'beta' missing`, which `tryEval` cannot catch, so the whole
  suite fails at eval instead of failing a named case. That is still red, but the
  message is nix's. The *extra-flake* half does fail by name (3 cases). Nothing
  reasonable makes an uncatchable eval error catchable.
- **VA-1's deepSeq clause has the direction backwards.** Removing `deepSeq`
  from `throws` does not make a case pass against a broken fleet. It turns
  "the slots, which are images, throw with it" **red against a correct fleet**:
  that throw lives inside the slot values, so WHNF never reaches it. The forcing
  is load-bearing, which is the point of RV-010 F-6, but the plan's sentence
  describes the opposite effect. Amend VA-1's text at reconcile.
- Oracles at PHASE-04's code commit: toplevel `7mf2xav…`, runner `6alppgz…`
  for `capsule`, every slot and `image-doctrine`, `hello` `4vj5406…`. All exact
  (VA-2). `just build-vm` built `image-doctrine` = `6alppgz…`.
- Also fixed: justfile `nix_paths` was missing `policies.nix`, so `just check`
  never parsed or formatted it. It now also lists fleet.nix and fleet-cases.nix.

### PHASE-05 (goad-walk)

- **EX-1's "(inputs.nixpkgs followed)" is not what landed** (user, 2026-10-01).
  goad-walk has no nixpkgs input: it imports `goad.inputs.nixpkgs`, so the
  follow EX-1 names would be a no-op with a warning. The only real alternative,
  `inputs.goad-walk.inputs.goad.inputs.nixpkgs.follows`, moves goad's toolchain
  off goad's own pin, so the guest drifts from goad's devshell. No follow, which
  is the same as `inputs.target`. The lock gains a second nixpkgs set
  (goad's, rust-overlay's, pub's). Amend EX-1's text at reconcile.
- `nix flake lock --update-input` no longer exists. Plain `nix flake lock` adds
  the missing input and moves nothing else. Checked by revision, not by node key
  (adding an input renumbers `nixpkgs_N`): no locked revision was lost, and every
  old root input has the same rev.
- Red: listing goad-walk in `targets/default.nix` without a `targetFlakes` entry
  fails eval with fleet.nix's reason ("no flake for goad-walk (DEC-019)").
- Oracles: toplevel, hello, `capsule`, a–i and `image-doctrine` are exact.
  `j` = `image-goad-walk` = `q1zl3fn…`.
- plan-d-fleet.md L1 still says "every slot declares `doctrine`" and cites
  DEC-016. It is a plan, so it is not present tense. Settle it with the DEC-016
  supersession at reconcile.
- **VH-1 / VH-2 pass** (the user booted j, 2026-10-01). `just up j` created
  and started j. `capsule j provision` went ahead under goad-walk, and the same
  verb with `--profile doctrine` refused as a mismatch. In the guest, `goad`,
  `goad-emit`, `ruby` and `jq` are on `PATH`, no goad source tree is in
  `/nix/store`, and the motd names goad-walk. The checkout's HEAD equals
  goad-walk's `main`, both `b4bc42f`, read in the guest and on the host.
  `remote -v` is empty by design: the seed runs `git init` and provision pushes
  in (`vm/capsule.nix:333`), so a remote is never evidence of whose checkout it is.
  This is RSK-002's start rung for `caches = {}` / `guestConfig = {}`.

## Audit harvest (RV-011, lifted from the phase sheets)

- **`vmmOf` is a rule over `["capsule"] ++ slots`**, not an eval of each VM's
  hostName (PHASE-01). The rule keeps guest evals out of the devshell. It is
  true only while DEC-020 (every image is hostName `capsule`) holds. A
  per-target hostname would break it silently.
- `own_vms` anchors `pgrep -f "^microvm@$1( |$)"`. ISS-016 was a prefix match,
  and the anchor goes beyond the design's text in its spirit.
- **resetHomeCases' run cases use one shipped store path for every image.** This
  is true because the scrub list derives from setup.nix and the shared
  `volumePath`. A per-target scrub list would need a run per image.
- `just build-vm` enumerates `image-*` with `nix eval`, so the justfile names no
  target (POL-002).
- fleetCases' subject is `import ./fleet.nix` applied to a stub `mkVm`, which is
  the library-suite rule in CLAUDE.md.
