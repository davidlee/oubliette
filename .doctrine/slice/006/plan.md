# Implementation Plan SL-006: Assistant room over many repos: clones, tools and a per-repo git channel

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

A room that declares repos holds a clone of each on a `/work` volume, runs
commands with one repo's tools through `session`, and exchanges git with the
host through one generic program the front end resolves for it (design sec-1).
The plan follows the dependency chain: what is shared, then what is declared,
then the guest that holds the clones, the program that reaches them, the verb
that names them, and the words that describe them.

```
PHASE-01 shared fragments + quarantineCases   refactor; slot behaviour pinned unchanged
PHASE-02 rooms.nix: repos/policy/work         roomsCases; three fixture appliers; POL-003 REV (user)
PHASE-03 guest: /work, seed, tree, session    sessionCases; second fixture target; image gate
PHASE-04 capsule-room-git                     roomGitCases; wrapped; room/<r> tmpfiles
PHASE-05 front end: push/collect/forget       roomVerbsCases; room ssh on one known_hosts
PHASE-06 template + contracts + Plan F
PHASE-07 live (user's edit and rebuild)       STD-001; closure EVD; ISS-021, RSK-011 close
```

## Sequencing & Rationale

**Extract before reuse.** PHASE-01 moves three fragments out of the slot
channel while it is still their only caller. A behaviour change then has
one suspect: the extraction. `gitChannelCases` stops at the ssh door, so it
cannot see the fetch, and RV-015 F-5 found exactly that gap. PHASE-01
therefore lands `quarantineCases` in the same phase, run against local bare
repos, where the fetch is reachable. Its `--atomic` case discriminates only
with two refspecs, so it is written that way. `refuseToken` keeps
`checkToken`'s signature (RV-015 F-8), so no slot caller is edited at all.

**The declaration before its consumers.** PHASE-02 changes what `rooms.nix`
takes and returns, and so touches every caller of it: the binding site and
three fixture appliers (RV-015 F-7). Nothing reads the new record fields yet,
so the suites that apply it must stay green with only their arguments added.
The `POL-003` rooms-row REV moves the governance with the code, in the same
phase, on the user's assent.

**The guest before the channel.** PHASE-03 makes the clones, the tree and
`session` real and gives the fixture assistant two repos with distinguishable
tool sets. PHASE-04's program then targets a guest shape whose image builds.
The second fixture target lands here because the image gate is the first check
that needs it.

**The program before the verb.** PHASE-04's `capsule-room-git` is complete,
wrapped and installed before the front end execs it. `roomVerbsCases` in
PHASE-05 then checks the resolution step, with a stub standing in for the
program. Moving the room `ssh` door onto the room's `known_hosts` is in
PHASE-05, not PHASE-04, because it is a front-end change and the visible
change to live rooms: on first contact after the rebuild, each live room
learns its key afresh. That is flagged, not designed around.

**Words after behaviour, live last.** PHASE-06 describes what PHASE-01..05
built. PHASE-07 is the only rung that crosses the ssh door (`STD-001`): the
banner branch, an authentication or host-key failure, and an actual push and
collect are unreachable by any case here, since `pkgs.openssh` cannot be
stubbed. Its entry is two acts of the user's: the `/srv/fleet` edit and the
rebuild in `~/flakes`.

## Notes

- **SL-005's constraint is met.** PHASE-09 (the door, `a07094d`) and PHASE-10
  (`a22f882`) are committed, so implementation can start at PHASE-01 and the
  live rung has its door.
- **`DEC-044` stays provisional.** No phase adds a fleet extra to a room. If
  the live rung shows a repo needs one, that calls for a successor decision,
  not a flag.
- **Each phase mutates once.** Every phase that adds a suite names the one
  mutation that must turn it red, per `CLAUDE.md`.
- **Relaying sec-6 to satan SL-023 is the user's act** (ADR-001 term 2), at
  the close of the slice.
