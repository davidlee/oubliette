# Notes SL-008: A room-client bundle: one export of a room's door for host clients and their jails

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-20 · ready (pre-PHASE-01) · 99a9f09

### Produced
- scope, research, locked design, plan; no code yet (commits 10f05c1..99a9f09)
- minted: DEC-054 — state root as mkFleet's declaration; DEC-055 — one door option list; DEC-056 — client binds and strictness; DEC-057 — bundle shape
- reviews: RV-023 — gpt-6-sol design pass, findings disposed; RV-022 — the run's ledger, concluded onto RV-023
- IMP-022 — related; resolves at close

### Learned
- mem.pattern.oubliette.fixture-sshd-in-the-build-sandbox — a case can pin host-key behaviour past the banner
- mem.fact.oubliette.ssh-reads-global-known-hosts — GlobalKnownHostsFile none for a one-store door
- mem.fact.oubliette.runtime-directory-goes-on-every-stop — bind the parent, not the RuntimeDirectory
- mem.fact.oubliette.flakes-home-manager-is-standalone — why DEC-054 is a flake output, not a module option

### Open
- ASM-004 — /run/capsule-room survives a relay stop; consumer's reach rung
- RV-023 F-5, F-8 — answered in design, settled by PHASE-02 and PHASE-03 cases
- DEC-042 successor and POL-003 revision — PHASE-04, need the user's assent

## Design review passes

2026-10-20, after RV-023 concluded (gpt-6-sol: adversarial pass over rev 19,
then a verification pass over rev 25).

What a further pass would probe, and why none is scheduled before locking:

- **F-5 and F-8 (sec-5 case 6)** are answered in rev 27 and not re-verified by
  the raiser. The open question is empirical, not a design question: can an
  unprivileged `sshd -i` run inside the nix build sandbox? The first phase
  answers it by building the case. If it cannot run, the design already names
  the fallback (a stated residual, and the user is told before the plan is
  approved). A further design pass would not settle it.
- **`/run/capsule-room` surviving a relay stop** is systemd's documented
  behaviour and has not been observed here. It belongs to the consumer's live
  rung, not to a design pass.
- A pass on **the state-root move** would read every `cfg.stateDir` reader. The
  verification pass already checked `moduleState`'s insertions (cli.nix:917,
  :937, :1907; volume-root.nix:76). The remaining readers are listed in sec-2's
  table.

## Plan-time refinements of the design

- Design sec-5 case 6 is split by subject. The channel's half (the shipped
  channel text behind a fixture sshd writes the room's known_hosts) goes in
  `roomGitCases` (PHASE-02). The bundle's half goes in `roomClientCases`
  (PHASE-03). Same assertions; each suite pins its own subject.
- The state-root refusal is `state-dir.nix` plus `stateDirCases`, not
  `fleet.nix` (design sec-8's "if").
- Sandbox spike (2026-10-20): an unprivileged `sshd -i` behind socat works in
  a nix build. Case 6's fallback is moot.
