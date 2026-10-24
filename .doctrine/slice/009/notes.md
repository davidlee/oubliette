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
## PHASE-02 (execute)

Decision: `capsuleImage.config._module.specialArgs.flavour` is NOT readable. The `extendModules {specialArgs...}` seam holds; the base flavour reaches the suite as a new `flavour` argument from `mkfleet.nix` (the only mkfleet.nix change: `flavour` added to the `fragmentsCases` import's inherit). Also: `fragmentsCases` literal added to the suite header (PHASE-01 VT-2 carry-over).

### Red and mutation evidence (from `nix build --no-link .#fragmentsCases`)

1. Cases 1-3 red first. EVAL ABORT (not a FAIL line): `fragments.slotRefusal` does not exist, which stops the whole suite at case 1 (case 3's `persists`/`modules` are the same absence):
```
error: attribute 'slotRefusal' missing
       at .../fragments-cases.nix:87:93:
           87|     ck "slotRefusal of a package-only selection is null" true ${lib.boolToString (fragments.slotRefusal ["agents"] == null)}
```

2. With fragments.nix written, case 2's base-flavour read, EVAL ABORT (settles reachability):
```
error: attribute '_module' missing
       at .../fragments-cases.nix:62:37:
           62|   baseFlavour = capsuleImage.config._module.specialArgs.flavour;
```
Fixed by passing `flavour` in from mkfleet.nix. All 9 PHASE-02 lines (+ the 4 PHASE-01 ones) then `ok`.

3. EX-4 variant A (attributable): capsule assertion replaced by `{assertion = false; message = "unrelated";}`:
```
> FAIL the fixture capsule refuses nothing: got 'unrelated', wanted ''
> FAIL   and it names postgresql-18: 'unrelated' does not mention 'postgresql-18'
> FAIL   and it is slotRefusal's own message: got 'false', wanted 'true'
> ok   slotRefusal of a package-only selection is null
> ok   slotRefusal names the capability fragment
> ok   a capsule selecting postgresql-18 has exactly one failing assertion
> ok     and the extended image still evaluates its package set
> ok   persists names the fragment and its path
> ok   modules of a package-only selection is empty
error: builder for '...fragments-cases.drv' failed with exit code 1;
```
Cases 1 and 3 stay `ok`; the break is local to case 2 (the control also goes red, as the base capsule now has a failing assertion). This is the variant that satisfies EX-4.

4. EX-4 variant B (the design's literal wording), `assertion = throw "unrelated";`: EVAL ABORT, not attributable (no FAIL line, build fails):
```
error: unrelated
note: trace involved the following derivations:
       derivation 'fragments-cases'
```
Restored `vm/capsule.nix` from a scratch copy after both; rebuilt green.

### Gate
`just check` green (alejandra complies); `just` exit 0; `just cases` exit 0. `doctrine slice verify-vt 9`: PHASE-01 VT-1..5 PASS; PHASE-02 VT-2 PASS, VT-1 and VT-3 UNATTRIBUTABLE (files not yet committed); no keyword-absent FAIL for PHASE-02 (PHASE-03 FAILs are for work not yet done).

### Not exercised
No room boots, no postgres runs. The `postgresql-18` module is evaluated nowhere except case 2's `config.assertions` path (it contributes only the refusal; the module itself is not imported by a capsule or a room). `roomImages` still excludes it; `vm/room.nix` untouched. No consumer (/srv/fleet) built.

## PHASE-03 (execute)

Base commit c13665d. Model: sonnet (standing SL-009 policy). Files: `vm/room.nix` (imports, `fileSystems`, `room-persist`, header paragraph, `utils` argument), `mkfleet.nix` (`persistRules`, `roomRecords` into `fragmentsCases`), `fragments.nix` (optional `lib ? pkgs.lib`; outside the design's file list), `fragments-cases.nix` (cases 4, 5, 6, 9), `fixture/default.nix` (`assistant.extras = ["search" "postgresql-18"]`, comment). `rooms.nix` unchanged.

### Spike: imports recursion
`imports = [door] ++ fragments.modules room.extras` with `fragments` built from the module's `pkgs`: `nix eval .#nixosConfigurations.assistant.config.networking.hostName` -> `error: infinite recursion encountered` (trace: "you probably reference `config` in `imports`"). Fixed with `lib ? pkgs.lib` on `fragments.nix`, and `vm/room.nix` passes `inherit pkgs lib`; re-eval -> `"capsule"`. mkfleet.nix and vm/capsule.nix pass no `lib` (default; same store path).

### Red first
After writing cases 4, 5, 6, 9 (before the module): eval aborts while a read precedes its feature (`The option services.postgresql.package' was accessed but has no value defined`, then `attribute 'listen_addresses' missing`, then `fileSystems.<no persist entry>.fsType' was accessed but has no value defined`); each was guarded (`optionalString`, `or`, a no-op extension when there are no entries) so the red is FAIL lines. Suite red:
```
FAIL assistant enables postgresql: got 'false', wanted 'true'
FAIL   at major 18: got '', wanted '18'
FAIL   listening on no address: got '<unset>', wanted ''
FAIL   with exactly the two access rules: got '', wanted 'local all      postgres peer map=postgres ...
FAIL   ensureUsers names exactly the declared users: got '[]', wanted '["agent","eve"]'
FAIL   ensureDatabases is the same list: got '[]', wanted '["agent","eve"]'
FAIL a login 'pg_demo' fails exactly one assertion: got '0', wanted '1'   (same for template1, shared_x)
FAIL a bind with fsType 'auto' fails exactly one persistence rule: got '0', wanted '1'
FAIL a bind without x-systemd.requires fails exactly one persistence rule: got '0', wanted '1'
```
With rules and fixture but no render: `error: The option fileSystems."/var/lib/postgresql".fsType' was accessed but has no value defined` (case 9's extensions define a lone entry; an abort, quoted, gone once the render exists). Case 6 was born green (no fragment on lounge, nothing to render): all four lines `ok` at first run. After the render: 40 `ok`, no FAIL.

### Mutations (each restored from a copy, `cmp`'d; tree rebuilt green, 40 ok)
| mutation | red | reason line |
|---|---|---|
| M1 drop `x-systemd.requires` (room.nix) | case 9 control; case 7's assistant control; 9a (fsAuto) 2 reasons; case 7 sudo "exactly one" 2 | `FAIL assistant fails no persistence rule: got '... persistence: /var/lib/postgresql lacks x-systemd.requires=room-persist.service; 'after' alone does not pull the oneshot in (DEC-061, RV-025 F-4)'` |
| M2a `requires = []` | same controls; 9a, 9b, sudo count 2 | `... persistence: room-persist does not require home.mount; /home may not be there to make them in (DEC-061)` |
| M2b `DefaultDependencies = true` | same | `... persistence: room-persist does not set DefaultDependencies = false; it would wait on a target that waits on it (DEC-061)` |
| M3 `fsType = "auto"` | 9 control, case 7 control, 9b 2 reasons, sudo count 2 | `... persistence: /var/lib/postgresql has an fsType other than "none"; a bind has no filesystem type (DEC-061, RV-025 F-2)` |
| M3b delete the `fsType` line | EVAL ABORT only, no FAIL line; does not exercise the rule | `error: The option fileSystems."/var/lib/postgresql".fsType' was accessed but has no value defined. Try setting the option.` |
| M4 `listen_addresses = mkForce "localhost"` | case 4 only | `FAIL   listening on no address: got 'localhost', wanted ''` |
| M5 add `local all      all      peer` | case 4 only | `FAIL   with exactly the two access rules: got 'local all      postgres peer map=postgres` (multi-line, shows the extra rule) |
| M6 drop `template1` | case 5 template1 lines only | `FAIL a login 'template1' fails exactly one assertion: got '0', wanted '1'`; `FAIL   and it names 'template1': '' does not mention 'template1'` |
| M7 drop `shared_` prefix | case 5 shared_x lines only | `FAIL a login 'shared_x' fails exactly one assertion: got '0', wanted '1'`; `FAIL   and it names 'shared_x': ...` |

M1's 9b stays ok (its `mkForce` already drops the option); M3's 9a stays ok (forces "auto" either way). Cases 4 and 5 stay ok under M1-M3 and vice versa under M4-M7.
Case 6 mutation: `lounge.extras = ["postgresql-18"]` (fixture) ->
```
FAIL lounge does not enable postgresql: got 'true', wanted 'false'
FAIL   has no filesystem at the bind: got 'true', wanted 'false'
FAIL   has no room-persist unit: got 'true', wanted 'false'
FAIL   and a login 'pg_demo' fails no assertion there: got 'fragments.nix postgresql-18: a login is a reserved role name: pg_demo', wanted ''
```
Restored; no other case moved.

### Gate
alejandra -c clean over all five files; `just check` green; `just` exit 0 (47s, warm cache; `roomImages` builds `assistant` and `lounge`, so the runner with postgres builds); `just cases` exit 0; `doctrine slice verify-vt 9`: PHASE-03 VT-1..3 PASS, VT-4 UNATTRIBUTABLE (fixture file uncommitted), no keyword-absent FAIL; `git diff --stat -- rooms.nix` empty.

### Not exercised
No room booted; `postgresql.target`, the ordering premise (ASM-005) and peer auth over a forward (ASM-006) are PHASE-05's. The bind's mount-unit entry in `room-persist.before` is rendered and not pinned by a rule (roomChecks pins `local-fs.target`, as design sec-5). No consumer room (/srv/fleet) built; the persistence rules now run over every room there (vacuously for a room with no capability fragment). The dependency half has mutation evidence (M2a, M2b) but no standing negative case; cheap candidates: extensions with `requires = mkForce []` and `DefaultDependencies = true`. M3b is an abort and proves nothing of the rule.
