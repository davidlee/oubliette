# Oubliette carries no target: a consumer flake declares the fleet

## Context

`IMP-015`. Oubliette's flake names the projects it confines: `inputs.target`
(doctrine) and `inputs.goad-walk` are literal inputs, so anyone cloning this
repo fetches this host's projects, and `~/flakes` needs a `follows` shim per
target input (`oubliette.inputs.{target,goad-walk}.follows = "nixpkgs"`). That
is `ISS-015`'s fetchability problem one layer up.

It is also the precondition for `IDE-002` (Plan F,
`docs/plan-f-assistant.md`): an assistant room over ~7 repos would add seven
more literal inputs here. `SL-003` laid the seam — generic code (`mkVm`,
`fleet.nix`, `host/profile.nix`, `host/services.nix`) already takes the target
set and a name→flake map (`targetFlakes`, `DEC-019`) as arguments, and
`flake.nix` is the one place that binds this host's values. This slice moves
that binding out.

`POL-002` taken to the repo boundary: nothing generic learns what the target is,
and neither does the generic repo.

## Scope & Objectives

```
before                                  after
oubliette/flake.nix                     oubliette/flake.nix
  inputs.target, inputs.goad-walk         (no target inputs)
  targets/ capsules.nix policies.nix      lib.<builder> { targets, targetFlakes,
  net.nix perimeter/*.txt  extras           capsules, policies, net, extras, … }
  → nixosConfigurations.<slot>            → nixosConfigurations.<slot>
  → nixosModules.capsule-perimeter          + host module + programs + checks
                                          own checks run on a fixture target
                                        <consumer>/flake.nix  (the operator's)
                                          inputs.oubliette, doctrine, goad-walk
                                          targets/ capsules.nix policies.nix …
                                          = oubliette.lib.<builder> {…}
```

1. Oubliette exports a builder taking this host's declarations as arguments and
   returning what the root flake returns today: the slot `nixosConfigurations`,
   the host module, the programs, the probes, the case suites over the real
   declarations.
2. Oubliette's flake has **no target inputs**. Its own `just build` / checks run
   over a **fixture target** (e.g. `toolsPackage = null`) and fixture slots, so
   it evaluates and builds with no real project. `ISS-015` considered and did
   not take an in-repo placeholder target; this is the context in which that
   trade flips.
3. A consumer flake holds this host's declarations and is what `microvm -c/-u`,
   `just up`, `just refresh-build` and `~/flakes` point at.
4. `docs/contract-target.md` (and the contracts it cites) say where a target is
   now declared, in the same commit as the move.

Which file is a *host declaration* and which is *generic* is part of the design,
not settled here. Starting position: `targets/`, `capsules.nix`,
`policies.nix`, `perimeter/*.txt`, `net.nix`, `probeTarget`/`probeFabric` and
`extras` are the host's; `fragments.nix`'s vocabulary and its source input
(`llm-agents`) stay generic (`docs/contract-flavour.md`); `inputs.doctrine` in
the devshell is this repo's governance CLI, not a target, and stays.

## Non-Goals

- Plan F's room, per-repo tool sets, or any new target.
- Changing what any program does. This is a move of bindings; a program whose
  text changes needs a reason recorded in the design.
- Per-slot flavour (`IMP-003`) or anything else that changes the declarations'
  *shape* rather than their *home*.
- Editing `~/flakes` from here. Its wiring changes (drop the `follows` shims;
  take the host module from the consumer) are the user's to make; this slice
  names them exactly.

## Affected surface

`flake.nix`, `flake.lock`, `targets/**`, `capsules.nix`, `policies.nix`,
`net.nix`, `perimeter/**`, `fleet.nix`, `fleet-cases.nix`, `setup.nix`,
`justfile`, `probe/**`, `host/services.nix` (its import arguments),
`docs/contract-*.md`, `README.md`, `CLAUDE.md`. Plus a new consumer flake
whose location is `OQ-1`.

## Open questions

- **OQ-1 Where does the consumer flake live?** *Answered by the user
  2026-10-16:* not in this repo, and ideally with no username in its realpath —
  an absolute path such as under `/srv/` if one is needed. It matters because
  `microvm -c -f <path>` records that path in `/var/lib/microvms/<slot>/flake`
  and every later `microvm -u` re-reads it, so the consumer's path is a durable
  host value rather than a checkout location. Left to design: its name, who
  owns the directory and how it comes to exist (declared in `~/flakes` or by
  hand), and whether it is a git repo.
- **OQ-2 Probes.** They are evidence about *this host's* capsule
  (`probeTarget`, `probe/netns-boot.sh` boots the real guest) and `probeFabric`
  is asserted disjoint from the real `capsules.nix` (`borrowed`). They need the
  real declarations, so the builder probably emits them; does `probeFabric`
  stay generic and `borrowed` run in the builder?
- **OQ-3 The devshell path and the justfile.** `just up <name>` passes
  `justfile_directory()` as `-f`; `capsule-host`, `vm` and the recipes assume
  this checkout is the flake. Does the consumer get the devshell and a
  justfile, or does oubliette's justfile take the consumer's path as a value?
  The devshell path must keep working with no rebuild and no root.
- **OQ-4 What exactly is generic in `net.nix` and `perimeter/`?** The guest-side
  `/30` is identical in every namespace (generic-looking); the aggregator
  addressing is this host's. The allowlists are plain files outside the store
  by design, so their location is a path value either way.
- **OQ-5 Cutover of live slots.** `/var/lib/microvms/<slot>/flake` records
  `/home/david/dev/oubliette`, and `microvm -u` re-reads it, so after the move
  each slot's recorded ref must be re-pointed (or the slot re-created) before
  the next refresh. *Answered by the user 2026-10-16:* no live workload
  constrains the timing (doctrine's SL-251 is long done), so the cutover is a
  plain step of this slice, with no in-flight re-pointing to design.

## Risks

- A builder function returning ~1500 lines' worth of outputs can become one
  giant closure over arguments — the coupling `IMP-015` exists to remove,
  reappearing as an argument list. The design should look for the seams
  (images, host module, programs, checks) rather than one function.
- `~/flakes` builds this repo two ways (`mem.fact.oubliette.flakes-builds-this-repo-two-ways`):
  an `--override-input oubliette git+file://…` at `just system-switch`, and the
  lock. Both change; missing one lands a stale host module silently.
- The case suites pin programs against fixtures already, but `hostModuleUnits`
  and the probes' shellcheck run over the real declarations; moving them must
  not leave a check that only the consumer runs and nobody runs (NOTES item 51
  step 3's failure).

## Verification / closure intent

- Oubliette's `just` (build, units, fmt) and `just check` pass with no target
  inputs in its lock.
- The consumer's build produces the same derivations as today's, or every
  difference is explained: for each slot's runner and the host module, compare
  `drvPath` before and after the move. The aim is identical; an unexplained
  difference fails closure.
- `~/flakes`' changes are written down exactly, and the user has applied them
  (or the slice records that they have not).
- Every case suite and probe that ran before runs after, in one of the two
  flakes, wired into its `just build`.

## Summary

## Follow-Ups
