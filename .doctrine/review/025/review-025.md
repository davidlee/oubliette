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
