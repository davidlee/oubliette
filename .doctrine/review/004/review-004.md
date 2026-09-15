# Review RV-004 — code-review of SL-002

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Scope: SL-002 PHASE-02 (`vm/reset-home.nix`, `vm/reset-home-cases.nix`, the
`vm/capsule.nix` wiring), PHASE-03 (the `volume` verb, `nameFrom`, the start
lock, `host/volume-cases.nix`) and PHASE-04 (`guestResetHome`, `scrubPending`
in `work()`, the reset-home branch) — `git diff 410e840 97de336`, code and
suites only. PHASE-01's helper is read only where the front end depends on it.
Depth: full pass. Destructive, root-adjacent code whose interesting branches are
reachable live only by deleting a real volume.

Lines of attack:

- **The marker invariant from the front end's side** (design sec-5): every
  inject passes the gate; a failed scrub keeps the marker; and the operator is
  told *why* and *what next*, since the gate is where a clone first meets its
  guest.
- **Refusal by reason and way out** (sec-2, the slice's risk on a pre-verb
  image): is each named remedy actually a remedy on this host?
- **The idle rule against the front end's own traffic**: the rule counts any
  non-login, non-manager `agent` session, including `closing` ones (`ASM-001`);
  which of the front end's own `agent@` probes precede a scrub?
- **Suites that pin what they name** (CLAUDE.md "check the suite can fail"):
  does each named exclusion and refusal have a case that only it satisfies?
- **POL-002 / POL-004**: target-derived values spliced into a root program's
  text; seams whose names say what they hold.
