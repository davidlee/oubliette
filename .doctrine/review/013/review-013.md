# Review RV-013 — reconciliation of SL-004

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Surface reviewed: the primary checkout, `main` at bb179e7 (no dispatch; capsule-driver in the main tree). Mode: conformance.

Lines of attack:

1. **Derivation neutrality** (design sec-6, ASM-003). Every phase's manifest diff is either empty or explained in notes.md. Check the explanations name a cause, not a shrug: the fleetCases baseline move (PHASE-03), the three suites (PHASE-07), the hostModulePrograms third home of policyDir (PHASE-09), the 23 entries of f2b8376.
2. **Boundary** (POL-002, POL-003). Oubliette's lock holds no target; no real declaration remains in its tree; mkFleet's surface is the eight owner-grouped arguments with no default; nothing under host/, vm/, perimeter/ imports a declaration.
3. **Gates** (design sec-5). Oubliette's `just` is green over the fixture and includes templateCases; every suite that ran before still runs.
4. **Design vs what happened.** Where the cutover, the ~/flakes wiring or the builder curry departed from design sec-7/sec-10, the design must be made to tell the truth.
5. **Governance footprint** (design sec-8). Which records still place a target in oubliette's flake.nix.
6. **Conformance registry.** Undeclared / undelivered cells, and whether the registry covers every commit of the slice.
7. **Loose ends.** Deferred work has a backlog home; memories that the cutover made stale are named.

Evidence run this session: `just` (default: check, build, template-cases, units) exit 0; `doctrine check gate` exit 0; `doctrine slice conformance 4` before and after extending PHASE-09's delta to bb179e7. Manifest figures are taken from notes.md, not re-derived.

## Synthesis

**Closure story.** SL-004 did what it set out to do. Oubliette's lock holds no target (`target` and `goad-walk` nodes are gone since 1284c5a); its flake calls `mkfleet.nix` over `fixture/`. `lib.mkFleet` takes the eight owner-grouped arguments, none defaulted. The real declarations live in the private consumer at `/srv/fleet`, which this host now runs on: ten slots, every `/var/lib/microvms/*/flake` re-pointed, `~/flakes` switched, one `refresh-build` and `capsule all status` run by the user. Oubliette's `just` is green over the fixture, including `templateCases`, which this audit re-ran (exit 0), along with `doctrine check gate` (exit 0).

Derivation neutrality, the slice's main claim, was held to the manifest at every phase. Each difference is explained in notes.md with a cause that was checked mechanically:
- `fleetCases` at PHASE-03 (the DEC-019 cases were deleted);
- three suites at PHASE-07, whose text took the caller's slots and injections;
- `policyDir` at PHASE-09, which has three homes rather than the two the design named (F-7);
- the 23 entries of the post-cutover wording pass, f2b8376, each shown equal to its old closure once the edited lines are substituted back.

This audit read those figures from notes.md and did not re-derive them.

**What the findings say.** No blockers. The code matches the design wherever the design was right. Most findings are records that went stale because the work outran them:
- governance still places targets in `flake.nix` (F-1, F-2, F-3, F-4);
- the design's `~/flakes` wiring was wrong, and the applied wiring is the truth (F-5);
- the design misses one input in the builder curry (F-6) and one home of `policyDir` (F-7);
- the selector registry is stale (F-8).

Fixed in this audit: the doc drift (F-9), two memories (F-11), and the lifecycle state (F-13). The registry gap (PHASE-09's delta stopped at 919b294) was closed by extending that delta to bb179e7. F-12 records that the user waived the "no `~/flakes` edits" non-goal. Two follow-ups were minted: CHR-017 (the `microvm-spike` fallback) and ISS-018 (an implicit policy-name requirement the move made generic, F-14).

**Standing risks.**
- The consumer's gate (`just` in `/srv/fleet`) runs only when someone runs it. Nothing checks the consumer when oubliette changes (design sec-9; stated, not solved).
- `.oubliette` and the devshell's binaries name the *locked* oubliette. Inside `/srv/fleet` an oubliette edit does nothing until the consumer is relocked or overridden.
- The manifest instrument excludes `devShells`, `checks` and `lib`, so shellHook and devshell changes (PHASE-05, PHASE-08) never showed in any manifest diff. They were checked by other means.
- ISS-018: every caller must declare policies named `build` and `sealed`.

**Tradeoffs accepted.**
- Plan criteria that turned out too narrow (the baseline after PHASE-03, `hostModulePrograms` at PHASE-09, `templateCases` in the default gate instead of `build`) were amended by rulings in notes.md, because plan.toml is immutable.
- The deferred wording shipped after the cutover so that the closure diff stayed quiet. The cost was a second manifest move, explained above.

**Human route.** The participating systems are oubliette `flake.nix` → `mkfleet.nix` (the builder) → `fixture/`, the private consumer `/srv/fleet` → `~/flakes` (the `fleet` input) → the host module. The important behaviour is that `borrowed` still throws in every caller's eval (`mkfleet.nix:1029-1040`); PHASE-04 and PHASE-07 each mutated it to watch it throw. `templateCases` (`templates/template-cases.nix`) is what keeps the public template wired to the builder. Sources that matter: `doctrine policy show POL-002` (the search rule, now stale), `doctrine show DEC-019` (to be superseded), and `doctrine show DEC-025` (the builder, as amended).

## Reconciliation Brief

### Per-slice (direct edit)
- **F-5** design.md sec-7 step 8:
  - `fleet` takes only `inputs.nixpkgs.follows`, and no target shims, because the module evaluates each target's guest image and needs `packages`;
  - the override comes from `~/flakes/bin/dev-checkouts` (`fleet` → `$FLAKES_FLEET`, default `/srv/fleet`), not `justfile:14`;
  - `~/flakes/flake.nix:189`, not `:193`.

  slice-004.md "Settled with the user": the shims do not move onto the fleet input; they go.
- **F-6** design.md sec-10: the curry closes over `nixpkgs`, `microvm` and `doctrine`, where `doctrine` is the devshell's governance CLI (as sec-1's `doctrine*`).
- **F-7** design.md sec-6 step 3: `policyDir` lives in units, tmpfiles and the wrappers' `CAPSULE_POLICY_DIR` default (host/wrap.nix), so the expected difference is `module` and `hostModulePrograms`.
- **F-8** selector registry (load-bearing; design.md sec-2/sec-5 is only the mirror):
  - `doctrine slice selector rm 4 host/policy-cases.nix host/volume-cases.nix host/volume-root-cases.nix host/template-cases.nix`;
  - `doctrine slice selector add 4 --intent design-target templates/template-cases.nix fragments.nix 'host/**' 'vm/**' 'probe/**' fleet-cases.nix flake.lock 'docs/*.md' host-capsules.nix`;
  - drop the scope-relevant rows those subsume;
  - re-run `slice conformance 4`. The only undeclared paths left should be `.doctrine/**`.
- **F-12** slice-004.md Non-Goals and design.md sec-9: note the user's waiver (2026-10-17). The seat made the `~/flakes` cutover edits on the user's word, uncommitted, for `~/flakes` SL-010.

### Governance/spec (REV)
- **F-1** REV modify. The proposed wording is in phase-07's sheet D8, copied here so it survives the sheets:
  - **POL-002**: "may appear in code" → "**only in a consumer flake** — the repo that calls `lib.mkFleet` with its host's declarations: its `targets/`, its target inputs and the `targets` argument pairing each with its flake, its `probe.target`, and a slot's `profile` in its `capsules.nix` — **and, in oubliette, only in `fixture/` and `templates/`**, whose targets are nobody's (SL-004). `inputs.doctrine` in oubliette's `flake.nix` is the governance CLI, not a target binding, and is excluded by name."
    - Smell sentence: "a toolchain's name appearing anywhere but a consumer's `targets/` (or oubliette's `fixture/`/`templates/`)".
    - The Excluded paragraph uses the same list.
    - "the justfile" also covers `just/fleet.just` (phase-05 sheet).
  - **POL-003** homes:
    - addressing → the caller's `net` argument;
    - slots → the caller's `fleet` (a consumer's `capsules.nix`);
    - host controls → the caller's `policies`;
    - confined repos → the caller's `targets`, `<name> = {decl; flake}`, with no second map (DEC-019 superseded);
    - a probe's fabric → the caller's `probe.fabric`;
    - Enforcement/Verification: `borrowed` (mkfleet.nix) throws in every caller's eval, the consumer's over the real slots and oubliette's over the fixture's;
    - `workBranch`: a constant in `mkfleet.nix`.
  - **POL-001** scope: "part of the perimeter lives in `~/flakes`, and the policies and allowlists live in the consumer".
  - **POL-004**: "call sites in `flake.nix`" → `mkfleet.nix` (lines 17, 58, 81).
  - **DEC-017**: "flake.nix throws" → mkfleet.nix/fleet.nix.
  - **DEC-018**: "flake.nix is the only place that binds this host's values" → the consumer's `mkFleet` call.
  - **DEC-020**: `.#capsule` is the probe target's image, in whichever flake builds it; the "until IMP-015" consequence is now met.
  - **CON-001**: `applies_to` and the `extras` home → the caller's `flavour.extras`.
  - **ISS-015**: a note that the placeholder target it did not take is now taken (`fixture/`).
- **F-2** supersede DEC-019 by DEC-025 (each target `{decl; flake}`; no second map, no throw).
- **F-3** REV modify DEC-030 choice: `templateCases` evaluates the template's actual `flake.nix` outputs against stub inputs.
- **F-4** `doctrine knowledge settle ASM-003` as held. Evidence: the PHASE-02/03/04 manifests in notes.md, with `fleetCases` the one explained difference.

### Not for reconcile
- F-9, F-11, F-13 fixed in this audit; F-10 → CHR-017; F-14 → ISS-018.
- IMP-015 (fulfilled by this slice) is closed at `/close`.

## Reconciliation Outcome

The user agreed to the full proposal ("agreed", 2026-10-17).

### Direct edits applied
- design.md sec-7 step 7: `flake.nix:189` (F-5).
- design.md sec-7 step 8: `fleet` gets no target shims, with the reason; the override comes via `bin/dev-checkouts` / `$FLAKES_FLEET` (F-5).
- design.md sec-6 step 3: three homes of `policyDir`, two manifest entries (F-7).
- design.md sec-10: the curry closes over `doctrine`, devshell only (F-6).
- design.md sec-9 and slice-004.md Non-Goals: the user's waiver for the `~/flakes` edits (F-12).
- slice-004.md "Settled with the user": the shims went rather than moved (F-5).
- Selector registry (F-8): removed the four untouched files and the narrow selectors now subsumed; added `host/**`, `vm/**`, `probe/**`, `perimeter/**`, `docs/*.md`, `fragments.nix`, `fleet-cases.nix`, `flake.lock`, `templates/template-cases.nix` and `host-capsules.nix` as design-target. `slice conformance 4`: undelivered 0; the only undeclared paths left are `.doctrine/**`. `selector doctor` reports the four deleted files (`policies.nix`, `net.nix`, `setup.nix`, `host-capsules.nix`) as unmatched, which is expected, since their deletion is the delivery.

### REVs completed
- REV-003 (`reconcile-sl-004`): done. Modified POL-002 (primary), POL-003, POL-001 and POL-004, landed by hand (F-1). POL-004 also states the `templateCases` gate exception (the PHASE-08 ruling). Rationale in revision-003.md.

### Knowledge and backlog records
- DEC-019 superseded by DEC-025, status `superseded` (F-2).
- DEC-030 choice reworded (F-3).
- DEC-017, DEC-018 and DEC-020 choices reworded; DEC-020's consequence marked met (F-1).
- CON-001: `applies_to` and body updated (F-1).
- ASM-003 validated (F-4).
- ISS-015: note appended (F-1).

### Found during reconcile, not acted on (hand back to /audit)
- POL-002 § Verification still says "a second target has never been declared (IMP-004)" and that three absent paths (`baseline = null`, `caches = {}`, `guestConfig = {}`) are "only reasoned" (RSK-002). goad-walk has been a second declared target since SL-003, and `fixture/` now builds all three absent paths. That section, and possibly IMP-004 and RSK-002, need re-reading. This is a new gap, not part of the brief.

Reconcile pass complete; hand off to /close.
