# Review RV-011 — reconciliation of SL-003

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Conformance audit of SL-003 on main (in-tree, solo; no dispatch candidate),
PHASE-01..05, 412b77f..77dfbe8. The slice's claim: one image per target, a
declared slot boots the image its `profile` names, and goad-walk runs on slot
`j` beside doctrine.

Lines of attack:

- **Path conformance**: `doctrine slice conformance 3` against the selector
  registry and sec-6. Each undeclared path is traced to the commit that made it.
- **design sec-2 invariants**, by grep: only `flake.nix` imports `targets/`;
  outside `targets/`, only `flake.nix` and a slot's `profile` name a real
  target; derived fields are computed only in `targets/default.nix`.
- **Oracles**: drvPaths for the toplevel, hello, `capsule`, a–i and
  image-doctrine are unchanged through PHASE-05, and only `j` moves.
- **Test honesty**: do the refusal cases each discriminate on their own state?
  Mutation is the check, not reading.
- **Carried findings** from notes.md (## Findings carried to reconcile,
  ### PHASE-04, ### PHASE-05), each turned into a ledger finding.
- **Governance** sec-6 set aside for reconcile, and docs that still describe one
  image for the fleet.
- **Human criteria**: PHASE-05 VH-1/VH-2 (j booted by the user) and PHASE-02
  VH-1 (c).

## Synthesis

**Closure story.** SL-003 did what it scoped. `targets/` is the one home of
the target set, `fleet.nix` binds each declared slot to the image its
`profile` names and throws, with a pinned reason, on a map or binding that
disagrees, and the front end refuses a profile verb whose target is not the
running image's (`bootedTarget`, DEC-017/DEC-023). The evidence comes in three
kinds, kept apart (STD-001):

- **Compare**: drvPath oracles exact for everything except `j` across
  PHASE-03..05.
- **Run**: fleetCases, policyCases, profileCases and resetHomeCases are in
  `just`, which is green at 77310cc.
- **Exercise**: the user booted j on image-goad-walk. The verb proceeded,
  `--profile doctrine` refused as a mismatch, goad's binaries were present
  with no source, and the checkout HEAD was goad-walk's `main` (b4bc42f).

**What the audit changed.** F-6 is the one real code finding. policyCases case
8 passed on case 4's leftover record, which is the inherited-wreckage shape
CLAUDE.md warns about, and it was confirmed by deleting case 4. It is fixed and
mutation-checked both ways. F-8 closed plan-d's L1. Everything else is the
design or governance catching up with the code. That is reconcile's work,
listed below.

**Standing risks.**

- c still runs an unmarked image and refuses its own profile verbs until
  `just refresh-build c`. This is designed behaviour (DEC-023). The timing is
  the user's because of SL-251.
- goad-walk's sizes (2 vCPU / 2 GiB / 8 GiB) are a starting point, not a
  measurement. The first real walk checks them, and `volume` is fixed at j's
  first boot.
- The goad-walk input keeps goad's own nixpkgs pin. The lock holds a second
  nixpkgs set, and the image may carry a second glibc. This was accepted for
  parity with goad's devshell, as with `inputs.target`.

**Tradeoffs accepted.** F-7: two plan criteria (PHASE-04 VA-1, PHASE-05 EX-1)
read wrongly and stay as written, because plan rows are append-only. The notes
and this ledger hold what was actually verified.

## Reconciliation Brief

### Per-slice (direct edit)

- **F-1** — selector registry: `doctrine slice selector add 3` (intent
  design-target) for `perimeter/root.nix`, `flake.lock`, `fragments.nix`,
  `host/state-snapshot.nix`, `host/state-snapshot-cases.nix`, `policies.nix`,
  `setup.nix`, `vm/guest-path.nix`, `probe/freshness.sh`, `probe/netns-boot.sh`,
  `probe/netns-egress.sh`, `probe/two-capsules.sh`,
  `docs/architecture-walkthrough.md`, `docs/contract-doctrine.md`,
  `docs/contract-flavour.md`, `docs/design.md`,
  `.doctrine/project-orientation.md`. The registry is what `slice conformance`
  reads. Mirror it in design.md sec-6 with a `perimeter/` row (`root.nix`, the
  one root fragment), a `flake.lock` row, and one row for the `target.nix`
  reference sweep.
- **F-2** — design.md sec-3: correct the `profileNameOk` whitespace sentence;
  name vm/capsule.nix's token assertion.
- **F-3** — design.md sec-6 test cases: the third mutation (drop
  `bootedTarget`'s final `|| true` → case 9 red) becomes "defensive, not
  pinned: its only caller suspends errexit".
- **F-4** — design.md sec-6: the host/cli.nix row gains `bootedControl`.
- **F-5** — design.md sec-3 and the sec-6 fleet.nix row: the interface gains
  `reasons.{images,slotImages}`.

### Governance/spec (REV)

- **F-9** — POL-002: revise the list of where a target's name may appear to
  `targets/`, `flake.nix`'s inputs and `targetFlakes`, the probe subject, and a
  slot's `profile` → REV modify.
- **F-9** — POL-003: its rows for the target axis (`targets/` as the one home;
  a declared slot's `profile` as the build binding) → REV modify.
- **F-9** — CON-001: narrowed to extras (design sec-2) → REV modify.
- **F-9** — DEC-016: superseded by a new decision recording the per-target
  split, citing NOTES items 21, 28, 51, 52 in prose (ADR-002) → new decision +
  supersede.
- **F-9** — IMP-012, IMP-006, ISS-011: resolved or updated by the binding and
  the `bootedTarget` refusal. RSK-002: build and start rungs exercised
  (PHASE-05, j's boot). IMP-015: its SL-003 dependency is delivered → backlog
  edits.
- **F-9** — ledger items 21, 28, 51, 52: the *State:* header only (ADR-002).
