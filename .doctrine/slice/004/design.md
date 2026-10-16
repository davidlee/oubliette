<!-- doctrine:section sec-1 -->
## Shape

Oubliette stops declaring a fleet and starts exporting the function that builds one (`DEC-025`). Today's `outputs` body — about 1,450 lines of `let … in` that bind this host's values and build everything from them — moves almost verbatim into `mkfleet.nix`. Its relative paths (`./vm`, `./host`, `./probe`) still resolve inside oubliette, so text and therefore derivations can stay equal. The two `self` references in that body (`flake.nix:651`, the module check, and `:1473`, `packages.default`) become references to the call's own bindings, since inside a consumer's call oubliette's `self` would name the fixture's outputs (RV-012 F-3).

```
oubliette (public)                              /srv/fleet (private remote)
  flake.nix                                       flake.nix
    inputs: nixpkgs microvm llm-agents doctrine*    inputs: oubliette doctrine goad-walk
    outputs = mkFleet fixture                       outputs = oubliette.lib.mkFleet {
      // { lib.mkFleet; templates.default; }          targets targetFlakes capsules policies
  mkfleet.nix   ← today's outputs body               net extras probe identity setup
  capsules.nix  ← machinery, a function (DEC-026)    fleetPath sources }
  targets/default.nix ← derive, a function         targets/ capsules.nix policies.nix
  fixture/      ← nobody's target and slots        net.nix setup.nix perimeter/ keys
  just/fleet.just ← every shared recipe (DEC-028)  justfile → import .oubliette/fleet.just
  templates/fleet/ ← doctrine-only consumer (DEC-030)
                                         * the devshell's governance CLI, not a target
```

The consumer checkout is both the flake and the devshell's state root (`DEC-027`): the operator works in `/srv/fleet`, `.vm/` is gitignored there, and `CAPSULE_ROOT`/`$PWD` keep their meaning, so no program learns a new root.

<!-- doctrine:section sec-10 -->
## The builder's argument surface

`lib.mkFleet` is curried like `fleet.nix`: oubliette closes over its own `nixpkgs` and `microvm` (so a consumer gets one microvm.nix pin by `follows`, G12), and the caller passes declarations only (POL-004 — never taps, nft or transports).

| argument | what | was | required |
|---|---|---|---|
| `targets` | the target set, already derived by `oubliette.lib.targets` from the consumer's files | `import ./targets` | yes |
| `targetFlakes` | name → flake, exactly the declared targets (DEC-019 throw stays in `fleet.nix`) | `flake.nix:130` | yes |
| `capsules` | `oubliette.lib.capsules {policies} {slots; uplinkNet; egressAddr; egressPeerAddr; volumeReserve}` (DEC-026): the slot set **and** the host's addressing and disk reserve, which `~/flakes` and this host's network must agree with (RV-012 F-1) | `capsules.nix:93,158,182,288` | yes |
| `policies` | the policy vocabulary | `import ./policies.nix` | yes |
| `net` | the link constants | `import ./net.nix` | yes |
| `extras` | fragment names from `fragments.nix`'s vocabulary | `flake.nix:120` | yes |
| `sources` | fragment sources, e.g. `{llm-agents = …}`; replaces handing every guest oubliette's whole `inputs` (research X6, G10) | `specialArgs.inputs` | yes |
| `probe` | `{target; fabric}` — the probe subject and `probeFabric`; `borrowed` throws here against the real `capsules` (DEC-029, G3) | `flake.nix:83,1026` | yes |
| `identity` | `{adminKeys; stopKey}` — root's keys in every image | `vm/capsule.nix:85,99` | yes |
| `setup` | `{volumePath}: [injection]` — the credential sources | `import ./setup.nix` | yes |
| `fleetPath` | the consumer checkout's absolute path; the module's `policyDir` is `fleetPath + "/" + policies.dir` | `host/services.nix:471` default | yes |

Every argument is required: no implicit default (POL-003). Helpers a consumer calls to *prepare* arguments — `lib.targets`, `lib.capsules` — are the split halves of today's files, not defaults. `workBranch` stays a constant inside `mkfleet.nix`; POL-003 already excludes it as an axis.

Interface and namespace *names* (`cap-`, `eg-up`, `eg-rt`, `vm-capsule`) stay oubliette's constants: they are the platform's vocabulary, and `borrowed` still asserts the probe fabric disjoint from them. **One `setup` value** reaches both its consumers — the guest's reset-home scrub list (`vm/capsule.nix:59`, via `specialArgs`) and the host's injections (`host/programs.nix:348`) — so the list scrubbed is the list injected by construction, and `resetHomeCases` keeps pinning it (RV-012 F-2).

`identity`, `setup` and `fleetPath` reach code that today imports or spells them (`vm/capsule.nix`, `host/programs.nix:348`, `host/services.nix:471`) as `specialArgs` or as arguments of the existing factories. Equal values produce equal derivations, so this is checkable by the manifest (§Verification).

<!-- doctrine:section sec-2 -->
## What moves where

| file today | becomes | in oubliette | in the consumer |
|---|---|---|---|
| `flake.nix` | `mkfleet.nix` (body) + a short `flake.nix` | builder, fixture call, `lib`, `templates` | a call of `lib.mkFleet` |
| `capsules.nix` | split (DEC-026) | a function → `{instances, socketOf, recordOf, volumeLock, egress, asserts…}`, with names as constants | `capsules.nix`: the slots plus `uplinkNet`, the two egress addresses and `volumeReserve` |
| `targets/default.nix` | split | `byName → {byName (derived), volumePath}` | `targets/default.nix`: the hand list |
| `targets/doctrine.nix` | moves | `templates/fleet/targets/doctrine.nix` (the commented reference) | a thin copy |
| `targets/goad-walk.nix` | moves | — | `targets/goad-walk.nix` |
| `policies.nix`, `net.nix`, `setup.nix`, `perimeter/*.txt` | move | commented reference copies in the template; fixture values in `fixture/` | this host's values |
| `vm/stop-key.pub`, `adminKeys` literal | move | fixture: no stop key file, `adminKeys = []` | `identity` |
| `justfile` | split (DEC-028) | `just/fleet.just` (shared recipes) + `justfile` (parse, fmt, oubliette-only) | `justfile`: `import '.oubliette/fleet.just'` plus its own parse/fmt |
| `fleet-cases.nix` and every `*-cases.nix` | unchanged location | over the fixture | — |

`perimeter/default.nix` and `perimeter/root.nix` are code and stay. `fragments.nix` (vocabulary) stays; `extras` (selection) moves.

The heavily-commented reference versions of the moving files live in `templates/fleet/`, still inside oubliette's tree, so ADR-002's `NOTES item` count does not fall and `docs/` links still resolve; the private consumer keeps thin copies that cite oubliette by repo and path (ADR-003 clause 2). `targets/goad-walk.nix`'s one citation leaves the tree with it, and the commit says so.

<!-- doctrine:section sec-3 -->
## The fixture

`fixture/` holds oubliette's own call of `mkFleet` — values that are nobody's (POL-002, ledger 051):

- target `fixture`: `toolsPackage = null`, `caches = {}`, `guestConfig = {}`, `baseline = null`, `path = "/nonexistent/fixture"` — every optional field on its absent path.
- slots `alpha` and `beta` (the existing precedent, `fleet-cases.nix`), both `profile = "fixture"`, on the fixture's two policies.
- `identity = {adminKeys = []; stopKey = <a fixture literal>}`; a fixture image has no usable root and is build-only.
- `probe.fabric`: a copy of today's `probeFabric` values, asserted disjoint from the fixture slots by the same `borrowed`.
- `targetFlakes.fixture`: a stub exposing an empty tool set, so `vm/capsule.nix` builds without a real project.
- `sources.llm-agents = inputs.llm-agents` — oubliette keeps that input for its fixture build; a consumer pins its own or `follows`.

`hello` stays an output. `nixosConfigurations` keeps DEC-020's rule that only slots (plus the probe subject `capsule`) are instantiable; the fixture adds `alpha`, `beta` and `capsule`, none of which a host would `microvm -c` since no host runs oubliette's own outputs.

Suites that take fixtures today (`guardCases`, `policyCases`, `volumeCases`, `volumeRootCases`) stop borrowing the real `capsules.nix` machinery-plus-slots and take `lib.capsules` applied to their own fixture, which is the shape their headers already describe.

<!-- doctrine:section sec-4 -->
## Recipes and the devshell

**One copy of every shared recipe** (DEC-028). `just/fleet.just` holds `build`, `units`, `cases`, `build-vm`, `verify` and every operational recipe (`up`, `down`, `refresh-build`, `status`, `provision`, `inject`, `refresh`, `baseline`, `collect`, `adopt`, `brief`, `setup`, `branches`, `fetch`, `load`, `allowed`, `_net`, `_policy`, `_proxy-log`). Their text is unchanged: `justfile_directory()` is the *root* justfile's directory, so in a consumer `just up a` still passes `-f /srv/fleet`, and `--file net.nix`/`policies.nix` read the consumer's files, which is why a consumer keeps those names at its root.

- oubliette's `justfile`: `import 'just/fleet.just'` plus `check`, `parse`, `fmt`, `fmt-check` over `nix_paths` (which drops the moved files and gains `mkfleet.nix`, `fixture`, `templates`).
- a consumer's `justfile`: `import? '.oubliette/fleet.just'` (optional, so a fresh checkout still parses) plus its own `check` and a tracked note recipe that says to enter the devshell when the shared recipes are absent (RV-012 F-6).
- `.oubliette` is a gitignored symlink to the locked oubliette source, re-pointed on *every* entry by the consumer devshell's `shellHook` (emitted by `mkFleet`), so inside a devshell the link always names that devshell's own oubliette. The template's `.envrc` is `use flake` (nix-direnv watches `flake.lock`, so an `oubliette` update reloads it) and `export CAPSULE_ROOT=$PWD`, the same as oubliette's own, so an inherited root from another checkout is replaced on entry (RV-012 F-7). For a plain `nix develop` without direnv, the `shellHook` warns when `CAPSULE_ROOT` (or the legacy `MICROVM_SPIKE_ROOT`) is set and is not `$PWD`; it warns rather than overriding, since a deliberate `CAPSULE_ROOT` is the caller's to set (`mem.fact.oubliette.wrap-hard-exports-defeat-the-caller`).

Shared recipes exist only inside the devshell, as the programs they call do; that is the devshell path's shape, not a gap. Outside a devshell the link may name an older oubliette, and that is tolerated for the same reason the devshell's binaries are (§Risks). Same staleness class as the devshell's binaries (`mem.fact.oubliette.devshell-binaries-are-store-paths`): re-enter the devshell after `nix flake update oubliette`. The recipes and the programs they call therefore come from one revision.

**The devshell** is emitted by `mkFleet`, so `nix develop` in `/srv/fleet` gives the real fleet's programs — the same store paths the module installs (RSK-004, G7). Oubliette's own devshell is the fixture's: right for working on oubliette, unable to drive a real slot, and it says so only by its slot names. No root, no rebuild (G8).

<!-- doctrine:section sec-5 -->
## Probes, suites and gates

| gate | runs | over |
|---|---|---|
| oubliette `just` | `check`; every `*Cases` suite; `hostModuleUnits`/`Programs`; every probe built (shellcheck); `templateCases` | the fixture |
| consumer `just` | `check` of its own files; `build` and `units` from the shared module | the real declarations |
| probes (`sudo probe-*`) | run only from the consumer devshell | the real `.#capsule` (DEC-029) |

`borrowed` throws at eval wherever `mkFleet` is called, so the real intersection runs in the consumer's eval and the fixture's in oubliette's (G3). DEC-020's "`.#capsule` is doctrine's image" becomes "the probe target's image, in whichever flake builds it".

**`templateCases`** (DEC-030) evaluates the template's **actual** `flake.nix`: `(import templates/fleet/flake.nix).outputs` called with stub inputs — `oubliette` carrying this tree's `lib`, `doctrine` a stub flake with an empty tool set, `nixpkgs` oubliette's own — so the template's own wiring of its declarations into `mkFleet` is what is tested (RV-012 F-8). Its inputs are never fetched, which is what keeps oubliette's lock target-free. It forces every slot runner's `drvPath` with `deepSeq` so a throw inside an attrset is seen (CLAUDE.md). A template that drifts from the builder's argument surface fails oubliette's build.

The consumer's `just` is a real gate and nothing runs it automatically. That is stated, not solved: G6 holds because the check exists in a `just build`, and running it is part of every consumer change.

<!-- doctrine:section sec-6 -->
## Verification

The move is meant to be derivation-neutral, and that is checkable before anything goes live (STD-001: this is the *compare* rung, not *start* or *exercise*).

1. **Before**, at oubliette HEAD: a manifest of `drvPath` for every `packages.x86_64-linux.*`, every `nixosConfigurations.<slot>.config.microvm.declaredRunner`, and **the module**: the `system.build.toplevel` of a probe NixOS system importing the flake's `nixosModules.capsule-perimeter` (with `owner = "nobody"`, as `hostModule` does), which covers unit definitions, tmpfiles, sudo rules and activation text rather than only unit names (RV-012 F-4). The same expression runs against oubliette and against the consumer. Written to the slice's runtime notes, not committed.
2. **Staged equality.** The phases are ordered so each refactor is checked against the manifest while oubliette still binds the real values: extract `mkfleet.nix` with real values → equal; split `capsules.nix`/`targets` and thread `identity`/`setup`/`fleetPath` → equal; only then swap oubliette's call to the fixture and create the consumer → the consumer's manifest equals the original.
3. **Every difference is explained** in the phase notes, or the phase does not close. While the real values are still bound, `fleetPath` is this checkout's current path, so the module's `policyDir` is unchanged and must be equal. It changes once, at cutover, to `/srv/fleet/perimeter`: an expected, explained difference.
4. oubliette's `just` green over the fixture; the consumer's `just` green over the real declarations.
5. **The real host, at the switch (the user's rung):** before `just system-switch`, the user diffs the old and new system closures (`nix store diff-closures` over the two toplevels, or `nvd diff`); the only expected changes are the `oubliette` → `fleet` input and `policyDir`'s new path. Afterwards `capsule all status` is the *start* evidence.
6. **Not exercised by this slice, and the record says so:** the `~/flakes` switch, the re-pointed slots, a `microvm -u` from `/srv/fleet`, and a probe run from the consumer. Those are the user's steps (§Cutover); the slice records which were done.

Case suites are written red-first where behaviour is new: `templateCases` and the `borrowed` throw over the fixture are each mutated once to watch them go red (CLAUDE.md).

<!-- doctrine:section sec-7 -->
## Cutover

Ordered; **(u)** marks the user's steps.

1. drvPath manifest at oubliette HEAD (§Verification 1).
2. Implement in oubliette, phase by phase, each equal to the manifest while real values are still bound.
3. **(u)** Create `/srv/fleet` owned by the user or `wheel`, and the private remote. The agent populates it from this host's current declarations and pushes only after the user says to.
4. Consumer manifest equals the original; both `just` green.
5. Push oubliette; the consumer locks `github:davidlee/oubliette` at that rev.
6. **(u)** Clear the pre-slot `capsule` and `capsule-b` state directories (CHR-013), then re-point every `/var/lib/microvms/*/flake` — both spellings, `microvm-spike` and `oubliette` — to `/srv/fleet`.
7. **(u)** Confirm the private remote is fetchable wherever `~/flakes` is evaluated, including `aarch64-darwin` (`~/flakes/flake.nix:193`): `nix flake metadata <fleet ref>` on each machine. If one cannot authenticate, stop here — the input swap would break that machine's lock (RV-012 F-9).
8. **(u)** `~/flakes`, exactly:
   - replace input `oubliette` with `fleet` (the private remote), `inputs.nixpkgs.follows = "nixpkgs"`, and the fetchability shims moved onto it: `doctrine.follows`, `goad-walk.follows` → `nixpkgs`;
   - `features/virt/capsule.nix`: `inputs.fleet.inputs.oubliette.inputs.microvm.nixosModules.host` and `inputs.fleet.nixosModules.capsule-perimeter` (one microvm.nix pin, G12);
   - `justfile:14`: `--override-input fleet git+file:///srv/fleet`;
   - the stale `microvm-spike` comments.
9. **(u)** `just system-switch`; then `just refresh-build <slot>` on one slot from `/srv/fleet`, and `capsule all status`.
10. Afterwards, not in this slice: delete the `~/dev/microvm-spike` symlink and the `MICROVM_SPIKE_ROOT` fallback in `perimeter/root.nix` (a program-text change, so its own item).

<!-- doctrine:section sec-8 -->
## Governance and docs footprint

Written in the same commits as the boundary moves (POL-002 scope), and reconciled through a REV at `/reconcile`:

- **POL-002**: the list of places a target's name may appear becomes "only in a consumer flake, plus `fixture/` and `templates/`", with `inputs.doctrine` (the governance CLI) named as an exclusion.
- **POL-003**: rows naming `flake.nix` as the home of `net`, `targetFlakes`, `probeFabric`, `extras` say "the consumer's `mkFleet` call"; Verification says `borrowed` throws in the consumer's eval.
- **POL-001** scope: the consumer holds `policies.nix` and the allowlists as well as `~/flakes` holding part of the perimeter. **POL-004**: "call sites in `flake.nix`" → `mkfleet.nix`.
- **DEC-017, DEC-018, DEC-019, DEC-020, CON-001**: wording that names `flake.nix` as a home; DEC-019's `inputs.target` leaves. An ISS-015 note: the placeholder target it did not take is now taken.
- **Docs**: `contract-target.md` (two literals, the reference file, porting step 1), `contract-flavour.md` (`extras`, fragment sources in the host's lock), `contract-doctrine.md`, `plan-d-fleet.md` §0/§1, `README.md`, `CLAUDE.md`.
- **Memories**: `microvm-create-takes-no-fragment`, `target-input-reads-pushed-edge`, `flakes-builds-this-repo-two-ways` (already stale), `devshell-*`.

<!-- doctrine:section sec-9 -->
## Risks and what is out of scope

- **The argument list is the new coupling.** Eleven required arguments is the honest size of "what a host declares"; the review question for every future change is whether it adds an argument or a value inside one.
- **The `.oubliette` symlink can be stale** (DEC-028 consequence). Mitigation is the existing habit — re-enter the devshell — and `just` could later compare it to the lock.
- **The consumer's gate runs only when someone runs it.** Stated in §Probes; not solved here.
- **Two ways `~/flakes` builds this repo** become two ways it builds the consumer: the lock and the `system-switch` override. Step 7 names both.
- **`~/flakes` still repeats `vm-capsule` and `3128`** (`features/virt/capsule.nix:83,104-105`) from `net`. Pre-existing; a follow-up has the consumer export `net` so `~/flakes` reads it (RV-012 F-5).
- **Out of scope:** Plan F's room, per-repo tool sets, new targets, per-slot flavour (IMP-003), any program behaviour change, and editing `~/flakes` from here.

