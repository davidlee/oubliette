# Review RV-008 — reconciliation of SL-001

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

The closure audit of `SL-001` (*a slot may declare which target it is for*).
Six phases `completed`, lifecycle moved `started → audit`, head `b243d8d`, tree
clean apart from the user's `flake.lock`.

**Surface reviewed.** The main worktree at `b243d8d`. This slice was driven
solo, not by `/dispatch`, so there is no candidate branch. The subject is
`git diff 648f98f..b243d8d` outside `.doctrine/`: 17 files. PHASE-01…05 built
it, and PHASE-06 produced live evidence only.

**Gate, run before raising.** `just` exited 0: check, build, `hostModuleUnits`,
every `*Cases` suite and fmt. `doctrine slice verify-vt SL-001` passes every
`VT` except PHASE-05 `VT-4`, which is unattributable by construction (see
`F-5`). `doctrine check gate` still resolves to a `just gate` recipe that does
not exist; that is `CHR-015`, filed from `RV-006`, so it is not raised again.

### Lines of attack

1. **Does the registry tell the truth?** `slice conformance`'s undeclared and
   undelivered cells, and whether each recorded phase range is the range that
   phase actually landed.
2. **Does the code do what design sec-2…sec-4 say?** Every row of sec-5's code
   impact table and sec-4's prose table; every row of sec-3's caller table;
   `provisionSlot` and `recordProvisioned` under errexit; `handoff`'s path
   comparison and its ordering against anything destructive. This lane ran as
   an independent read-only pass over the diff.
3. **Can each case fail?** The design names a case for most mutations; the
   phase sheets' VA logs are the evidence, and they are disposable
   (gitignored).
4. **Is each claim's evidence its own?** `STD-001`: VH-2 is a refusal, not a
   push, and must not be read as a completed provision from panopticon's path.
5. **What was found and never filed?** The phase sheets' Findings sections and
   the notes' "fourth pass" questions.

### Invariants the slice is held to

- `POL-002` as revised by `REV-001`: the target's name appears in code only in
  `target.nix`, `inputs.target.url` and `capsules.nix`'s `profile` values, plus
  the declared `.doctrine/` layout fixtures.
- `POL-003` as revised: resolution is the front end's act, in the order flag,
  record, declaration, sole document.
- `POL-004`: every new behaviour is reachable by a case suite through an
  argument, not a host path.
- `DEC-012`…`DEC-016`.
- A provision that exited non-zero is never recorded, and a pin is never left
  without a record except when that one write fails.
