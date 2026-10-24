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

## PHASE-01 (execute)

### Red and mutation evidence (all quoted from `nix build --no-link .#fragmentsCases`)

Base: `just check` green before edits (alejandra "complies").

1. Case 7 red first (suite wired, no rule, sudo not yet off). Cause: the absent rule, not an eval error:
```
fragments-cases> FAIL a NOPASSWD sudo in a room fails exactly one rule: got '0', wanted '1'
fragments-cases> FAIL   and that rule is the elevation rule: '' does not mention 'no elevation'
fragments-cases> ok   room 'assistant' passes every roomChecks rule
fragments-cases> ok   room 'lounge' passes every roomChecks rule
```
(7a passes vacuously, since no rule yet.)

2. VA-1: appended `let x = ;` to fragments-cases.nix; `just check`:
```
error: syntax error, expecting '{'
       at /home/david/dev/oubliette/fragments-cases.nix:89:5:
           88|   ''
           89| let x = ;
error: recipe `parse` failed with exit code 123
```
Reverted from a scratch copy; `just check` green again ("Congratulations! Your code complies with the Alejandra style.").

3. Rules added, `vm/room.nix` not yet off (control discriminates; why the module setting lands in the same phase). 7b "passes" here only because the clean room already fails the rule, i.e. it is not yet distinguishing:
```
fragments-cases> FAIL room 'assistant' passes every roomChecks rule: got 'roomImages: room 'assistant': security.sudo.enable is on; a room has no elevation (DEC-060, RV-025 F-3)', wanted ''
fragments-cases> FAIL room 'lounge' passes every roomChecks rule: got 'roomImages: room 'lounge': security.sudo.enable is on; a room has no elevation (DEC-060, RV-025 F-3)', wanted ''
fragments-cases> ok   a NOPASSWD sudo in a room fails exactly one rule
fragments-cases> ok     and that rule is the elevation rule
```

4. Green after `security.sudo.enable = false` in vm/room.nix: all four case-7 lines `ok`.

5. EX-5 mutation (elevation rule removed from `doorRules`; rule restored after, rebuilt green):
```
fragments-cases> FAIL a NOPASSWD sudo in a room fails exactly one rule: got '0', wanted '1'
fragments-cases> FAIL   and that rule is the elevation rule: '' does not mention 'no elevation'
fragments-cases> ok   room 'assistant' passes every roomChecks rule
fragments-cases> ok   room 'lounge' passes every roomChecks rule
error: builder for '/nix/store/6v07sikixlpgwm41bijk4bjkd2y969n1-fragments-cases.drv' failed with exit code 1;
```
Non-zero build exit = a failing case fails the build (`.#fragmentsCases` is in `just build`).

Gate: `just check` green; `just` exit 0 (includes roomImages over both rooms and fragmentsCases); `just cases` exit 0.
Not exercised: no consumer room (/srv/fleet) built; no VM booted; the three non-elevation door rules have no negative case (design does not require one; the clean-room control covers their evaluation).
