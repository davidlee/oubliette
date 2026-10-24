# Notes SL-009: PostgreSQL service for rooms

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: <yyyy-mm-dd> · <PHASE-NN | stage> · <head-commit>

### Produced

### Learned

### Open

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
