# Notes SL-004: Oubliette carries no target: a consumer flake declares the fleet

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-16 · ready (plan approved, no phase started) · 0790448

### Produced
- design locked (run rev 42, commit 889d550); nothing implemented
- DEC-025..DEC-030 — the builder, the split, consumer as flake+state root, shared just module, probes built here/run there, template eval-checked
- DEC-025 amended after review: eight owner-grouped arguments, each target paired with its flake
- RV-012 — two GPT passes, eleven findings verified (F-10, F-11 from the sec-10 re-pass); F-3/F-6 demonstrate and F-4/F-8 control are placed in plan phases
- plan.toml/plan.md — nine phases against one drvPath manifest (0790448); phase sheets materialised
- minted: IMP-016 — ~/flakes reads the fleet's net instead of repeating tap and port; IDE-002 — Plan F, which this slice unblocks

### Learned
- mem.fact.oubliette.design-apply-ordering — sections sort as text; needs edges need a second apply; slice edits drift the research baseline
- mem.fact.oubliette.codex-exec-reads-stdin — codex exec needs </dev/null; a design lock wants a route on every severe finding
- mem.fact.oubliette.microvm-create-takes-no-fragment — corrected: two recorded flake spellings across slots
- mem.fact.oubliette.flakes-builds-this-repo-two-ways — corrected: the override path is the oubliette checkout now

### Open
- ASM-003 — the outputs body moves into mkfleet.nix derivation-neutrally; PHASE-02 is its first test
- DEC-019 — superseded at reconcile (targets carry their own flakes)
- user act before PHASE-06: create /srv/fleet and the private remote
