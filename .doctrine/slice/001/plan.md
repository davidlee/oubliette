# Implementation Plan SL-001: A slot may declare which target it is for

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Cite entities by padded id (SL-020, REQ-059); phases as PHASE-01,
     criteria as EN-1/EX-1/VT-1/VA-1/VH-1. See glossary.md § reference forms. -->

## Overview

Six phases, each ending with a green `just build` and a commit. The first five
change code; the sixth is the live check on this host that no case suite can
stand in for. The design (`design.md` sec-1…sec-5, locked) is the reference for
*what* each change is; this file says only why the phases are cut and ordered
as they are.

```
PHASE-01 grammar ──▶ PHASE-02 status cell ──▶ PHASE-03 declaration + resolution
                                                  (+ POL-002 / POL-003)
                                                        │
                     PHASE-06 live ◀── PHASE-05 source ◀── PHASE-04 provision
```

## Sequencing & Rationale

**Grammar first (PHASE-01).** The predicate and the reserved `-` have no
dependants that could break them. The `profile` field can exist, defaulting to
null, while no slot declares one, so the assertion is present and holds before
any value exists. Every later phase leans on `profileLoad`'s refusal, so it
settles first.

**The status cell before the declaration (PHASE-02).** `DEC-014`'s ambiguity
already exists: the sole-document fallback reads as a bare name, the same as a
record. Bracketing it first means no commit exists in which a declared default
reads as an assignment. The width change rides here too, because it is what the
brackets cost. One mutation (the profile column at its old width) needs a
ten-character cell that only PHASE-03's `decl` slot supplies, so it is deferred
there and says so.

**The declaration, the resolver and the governance together (PHASE-03).** The
moment `capsules.nix` carries `"doctrine"` is the moment `POL-002`'s current
wording is broken, so the revisions and the documents that state the resolution
order land in the same commit (`DEC-012`). The user approves the revisions
before they are applied (`VH-1`), which is why they are drafted as an entrance
criterion rather than written at the end. Every caller of the resolver moves in
this phase, because the table in sec-3 is one decision: splitting it would leave
a commit in which a misdeclared slot records a unit it cannot load.

**The provision path after the declaration (PHASE-04).** Its cases run on the
declared `dflt` slot, and objective 4a's defects are easiest to reach once
defaults exist. It is separate from PHASE-03 because it changes what a
provision *writes*, which is the riskiest edit in the slice (`CHR-011` bug 3's
branch). It should be reviewable on its own.

**Source last among the code phases (PHASE-05).** `ISS-008`'s fix is small in
code and large in prose. The design requires every false sentence to be
corrected in the same commit as the code, so this phase is dominated by the
sweep, and the sweep is run before editing so it is seen to find today's
instances. `handoff`'s path check lives here rather than in PHASE-04 because it
exists for the pinned-source rule this phase makes real on the module path. The
removed-option check goes inside `hostModule`'s `checked` rather than into a new
attribute, so no justfile edit is needed (`fnd-34`).

**Live last (PHASE-06).** It needs the user's host switch, which is theirs to
run, and it is the only evidence that the module path reaches the document's
`path`. The chosen slot must be started, unassigned and not `c`; see sec-5.

## Notes

- Every phase names its mutations as `VA-1`. A case is not done until the
  mutation it claims to catch has been watched turning it red
  (`mem.pattern.oubliette.a-mutation-must-reach-the-case`).
- PHASE-03 through PHASE-05 all edit `host/policy-cases.nix` and
  `host/cli.nix`, so the phases are serial. Nothing here parallelises safely.
- `ISS-011` and `ISS-012` are parked defects the design names. No phase touches
  them.
