# Notes SL-009: PostgreSQL service for rooms

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-24 · plan (design locked) · 7b5435e

### Produced
- design locked — capability fragment `postgresql-18` for rooms; `design.md` sec-1..sec-9 (commits e5d94d3..7b5435e)
- DEC-059..DEC-068 — the settled answers; DEC-060, DEC-061, DEC-063, DEC-065, DEC-068 amended in-run
- RV-025 — adversarial design review (codex), 11 findings, routes F-1/F-5 demonstrate, rest control

### Learned
- mem.fact.oubliette.nixos-service-defaults-defeat-naive-overrides — ProtectHome, mkAfter pg_hba, sudo's default rules
- mem.fact.oubliette.design-lock-needs-routed-findings — route severe findings at first dispose

### Open
- ASM-005 — room-persist / bind / postgresql.target boot ordering, live only
- ASM-006 — peer auth over an ssh -L forward, and samerole, live only
- DEC-064 — the six VH steps are the user's to run

## Design review passes

**RV-025** (adversarial, Codex gpt-6.1-sol, 2026-10-24): 4 rounds, 11 findings,
all verified fix-now. Evidence was read-only nix evals over the fixture, the
pinned nixpkgs/microvm sources and PostgreSQL 18 docs and source; nothing was
built or booted.

**No further design pass is needed.** What remains open is runtime, which no
further reading can settle and which `DEC-064`'s live run owns:

- the early-boot ordering of `room-persist` → bind → `postgresql.target` in a
  firecracker guest (VH 1, 3);
- peer auth over an `ssh -L` stream-local forward (VH 4);
- `samerole` refusals and the shared-role recipe on a live cluster (VH 5, 6).

A pass after implementation belongs to `/audit` against the built code, where
it would probe whether `fragmentsCases`' mutations actually go red.
