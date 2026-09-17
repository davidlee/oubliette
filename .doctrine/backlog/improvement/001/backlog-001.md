# IMP-001: Plan D D3 and D4 — volume verbs and clone semantics

`docs/plan-d-fleet.md` §9 order of work, step 6. **Ungated** since `NOTES item
49`'s read on who owns a state directory was taken.

The case for doing it next is operational rather than architectural: S4 and S5
are the two most frequent administrative actions here, and **one of them is a
hand-typed `rm -rf`**.

Large enough to warrant a slice rather than execution straight off this item
(`ADR-001` term 1) — volume verbs touch the state-directory ownership question
and clone semantics touch provisioning.

## `SL-002` carries part of this, and the item stays open for the rest

Sliced 2026-08-18 as `SL-002` — *volume verbs, and a clone that does not carry an
identity* — which takes **D3's four verbs and D4's identity half**: `df`, `reset`,
`reset-home`, `clone-from <m>`, host-side, refusing while the VM runs, with a
cloned volume's ssh host keys, injected credentials and `.env` scrubbed by default
and `--identity` to keep.

**Deliberately left here: D4's other half**, the refusal of reuse on a non-clean
volume across a change of project, flavour or policy, and with it **Q3's
`unassigned → provisioned(sha) → baselined(sha) → dirty` model** and the dev-host
waiver by declaration. Two of that predicate's four signals live only inside the
guest, so a stopped slot cannot be asked; and the *policy* about what may be
reused is the target's. So this item is not `promoted` — a promotion would close
it on work nobody has scoped.

Evidence rung (`STD-001`): **the `SL-002` half is built and exercised live**;
this item's remaining half is still unbuilt.

`SL-002` closed 2026-09-17 with all four verbs shipped, `volumeCases` pinning the
marker invariant at every status the guest can return, and PHASE-06 running the
clone, the scrub and the inject on a real guest. What that does **not** touch is
what was reserved above: the refusal of reuse on a non-clean volume across a
change of project, flavour or policy, and Q3's
`unassigned → provisioned(sha) → baselined(sha) → dirty` model. `SL-002`'s audit
sharpened one part of the case for it —
`mem.fact.oubliette.a-provision-resets-tracked-files-only`: a repurpose is not a
reset, so the last assignment's residue crosses the boundary and only the volume
is deterministic. That is the gap this item still owns.
