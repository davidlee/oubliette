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
