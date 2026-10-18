# Implementation Plan SL-007: Programs bring their own tools: session's base tools and the profile reader's jq

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Two independent halves, each a decision: the reader's `jq` (`DEC-053`), then
the room base (`DEC-052`) in two steps, declaration before render. Docs follow
the code, and the live check comes last because it needs the user's rebuild.

```
PHASE-01 reader jq ──────────────────────────────┐
PHASE-02 rooms.extras (declare, refuse) ─┐        ├─► PHASE-04 contracts ─► PHASE-05 live (user rebuild)
PHASE-03 base render + session ◄─────────┘        │
          (needs the record's extras) ────────────┘
```

## Sequencing & Rationale

- **PHASE-01 first.** It is the smaller half, it touches no room code, and its
  suite edits (dropping masking `jq`) are easiest to judge with nothing else
  moving. It shares no file with PHASE-02/03 except `mkfleet.nix`, in different
  bindings.
- **PHASE-02 before PHASE-03.** The render reads `room.extras`, so the
  declaration and its refusals land first and are pinned by eval-only cases.
  PHASE-02 changes no image.
- **PHASE-03 is the one that changes images**, every room's, repo-less ones
  included (they gain the floor and `/etc/room/base`). Design sec-2 chose one
  rule over a special case; the plan states the consequence rather than
  hiding it.
- **PHASE-04 after the code**, so the docs describe what was built.
- **PHASE-05 is the user's gate.** Nix system builds are theirs (CLAUDE.md
  "Working here").

## Notes

Choices made at plan time, where the design left one open:

- **Where the store-path check lives** (design sec-4 "`hostModuleUnits` or the
  nearest suite"): `profileCases`, handed the seven shipped splicers.
  `hostModuleUnits` only evaluates, and a built program's text can be read only
  in a build. `profileCases` is already the reader's suite, so the claim
  "every splice carries the reader's `jq`" sits beside the claim "the reader's
  text runs without ambient `jq`".
- **`fragmentNames` at six appliers.** The design names the argument and its
  binding site. The plan adds the five fixture suites that apply `rooms.nix`,
  each passing a fixture list, as they do `policies`.
- **`session`'s new refusal is checked after the repo lookup.** The shipped
  copy's existing refusals in `sessionCases` (no `/etc/room/repo` in the
  sandbox) keep their reasons, and a call that names no repo is refused for
  that, not for a missing base.
- **The fixture's extra is `search`, not `emacs`**, to keep `just build` cheap.
- **Research drift** (`doctrine slice research 7`) is the slice's own
  `slice-007.md` and `design.md` only. Code premises were re-grepped at plan
  time and hold.
