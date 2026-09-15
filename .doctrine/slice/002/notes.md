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

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-15 · design (drafting runbook cleared, sec-3..8 unreviewed) · 4379895

### Produced
- `design.md` sec-1..sec-8 — materialised from run `dr-01a0a2ae…`; sec-1/2 walked with the user, sec-3..8 not
- `DEC-001`..`DEC-011` — the design's rulings, all accepted
- `IMP-008`, `IMP-009`, `IMP-010`, `CHR-013` — follow-ups filed during inquiry
- commits `78a6460`, `10d277b`, `4379895` — nothing built or run

### Learned
- mem.fact.oubliette.design-apply-disposes-through-checkpoints — how the run takes dispositions

### Open
- `ASM-001` — a detached baseline keeps its logind session (live exercise 2)
- `ASM-002` — restarting guest sshd keeps the admin session (live exercise 3)
