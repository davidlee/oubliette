# Notes SL-002: Volume verbs, and a clone that does not carry an identity

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage — 2026-09-15

Exploring-stage triage, superseded by the design run's decisions
(`DEC-001`..`DEC-011`) and `design.md`. What survives that the run does not hold:

- **Research F4 was wrong.** `$HOME` is contract-derived
  (`docs/contract-target.md:274`), so `research/research.md`'s F4 and OQ-6 should
  not be relied on.
- **Disk was 108 GiB free, 94% used on 2026-09-15** (`df /var/lib`), against
  86 GiB on 2026-08-18. `docs/probes.md` still says 166 GiB; its refresh is in
  sec-8.

## Review passes — 2026-09-15

**Pass 1** was the user's walk of sec-1..8 with the agent checking each claim
against code and the pinned nixpkgs: `RV-001` `F-1`..`F-5`, all fixed in
`075ead9`. `F-1`, a failed clone unmarking an earlier unscrubbed clone, is the
kind a second pass exists to find:
an ordering argument that read as sound until a *pre-existing* state was put in
front of it.

**What a further pass would probe**, in order of what it could still change:

1. **Check-then-act windows.** sec-3 `fuser` then `rm`/`cp` against a
   `capsule <slot> start` racing it from a second shell; sec-4's session check
   then `rm -rf` against a login arriving between them. Both need the operator to
   race themselves, and the guest-side one is convenience rather than perimeter
   (`POL-001`), so the likely disposition is "stated, not closed". It still needs
   stating in sec-2.
2. **`agent` processes outside any logind session.** A `systemd --user` unit
   (the console session starts `user@1000.service`) is in no session, so sec-4's
   idle test does not see it, and it may write into `$HOME` while that is being
   deleted or reseeded.
3. **Pre-existing state generally**, which is `F-1`'s class: a leftover marker
   under `reset` after a crash, a `capsule-work.img.clone` left while a slot is
   running, a marker whose content names a source other than the current clone's.
4. Checked and not a defect: `setup` on a marked slot provisions, then stops at
   the gate before the baseline, exactly as it stops at any failed inject today;
   `capsule <slot> inject` recovers.

**Whether one is needed:** items 1–3 are bounded and none touches a decision, so
the design can lock without one. If a pass is run, `/inquisition` or an external
reviewer should be aimed at items 1–3 rather than the whole document.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-15 · design (reviewing; review.scope and review.selectors discharged) · 075ead9

### Produced
- `design.md` sec-1..sec-8 — materialised from run `dr-01a0a2ae…`; all eight walked with the user, sec-3/4/5/7/8 revised for `RV-001` `F-1`..`F-5` (`075ead9`)
- `DEC-001`..`DEC-011` — the design's rulings, all accepted
- `IMP-008`, `IMP-009`, `IMP-010`, `CHR-013` — follow-ups filed during inquiry
- commits `78a6460`, `10d277b`, `4379895`, `075ead9` — nothing built or run

### Learned
- mem.fact.oubliette.design-apply-disposes-through-checkpoints — how the run takes dispositions

### Open
- `ASM-001` — a detached baseline keeps its logind session (live exercise 2)
- `ASM-002` — restarting guest sshd keeps the admin session (live exercise 3)
