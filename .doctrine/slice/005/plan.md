# Implementation Plan SL-005: Rooms — a namespace with no uplink, and the door a room is reached by

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

A room is a guest record with `uplink = null` (design sec-1). The plan builds
the pure pieces first, then the guest module that slots and rooms share, then
the declaration, then everything that iterates guests.

```
PHASE-01 rooms.nix + roomsCases          pure; nothing calls it yet
PHASE-02 capsule-netns, no uplink        program + netnsCases; slot path pinned unchanged
PHASE-03 vm/door.nix extracted           slot runners equal (SL-004 manifest)
PHASE-04 ninth argument ── breaking ──── fixture + template in the same commit; DEC-025, POL-003
PHASE-05 vm/room.nix + roomImages        first VM-image gate in just build (RV-014 F-7)
PHASE-06 units over guests, guard        perGuest; guardCases; hostModuleUnits assertions
PHASE-07 front end: four verbs           roomVerbsCases; collide widened
PHASE-08 docs footprint, POL-004, relay
PHASE-09 live (user, root)               RV-014 F-6 demonstrated; docs/probes.md
```

## Sequencing & Rationale

**Pure before wired.** `rooms.nix` and `capsule-netns`'s absent uplink can
each be proven with no caller. PHASE-01 and PHASE-02 land behind green suites
before anything depends on them, so a later failure points at the wiring.

**The door before the argument.** PHASE-03 changes the live slot image's
source, and nothing else. It goes before any room exists so the instrument
(SL-004's drvPath manifest) compares like with like: with no room declared,
every slot runner must be equal. Done later, a room's new
`nixosConfiguration` would sit in the same diff.

**The breaking change is one phase.** `rooms` is required (`DEC-033`), so the
argument, the fixture's two rooms and the template's `rooms = {}` must land
in one commit or `just build` breaks. PHASE-04 carries only that and the
`liveNames`/`borrowed` coverage that comes with the records. With `rooms =
{}` the manifest must be equal to PHASE-03's end, which isolates the argument
from its consequences. The governance it moves (`DEC-025`'s successor,
`POL-003`'s revision) is in the same phase, per POL-002's same-commit rule,
and each waits on the user's assent.

**Images before units.** PHASE-05 gives each room a `nixosConfiguration` and
a build gate. PHASE-06's units then refer to guests whose images exist, and
its `hostModuleUnits` assertions run over a fixture that fully declares them.

**The front end last among code.** It is the widest file and its suite can
observe least (RV-014 F-6). Everything it names (sockets, units, images)
exists by then.

**Docs move with their code where they can.** Each sec-10 row sits on the
phase that moves its boundary: `CLAUDE.md`'s suite list grows in PHASE-02 and
PHASE-07, `DEC-032` replaces `DEC-020` there in PHASE-05, `RSK-005` in
PHASE-04, `CON-005` and the assignment contract in PHASE-06. PHASE-08 holds
what has no single code boundary: the plans, `POL-004`'s rationale, and the
relay to satan.

**Live last, and the user's.** PHASE-09 needs root, a pushed oubliette, and
the user's edit to `/srv/fleet`. It is where the front end's argv is proven.

## Routed review findings

RV-014 has two routed findings:

- **F-7 (control)**: `just build` builds no VM image. PHASE-05/EX-2 adds
  `roomImages` to it and breaks `vm/room.nix` once to watch the build fail.
- **F-6 (demonstrate)**: `roomVerbsCases` cannot stub `ssh` or `systemctl`.
  PHASE-07 pins what is observable; PHASE-09/EX-2 and EX-4 prove the argv by
  behaviour.

## Found while planning

Reading satan's SL-023 against this design found that `DEC-040`'s clone path
(`guestPath`, under `/work`) is off a room's only volume (`/home`). No phase
here builds a clone, so it is recorded as `ISS-021` for the follow-on channel
slice and named in the relay (PHASE-08/EX-3).

Planning also found that sec-1's "devshell programs refuse room names" was
built by nothing: `packages` maps every `vms` entry by name
(`mkfleet.nix:1428`), and `host/vm-name.nix` checks only that a name is a
bare token. The design was amended (run rev 38, the user's choice): rooms
stay out of `packages`' per-name map, and `vm`/`vm-stop` refuse a baked room
list before any state. It lands in PHASE-05, the phase in which a room's
image would first become a package.

## Not in this plan

Design sec-11's out-of-scope list holds: no model door, no per-repo tools or
channel, no tailnet ingress, no reset verb, no rooms-without-slots host, no
change to `any_vm_running`, nothing in `~/flakes` or satan.
