# Notes SL-004: Oubliette carries no target: a consumer flake declares the fleet

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-16 · ready (plan approved, no phase started) · 0790448

### Produced
- design locked (run rev 42, commit 889d550); nothing implemented
- DEC-025..DEC-030 — the builder, the split, consumer as flake+state root, shared just module, probes built here/run there, template eval-checked
- DEC-025 amended after review: eight owner-grouped arguments, each target paired with its flake
- RV-012 — two GPT passes, eleven findings verified (F-10, F-11 from the sec-10 re-pass); F-3/F-6 demonstrate and F-4/F-8 control are placed in plan phases
- plan.toml/plan.md — nine phases against one drvPath manifest (0790448); phase sheets materialised
- minted: IMP-016 — ~/flakes reads the fleet's net instead of repeating tap and port; IDE-002 — Plan F, which this slice unblocks

### Learned
- mem.fact.oubliette.design-apply-ordering — sections sort as text; needs edges need a second apply; slice edits drift the research baseline
- mem.fact.oubliette.codex-exec-reads-stdin — codex exec needs </dev/null; a design lock wants a route on every severe finding
- mem.fact.oubliette.microvm-create-takes-no-fragment — corrected: two recorded flake spellings across slots
- mem.fact.oubliette.flakes-builds-this-repo-two-ways — corrected: the override path is the oubliette checkout now

### Open
- ASM-003 — the outputs body moves into mkfleet.nix derivation-neutrally; PHASE-02 is its first test
- DEC-019 — superseded at reconcile (targets carry their own flakes)
- user act before PHASE-06: create /srv/fleet and the private remote

## Manifest baseline (ruling, capsule-driver seat, after PHASE-03)
PHASE-03 EX-3 deletes the DEC-019 images check and its cases, which moves
`packages.fleetCases` — so EX-5's "equal to PHASE-01's" cannot hold for that one
entry. Accepted as PHASE-03's one explained difference. **From PHASE-04 on,
every "PHASE-01's manifest" in plan.toml (PHASE-04 EX-5/VA-1, PHASE-05, PHASE-06
EX-1/EX-4/VA-1, PHASE-07, PHASE-09 EX-1/VA-1) reads as the manifest at 4572d07**:
PHASE-01's with `fleetCases` at its PHASE-03 value. plan.toml text is left as
approved; this note is the amendment. Regenerate the baseline without touching
the tree by pointing the instrument at
`builtins.getFlake "git+file://$PWD?rev=4572d07…"` (full sha).

## PHASE-07: wording deferred out of shipped text

At 1284c5a the consumer manifest moved 22 entries against the baseline. Cause:
Part B's wording edits landed inside text that becomes a derivation — shell
comments and messages in `writeShellApplication` text, an option description
(the module's manual), and probe scripts (concatenated whole into each probe).
`profile.nix`'s locator fragment and `perimeter/`'s proxy are spliced into most
programs, so two lines moved `module`, `hostModulePrograms`, every `capsule-*`
program and every suite that takes one. Nix comments outside strings move
nothing and were kept.

Reverted to 61701fe's text; apply after cutover (PHASE-09), when the closure
diff no longer needs to be quiet:

| file | shipped text now (61701fe) | intended |
| --- | --- | --- |
| host/cli.nix (`policyFile` shell comment) | `(policies.nix)` | `(the fleet's \`policies\`)` |
| host/inject.nix (usage echo) | `every declared one (./setup.nix).` | `every declared one (the consumer's setup).` |
| host/profile.nix (`profileLoad` shell comment) | `same reason (policies.nix), one directory up.` | `same reason (the fleet's \`policies\`), one directory up.` |
| host/services.nix (`policyDir` option description) | `bounded and legible (policies.nix).` | `bounded and legible (the fleet's \`policies\`).` |
| mkfleet.nix (`capsule-host` usage echo) | `(policies.nix, NOTES item 36).` | `(the fleet's policies argument, NOTES item 36).` |
| perimeter/default.nix (proxy refusal) | `See policies.nix.` | `See the fleet's policies argument.` |
| probe/harness.sh | `flake.nix` (concatenation, `prelude`, `guestSsh`), `flake.nix`'s \`probeFabric\` / \`capsules.nix\`, `net.nix` | `` `mkProbe` in mkfleet.nix ``, the caller's \`probe.fabric\` (refused at eval by mkfleet.nix) / the caller's \`fleet\`, the caller's \`net\` |
| probe/freshness.sh, netns-boot.sh, netns-egress.sh, netns-restart.sh, netns.sh, two-capsules.sh (headers) | `concatenated … by flake.nix`, `net.nix and targets/`, `has net.nix baked into it`, `flake.nix`'s \`probeFabric\` … \`capsules.nix\` | `` by `mkProbe` in mkfleet.nix ``, the caller's \`net\` and \`targets\`, `has the \`net\` declaration baked into it`, the caller's \`probe.fabric\` that mkfleet.nix refuses to share with the caller's \`fleet\` |

The full intended probe text is `git show 1284c5a:probe/<file>.sh`.
`capsules.nix`'s throw message was kept: a throw is not in any derivation.
`host/git-channel.nix`'s `policyCase` comment, garbled by Part B's edit, was
repaired as a Nix comment (moves nothing).

Residual differences against the baseline, after the revert — inputs
(`inputDrvs`, `inputSrcs`, env keys) identical; only the suite's own text:

- `briefCases` — host/brief-cases.nix takes `slots` (mkfleet.nix
  `declaredSlots`): the source loop runs over the declared slots rather than
  `a b`, the spec-checker's undeclared name is built to miss every declared
  slot, and the declared-name-as-path round asserts its reason.
- `vmCases` — host/vm-cases.nix takes `slots`: the build rounds name a declared
  slot (`a` in this fleet) rather than the literal `c`.
- `resetHomeCases` — vm/reset-home-cases.nix takes the caller's `injections`
  (mkfleet.nix `inherit (access) injections`): the hard-coded `.env` check
  becomes one check per injected payload outside `$HOME` (here `/work/.env`).

`module` and every non-suite program are equal.

## PHASE-08: the template, and templateCases over its actual wiring

`templates/fleet/` is a doctrine-only consumer (one slot, `a`), exported as
`templates.default`; `templates/template-cases.nix` evaluates its **actual**
`flake.nix` outputs against stub inputs (design sec-5, RV-012 F-8): `nixpkgs`
and `llm-agents` are oubliette's own, `oubliette` is `{lib = oublietteLib;}`
(the same value `flake.nix` exports as `lib`), and `doctrine` is a stub whose
one package is named by the template's own `toolsPackage`. A guard throws
naming any template input without a stub, or any stub the template does not
declare. Every runner's drvPath and the devshell's are forced with `deepSeq`;
only slot names reach the derivation text, so the check builds one tiny
derivation and no runner (one `.drv` built: `template-cases`). Eval ~12.5s
wall (guest eval per image plus the devshell).

Red first (T1; template's mkFleet call carrying only `targets`):

    error: function 'anonymous lambda' called without required arguments 'fleet', 'policies', 'net', 'flavour', 'access', 'probe' and 'fleetPath'

Control, EX-3 / VA-1 (T6): `access = {…};` removed from the template's mkFleet
call →

    error: function 'anonymous lambda' called without required argument 'access'

Restored by re-writing the saved copy; `sha256sum -c` OK
(`411fff4c…b42d35`), green again. The same mutation under `just` (default)
passes `check` and `build` and fails at `template-cases` with that line, so a
mis-wired template fails oubliette's gate. Two more mutations, each restored by
copy and sha256-checked: the suite mapping over `{}` →
`templateCases: the template declares no slot, so no runner was forced`; and
`llm-agents` dropped from the stubs →
`templateCases: the template declares inputs this suite has no stub for: llm-agents`.

No move (T7): `/srv/fleet` at 822861b, cloned, oubliette overridden to a
throwaway scratch commit of this working tree (`git+file://…?rev=`): the
consumer manifest is **equal** to the 09f4df8 consumer manifest
(`m07-cons2.json`). Oubliette's own manifest, 09f4df8 → working tree: exactly
one new key, `packages.templateCases`.

`nix flake init -t git+file://<oubliette>` copies the template byte-identical,
`.envrc` included (the template's `.gitignore` re-includes it over a global
ignore: `git check-ignore -v --no-index` names `templates/fleet/.gitignore:9:!.envrc`).

Choices:

- **Stop key (OQ1, D4).** `keys/stop-key.pub` is a real ed25519 public key
  whose private half was deleted at generation, comment
  `template-placeholder-replace-me`. The template's `justfile` `check` gains a
  `stop-key` recipe refusing it, so a fresh consumer's gate is red until the
  operator replaces it (observed in an init'd copy: red on the placeholder,
  green on a fresh key). `adminKeys = []`. The README's key step follows
  oubliette's README ("Host requirements": private half in
  `/var/lib/capsule-stop/key`), not the phase sheet's `ssh-keygen -f
  keys/stop-key`, which would put a private key in the checkout.
- **Wiring (OQ2 fallback).** `just/fleet.just` is unchanged. Oubliette's own
  `justfile` gains `template-cases` and `default: check build template-cases
  units`. **Reconcile item:** EX-2's literal "in `just build`" is met as "in
  oubliette's default gate", because the shared `build` recipe ships to every
  consumer and `templateCases` is oubliette's own check.
- **DEC-030 (OQ3).** Its `choice` says templateCases evaluates the template's
  "declaration files (not its flake.nix)"; this phase follows design sec-5 and
  RV-012 F-8 (the actual `flake.nix`). **Reconcile item:** amend DEC-030.
- `fleetPath` in the template is `/srv/fleet` with a comment that it is this
  checkout's path and is read by nothing yet (RV-012 F-11); `targets/doctrine.nix`'s
  `path` is the placeholder `/srv/src/doctrine`.
- `templates` added to oubliette's `nix_paths`, so `just check` parses and
  formats the template. `just cases` does not list templateCases (its output is
  slot names only).

Not exercised: the template was never locked or built against the real
doctrine flake, never booted, `nix flake check` was not run, and its
`justfile`/`.envrc`/README steps run only as far as the init'd copy's `just
check` above.

Doc drift for reconcile: `docs/contract-target.md:73` still calls
`templates/fleet/targets/doctrine.nix` "forthcoming in SL-004 PHASE-08".

## PHASE-09: cutover, repo side

Repo-side steps only (T1-T5); nothing pushed, nothing committed by the worker,
no sudo, `~/flakes` and `/var/lib/*` read only. The host steps are T5 below.

**T2 (oubliette, host/services.nix).** `policyDir` default is now
`fleetPath + "/" + policies.dir` (`defaultText` `${fleetPath}/${policies.dir}`);
the argument's comment reads in the present tense. The option `description`
and every other shipped string are untouched. `grep microvm-spike` over
host/, mkfleet.nix, fixture/, templates/, vm/, perimeter/, flake.nix, justfile:
no hit; no case asserted the old default (`wrap-cases.nix` passes its own
fixture `policyDir`). README.md lines 153/181/222 name the flake input and
the checkout path, not the default. `just check` and `just` green.

**T1 (consumer relock, /srv/fleet, uncommitted).** `nix flake update oubliette`:
`oubliette` 61701fe -> 9654a71c28e675b66babbf8eb3795d77700bcd0e (as expected).
Root inputs resolved through follows are unchanged by rev: doctrine d804787d,
goad-walk b4bc42fd, nixpkgs e94cb152, llm-agents 03aa73a4 (node renamed
`llm-agents_5` -> `llm-agents_4`). No `file://` anywhere; the only
`git`-typed node is `spectrum` (https://spectrum-os.org/git/spectrum, rev
77d23898, unchanged, microvm.nix's). Removed, all oubliette's former
transitive target inputs (1284c5a: no target in its lock): `target`
(doctrine d804787d) and its subtree (agents_3, pub_2, bun2nix_5/6, crane_4/5,
devshell_3, emacs-overlay_2, flake-parts_7-9, flake-utils_4/5, goad_2,
goad-walk_2, jail-nix_4/5, llm-agents_4(old)/6, nixpkgs-lib_3,
nixpkgs-stable_2, rust-overlay_4/5, systems_8-11, treefmt-nix_5/6), plus
nixpkgs_18..27 duplicates those pulled; `nixpkgs_17` renumbered to rev
d54020a6 (was 6774f7bc, one of the removed target's). Consumer gate
(`env -u MICROVM_SPIKE_ROOT CAPSULE_ROOT=/srv/fleet nix develop -c just`) green.

**T3 (manifest).** Instrument: manifest.nix from a scratch clone of the
consumer (`/tmp/claude-1000/-home-david-dev-oubliette/cc48e7b8-0f76-4f0a-89a6-b60b70522dc3/scratchpad/p09-fleet`, relocked with `--override-input oubliette
git+file://$SP/p09-oub?rev=4f600f58fe5574490df178c4a7f7fe75667719ae`) where
`p09-oub` is a scratch clone of oubliette with the T2 diff committed (never
committed in the real tree). Output `$SP/m09-cons.json`
sha256 `ac277bc05ad6a75c0c220cece125291ea9f1f8037b379c05cebdeea935d81ce4`.
Baseline `m03.json` sha256 7467d0e4...06bc verified. `$SP` = the session scratchpad.

- vs m03.json: `briefCases`, `vmCases`, `resetHomeCases` (explained under
  PHASE-07), `module`, and **`packages.hostModulePrograms`**.
- vs m07-cons2.json (09f4df8 consumer): `module` and
  **`packages.hostModulePrograms`**. The stated expectation was `module`
  alone; `hostModulePrograms` is the second, see below.

`module` leaf walk (`nix derivation show`, recursing the inputDrvs that
differ). Chain: `nixos-system` -> `activate` -> `etc` -> `dbus-1` /
`system-units` / ... and `system-path` -> leaves. 18 leaves, every one equal
to its old self once `/srv/fleet/perimeter` is replaced by
`/home/nobody/dev/microvm-spike/perimeter` (checked mechanically; builder,
args, inputSrcs equal, inputDrv name sets equal):
- 7 wrapper programs `capsule`, `capsule-adopt`, `-baseline`, `-brief`,
  `-collect`, `-provision`, `-refresh`: `CAPSULE_POLICY_DIR:-<policyDir>` (host/wrap.nix);
- `nixos-tmpfiles.d`: the `d`/`a` line for the allowlist directory;
- 10 `unit-capsule-proxy-{a..j}.service`: `ReadOnlyPaths=<policyDir>`;
- intermediates changed only because their inputs did: system-path, etc,
  system-units, activate, dbus-1 (serviceDirectories names system-path),
  `unit-dbus-broker` and `unit-systemd-tmpfiles-resetup` (restart-trigger
  drvs hash the changed `etc`/units), nixos-system.
`hostModulePrograms` (the module's program set as text) differs in exactly the
7 wrapper leaves above and nothing else (7 leaves, residual check clean). It is
a program set built from the same evaluated module, so the same string reaches
it; but it is a manifest entry beyond what the plan's EX-1/VA-1 words allow
("module" alone / "policyDir string in units and tmpfiles"). **Ruling (orchestrator, PHASE-09): accepted as the same one-string change.** The plan's EX-1/VA-1 wording ("module" alone; "units and tmpfiles") missed a third home of the string, the wrappers' `CAPSULE_POLICY_DIR` default (host/wrap.nix), which `hostModulePrograms` renders from the same evaluated module. Read EX-1/VA-1 as "`module` and `hostModulePrograms`, both differing in the policyDir string alone"; plan.toml text is left as approved, this note is the amendment (as the "Manifest baseline" ruling was). The wrapper's
`CAPSULE_POLICY_DIR` default is a third place the string lives besides units
and tmpfiles. The `hostModuleUnits` entry is unchanged (unit names only).

Gates: oubliette `just` green; consumer `just` green on the T1 lock and again
with `--override-input oubliette git+file://...?rev=4f600f58` (lock unchanged:
`cmp` against the T1 lock). `git -C /srv/fleet status` shows only
`M flake.lock`.

**Re-run on the committed sha (orchestrator).** Oubliette b9ad175 (the T2 commit), consumer c328b7a (the T1 relock). A fresh scratch clone of /srv/fleet, locked with `--override-input oubliette git+file:///home/david/dev/oubliette?rev=b9ad17507f571fafe203ecb0edf6e53a0382d75f`, gives a manifest byte-identical to the worker's scratch-commit one (sha256 `ac277bc0…81ce4`). Key diffs: vs m03 `module`, `briefCases`, `hostModulePrograms`, `resetHomeCases`, `vmCases`; vs m07-cons2 `module`, `hostModulePrograms`. Independent check of the leaf claim: `nix derivation show -r` of both closures (old m07-cons2, new), every store hash replaced by a constant and both policyDir spellings by one token, keys re-sorted: `module` 3671 = 3671 derivations, `hostModulePrograms` 2535 = 2535, equal as sets. So the two entries differ in the policyDir string and nothing else. VA-1 holds under the ruling above.

**T4.** The PHASE-07 deferred-wording table is NOT applied here: it would move
derivations the closure diff (VH-1) must show quiet. Applying it is a
follow-up after the host has switched.

### T5: the user's host checklist (prepared, not run)

Ordered. Current state as read: `/var/lib/microvms/{a,b,capsule,capsule-b,f}/flake`
= `/home/david/dev/microvm-spike`; `{c,d,e,j}/flake` = `/home/david/dev/oubliette`;
`/var/lib/capsule` holds `collect doctrine.git slot` (slots a..j).

0. Push request. The oubliette T2 commit is b9ad17507f571fafe203ecb0edf6e53a0382d75f; it must be on origin/main (with the notes commit after it) before the relock. After
   `git push` of oubliette main:
   ```
   cd /srv/fleet && nix flake update oubliette
   jq -r .nodes.oubliette.locked.rev flake.lock     # must be origin/main's sha after the push (b9ad175 or a descendant)
   git commit -am "lock oubliette at the cutover rev" && git push -u origin main   # origin: git@github.com:davidlee/oubliette-fleet.git
   ```
1. CHR-013 (check first, then remove; root, the operator's call):
   ```
   systemctl list-units 'microvm@capsule*'; pgrep -af microvm
   sudo rm -rf /var/lib/microvms/capsule /var/lib/microvms/capsule-b
   ```
2. Re-point every remaining flake file (listed: a b c d e f j):
   ```
   for s in a b c d e f j; do echo /srv/fleet | sudo tee /var/lib/microvms/$s/flake >/dev/null; done
   for f in /var/lib/microvms/*/flake; do echo "$f: $(cat $f)"; done   # all /srv/fleet
   ```
3. RV-012 F-9, on every machine that evaluates ~/flakes (incl. the aarch64-darwin one, ~/flakes/flake.nix:189 `systems = linuxSystems ++ ["aarch64-darwin"]`; design said :193, now :189). **Stop if any fails**:
   ```
   nix flake metadata git+ssh://git@github.com/davidlee/oubliette-fleet
   ```
4. ~/flakes edits (file:line as read now; the design's wording needs three corrections, flagged):
   - flake.nix:128-134: replace the `oubliette` input with
     `fleet = { url = "git+ssh://git@github.com/davidlee/oubliette-fleet"; inputs = { nixpkgs.follows = "nixpkgs"; doctrine.follows = "nixpkgs"; goad-walk.follows = "nixpkgs"; }; };`
     **Correction:** the current shim `target.follows` (line 132) goes — the fleet has no `target` input, it has root `doctrine` and `goad-walk` (and `llm-agents` follows oubliette's). Comment block flake.nix:111-127 (incl. "Was github:davidlee/microvm-spike") to be reworded: it names `oubliette`/`target`.
   - features/virt/capsule.nix:53-54: `inputs.fleet.inputs.oubliette.inputs.microvm.nixosModules.host` and `inputs.fleet.nixosModules.capsule-perimeter`.
   - **Correction:** the design's `justfile:14 --override-input fleet git+file:///srv/fleet` is stale. justfile:14-18 now builds `local_override` from `tree_override` plus `bin/dev-checkouts override`, which emits `--override-input <i> git+file://$HOME/dev/<i>` for `inputs=(oubliette goad panopticon satan-patcher satan-attrd)` (bin/dev-checkouts:16). `oubliette` there would name an input that no longer exists, and `fleet` is at /srv/fleet, not ~/dev/fleet. Needs a decision: add `fleet_override := "--override-input fleet git+file:///srv/fleet"` to `local_override` (justfile:18), and swap `oubliette` for `fleet` in bin/dev-checkouts:16 only if its root rule can express /srv/fleet (it cannot as written); also `update-local` (justfile:182-184, `nix flake update ... $(bin/dev-checkouts names)`) and bin/dev-checkouts-test (lines 63, 70, 73, 106, 108) name `oubliette`. `push-local` (justfile:187) pushes ~/dev/oubliette and can stay.
   - stale `microvm-spike` comments: features/virt/capsule.nix:1-2, 111; flake.nix:114; hosts/Sleipnir/features.nix:11 ("local oubliette checkout").
   - **Done by the seat, 2026-10-17, uncommitted in ~/flakes (the user's tree holds unrelated uncommitted edits too):**
     - The shim proposed above is **wrong**: with `doctrine` (and `goad-walk`) following nixpkgs, the fleet's
       `capsule-perimeter` module fails eval with `attribute 'packages' missing` — it evaluates each target's guest
       image (`nixos-system-capsule`, `firecracker-capsule.json`), which reads the target flake's `packages`. Shown on
       a scratch clone of /srv/fleet relocked with both overridden to nixpkgs; the unshimmed module evaluates. So
       `fleet = { url = "git+ssh://git@github.com/davidlee/oubliette-fleet"; inputs.nixpkgs.follows = "nixpkgs"; };`,
       and the comment says why. capsule.nix's claim that this config never evaluates the guest closure was already
       untrue of the module and is reworded.
     - Override: `bin/dev-checkouts` stays the one list — `inputs=(fleet goad …)`, with `fleet` resolving to
       `$FLAKES_FLEET` (default /srv/fleet) instead of `<root>/fleet`; whitespace refused for it too. Red-first in
       `bin/dev-checkouts-test` (six cases; every case aims FLAKES_FLEET into the throwaway tree so this host's
       /srv/fleet cannot leak in); mutation (fleet resolved under the root) turns two red; shellcheck clean.
       `update-local`, `stub`, `ahead` and `names` now cover the fleet with no justfile change.
     - `nix flake lock`: root inputs resolved by reference differ only in `oubliette` → `fleet` (3a19e0f, whose
       oubliette is 63cc360); no other root input moved; no `file://` node. The added nodes are doctrine's and
       goad-walk's own dependencies, now locked rather than shimmed.
5. Closure diff (VH-1), `~/flakes`:
   ```
   just system-build        # sudo ./run.sh build <host> <override>; prints/links the new toplevel
   nix store diff-closures /nix/var/nix/profiles/system-1100-link <new toplevel path>
   ```
   **Baseline correction (seat, 2026-10-17):** `/run/current-system` is system-1101 (switched 10:16 today), which
   carries the *fixture's* host module (`microvm@alpha`/`@beta` drop-ins, two proxy units, no a–j) — the hazard
   flagged after PHASE-07. Diff against system-1100 (2026-10-16 13:07), the last real-fleet system; against 1101 the
   diff is the fixture → fleet swap and says nothing about policyDir. Also expect guest-image evaluation to be
   new to ~/flakes' eval (see step 4), though the toplevel need not contain a runner.
   Expected: the oubliette -> fleet input swap and `policyDir` moving
   `/home/<owner>/dev/microvm-spike/perimeter` -> `/srv/fleet/perimeter` in 7 wrappers, tmpfiles, and 10 proxy units (and their dependents). Nothing else; anything else, stop.
6. `cd ~/flakes && just system-switch`.
7. `cd /srv/fleet && direnv allow`, then `just refresh-build <slot>` for one slot (e.g. `a`).
8. `/run/current-system/sw/bin/capsule all status`.
9. Oubliette follow-up: `perimeter/egress-allow.txt` and `perimeter/egress-none.txt` both exist in /srv/fleet/perimeter and are byte-identical (`cmp`). Nothing in oubliette's code, fixture, template, justfile or devshell reads `perimeter/*.txt` (fixture uses `fixture/perimeter/`, the template `templates/fleet/perimeter/`; `mkfleet.nix` reads `policies.dir`). So `git rm perimeter/egress-allow.txt perimeter/egress-none.txt` is a plain delete for code; docs still cite it (docs/architecture-walkthrough.md:156, design.md:23,83, contract-assignment.md:146, plan-b:135, plan-d:110,302) and want a pass in the same commit. Do this only after step 8 is green.
10. Sec-7 step 10 (delete the `~/dev/microvm-spike` symlink and the `MICROVM_SPIKE_ROOT` fallback in `perimeter/root.nix`) is out of this slice.

## PHASE-09: the user's steps, and their results (EX-4)

Recorded by the seat on the user's word, 2026-10-17.

| step | done | result |
| --- | --- | --- |
| push oubliette; consumer relocked and pushed (EX-2) | yes, by the user | oubliette origin/main ⊇ 63cc360; /srv/fleet 3a19e0f "lock oubliette at the cutover rev" on origin |
| 1 CHR-013: clear `capsule`, `capsule-b` | yes | `/var/lib/microvms/capsule*` absent |
| 2 re-point `/var/lib/microvms/*/flake` | yes | a b c d e f j all read `/srv/fleet` |
| 3 RV-012 F-9: fetch the private fleet on every machine | yes | Sleipnir locks it; the user reports the Mac's `nix flake metadata` and `just darwin-build` work |
| 4 ~/flakes edits | yes, by the seat on the user's word | see the step-4 entry above; uncommitted in ~/flakes at the time, for the user and ~/flakes SL-010 |
| 5 closure diff vs system-1100 (VH-1) | yes | `diff-closures` showed only terminfo packages (~/flakes SL-010 fe348e8f, not this slice). It hides one-string edits, so the seat compared system-1100 with the new toplevel directly, store hashes and both policyDir spellings normalised: capsule units, `microvm@` drop-ins, unit set, capsule tmpfiles and every `capsule*` wrapper equal; 7 wrappers carry `/srv/fleet/perimeter`; no `microvm-spike` left. **User accepts VH-1: "VH-1 yes".** |
| 6 `just system-switch` | yes | current-system 3ki8rhf6…-nixos-system-Sleipnir |
| 7 `direnv allow`; `just refresh-build a` from /srv/fleet (VH-2) | yes | **user: "just ran it, no issues"** |
| 8 `capsule all status` (module copy) | yes | all ten slots a–j listed. With `a` started: vm/proxy/relay running, door and answers yes, baseline ok; `capsule-perimeter-guard: 1 of 10 declared capsule namespace(s) verified` |

Found on the way:
- system-1101 (10:16, before the cutover) had already carried the fixture's host module. ~/flakes' local override read oubliette after PHASE-07. No capsule was running; the switch replaced it.
- `a` refused ssh after the cutover (fresh host keys). The user fixed known_hosts by hand. `reset-known-hosts` picks its branch from a socket, so it is folded into ISS-017 (919b294).

Still to do after cutover, in oubliette:
- the wording deferred out of shipped text (PHASE-07 section above);
- delete `perimeter/egress-{allow,none}.txt` once `cmp` agrees with /srv/fleet's copies, with the doc pass.

## Post-cutover follow-ups (PHASE-07 wording, PHASE-09 item 9)

- **A, commit f2b8376.** The PHASE-07 table applied as its "intended" column, line for line from 1284c5a, except `host/services.nix`: only the `policyDir` description (its default and the `fleetPath` comment are newer than 1284c5a). `just` green. Oubliette manifest vs 3defd26: 23 entries move — `module`, `packages.hostModulePrograms`, capsule-baseline/-brief/-cli/-collect/-host/-inject/-provision/-refresh, probe-freshness/-netns/-netns-boot/-netns-egress/-netns-restart/-two-capsules, gitChannelCases/observeCases/policyCases/profileCases/snapshotCases/volumeCases/wrapCases; no runner. Method: for each moved entry, `nix derivation show -r` of the old and new closure, store hashes replaced by a constant, inputDrvs/inputSrcs sorted, and in the new closure the 27 edited lines replaced by their old text (both JSON and double-encoded `__json` forms). Every one equals its old closure, and none does without the substitution, so every move is an edited line reaching it. Consumer (scratch clone of /srv/fleet, oubliette overridden to f2b8376) vs the same clone at 3defd26 (itself equal to the live lock on 63cc360): the same 23 entries, every one explained by the same check; runners unmoved. (1284c5a's 22 were counted against m03, a different baseline; not re-derived.)
- **B (this commit).** `perimeter/egress-allow.txt` and `perimeter/egress-none.txt` deleted after `cmp` against /srv/fleet/perimeter. Doc pass: README.md, CLAUDE.md, docs/architecture-walkthrough.md, docs/design.md, docs/contract-assignment.md, docs/plan-b-other-jails.md, docs/plan-d-fleet.md. `just` green. Oubliette manifest byte-identical to commit A's (nothing builds from those two files; the fleet reads `policies.dir`, here `fixture/perimeter`). Left citing them: docs/ledger (closed, ADR-002), docs/plan-d-fleet.md:302-303 (history, NOTES item 23), IMP-015's prose (a record; not edited).
