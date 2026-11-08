# Notes SL-010: A model door for a capsule: a slot reaches the host LLM gateway through its namespace, first for pi

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-08 · ready (plan, PHASE-01 next) · 304bae1

### Produced
- DEC-069..DEC-073 (design run inq-1..inq-5); DEC-073 rationale corrected per RV-027 F-3
- design locked at run rev 39 (commit e040bee); RV-027 concluded after 6 raiser rounds, F-1..F-11
- slice-010.md scope matched to the locked design (799501b)
- plan.toml/plan.md, PHASE-01..PHASE-08, phase sheets materialised (03cf26d, f324d60, 304bae1)
- RSK-013, IDE-004, IMP-029, ISS-029 minted earlier; QUE-003 answered; IDE-003 widened
- no code yet; no suite or build run this slice

### Learned
- mem.pattern.oubliette.a-state-file-is-compared-by-bytes — grep -qx, $(…) and an exec'd pipeline tail each admit a forged override; cmp + exit; mv -T
- research.md Thread 2 fact 4 was wrong ($HOME persists); corrected with DEC-073

### Open
- RV-027 F-4 — control route; re-submit to the raiser once PHASE-06 EX-4/EX-5 exist
- RV-027 F-1, F-2 — probe routes transcribed onto PHASE-04 EX-3 and PHASE-06 EX-2/EX-3
- POL-003 table revision (net.modelDoor, modelDoor) — at reconcile, via doctrine revision (design sec-7)
- mv -T in recordWrite — a planning hardening beyond design sec-4; reconcile writes it back (§ Planning findings)
- fixture slot count for hostModuleUnits — PHASE-05 phase-plan decides (plan.md Notes)
- IMP-009 — gets a note at PHASE-06; ISS-029 — residual for the policy link only

## Drafting concerns carried from inquiry (not represented in the run)

Concerns the decisions imply but do not settle. The drafter resolves each in a
section, or raises it as a new inquiry.

- **D-1. A static `wants` fights the run-time override.** DEC-069 has a verb
  toggle a door whose declared state is `on`/`off`. If the `microvm@` drop-in
  `wants` the relay whenever the declared state is `on` (as it does the proxy,
  `host/services.nix:448`), a slot switched `off` gets its relay back at the
  next VM start. The effective state must be consulted at start. The precedent
  is `allowlistDir` (`host/services.nix:551-563`): run-time state in a dedicated
  `/var/lib/capsule-<kind>/` that tmpfiles seeds at the declared default and the
  verb re-points. `slotPolicy` and `effectivePolicy` (`host/cli.nix:557-616`)
  are the front end's halves. Options: an `ExecCondition` on the relay reading
  such a file, or the front end's `start` starting it. The second misses a bare
  `systemctl start microvm@<n>`.
- **D-2. The verb copies `policy`'s shape and refusal order.** Memories:
  `fact.oubliette.policy-verb-is-owner-only`,
  `fact.oubliette.two-copies-refuse-in-different-orders`,
  `fact.oubliette.devshell-programs-shadow-the-modules`. A suite for it sits
  beside `policyCases` and runs the shipped text (POL-004).
- **D-3. The status table is already too wide** (IMP-009). The `model` column
  adds to that; say so, or fold it into an existing cell.
- **D-4. The path refusal's fit is unchecked.** DEC-071 reuses `state-dir.nix`'s
  refusal for the socket path. Confirm it accepts a `/run/...` socket path, not
  only a state directory, before relying on it. Otherwise factor out the shared
  part rather than writing a second one.
- **D-5. Guest-side pi facts** (pi 1.5.0 docs, ✓ in research.md):
  - `PI_OFFLINE`, `PI_SKIP_VERSION_CHECK` and `PI_TELEMETRY=0` stop startup
    network calls.
  - `settings.json` `packages` try npm at startup, then warn and skip.
  - `authHeader` defaults to `false`, yet the host's gateway provider works
    without it. That pi sends Bearer for `openai-completions` is inferred, not
    documented.
  - `NO_PROXY` already covers `net.host` (`vm/capsule.nix:178-183`).
  - The template and fixture examples should show these.
- **D-6. Where the far end is.**
  - On this host the socket is `~/flakes`' `/run/llm-gateway-client/api.sock`
    (`SocketUser` = the human, mode 0600; `flakes:DEC-075`).
  - The gateway serves `/v1/chat/completions` and `/v1/models` only.
  - Nothing in oubliette may name it, nor order a unit after `llm-gateway*`
    (DEC-070).
  - The consumer is `/srv/fleet`; the user rebuilds it, and `~/flakes`, themselves.

## Further review passes (written after RV-027's last pass, 2026-11-08)

None is needed before lock. RV-027 ran six raiser rounds (Codex, gpt-6.1-sol,
high) and its last two raised one minor each, both on the condition's few lines,
now verified. What a further pass would probe, if one is wanted later, is
what no design reading can settle, and each has an owner already:

- **systemd's use of the condition's status** (exit 1 and 2 skip, 255 fails),
  and whether a switch restarts a changed active relay: live legs in sec-6.
- **F-4's control route**: verifiable only once `/plan` transcribes its
  rounds and mutations onto a host phase's VT criteria; re-verify on RV-027
  then.
- **`IPAddressAllow` support on this host** (live leg 2's red case).

## Planning findings (2026-11-08, for reconcile)

- **`recordWrite`'s final `mv` becomes `mv -T`** (PHASE-04). Design sec-4 says
  `mv`. A plain `mv` onto a directory at `assignment.json` exits 0 and buries
  the candidate inside it (checked: GNU coreutils), so a record write is
  silently lost today, and the "`mv` fails" undo row would be unreachable in a
  sandbox. Hardening within the design's intent; reconcile writes it back.
- **F-1's criterion is transcribed against the locked design** (PHASE-06
  EX-2): its sketch paused `start` at a lock boundary, but rev 29 removed every
  write `start` made, so the rounds drive the verb against each `vmmState`.
- **The status column's live values are not reachable by a case**: `unitState`
  calls `systemctl` from `runtimeInputs`, so every sandbox cell reads `--`.

## Session process notes

- Quotient's allowlisted roots exclude `/home/david`. Run pi workers from
  `~/dev/oubliette` or `~/flakes`.
- Do not read secret values under `~/.pi/agent/` (the harness refuses it, and
  correctly).

## Implementation run (2026-11-08, /super-orchestrator seat)

- **Plan approved (PHASE-01 EN-1, PHASE-02 EN-1).** The user, asked to approve
  the plan's contents phase by phase, replied "Approve as written" this
  session. Scope of the run: PHASE-01..PHASE-07; PHASE-08 is the user's live
  run and is not driven; the seat halts before audit.
- **Envelope: the super-orchestrator default**, accepted by the user. Commits
  per phase on `main`, paths named, never pushed. Re-submitting RV-027 F-4 to
  Codex after PHASE-06 (strong tier, `gpt-6.1-sol`, fresh thread with an
  RV-027 brief, raiser label `raiser`) is in-envelope. Codex tiers checked
  current at run start.
- **pi form: the machine form, unchanged** (user: "dealer's choice"). pi has
  `just`, `git`, `jq`, `cmp`, `bash`, network; it lacks `nix`,
  `nix-instantiate`, `alejandra`, `shellcheck`, `socat`. So pi drafts edits
  only; **every gate is the sub-orchestrator's, on the host**: `just check`
  after each file, `just cases` / `nix build --no-link .#<suite>` for suites,
  `just` at phase end. Host gate is plain `just` (devshell PATH); `just check`
  green at 77fd63e. Run pi with `cwd` `/home/david/dev/oubliette`.
- New files are invisible to the flake eval until `git add`.
- Known sandbox-only failures: none identified (pi cannot run the suites at all).
- Other writers: none expected; tree clean at 77fd63e.

## Autonomy log
- PHASE-01 · `model-door.nix`'s `reasons` is five named keys, `value` throws the first in sec-2 order · lets a round assert the one rule it breaks and that the others hold · decided
- PHASE-01 · `perimeterOf` forces the checked door with `builtins.seq` until PHASE-05 threads it into services.nix (replace the seq then) · nothing reads the value yet, and EX-2 wants every caller's eval to refuse · decided
- PHASE-03 · the suite's `CASE_PROXY_*` variables keep their names under `unitControl` · EX-3 allows only the log spelling to change in the policy rounds; PHASE-06 adds its own · decided
- PHASE-03 · `slice-010.toml`'s selector still names `host/proxy-restart.nix` · a scope selector, not code; reconcile moves it to `host/unit-command.nix` · deferred (audit)
- PHASE-04 · the failing-`mv` round restores the link by hand and asserts nothing about it · the policy verb declares no `recordUndo`, so the link's fate after a failed `mv` is unpinned until PHASE-06; EX-3 asks only that the hook is reached and no generation printed · decided
- PHASE-05 · EN-3: a third fixture slot `gamma` (alpha on, beta off, gamma undeclared), not a second module eval · every `beta` hit in the five named suites is the suite's own fixture; suites fed the fixture's slots go through `declaredSlots` and none pins the count (grep in the phase sheet) · decided
- PHASE-05 · mkfleet's `seq` replaced by a `modelDoor` argument to services.nix, forced there by `withDoor = builtins.seq modelDoor (...)` · keeps PHASE-01 EX-2 (a bad `net.modelDoor` no slot consumes still refuses) while the checked value is the one consumed · decided
- PHASE-05 · `hostModuleUnits`' relay pins are one `modelRelayFaults` list thrown as one branch after `ungranted` · one red run shows every broken pin, not the first; `ungranted` became (verb, unit) pairs · decided
- PHASE-05 · I wrote T1 (option, wrap.nix variable, wrapCases) myself · ~20 lines, and its red/green loop is a nix build pi cannot run · decided
- PHASE-06 · policyCases' fixture gains slot doors only, no `net.modelDoor` · cli.nix reads no `net.modelDoor`; the slot field alone decides refusal 3 · decided
- PHASE-06 · `publishModelDoor`'s remove branch returned 0 whatever `rm` did (pi draft), fixed to return its status, with a round for a restore that fails · an unchecked restore-to-absent would report "did not move" over a stale `on` override, fail-open at the next VM start · decided
- PHASE-07 · `docs/contract-target.md`'s "`:336`" read as the egress row (`:301`): `:336` is the nix floor, and the file is unchanged since before the slice · the egress row is the neighbouring wording that the door makes incomplete; it now names the door as the one host service besides the proxy · decided
- PHASE-07 · the template's `net = import ./net.nix` is commented with the example, not live · the template's `net.nix` declares no door, so a live `net.modelDoor.port` would not evaluate; the uncommented example was evaluated, run and shellchecked in scratch instead · decided
- PHASE-07 · the fixture's `net` moved into its `let` and is `inherit`ed, values unchanged · `access.injections`' live `pi-models` reads `net.host` and `net.modelDoor.port` without spelling them twice · decided
- PHASE-07 · CLAUDE.md's fixture count is nineteen: `modelDoorCases` added (declarations nobody's, its header), `modelDoorOpenCases` not (it takes only its shipped store path; the override files are its own) · counted from the two headers · decided

## Review passes (implementation run)

- PHASE-01 · pi implement T2a (host-path.nix, state-dir.nix, recordOf) $0.012, clean · pi implement T2b (model-door.nix, mkfleet read/force) $0.044, green first build; port message read "is neither … nor 22" for port 22 and a header rationale was invented, both fixed by hand · Sonnet capsule-worker T1 (suite + wiring, red vs stub), clean.
- PHASE-02 · Sonnet capsule-worker T1 (suite + wiring, red vs stub), clean · pi implement T2 (the four lines + header) $0.008, green first build.
- PHASE-03 · pi implement (the rename, seam, suite substitute, `ungranted`) $0.015, green first build; nothing missed. Sudoers configFile compared at 934e468 and after, from `git archive` scratch copies with `hostModule.sudoers` exposed: `cmp` identical (561 bytes). Mutation `unitDo restart`→`stop` in the policy verb: policyCases red at "and the proxy really was restarted", reverted (cmp).
- PHASE-04 · Sonnet capsule-worker T1 (three commit-failure rounds in policyCases, red vs HEAD: rounds 1-2 hook reached, round 3 exit 0 with a generation), clean · pi implement T2 (record.nix order, `mv -T`, `recordUndo`, `model_door`, contract row) $0.010, green first build. Mutation (EX-4): hook moved back above the record read turns the malformed and unwritable-candidate rounds red (link moved, proxy restarted), reverted (cmp).
- PHASE-05 · me T1 (`modelDoorDir` option, `CAPSULE_MODEL_DOOR_DIR` in wrap.nix, wrapCases): red first at "exactly these and no others" (set lacked the variable), green after · Sonnet capsule-worker T2 (fixture door + `gamma`, `modelRelayFaults`, `ungranted` over verbs), red vs a module with the option only: "no such unit" for alpha/beta, no `d` rule; clean · pi implement T3 (services.nix: `relayHardening`, `modelRelayServices`, drop-in, tmpfiles, grant, `modelDoor` arg) $0.068, green first build; needed alejandra (two `{…} // relayHardening` shapes) and two comments fixed by hand (named "pi" in host/, a vacuous 0755 reason). **EX-4**: `capsule-ssh-relay-alpha` and `-lounge` rendered unit text (`config.systemd.units.<u>.text` via `builtins.getFlake` over `git+file?rev=f7013c3` and the dirty tree) `cmp` identical, 38 lines each; the ssh relay already had `RestrictAddressFamilies=AF_INET AF_UNIX`, so nothing moved. The model relay's text differs from the ssh relay's only in Description, ExecCondition, ExecStart and no RuntimeDirectory. **EX-2 mutations** (each reverted, cmp): `after` + a third unit → "after is not exactly the namespace and the tap" (alpha, beta); grant without `stop` → ungranted "stop capsule-model-relay-alpha, …beta"; drop-in want removed → "microvm@alpha does not want it"; an `f` rule under modelDoorDir → "is under … whose files are the verb's"; gamma given a door → "capsule-model-relay-gamma: exists"; `MemoryMax` overridden on the model relay → "MemoryMax … differs from the ssh relay's". **EX-5**: `grep -rnE "llm-gateway|gateway-client|api\.sock|\b4000\b|fixture-model-door" host/` → no hit (rc 1); "gateway" appears only as the generic word in comments. `just check`, `just`, `just cases` rc 0.
- PHASE-06 · Sonnet capsule-worker T1 (policyCases rounds EX-1..EX-6, seams `CASE_VMM` / `CASE_UNIT_FAIL_FROM`, `cellOf` generalising `profileOf`), red vs HEAD: 116 FAILs, all in the new section ("'model' is neither a verb nor a capsule", no model column), none in an existing round; clean · pi implement T2 (the verb, hooks, `slotModelDoor`, `effectiveModelDoor`, status column, usage, `ownVerbs`) $0.114, green first build (632 ok); missed: `publishModelDoor`'s remove branch returned 0 whatever `rm` did, fixed by hand · Sonnet capsule-worker T3: `CASE_UNIT_LOCK_DIR` and two failed-restore rounds (red against the unchecked `rm`: "state is unknown" absent, "did not move" present), and **EX-5 mutations**, each reverted (`cmp` vs a pristine copy): M1 no restore when the stop fails → off-over-on/absent unit-failure rounds red ("saying why", "override is as it was"); M2 restoring `on` where there was no file → four "override is as it was" in the from-absent rounds; M3 `off` skipping the stop when the VM is not running → "the relay was stopped" for inactive and activating, and the off/down undo row; M4 an undo that starts the relay when the VM runs → the four VM-running undo rows ("last of them is a stop") and the failed-undo round; M5 a hook ignoring a failed override write (its `return 1` deleted; `return 0` instead fails shellcheck SC2317 before any round) → the four override-unwritable rounds (exit 0, generation printed, record moved). `volumeCases`' positional `alloc` reader moved `$13`→`$14` for the new column. `just check`, `just`, `just cases` rc 0.
- PHASE-07 · pi implement T1 (fixture live entries, template net/capsules/setup commented, README section) $0.022, `just check` needed alejandra (one blank line in setup.nix); fixed by hand: the fixture lost the scrub-list reason for `fixture-env`; net.nix said the relay runs "as that slot's `owner`" and cited DEC-069 alone; the README's declaration paragraph and `$HOME` (host or guest); **the template's model id `"<the consumer's model id>"` carried an apostrophe inside the jq program's single quotes, so the example broke the shell once uncommented** — caught only by evaluating, running and shellchecking the uncommented copy in scratch · me T2 (contract-target `:324-325` and `:301`, plan-f §2 annotation, CLAUDE.md suite list, branch clauses, count). VT-1..VT-4 keyword greps 0 before, ≥1 after. `grep -rnE 'llm-gateway|gateway-client|api\.sock' host/ *.nix` (cases excluded) no hit. Built `capsule-inject` carries the fixture's `pi-models` (shellchecked by `just build`). `just check`, `hostModuleUnits`, `templateCases`, `just` rc 0.
- seat, after PHASE-07: the template's gateway example was flagged as an unchecked assumption about `~/flakes`. Read-only check: `~/flakes` `agents/gateway.nix:10` (client socket `/run/llm-gateway-client/api.sock`), `features/agents/gateway.nix:148-149` (`SocketUser = username`, `0600`), `agents/gateway-jail.nix:78` (`llm-gateway issue <alias> --models … --budget … --out …`). The template matches; no fix. decided.
