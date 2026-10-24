# Review RV-025 — design of SL-009

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Raiser: `codex`. Full adversarial design pass over SL-009 sec-1..sec-9 and
DEC-059..DEC-068, against CLAUDE.md, POL-001..POL-005, STD-001,
DEC-033/034/036/048/052 and docs/contract-flavour.md.

Lines of attack: stage-1 versus stage-2 mounts and early service dependencies;
PostgreSQL module recursion, provisioning, readiness, ownership and peer
authentication; the fragment/guest boundary and slot refusal; whether the door
and persistence predicates discriminate their stated regressions.

Evidence: pinned nixpkgs and microvm.nix sources, current call sites, focused
read-only Nix evaluations and upstream primary documentation. Runtime outcomes
derived from source are explicitly marked inference. No VM images built, no
guest started, no live database or forwarding connection exercised. Only this
review ledger is edited.

## Synthesis

**Overall:** acceptable as a design, with the stated live checks outstanding.

**Synopsis:** All eleven findings are verified against the revised design,
through revision `09d1739`. Persistence has an explicit filesystem type and
checked dependency edges; elevation checks inspect disabled mechanisms rather
than NixOS's default rule lists; PostgreSQL uses peer identity and role-based
database admission, protects built-in names, and reserves `shared_` for
operator-created shared role/database pairs. The admin recipe names root
explicitly. The vocabulary remains repository-owned, and the guard explicitly
covers a finite set of settings.

Evidence is source inspection, focused read-only Nix evaluations, mutation
projections and isolated execution of the shipped SSH argument parser. The
design's module snippet evaluates; this review does not certify an implemented
fragment or case suite. No VM image was built, guest booted, database or role
mutated, live forwarding connection attempted, or persistence read back.
Those claims retain the design's separate live verification obligations.

**Haiku:**

Names divide the rooms  
Keys turn toward the quiet door  
Boot must prove the rest
