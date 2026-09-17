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

## Synthesis

**Overall:** acceptable.

**Synopsis.** Three phases of destructive, root-adjacent code whose interesting
branches a live host reaches only by deleting something real. The invariants
held. The marker invariant is sound from the front end's side and well pinned:
every inject inside `capsule` passes `work()`, the marker outlives a failed
scrub, and the gate cannot be reached around — the one route that bypasses it,
`capsule-inject` straight off `PATH`, is stated in the design rather than
papered over. The name gate is the same shape: a destructive verb refuses a
resolved name and a `CAPSULE_NAME` name, and `all volume` is refused outright,
which is `POL-003` doing real work rather than being cited. The suites are the
reason any of this is checkable at all, and `resetHomeCases` — the first whose
subject ships in the guest — reads its expected values off the evaluated image
instead of recomputing them, so it cannot agree with itself while disagreeing
with what ships. 👍 for both, and for `volumeRootCases` taking its sandbox roots
as build-time arguments so a root program's fixed paths stay fixed.

What the pass actually found was not the deleting. It was **operator guidance**
and **one case that could not fail**. The two majors were the same defect twice:
a refusal that names a remedy which is not one (127 said stop-then-start, and
only `microvm -u` moves a slot's `current`, so the advice was a loop), and a
gate that collapsed every scrub failure into one message while the mapping sat
inline in the only branch that did not need it. Both were design-wrong before
they were code-wrong, and the design was reopened and relocked at revision 74
before a line changed — the right order, and the reason `F-1` and `F-2` landed
as one commit against text that already said what to do. `F-3` is the one that
should sting: a case named for the `manager-early` exclusion was satisfied by
the `login` exclusion, so it was green with the behaviour it claimed to pin
deleted. That is exactly the failure CLAUDE.md's mutate-and-re-run rule exists
to catch, in a suite written under that rule. Every fix here was mutated and
read.

**Standing risks, consciously accepted.** `ASM-001` — the idle rule counts a
`State=closing` session as work — is unsettled, and `F-5` found that the front
end opens an `agent@` session immediately before every scrub it triggers. No
code moved: it is a design question, and it is now a STOP condition on
PHASE-06's exercise 3 rather than a guess pre-empted in code. `F-4`'s guard
refuses a hostile `volumePath` at eval, but nothing pins that `vm/capsule.nix`
*calls* it — dropping the call is invisible for a good target, and catching it
needs a guest evaluated against a hostile one. Named, not closed; carried to
reconcile. `F-7` is a cohesion nit, tolerated on purpose: renaming `vmmState`'s
seam would touch every render of the front end for no behaviour, immediately
before PHASE-05 edits the same file. And the whole of this review is static —
**no slot has run any of it**. PHASE-06 is where the volume actually gets
deleted.

**Haiku:**

    the remedy named
    boots the same image again —
    a loop, kindly phrased
