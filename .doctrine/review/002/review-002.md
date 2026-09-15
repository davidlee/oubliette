# Review RV-002 — design of SL-002

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

The pass over the design run's reopening (revision 46 onwards). The run opened
this ledger itself when it moved back from `locked` to `reviewing`.

**What it covers:** `sec-2`, `sec-4` and `sec-8` as revised for `RV-001` `F-11`
(the agent's user manager is a logind session, so the idle test refused on every
guest). `F-11` was found while planning, raised and answered on `RV-001` beside
`F-1`..`F-10`, so the history of the idle test stays on one ledger.

**Result:** the user read the three revised sections and raised nothing new. No
findings.
