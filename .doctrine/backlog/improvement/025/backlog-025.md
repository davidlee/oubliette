# IMP-025: One home for the case-harness helpers (ck, saw, never, run)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-024 F-13 (SL-008 audit) and SL-008 PHASE-03's friction observation. Every
`*-cases.nix` suite redefines `ck`, `saw`, `never` and `run`. Lift them into one
fragment that each suite splices, the way `probe/harness.sh` is concatenated
ahead of probes. While there: suites that print only on failure hide the
"stayed ok" evidence a mutation run needs, so print ok lines too.
