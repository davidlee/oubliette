# Review RV-003 — design of SL-002

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

The pass over the design run's second reopening (revision 54 onwards). The run
opened this ledger itself when it moved back from `locked` to `reviewing`.

**What it covers:** `F-1`, found while executing PHASE-01. Root did path-based
acts inside an image directory that the `microvm` uid can write. `sec-1`,
`sec-3` and `sec-8` were revised so that every such act runs as the image owner.

**Result:** the user read the three revised sections and accepted them. `F-1`
is fixed and verified.
