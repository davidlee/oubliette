# Implementation Plan SL-002: Volume verbs, and a clone that does not carry an identity

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.

## Overview

Six phases. The first two build the two new programs, each with its own suite
and nothing calling it. The next three grow the front end in three cuts: the
host-side verbs, the guest-side verb and its gate, then status. The last runs the
live exercises no suite can reach.

```
PHASE-01 root helper ───► PHASE-03 volume verb ──┬──► PHASE-04 reset-home + gate ──┐
PHASE-02 guest program ──────────────────────────┘                                 ├──► PHASE-06 live
                           PHASE-03 ──────────────────► PHASE-05 status ───────────┘
```

## Sequencing & Rationale

**Programs before their caller.** `design.md` sec-1 gives four parts with one
direction of dependency: the front end calls the root helper by store path and
the guest program over the admin door; neither program knows the front end.
Building each program first, pinned by its own suite, means the front end's
phases substitute a program whose exit statuses and refusals are already fixed
rather than designed at the same time as their caller.

**One suite per program, landing with it.** `CLAUDE.md` requires a suite to be
in `just build` in the commit that adds it (`NOTES item 51` step 3), so wiring
and the suite-list edit are exit criteria of the phase that adds the suite, not
a clean-up phase at the end. The same holds for the documents sec-8 names: each
moves in the phase whose behaviour it describes.

**The front end in three cuts.** `host/cli.nix` is 2,200 lines, and the volume
work touches it in four places (the verb, `work()`, `start`, status). PHASE-03 is
the part with no guest in it: parsing, the name rule, the two root sub-verbs and
the start lock. PHASE-04 adds the part that talks to a guest, which needs
PHASE-02's exit statuses. PHASE-05 is status, which shares only the `microvms`
argument with the rest.

**Live last, and the user's.** Sec-8's live exercises need root, a rebuilt host
and a slot that can be destroyed. They settle `ASM-001` and `ASM-002`, which the
design carries as assumptions.

## Notes
