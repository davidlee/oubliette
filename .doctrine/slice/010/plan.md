# Implementation Plan SL-010: A model door for a capsule: a slot reaches the host LLM gateway through its namespace, first for pi

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Eight phases: seven an agent can close, and the user's live run.

```
PHASE-01  declaration + refusals (eval)     ──┐
PHASE-02  condition program + its cases     ──┼──┐   independent of each other
PHASE-03  unit-command + unitControl seam   ──┘  │   refactor, policy rounds prove it
PHASE-04  recordWrite order + recordUndo  ◄─ 03  │
PHASE-05  relay unit, drop-in, dir, grant ◄─ 01,02,03
PHASE-06  model verb + status + F-1/F-2/F-4 rounds ◄─ 03,04,05
PHASE-07  template, fixture inject, docs  ◄─ 05
PHASE-08  live legs 1–9 (VH, user)        ◄─ all
```

## Sequencing & Rationale

**Pure layers first.** PHASE-01 and PHASE-02 have no host effect and no caller:
the refusals are eval-only and the condition program is called by nothing until
PHASE-05 writes the unit. Each lands green alone with its suite, so the later
phases build on pinned pieces rather than discovering their edges.

**The seam before the verb, and as a refactor.** PHASE-03 renames
`proxy-restart.nix` and generalises `proxyControl` to `unitControl` with no
behaviour change, so the existing policy rounds are the whole proof and a red
case has one cause. Folding it into PHASE-06 would put a refactor and a new
verb behind the same red.

**The record change alone.** PHASE-04 reorders `recordWrite`, which every
record-writing verb uses. It lands while the policy verb is the only hook
user, so a regression shows in `policyCases`, `volumeCases` and
`roomVerbsCases` before the model verb depends on the new order. The policy
verb's exposure narrows as a side effect (design sec-4).

**Unit before verb.** PHASE-05 makes the relay exist, be wanted and be granted;
PHASE-06 drives it. `hostModuleUnits` can pin the unit's text without a verb,
while the verb's cases need the state directory variable the wrapper exports.

**The routed findings land on PHASE-06**, the earliest phase where all their
constraints hold (`unitControl` from PHASE-03, the record order from PHASE-04,
the directory from PHASE-05). F-2's record half also has rounds in PHASE-04
through the policy verb. F-1's criterion is transcribed against the *locked*
design: its original sketch paused `start` at a lock boundary, but revision
29 removed every write `start` made, so the verb is the only writer and the
interleaving reduces to the verb against each VM state, which `vmmState`
substitutes.

**Docs after the fixture.** PHASE-07's inject example reads `net.modelDoor`,
which the fixture gains in PHASE-05.

**The user's run last.** PHASE-08 needs `/srv/fleet` rebuilt by the user. Five
inferences in design sec-8 are verified only there; a red leg reopens the
design or becomes a backlog item.

## Notes

- **Fixture slots.** The design's `hostModuleUnits` wants an `on`, an `off`
  and an undeclared slot; the fixture has two (`alpha`, `beta`). PHASE-05's
  phase plan chooses between a third slot and a second module eval, after
  checking which suites enumerate the fixture's slots.
- **Disruption, flagged** (auto-memory `forward-design-over-live-capsules`):
  PHASE-04 changes the order of every record write on this host once
  `/srv/fleet` takes it; PHASE-05 adds a field every `assignment.json` carries
  from its next write. Neither touches a slot that declares no door, beyond the
  `model_door: null` skeleton field.
- **Deferred to reconcile:** POL-003's table rows (`net.modelDoor`,
  `modelDoor`), through `doctrine revision` (design sec-7).
- **RV-027 F-4** stays `answered` until PHASE-06's EX-4/EX-5 exist; re-submit it
  to the raiser then.
