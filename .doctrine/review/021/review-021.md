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
