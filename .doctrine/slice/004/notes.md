# Notes SL-004: Oubliette carries no target: a consumer flake declares the fleet

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-16 · reviewing · d880e26

### Produced
- design drafted, reviewed adversarially and revised; nothing implemented (commits b94c696..HEAD)
- DEC-025..DEC-030 — the builder, the split, consumer as flake+state root, shared just module, probes built here/run there, template eval-checked
- DEC-025 amended after review: eight owner-grouped arguments, each target paired with its flake
- RV-012 — GPT pass, nine findings answered and verified; RV-012's pass reads STALE after the grouping amendment
- minted: IMP-016 — ~/flakes reads the fleet's net instead of repeating tap and port; IDE-002 — Plan F, which this slice unblocks

### Learned
- mem.fact.oubliette.design-apply-ordering — sections sort as text; needs edges need a second apply; slice edits drift the research baseline
- mem.fact.oubliette.microvm-create-takes-no-fragment — corrected: two recorded flake spellings across slots
- mem.fact.oubliette.flakes-builds-this-repo-two-ways — corrected: the override path is the oubliette checkout now

### Open
- ASM-003 — the outputs body moves into mkfleet.nix derivation-neutrally; validated by the phased manifest
- DEC-019 — superseded at reconcile (targets carry their own flakes)
- user acts outstanding to lock: section-reviewed ×10, review-disposed (conducted RV-012 or a fresh pass), design-accepted
