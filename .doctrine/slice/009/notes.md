# Notes SL-009: PostgreSQL service for rooms

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-24 · PHASE-01..04 completed, PHASE-05 (VH) next · e07fb7b

### Produced
- design locked: capability fragment `postgresql-18` for rooms; `design.md` sec-1..sec-9 (e5d94d3..7b5435e)
- DEC-059..DEC-068: the settled answers (DEC-060, -061, -063, -065, -068 amended in-run)
- RV-025: design review (codex), 11 findings, F-1/F-5 demonstrate, rest control
- plan: 5 phases, reviewed by two pi agents (039c24f, 2a89c9d, af13f5e); ready b60823c
- PHASE-01 b367b32 · PHASE-02 c13665d · PHASE-03 ee733f7 · seat fix-up 17d6ef2 · PHASE-04 c71f2bd, c7f4b35 · README root-path correction e07fb7b
- `fragmentsCases` (new suite, 40 ok); `just check && just` green at e07fb7b; verify-vt PHASE-01..04 pass
- friction observations: 8752487, d82bc95
- adaptations outside the design's file list: `fragments.nix` takes a required `lib` (imports recursion); `fragmentsCases` also takes `flavour` and `roomRecords`

### Learned
- mem.fact.oubliette.nixos-service-defaults-defeat-naive-overrides: ProtectHome, mkAfter pg_hba, sudo's default rules
- mem.fact.oubliette.design-lock-needs-routed-findings: route severe findings at first dispose
- mem.fact.oubliette.room-postgres-superuser-path: root (admin keys or the stop key) → `runuser -u postgres -- psql`; `shared_` rule; forward via the room-client bundle
- mem.fact.oubliette.imports-may-not-force-pkgs: a module's imports may not force `pkgs`, so pass `lib`

### Open
- ASM-005: room-persist / bind / postgresql.target boot ordering, live only (PHASE-05 steps 1-3)
- ASM-006: peer auth over an ssh -L forward, and samerole, live only (PHASE-05 steps 4-6)
- DEC-064: the six VH steps are the user's to run
- for /reconcile: design sec-4 says root is reached "only by the host's admin keys", which is false because the stop key is an unrestricted root key (vm/door.nix:86; README fixed in e07fb7b). Design sec-4/sec-7's forward "or `capsule <room> ssh`" is impossible: that verb takes no ssh options (host/cli.nix:1922-1948). Sec-9 omits `fragments.nix`'s `lib` argument
- for /audit (coverage gaps, none required by the design): the password/root-login/default-route rules have no negative case; the bind's `.mount` in `room-persist.before` is unpinned; no case proves an unselected `guestModule` is never evaluated

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

## Seat review fix-up
Behaviour-preserving refactor, so no red step. `fragmentsCases` ok count 40 before, 40 after; `just check` exit 0, `just` exit 0.

1. `fragments.nix`: `lib` is a required argument (dropped `? pkgs.lib`, the expression that recurses for a module caller); comment updated. `mkfleet.nix` and `vm/capsule.nix` now pass `lib` (`vm/room.nix` already did; no other importer).
2. `mkfleet.nix` persistence rule reads `fs.device or null`, presence-guarded as roomChecks' header rule says.
3. `fragments-cases.nix`: the slotRefusal-vs-slotRefusal case is relabelled as a wiring check ("the capsule reports slotRefusal's message, not a second one"); the "still evaluates" case is relabelled to what it pins, that selecting the fragment adds no packages to the capsule.
4. `fragments-cases.nix` tidy: door-rules sentence is its own header paragraph; header states cases are ordered by phase, not design number; dead `baseFlavour` alias removed; `reasonsOf` and `joined` merged into `joinReasons`, uses replaced.

## PHASE-04 (execute)

Prose only; no `.nix` logic touched (one comment in the template).

- `docs/contract-flavour.md`: opening paragraph now says capability fragments are built, for rooms (`SL-009`, `DEC-059`, `DEC-060`) and drops them from **Unbuilt**; new `### Capability fragments, built for rooms` (keys table, guest owns persistence `DEC-061`/`DEC-068`, slots refuse via `slotRefusal`, vocabulary is oubliette's); capability table row reworded, `item 4` kept a possibility; `## Open` guest-services bullet says built for rooms, item 4 open for slots. `docs/index.md` line 18 ("selection unbuilt") is about per-assignment selection and stays true; unchanged.
- `README.md`: new `## PostgreSQL in a room` after `## Rooms`, plus a pointer line in `## Rooms` after the `extras` paragraph. Every VT-1 keyword present. Superuser path is exactly `capsule <room> ssh root` then `runuser -u postgres -- psql`.
- `templates/fleet/flake.nix`: one comment sentence pointing at the section.
- `CLAUDE.md`: `fragmentsCases` in the run-list, `Seventeen` -> `Eighteen` (count re-done by eye: 17 before, 18 now), fixture clause for `fragments-cases.nix` appended, one "and" kept. Looseness: the run-list's defining clause ("run a program's own text") fits `fragmentsCases` loosely, since its subject is the shipped vocabulary and rules over evaluated images; the clause was not rewritten.
- T5 wiring: `fragmentsCases` present in `mkfleet.nix` (992, 1989), `just/fleet.just` (80, 118). T6: `fragments.nix` and `vm/room.nix` headers make no unbuilt/sudo claim; no edit.

`-L` through `capsule <room> ssh`: not possible (`host/cli.nix` ssh verb: first argument is the user, the rest is the remote command). README says so plainly and documents the forward through the room-client bundle: `"$b/bin/ssh" -F "$b/etc/ssh_config" -L 5432:/run/postgresql/.s.PGSQL.5432 <user>@room-<room>`, the destination form being `docs/contract-room-client.md`'s own example (`Host *` matches any name).

Verify: `just check` exit 0; `just` exit 0; `doctrine slice verify-vt 9`: PHASE-01..03 PASS, PHASE-04 VT-1..3 UNATTRIBUTABLE (keyword present; files uncommitted), as expected.

Not exercised: no room booted. The forward command line was derived from docs, not run; `ASM-005` (bind ordering at boot) and `ASM-006` (peer auth over a forward) are stated in the README as not proven (PHASE-05). Reset/`microvm -u` wording rests on the memory body only. EX-4 (memory) is the orchestrator's.

Follow-up: README "From the host." now reads "an `ssh -L` over the room's door" so VT-1 keyword `ssh -L` appears literally (it was only `-L` on the code block's second line); code block unchanged.
