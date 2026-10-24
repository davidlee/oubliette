# Implementation Plan SL-009: PostgreSQL service for rooms

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Five phases: four that an agent can close, and one that is the user's.

```
PHASE-01  door rules + sudo off       ──┐  independent; scaffolds fragmentsCases
PHASE-02  fragment interface + entry  ──┤  + slot refusal (no room imports yet)
PHASE-03  room persistence + fixture  ◄─┘  needs both
PHASE-04  contract, README, CLAUDE.md, memory
PHASE-05  live checks (VH, user)      →  settles ASM-005 / ASM-006
```

## Sequencing & Rationale

**PHASE-01 first** because it stands alone and is the riskiest to consumers.
Turning sudo off reaches every room that `roomChecks` evaluates, consumer rooms
included, so it lands on its own, where a red consumer `roomImages` points at
one cause. The handover asks for the elevation rule and sudo-off to land in one
phase, because the rule fails any room that still has sudo enabled. Putting
the suite scaffold here also gives `fragmentsCases` a positive control (both
clean rooms pass every rule) before any fragment exists.

**PHASE-02 before PHASE-03** because the suite's subject is the shipped
vocabulary (design sec-6). Cases 1-3 cannot be red-then-green against
`postgresql-18` until the entry exists. The entry, the selection functions
and the slot refusal can all be proven without a room. `vm/room.nix` is
deliberately untouched in PHASE-02. Importing modules there without
persistence would put a selected database on tmpfs, which is worse than
giving no service at all. In the gap between PHASE-02 and PHASE-03, selecting
`postgresql-18` yields no packages and no service, and no fixture or consumer
selects it.

**PHASE-03 carries the room's half** and the mutations over it. Both the
persistence rules and the service contract are first exercised by the real
entry, because no fixture vocabulary exists (handover). Every persistence
mutation listed in design sec-6 case 8 is in this phase, along with two
additions, each transcribed from a routed finding: the `fsType` mutation
(RV-025 F-2) and the `shared_`-prefix mutation (F-11, whose verification cites
a prefix-removal mutation). The capsule-assertion mutation goes in PHASE-02,
the phase that pins case 2.

**PHASE-04 is docs and memory**, after the code ships (design sec-7; user,
2026-10-24).

**PHASE-05 is separate** because its evidence is a running room, not a build.
It needs a host the agent does not drive (`DEC-064`). F-1 and F-5 are routed
`demonstrate`, so their criteria live here. The slice can reach audit with
PHASE-05's steps reported at the rung reached. A step that was not run is
reported as not exercised, never as passed.

## Routed findings (RV-025) → criteria

| finding | route | where |
|---|---|---|
| F-1 database exclusion | demonstrate | PHASE-05/EX-2 (VH steps 5-6); the HBA text is pinned by PHASE-03 case 4 |
| F-2 fsType | control | PHASE-03/EX-2 |
| F-3 elevation | control | PHASE-01/EX-3 |
| F-4 requires edge | control | PHASE-03/EX-2 |
| F-5 readiness | demonstrate | PHASE-05/EX-1 |
| F-6 / F-9 / F-11 reserved names | control | PHASE-03/EX-3 |

F-7, F-8 and F-10 have no route. They are built into PHASE-03's script, the
`config.assertions` reading in PHASE-02, and PHASE-04's README.

## Notes

- Design sec-9 says `vm/capsule.nix` "throws"; sec-5 governs, and it is an
  `assertions` entry. The plan follows sec-5.
- PHASE-02 case 2 depends on `extendModules` accepting a `specialArgs.flavour`
  override on an evaluated capsule. The fallback is named in the phase
  objective.
- The research baseline's drift is only the slice's own scope and design
  files, not source; no research section needs refreshing.
