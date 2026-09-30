# IMP-015: Oubliette carries no target: the fleet's declarations move to a consumer flake

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

**Oubliette's flake names the projects it confines.** `inputs.target` is
doctrine, and `SL-003` adds goad-walk (and goad through it). A flake input's url
must be a literal in `flake.nix`, so as long as the targets are declared in this
repo, anyone cloning it fetches this host's projects. That is `ISS-015`'s
fetchability problem one layer up: a private target breaks the lock for everyone
else, and `~/flakes` needs a `follows` shim per target input.

## Shape

The host's declarations leave this repo, and oubliette exports a builder:

```
oubliette/flake.nix                  consumer flake (the operator's)
  (no target inputs)                   inputs.doctrine, inputs.goad-walk, …
  lib.mkFleet { targets,               targets/, capsules.nix, policies.nix
    targetFlakes, capsules,            nixosConfigurations = mkFleet {…}
    policies, net }                    nixosModules.capsule-perimeter
    → nixosConfigurations.<slot>       `microvm -c <slot> -f <consumer>`
    + the host module
```

This is `POL-002` taken to the repo boundary: nothing generic learns what the
target is, *and neither does the generic repo*.

## What moves, and what it costs

- `targets/`, `capsules.nix`, `policies.nix`, `net.nix` are all this host's
  declarations; `probeFabric` is checked against `capsules.nix` (`borrowed`).
- `microvm -c` / `microvm -u` / `just refresh-build` point at the consumer
  flake (`mem.fact.oubliette.microvm-create-takes-no-fragment`).
- `~/flakes` wiring changes (`mem.fact.oubliette.flakes-builds-this-repo-two-ways`).
- The case suites, `hostModuleUnits` and the probes need a **fixture target**
  so oubliette evaluates and builds with no real one — e.g. `toolsPackage =
  null`. `ISS-015` considered and did not take an in-repo placeholder target;
  this item is the context in which that trade flips.
- `perimeter/egress-allow.txt` and the devshell path (no rebuild, no root)
  must keep working.

## Precondition

`SL-003` lays the seam: generic code (`mkVm`, `vm/capsule.nix`,
`host/profile.nix`, `host/services.nix`) takes the target set and a
name→flake map as **arguments**, and `flake.nix` is the one place that binds
this host's values. With that seam, this item is moving one binding block;
without it, it is a rewrite.

Evidence rung (`STD-001`): reasoned. Unbuilt.
