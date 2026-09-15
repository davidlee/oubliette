# Review RV-005 — design of SL-002

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

The pass over the design run's third reopening (revision 62 onwards). The run
opened this ledger itself when it moved back from `locked` to `reviewing`.

**What it covers:** `sec-2`, `sec-5`, `sec-7` and `sec-8` as revised for the
code review `RV-004`. Its `F-1` found that the refusal for a guest image without
`capsule-reset-home` named stop then start, which boots the same image; the remedy
is `just refresh-build <slot>`. Its `F-2` found that the clone's scrub gate gave
one message for every guest status, while `reset-home` refused by reason; both
now call one status-to-refusal function, `resetHomeRefusal`, which also tells
ssh's 255 apart. `F-6` (a reset names `just reset-known-hosts`) was folded into
`sec-7` in the same pass. The findings, their fix plans and their verification
stay on `RV-004`, since they are verified against code.

**Result:** the user read the four revised sections and accepted them. No new
findings.
