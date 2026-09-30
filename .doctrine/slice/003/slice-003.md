# A slot boots its own image, so a second target runs beside doctrine

## Context

The trigger is a real second target: `~/dev/goad-walk`, a flake whose
`packages.x86_64-linux.default` is the tool set a goad kit walk runs with (goad,
goad-emit, ruby, jq; goad-check and goad-kit once goad exports them). It must run
**beside** doctrine, not instead of it. Existing capsules may be disrupted by
this work — the user's call, 2026-09-30: the design going forward matters, not
preserving what is running (`DEC-023`).

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

Revised after the design inquiry (2026-09-30); the decisions are `DEC-017` to
`DEC-023`.

1. **A runner names its target, and a profile verb checks it** (`IMP-012` in
   intent). Every image carries `capsule.target=<name>` on its kernel command
   line (`DEC-021`). The front end reads it through `booted` at use and pins
   nothing; the record's `image` field stays `IMP-003`'s (`DEC-022`). A
   profile verb refuses unless the running image names the resolved profile's
   target, and an image with no marker refuses too (`DEC-023`). That one rule
   also closes `ISS-011`.
2. **Targets become a declared set, passed as an argument.** `target.nix` is
   replaced by `targets/<name>.nix`, listed by hand in `targets/default.nix`,
   which derives `name`, `guestPath` and `cachePaths` once; `volumePath` is the
   capsule's (`DEC-018`). Generic code (`mkVm`, `vm/capsule.nix`,
   `host/profile.nix`, `host/services.nix`) takes the set and a name→flake map
   as arguments, and `flake.nix` is the one site binding this host's values —
   the seam `IMP-015` needs. Each tool-set flake is a literal input: `target`
   stays doctrine's and `goad-walk` is added (`DEC-019`).
3. **One image per target, each slot bound by its `profile`.** A declared
   slot's `profile` is required and selects its image; eval throws when it
   names no target (`DEC-017`). Every image is `hostName = "capsule"`;
   `nixosConfigurations` stays `hello`, `capsule` (doctrine's, the probes'
   subject) and the slots, and each target's runner is a packages-only
   `image-<target>` (`DEC-020`).
4. **goad-walk declared as the second target** and one slot bound to it.
   `DEC-016` is superseded at reconcile, once the split is true on this host.
5. ~~Capsule `c` is untouched.~~ **Withdrawn by the user (2026-09-30).**
   Every capsule booted before this slice refuses profile verbs until restarted
   onto a marked image (`DEC-023`), and that is accepted.

## Non-Goals

- **`IMP-003` / Plan D D7** — per-*assignment* extras selection, gcroots, and
  the dirty-volume recompose refusal. This slice is per-*slot* and per-*target*;
  extras stay fleet-wide (`CON-001` holds for extras).
- **`IMP-013`** staleness reporting in `status`. It reads the same `booted`
  observation (`DEC-022`) and can follow; not required to run goad-walk.
- **Making goad-walk fetchable.** Owned by the user, upstream, and a
  precondition of objective 4 (below). This repo refuses a `git+file:` or
  path input for a target (`ISS-015`).
- Per-target allowlists or collect bounds — those are policies, already per
  slot (`NOTES item 36`).

## Affected surface

`flake.nix` (inputs, `targetFlakes`, `mkVm`, `packages.image-<target>`,
profile renders, probe preludes), `fleet.nix` (new: the pure target → image →
slot binding), `target.nix` → `targets/`, `capsules.nix` (slot `profile`
binds; comments), `vm/capsule.nix` (tool set from `targetFlake`, the marker),
`host/cli.nix` (the marker reader and the refusal at profile-verb dispatch),
`host/profile.nix`, `host/programs.nix`, `host/services.nix`, the case suites
(`policyCases`, `profileCases`, `resetHomeCases`, and a new `fleetCases`),
`justfile`, `docs/contract-target.md`, `docs/contract-assignment.md`,
`README.md`, `CLAUDE.md`.

## Preconditions (user-owned)

- goad's `main` pushed (it is 57 commits ahead of `origin`).
- goad-walk's `goad` input changed to `github:davidlee/goad`, its `flake.lock`
  committed, and goad-walk pushed to a fetchable remote.
- If either repo is private, fetch credentials wherever the image is built,
  including `~/flakes`.

## Risks

- **Doctrine's image changes** — by the `capsule.target` kernel parameter
  (`DEC-021`) at least. Accepted; no preservation goal.
- **Process identity.** A second image must not make `pkill -f` by name look
  safe. Every image keeps `hostName = "capsule"` (`DEC-020`), so every VMM is
  still `microvm@capsule` and is identified by its namespace alone.
- **Build cost.** Each target is another ~3.0 GiB erofs (Plan C's figure, not
  probed) and another toolchain closure in `just build`.
- **goad-walk's guest needs.** panopticon needed nix-ld (`NOTES item 23`); goad
  (ruby) may need a guest capability not yet present. Unknown until booted.

## Open questions

- ~~Shape of the target set~~ — `targets/`, listed by hand (`DEC-018`).
- ~~Where the slot → target binding lives~~ — the slot's `profile` (`DEC-017`).
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

- `just` green, including new/extended cases for: the marker reader and
  `DEC-023`'s three outcomes (match, mismatch, unmarked), over a fixture runner
  tree; eval throws for a slot `profile` naming no target and for a
  `targetFlakes` map that disagrees with the target set; every `image-<target>`
  built, and the reset-home scrub list checked per image.
- goad-walk's image builds from a fetchable input; one slot boots it, the agent
  sees goad's tools and no goad source. Boot is
  VH (by the human), since starting a slot is the user's act on this host.

## Summary

Make slot → image a per-slot answer so goad-walk can run beside doctrine:
a runner that names its target and a fail-closed check, then targets as an
argument with one image each, then declare goad-walk.

## Follow-Ups

- `IMP-013` (staleness) reads `booted` live, as the refusal does.
- `IMP-003` (per-assignment extras) remains open; this slice is its image tier.
- `IMP-015` — oubliette carries no target; the fleet's declarations move to a
  consumer flake. Out of scope here, but this slice lays its seam: generic code
  takes the target set as an argument and `flake.nix` is the one binding site.
