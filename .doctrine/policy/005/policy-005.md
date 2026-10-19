# POL-005: A room never fetches

## Statement

**A room has no egress, and nothing a room repo needs is fetched at run time.**
A room repo's language-package dependencies (`node_modules`, a gem set, a
Python environment) are **its flake's output, fixed by its lockfile**, and the
room reaches them through the repo's `toolsPackage` like any other tool.

Three limbs:

1. **The room stays sealed.** No room is attached to the proxy, permanently or
   for a setup boot, to make a package manager work. `DEC-036`'s "a room has no
   uplink" holds without exception.
2. **The repo owns its dependency tree.** The tree is built by the repo's flake,
   as a fixed-output derivation or a lockfile importer (`importNpmLock`,
   `bundlerEnv`), and exported where the room's `toolsPackage` reaches it.
   Putting it into the clone (a link or a copy) is the repo's recipe, with
   a working absent path for a host or slot that installs the usual way.
   Nothing in oubliette learns which package manager a repo uses (`POL-002`).
3. **A dependency change is made outside the room.** Edit the lockfile on the
   host or in a slot, rebuild the repo's output, push, update the consumer's
   lock, rebuild the room. The room never runs a package manager's install.

## Rationale

A room holds many repos and every user's home (`CHR-018`). Egress from a room
puts all of it within reach of whatever runs with that egress. An allowlist of
hosts is not a one-way valve: an HTTPS tunnel is opaque to the proxy, and the
registries it would admit accept uploads. `RFC-001` compared five ways to get
dependencies into a room against nine principles. The options that keep the
room sealed are a repo-built tree (A) or a fetch done elsewhere and handed in
(D). The option that opens it safely needs a second boot shape and new
perimeter code (E).

The repo-built tree wins on evidence, not principle alone. Of the three room
repos surveyed on 2026-10-19:

- doctrine already builds `web/map`'s `node_modules` as a fixed-output
  derivation (`webModules`);
- malebolge already builds its production `node_modules` (`buildNpmPackage`);
- www's Ruby set is already `bundlerEnv` over `gemset.nix`.

So the cost is exporting what exists, not building a mechanism. It is also the
floor rule already in force (`docs/contract-flavour.md`): a tool the project
builds or tests with belongs in that repo's flake, so the room cannot drift
from the repo's devshell.

The price is limb 3: a dependency change is a round-trip through the host and
the consumer flake, not a command in the room.

## Scope

**Applies to** every room repo (`repos.targets` in a consumer's `rooms`) and to
oubliette's room code: `vm/room.nix`, `rooms.nix`, and the room arms of
`host/`.

**Does not apply to slots.** A slot has an uplink under a declared policy, and
installing from a registry through it remains supported.

**Revisit** if a repo's ecosystem cannot be packaged as a flake output, or if
dependency churn inside the room makes limb 3's round-trip the dominant cost.
`RFC-001`'s option E (a setup boot that attaches none of the room's volumes) is
the recorded escape hatch. Adopting it supersedes this policy and `DEC-036`.

## Verification

**Built: `vm/room.nix` declares no proxy variables and `rooms.nix` sets
`uplink = null` for every room.** `netnsCases` pins that a namespace with no
uplink builds no veth and no resolver file. Limbs 2 and 3 are the repos'
practice and are checked by review: a change that adds a room uplink, or a
generic program that names a package manager, violates this policy.

**Not exercised:** no room repo yet runs its tooling from a flake-built tree.
The follow-ups are in the repos' own backlogs. Two things are unverified:
whether tools that write into `node_modules` (vite's `.vite` cache) tolerate a
store path, and whether npm's prebuilt native binaries run in a room, which has
no `nix-ld` (`RFC-001`, Context).

## References

- `RFC-001` — the comparison this policy settles
- `DEC-036` — a room has no uplink
- `IMP-019` — the gap that raised it
- `CHR-018` — the room holds the rest of the user's repos
- `POL-001`, `POL-002`
- `docs/plan-e-room.md`, `docs/plan-f-assistant.md` §1
- `docs/contract-target.md` § As a room's repo
