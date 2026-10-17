# REV REV-003 — reconcile SL-004

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

## Reconcile narrative

SL-004 moved every host declaration out of oubliette into a consumer flake
(`/srv/fleet` on this host) that calls `lib.mkFleet` with eight owner-grouped
arguments. Oubliette builds itself over `fixture/`, and its lock holds no
target. All four policies still placed axes in oubliette's `flake.nix`. Wording
drafted in SL-004 PHASE-07 (sheet D8), carried in RV-013's reconciliation brief.

- [RV-013 F-1] **POL-002**: a target's name may appear in code only in a
  consumer flake and, in oubliette, only in `fixture/` and `templates/`;
  `inputs.doctrine` (the governance CLI) is excluded by name. The smell sentence
  and the Excluded paragraph follow, and "the justfile" covers `just/fleet.just`.
- [RV-013 F-1] **POL-003**: each axis's home is the caller's `mkFleet` argument
  (`net`, `fleet`, `policies`, `targets` as `{decl; flake}`, `probe.fabric`);
  `borrowed` throws in every caller's eval; `workBranch` is a constant in
  `mkfleet.nix`. DEC-019's second map is gone (superseded by DEC-025).
- [RV-013 F-1] **POL-001** scope: the policies and allowlists live in the
  consumer, beside the part of the perimeter in `~/flakes`.
- [RV-013 F-1] **POL-004**: call sites are in `mkfleet.nix`. `templateCases` is
  oubliette's own check, in oubliette's default gate rather than the shared
  `build` recipe (SL-004 PHASE-08 ruling).

Knowledge records reconciled alongside, by their own verbs (not rows here):
DEC-019 superseded by DEC-025; DEC-017, DEC-018, DEC-020, DEC-030, CON-001
reworded; ASM-003 validated; an ISS-015 note.
