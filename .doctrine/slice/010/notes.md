# Notes SL-010: A model door for a capsule: a slot reaches the host LLM gateway through its namespace, first for pi

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-08 · design/reviewing (rev 28) · 29d9d63

### Produced
- DEC-069, DEC-070, DEC-071, DEC-072, DEC-073 (design run inq-1..inq-5)
- RSK-013, IDE-004 (OAuth credential in a capsule; gateway-held OAuth, needs IDE-003)
- IMP-029 (optional proxy/uplink for a slot; needs SL-010)
- QUE-003 answered (an injected credential lasts about a year, user's estimate)
- IDE-003 widened to a capsule or room
- design.md sec-1..sec-9 (drafted from DEC-069..DEC-073); 28 design-target selectors
- RV-027 (GPT hostile pass; F-1..F-9; rounds 1-2 integrated)
- ISS-029 (a moved declared default does not reach an existing render; policy link and model door)

### Learned
- research.md Thread 2 fact 4 was wrong ($HOME persists; reset is a host verb); corrected, and DEC-073 rationale with it
- research.md (gitignored, `.doctrine/slice/010/research/`); its ✓ rows are verified

### Open
- RV-027: F-3, F-4, F-9 answered, awaiting raiser round 3
- Section attestations (user), review-disposed, design-accepted; review.scope (slice-010.md vs revised design) and review.selectors runbook steps
- D-1..D-6 resolved in sections: D-1 sec-4, D-2 sec-4, D-3 sec-4, D-4 sec-2, D-5 sec-5, D-6 sec-3
- POL-003 table revision (net + slots rows) proposed for reconcile (sec-7)

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

## Session process notes

- Quotient's allowlisted roots exclude `/home/david`. Run pi workers from
  `~/dev/oubliette` or `~/flakes`.
- Do not read secret values under `~/.pi/agent/` (the harness refuses it, and
  correctly).
