# ISS-022: The probe-fabric throw fires only when a probe is built, and its wiring is pinned by nothing

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## The issue

Raised as `RV-017` F-1 (SL-005 audit) and deferred, on the user's choice, until
SL-006 is no longer editing the same files.

1. **The wiring is pinned by nothing.** `fabricCases` pins `fabric.nix`'s
   `borrowed` and `reason` as values. The line that turns `reason` into a throw,
   `fabricPrelude = assert fabricCheck.reason == null || throw fabricCheck.reason;`
   in `mkfleet.nix`, can be deleted with every suite green. SL-005 design sec-9
   row 3 asked for a mkFleet-level verdict ("a fixture variant whose fabric
   names `room-lounge` throws"). Only a hand eval exists (PHASE-04 V5/M1).
2. **The throw fires only when a probe is forced.** It sits in the probe
   prelude, so an eval of `nixosModules`, a runner or `hostModuleUnits` alone
   never meets it. POL-003 and CLAUDE.md say `borrowed` "throws at eval in
   every caller's eval, the consumer's included". This predates SL-005.

## The fix (proposed)

- Move the `assert` from `fabricPrelude` onto mkFleet's returned attrset, so
  forcing any output forces the check. The prelude keeps only its values.
- Pin the wiring in oubliette's own flake, beside `templateCases`: mkFleet
  applied to the fixture with a probe fabric naming `room-lounge` (and one
  naming a slot's `cap-<n>`), with `tryEval` over a non-probe output
  (e.g. `nixosModules` or `hostModuleUnits.drvPath`) reading `false`. The
  reason itself is already pinned by `fabricCases`.
- Mutate: restore the assert to the prelude and watch the new case go red.

Then the policy's wording is true as written, and no revision is needed.
