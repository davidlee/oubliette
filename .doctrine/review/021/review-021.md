# Review RV-021 — code-review of RFC-001

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Critical review of RFC-001's resolved option A and the deferred alternatives
that POL-005 names as future escape hatches. Examine whether the declared
offline dependency contract detects drift, whether the surveyed existing
outputs cover the motivating development commands, and whether option E's
volume separation actually prevents information flowing out of a room.

Evidence: RFC-001 and POL-005 via Doctrine; vm/room.nix, vm/session.nix,
docs/contract-target.md, docs/contract-flavour.md; read-only inspection of
the local doctrine, malebolge and www flakes and relevant recipes/manifests.
No builds, evaluations, dependency installations or live guest commands.
Failure scenarios are design deductions from these sources, not reproduced
exploits. The review does not revise the resolved RFC or accepted policy.

## Synthesis

**Overall:** acceptable.

**Synopsis:** Option A preserves the sealed-room boundary through repo-owned
dependency outputs. The response repairs the three reviewed specification
defects: E requires fresh scratch and a mandatory discard before another
networked boot; dependency drift covers all tree-defining inputs rather than
only lockfiles; and the adoption estimate distinguishes malebolge's existing
packaging machinery from its missing development tree. The corresponding
policy, target contract and consuming-repo backlog obligations were inspected.
This accepts the documentation repairs, not their future implementation.
No builds, guard execution, live room commands or exploit probes were run.
Writable caches, native loaders and end-to-end acceptance remain the already
recorded implementation obligations. No additional harvest records are needed:
the findings, corrected rules and consuming-repo follow-ups have durable homes.

**Haiku:**

Fresh disks cross the gate  
Manifests name what we need  
The room stays silent
