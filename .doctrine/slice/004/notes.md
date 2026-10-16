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
