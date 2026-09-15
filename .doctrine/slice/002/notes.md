# Notes SL-002: Volume verbs, and a clone that does not carry an identity

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage — 2026-09-15, exploring

Design run `dr-01a0a2ae…`. The question map is in the run (`doctrine design show
002`), with ids `inq-1`…`inq-13`; it is not restated here. Research is
`research/research.md` (baseline current as of today).

**Governing:** `POL-001` (the verb stays host-initiated), `POL-002` (a verb may
not know what a credential or a `$HOME` is), `POL-003` (the front end resolves the
slot; `$HOME` has no host-side home, so don't mint a second one), `POL-004`
(`microvms` becomes an argument with a default), `STD-001` (a suite covers argv
and refusals; only a live run covers root and a real image), `ADR-003` (figures
go in `docs/probes.md`). No spec governs this surface.

**Shaping decisions carried in from research, not yet accepted by the user:**
- `reset` is a file delete. The runner recreates the image and the guest re-seeds
  `/work` on every boot (research F2), so no re-seed logic belongs here.
- The scrub removes declared paths, and `inject` puts the three it owns back at
  the next `start` (F3).
- Default privilege is a password-prompting `sudo`, the same as `start` (F1,
  `inq-7`).

**Assumptions:**
- Nothing else writes `/var/lib/microvms/<slot>` while a stopped slot is being
  changed. This holds only because the units are ours.
- Volume verbs are about module-path slots under `/var/lib/microvms`. The
  devshell capsule's volume is `.vm/capsule/`, and a slot is a module-path thing
  (`mem.fact.oubliette.capsule-state-moves-the-quarantine-not-the-record`). "Both
  transports keep working" in the scope means both copies of the front end, not
  both volume homes. To be confirmed under `inq-5`.

**Risks:**
- A destructive verb given the wrong name cannot be undone (`inq-4`, `inq-6`).
- The clone's cost is the source's high-water mark, and it stays that high (F6).
  Disk read 108 GiB free and 94% used today, against 86 GiB on 2026-08-18.
- A sudo grant is not an access
  (`mem.fact.oubliette.policy-verb-is-owner-only`). If a `NOPASSWD` helper is
  chosen, only a call by a non-owner proves it.

**Found while exploring, outside scope:** `/var/lib/microvms/capsule` and
`/var/lib/microvms/capsule-b` still exist. They are pre-slot state directories
with a 1.6 GiB allocated image each, and they are named after the image rather
than a slot, which is `RSK-005`'s shape. `volume` must refuse them, since they are
not declared slots. Removing them is a chore, not this slice.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: <yyyy-mm-dd> · <PHASE-NN | stage> · <head-commit>

### Produced

### Learned

### Open
