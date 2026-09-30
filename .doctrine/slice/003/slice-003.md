# A slot boots its own image, so a second target runs beside doctrine

## Context

The trigger is a real second target: `~/dev/goad-walk`, a flake whose
`packages.x86_64-linux.default` is the tool set a goad kit walk runs with (goad,
goad-emit, ruby, jq; goad-check and goad-kit once goad exports them). It must run
**beside** doctrine, not instead of it — capsule `c` is driving doctrine's
`SL-251` and must not be restarted or re-imaged by this work.

Today that is impossible by values alone:

```
capsules.nix  a..j ──all──▶ capsuleVm  (flake.nix: lib.mapAttrs (_: _: capsuleVm))
                               ▲
              vm/capsule.nix reads target.nix at build time
              inputs.target = github:davidlee/doctrine/edge (a literal)
```

- `DEC-016`: every slot declares `profile = "doctrine"` because the host builds
  one image and it is doctrine's; a split waits on `IMP-006`.
- `IMP-006`: a second target *at once* is a second guest image — +3.0 GiB of
  erofs, its own tool set, its own `target.nix` values. Needs `IMP-004` (done)
  and `IMP-012`.
- `IMP-012`: the record's `image` field is `null` everywhere, written by nobody.
  A slot names the project it was *assigned* and cannot name the project it is
  *running*; today those cannot disagree, and this slice is what lets them.
- `CON-001`: "one image" is an argument about the declaration — the fleet has
  already run as three runner store paths at once.

## Scope & Objectives

1. **`IMP-012` first — a slot records which image it booted.** At `start`, pin
   the runner store path the VMM launched (`/var/lib/microvms/<slot>/booted`)
   into the record's `image`, the way `profile_snapshot` is pinned at provision.
   Refuse when the record's assigned profile and the booted image are for
   different targets. Lands alone, while there is still one image, as insurance.
2. **Targets become a declared set.** `target.nix` (one target) becomes one
   declaration per target, one home for the axis (`POL-003`); each target's
   flake input is its own literal in `flake.nix`. The profile render already
   takes a target as an argument (`IMP-004`); the guest build must too.
3. **One `capsuleVm` per declared target, and each slot bound to one.** The slot
   declaration in `capsules.nix` says which target's image it boots. The
   binding is declared, never inferred from the slot's name (`Plan D` §0), and
   the declared `profile` and the bound image must agree at eval.
4. **goad-walk declared as the second target** and one slot bound to it.
   `DEC-016` superseded by a decision recording the split.
5. **Capsule `c` is untouched.** Rolling this out does not restart, re-image or
   re-provision any running slot; each slot picks up a new image only on its own
   `microvm -u` / restart.

## Non-Goals

- **`IMP-003` / Plan D D7** — per-*assignment* extras selection, gcroots, and
  the dirty-volume recompose refusal. This slice is per-*slot* and per-*target*;
  extras stay fleet-wide (`CON-001` holds for extras).
- **`IMP-013`** staleness reporting in `status`. It consumes `IMP-012`'s field
  and can follow; not required to run goad-walk.
- **Making goad-walk fetchable.** Owned by the user, upstream, and a
  precondition of objective 4 (below). This repo refuses a `git+file:` or
  path input for a target (`ISS-015`).
- Per-target allowlists or collect bounds — those are policies, already per
  slot (`NOTES item 36`).

## Affected surface

`flake.nix` (inputs, `mkVm`, `capsuleVm`, instance binding, profile renders),
`target.nix` → per-target declarations, `capsules.nix` (slot → target),
`vm/capsule.nix` and anything else reading `target` at build time,
`host/cli.nix` / `host/record.nix` (the `image` field and its refusal),
`host/profile.nix`, `host/services.nix`, the case suites pinning those
(`policyCases`, `profileCases`, `vmCases`, `hostModuleUnits`),
`docs/contract-target.md`, `docs/contract-assignment.md`, `README.md`.

## Preconditions (user-owned)

- goad's `main` pushed (it is 57 commits ahead of `origin`).
- goad-walk's `goad` input changed to `github:davidlee/goad`, its `flake.lock`
  committed, and goad-walk pushed to a fetchable remote.
- If either repo is private, fetch credentials wherever the image is built,
  including `~/flakes`.

## Risks

- **Doctrine's runner store path moves.** Refactoring `vm/capsule.nix` to take
  a target argument may change doctrine's image derivation even with identical
  values. Harmless to `c` while it runs (a VMM keeps the path it launched), but
  its next restart boots the new one. Goal: doctrine's image derivation is
  byte-identical before and after objectives 2–3; if not, say so.
- **Process identity.** Per-slot images must not make `pkill -f` by name look
  safe; a VMM is still identified by its namespace (`IMP-003`'s warning).
- **Build cost.** Each target is another ~3.0 GiB erofs (Plan C's figure, not
  probed) and another toolchain closure in `just build`.
- **goad-walk's guest needs.** panopticon needed nix-ld (`NOTES item 23`); goad
  (ruby) may need a guest capability not yet present. Unknown until booted.

## Open questions

- Shape of the target set: a `targets/` directory of one file per target, or one
  attrset file. Either keeps one home; choose in `/design`.
- Where the slot → target binding lives: reuse the slot's `profile` field as the
  image selector, or a separate field. Two fields can disagree; one field
  conflates the operator's convenience with the build (`SL-001` called `profile`
  a convenience, not a control). Choose in `/design`.
- ~~What goad-walk's target values are~~ — **answered by the user
  (2026-09-30):** every field at its absent path. `toolsPackage = "default"`
  and nothing else in the guest: no `extraTools`, `caches = {}`, no
  `statePaths`, `baseline = null`, `refresh = null`. The walk is stdlib-only
  ruby building a new script against an included SDK and test harness, so
  there is nothing to prebuild. This makes goad-walk the first real target on
  `RSK-002`'s absent paths (`IMP-006`'s "what only this tier can buy"). A later
  language may need a new package source through the proxy; that is a policy
  change, not this slice.

## Verification / closure intent

- `just` green, including new/extended cases for: the `image` pin and its
  refusal; a slot bound to a target with no image (eval throw); declared
  `profile` vs bound image disagreement (eval throw).
- Doctrine's image derivation compared before/after (identical, or the delta
  explained).
- goad-walk's image builds from a fetchable input; one slot boots it, the agent
  sees goad's tools and no goad source, while `c` keeps running. Boot is
  VH (by the human), since starting a slot is the user's act on this host.

## Summary

Make slot → image a per-slot answer so goad-walk can run beside doctrine:
`IMP-012`, then `IMP-006`, then declare goad-walk.

## Follow-Ups

- `IMP-013` (staleness) once `image` is written.
- `IMP-003` (per-assignment extras) remains open; this slice is its image tier.
- `IMP-015` — oubliette carries no target; the fleet's declarations move to a
  consumer flake. Out of scope here, but this slice lays its seam: generic code
  takes the target set as an argument and `flake.nix` is the one binding site.
