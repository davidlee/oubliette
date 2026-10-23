# PostgreSQL service for rooms

## Context

The room capability currently provides users, optional repo clones, sizes,
extras, and a shared guest module. The requested capability is to add a
PostgreSQL server as a room service; installing a PostgreSQL package in the
room's tool set would not configure or supervise a database service.

## Scope & Objectives

- Let a room declaration opt into a PostgreSQL service, with a deliberate
  configuration surface for version and initial database access.
- Run PostgreSQL under the room VM's NixOS service manager.
- Define where its data lives and what survives room stop/start, image rebuild,
  and reprovisioning. The existing guest has a persistent `/home` volume and,
  for rooms with repos, a `/work` volume; database data must not silently rely
  on the ephemeral root filesystem (`vm/room.nix`).
- Define how room users and clients reach the server while preserving the
  room's sealed network boundary.
- Add fixture coverage for enabled and absent service configurations and the
  service's data and access contract.

## Affected surface (coarse)

Narrowed by inquiry (DEC-059…DEC-068): the service is a **capability
fragment**, selected through the existing `extras`, so `rooms.nix` gains no
field and no host-side volume is created.

- `fragments.nix`: an optional `guestModule` per entry, and `postgresql-18`.
- `vm/room.nix`: import the selected fragments' modules, each handed its own
  persistent directory under `/home/.fragments/`.
- `vm/capsule.nix` or `mkfleet.nix`: refuse a capability fragment in slots'
  `flavour.extras` (DEC-060).
- `mkfleet.nix` `roomChecks`: three door rules (password auth, root login, no
  default route) and the postgres fragment's mount, service and listener.
- `rooms-cases.nix` (or the suite owning `flavour.extras`), `fixture/`,
  `templates/`: the `assistant` room selects `postgresql-18`; `lounge` is the
  absent path.
- `docs/contract-flavour.md` (capability fragments built, for rooms) and room
  usage docs (forwarding, reset, backup, upgrade).

## Non-Goals

- Adding PostgreSQL to a repo's tools package or managing that repo's
  language-level dependencies.
- Giving rooms general egress or exposing the database through a new direct
  host network path as an implicit side effect.
- A general arbitrary-NixOS-services extension unless design shows it is
  necessary for this capability.
- Designing application schemas, migrations, or application-specific backup
  jobs.

## Risks, assumptions, and open questions

Settled at design inquiry: storage DEC-061, upgrade DEC-062, access DEC-063,
readiness DEC-065, reset/backup DEC-067, selection seam DEC-059/DEC-060.
Remaining inferences, each verified live (DEC-064):

- systemd orders the bind mount after `/home` and postgres after the bind.
- A connection forwarded over the door reaches peer auth as the logged-in user.

## Verification / closure intent

The design should produce a declarative room contract and a concrete lifecycle
for service startup, persistent state, access, and upgrades. Closure should
include evaluation/build cases for a service-enabled room and the absent path,
plus a verification of volume and service ordering in the rendered guest and
host configuration. Any live service or connection claim must be reported at
the evidence level actually exercised; a build alone does not prove runtime
database readiness or durable data across a VM cycle.

## Summary

Enable an explicitly declared PostgreSQL server in a room with an intentional
data lifecycle and connection contract.

## Follow-Ups
