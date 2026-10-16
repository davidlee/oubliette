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
