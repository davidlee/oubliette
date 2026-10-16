# Implementation Plan SL-004: Oubliette carries no target: a consumer flake declares the fleet

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

The slice is a move of bindings, and the design says a move like this should
change no derivations (ASM-003). So every phase is checked by one instrument:
a manifest of `drvPath`s for the packages, every slot's runner, and the host
module. PHASE-01 records it at HEAD and shows it can fail. Each later phase
must reproduce it entry for entry. The one exception is the planned
`policyDir` change at cutover.

```
PHASE-01 manifest + control ─┐
PHASE-02 body → mkfleet.nix  │  oubliette still binds this host's values:
PHASE-03 split, pair targets │  every phase equal to the PHASE-01 manifest
PHASE-04 eight arguments     │
PHASE-05 shared recipes      ┘
PHASE-06 consumer at /srv/fleet ── consumer manifest = PHASE-01 (oubliette overridden)
PHASE-07 oubliette on fixture  ── consumer still equal; oubliette's lock target-free
PHASE-08 template + templateCases
PHASE-09 cutover ── policyDir the one explained difference; user's steps
```

## Sequencing & Rationale

**Real values stay bound for as long as possible.** PHASE-02 to PHASE-05
reshape oubliette while it still declares this host, so a difference in the
manifest points at the refactor and not at a changed value. That is the
design's staged equality (sec-6 step 2), split into one phase per kind of
rewiring. PHASE-02 is the extraction alone, so it tests ASM-003 before
anything else rests on it. PHASE-03 moves files apart. PHASE-04 changes
the builder's surface. A difference in PHASE-04 therefore names an argument,
not a file.

**The consumer comes before the fixture.** PHASE-06 builds the real fleet
from `/srv/fleet` while oubliette still builds it too, so the two can be
compared directly. Only once they are equal does PHASE-07 take the real
values out of oubliette. If PHASE-07 went first, no build would hold the real
values while the consumer was being written.

**Recipes before the consumer.** The consumer's justfile imports
`.oubliette/fleet.just`, which PHASE-05 creates.

**The template after the fixture.** `templateCases` stubs `oubliette` with
this tree's `lib`, and is only meaningful once that `lib` is the builder
oubliette itself calls on a fixture.

**Cutover last, and mostly the user's.** The `policyDir` default switches in
PHASE-09 and nowhere earlier. It is owner-dependent today, so no `fleetPath`
reproduces it (RV-012 F-11). The pushes need the user's word. The `~/flakes`
edits, the slot re-pointing and the switch are the user's (design sec-7). The
slice records which were done rather than claiming them (design sec-6 step 6).

**Routed review findings.** RV-012's four routed findings sit on the earliest
phase that can settle them:

| finding | route | phase |
|---|---|---|
| F-4: the manifest must cover the module | control | PHASE-01 |
| F-3: the `self` references | demonstrate | PHASE-02 |
| F-6: a fresh consumer clone must parse | demonstrate | PHASE-06 |
| F-8: templateCases tests the template's wiring | control | PHASE-08 |

## Notes

- **The manifest expression is committed, and its output is not.** The
  expression lives in the slice directory so that PHASE-06 to PHASE-09 run the
  same one against the consumer. Its output goes in runtime notes (design
  sec-6 step 1).
- **Checked at planning for ASM-003.** No `.nix` file interpolates `./.` or
  `self` as a source. The only path reads are `builtins.readFile` of
  `vm/stop-key.pub` and `probe/harness.sh`, which hash content, not location.
  `fragments.nix:58` is the only reader of `inputs` (llm-agents). This is
  planning-time grep, not proof; PHASE-02 is the test.
- **The consumer's `follows` (PHASE-06 EX-5)** are plan-level wiring that the
  design implies but does not spell out. Without them the consumer would lock
  its own `nixpkgs`, the manifest would differ for a reason that is not the
  refactor, and `~/flakes`' follows would not reach the module.
- **VT floors are weak in the refactor phases** (02–04), because a move adds
  little that a keyword can find. The manifest diff (each phase's VA) is the
  real gate there.
- **Research drift** reported by `doctrine slice research 4` is only the
  slice's own `slice-004.md` and `design.md`, which postdate the research. The
  code the research cites was re-grepped at planning and still matches.
