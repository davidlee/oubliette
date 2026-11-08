# Review RV-028 — reconciliation of SL-010

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Self-audit, conformance mode, over SL-010 PHASE-01..PHASE-08 (`5849fb7..9f7542d`) in the main worktree. Lines of attack:

- **Conformance**: `doctrine slice conformance 10`, with PHASE-08's delta recorded (`99b5a8d..9f7542d`).
- **Gates**: `just` (build, units, every `*Cases`, fmt) and `doctrine check gate`, both rc 0 at `9f7542d`.
- **Design against behaviour**: sec-6's nine live legs (docs/probes.md, "A model door on one slot, live") checked against sec-2/sec-4's states. Does every state the design names have a path into it and out of it?
- **Deferred items**: the autonomy log's `deferred` lines, notes § Planning findings, and design sec-7's commitments at reconcile.
- **Invariants held**: POL-001 (the door is host-side, admission is the guest's /32), POL-002 (`grep host/` finds no gateway name, PHASE-05 EX-5), POL-003 (one home per value), ADR-003 (each live verdict says what it does not prove).

## Synthesis

**The closure story.** The slice delivers what it was designed to: a per-slot model door. It is declared in two places (`net.modelDoor`, and `modelDoor` on a slot), refused at eval for every bad value (modelDoorCases), and rendered as a relay unit that only the guest's address can reach. The unit is gated by a condition program reading an override (modelDoorOpenCases). `capsule <n> model on|off` moves the record, the override and the relay together, with an undo for every failure (policyCases). All four kinds of check are in `just build`, and each new case was mutation-checked (notes § Review passes). On the wire, all nine legs passed both ways on this host, including the eBPF source filter (leg 2, with its control) and a declared change under a running VM (leg 9).

**What the audit found.**
- One real design gap (F-1, ISS-030): an override cannot be cleared. Toggling a slot's door is one-way with respect to its declaration.
- One shipped example that did not work (F-2): the template's `models.json` lacked pi's `compat`. Fixed in `9f7542d`.
- The rest is text that lags the code: `mv -T`, the selector registry, and POL-003's table, which the design itself deferred to reconcile.

**Standing risks.**
- ISS-030: a slot's declaration can be silently overridden forever. Status shows the override, so this is visible, but there is no command to undo it.
- CHR-019: the `PI_*` lines are verified as delivered, not as honoured, by pi 0.87.1.
- ISS-031: the relay is triggered twice at one VM start.
- The verb's undo paths are pinned by fixture only (policyCases), never exercised live.

**Tradeoffs consciously accepted.**
- F-8: one off-style commit subject stays in history.
- F-9: the status column's live values stay outside any case, because the front end gains no `systemctl` seam for them.

## Reconciliation Brief

### Per-slice (direct edit)
- **F-1**: design.md sec-4 (by :409) and sec-7 (:655) say that `null` is only the state before the verb's first use. Once used, the override governs until the file is removed by hand, and ISS-030 owns a verb to clear it. Mirror this in docs/contract-assignment.md's `model_door` row, which sec-7 moved in the same slice.
- **F-3**: the selector registry is the load-bearing change. Run `doctrine slice selector rm 10 host/proxy-restart.nix` and `doctrine slice selector add 10 host/volume-cases.nix` (design-target), then mirror both in design.md's file table.
- **F-5**: design.md sec-4 replaces the final `mv` with `mv -T`, adding a one-line reason.

### Governance/spec (REV)
- **F-4**: POL-003 → REV modify the axis table. The addressing row adds the model door (`net.modelDoor`: port, socket); the slots row adds each slot's `modelDoor` (`"on"` / `"off"` / absent).

## Reconciliation Outcome

### Direct edits applied
- design.md sec-4: `null` is the state before the verb's first use. No verb writes it back, and `ISS-030` owns that verb. sec-7's contract bullet says the same, and so does docs/contract-assignment.md's `model_door` row (F-1).
- Selector registry: `rm host/proxy-restart.nix`, `add host/volume-cases.nix` (design-target). The design file table mirrors both. `slice conformance 10`: 0 undelivered (F-3).
- design.md sec-4: the final step is `mv -T`, with its reason (F-5).

### REVs completed
- REV-010 (`reconcile-sl-010`): done. POL-003's table names the model door on the addressing row and each slot's `modelDoor` on the slots row (F-4). The rationale is in revision-010.md.

### Fixed in the slice / follow-up / tolerated
- F-2: fixed in 9f7542d.
- F-6 → CHR-019 and F-7 → ISS-031: follow-up.
- F-8, F-9: tolerated, with rationale in their dispositions.

Reconcile pass complete; handoff to /close.
