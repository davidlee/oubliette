# Review RV-024 — reconciliation of SL-008

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Conformance audit of SL-008 over `ba3e2af..789c102`, reviewed in the primary
tree (not dispatched). Held to the locked design (sec-1 to sec-8), plan.toml's
EN/EX/VT for PHASE-01 to PHASE-04, notes.md's plan-time refinements, DEC-054 to
DEC-058, RV-023 F-1 to F-8, and POL-001 to POL-005. Lines of attack:

1. Is each design decision implemented as stated, and is any design text now false?
2. The path algebra from `doctrine slice conformance 8`: undeclared and undelivered cells.
3. Is each EX/VT met by the suites as they stand, and is every new suite in both `just build` and `just cases`?
4. Is each RV-023 fix actually present in code?
5. Policy: no target name in generic code, no implicit `stateDir` default, reusable code knows nothing of the jail, perimeter untouched.
6. Stale prose: `/var/lib/capsule`, `cfg.stateDir`, `accept-new`, `nine arguments`, `DEC-042`.
7. Trust semantics of the shipped client bundle: what a client can reach, write and be fooled by.

Evidence run by the seat: `just check` 0, `just` 0, `just cases` 0 (no FAIL),
`doctrine check gate` 0. A read-only reviewer (opus) gathered the line-level
evidence, and the seat spot-checked F-1, F-5, F-7 and F-8 before raising them.
Mutations claimed in b4698aa, 923e3e3 and 8cf3ea8 were not re-run.

## Synthesis

The slice delivers what its design decided. The state root is one required
declaration with a canonical-form refusal (DEC-054, DEC-058, POL-003). Oubliette's
room doors share one rendering, which no longer reads this host's global
known_hosts (DEC-055). A room ships a strict, read-only client bundle whose binds
survive a relay stop (DEC-056, DEC-057). Every RV-023 fix is present in code. The
slot programs' store paths are unchanged, and both CLI copies remain one store
path, now pinned in `hostModuleUnits` (RSK-004). No finding is a blocker, and
none is missing code.

The findings fall into three groups:

- **The design text lags the plan** (F-2, F-3, F-4). notes.md recorded the
  refinements: state-dir.nix instead of fleet.nix, case 6 split across two
  suites, the shared fixture sshd, `doorRootOf`. design.md and the selector
  registry were not updated. Reconcile's per-slice surface fixes both.
- **The contract under-stated what a client gets** (F-7, F-8, F-10, F-11). The
  door root reaches every room's socket, an `Include` of `Host *` captures every
  destination, and the bwrap sketch had no passwd. All four are fixed in the
  contract now. The reach of the door root is accepted by DEC-056, so the fix
  is a stated sentence rather than a narrower bind.
- **The governance and docs this slice wrote** (F-1, F-5, F-6). CLAUDE.md
  claimed a symlink case, and DEC-058's body still said pending; both are fixed.
  POL-003's new row says `stateDir` holds volumes, and it does not. That is a
  governance errata, so it goes to reconcile as a REV.

Standing risks:

- Nothing here ran on a live host. There was no rebuild, no tmpfiles run, no
  live room, and no push or collect past authentication.
- A changed host key being refused is unexercised.
- The bwrap example is unexercised; satan:SL-027 is the first real jail.
- ASM-004 (that `/run/capsule-room` survives a relay stop) is held for the live
  rung.
- "A client never writes known_hosts" rests on openssh's implicit
  `UpdateHostKeys` default (IMP-024). The read-only bind turns a regression into
  a failure, not a write.

Tradeoffs consciously accepted:

- The refusal is lazy (mkfleet.nix:58): it fires wherever `stateDir` is read.
- An absent `stateDir` is refused by Nix's own error and pinned by no suite
  (F-12).
- The case-harness helpers are duplicated across suites (IMP-025).

Outside this repo: `/srv/fleet` declares `stateDir` but pins oubliette `10f05c1`.
Fixing it needs this repo pushed and that lock bumped, which is the user's step.

## Reconciliation Brief

### Per-slice (direct edit)

- **F-2: design.md sec-2.** The refusal lives in `state-dir.nix` and is pinned
  by `stateDirCases`, not fleet.nix and `fleetCases`. Its rule is canonical
  form: every component after the leading `/` is a name, which also refuses
  `/`, `//`, a trailing slash and `.`. It is refused wherever the value is read.
  In sec-5, retitle the `fleetCases` bullet to `stateDirCases`.
- **F-3: design.md sec-5 case 6.** Rewrite it as two halves:
  - the channel half in `roomGitCases`, with run-time `CAPSULE_STATE=$here/state`;
  - the bundle half in `room-client-cases.nix`, at `/build/state`, learning the
    key through `roomDoor.words`.

  The wrong-`knownHosts` call-site mutation moves to `roomGitCases`.
- **F-4: the selector registry, which is load-bearing for conformance.**
  - `doctrine slice selector rm 8` for `fleet.nix`, `host/fleet-cases.nix` and
    `host/wrap-cases.nix`.
  - `doctrine slice selector add 8` for `state-dir.nix`, `state-dir-cases.nix`,
    `host/fixture-sshd.nix`, `rooms.nix`, `rooms-cases.nix`, `justfile`,
    `docs/contract-target.md`, `templates/fleet/README.md` and `host/record.nix`.
  - Keep `host/volume-root.nix`, noting that no diff is intended.
  - Mirror the changes in sec-8's table. Add `doorRootOf` to the sec-1 diagram.
    In sec-3, socat is an argument built in programs.nix, not built in
    room-door.nix.

### Governance/spec (REV)

- **F-5: POL-003, REV modify.** The host-state-root row's "what it holds"
  becomes "slot records, the scrub marker, quarantines and each room's
  known_hosts", since volumes live under `microvms`. DEC-058 gets a dated
  amendment line in its record body making the same correction. Its decision is
  unchanged.

## Reconciliation Outcome

User agreement for every item below: "agreed" (2026-10-20), given to the
proposal that listed E1 to E8, the selector changes and the REV.

### Direct edits applied
- design.md sec-1 diagram: `state-dir.nix` line; `doorRootOf` added to rooms.nix (F-4).
- design.md sec-2: canonical-form rule; refused wherever read; the refusal lives in `state-dir.nix`, pinned by `stateDirCases` (F-2).
- design.md sec-3: socat built in host/programs.nix and passed to room-door.nix (F-4).
- design.md sec-5:
  - case 6 rewritten as its two delivered halves, `roomGitCases` and `roomClientCases`, on `host/fixture-sshd.nix` (F-3);
  - the call-site mutation is attributed to `roomGitCases`;
  - the `roomVerbsCases`/`roomGitCases` bullet says what each gained (F-3);
  - the `fleetCases` bullet is now `stateDirCases`, with the delivered values and F-12's unpinned absent argument (F-2).
- design.md sec-8: the `fleet.nix`/`fleet-cases.nix` row is gone and `wrap-cases.nix` is dropped from its row; there are rows for `state-dir*.nix`, `host/fixture-sshd.nix`, `rooms.nix`/`rooms-cases.nix`, `justfile`, `docs/contract-target.md`/`templates/fleet/README.md` and `host/record.nix` (F-4).
- Selector registry (F-4):
  - removed `fleet.nix`, `host/fleet-cases.nix` and `host/wrap-cases.nix`;
  - added nine `design-target` selectors;
  - `host/volume-root.nix` noted as "no diff intended".
- Conformance afterwards: one undelivered path, `host/volume-root.nix` (by design, noted). Undeclared paths are only `.doctrine/` records and `slice-008.md`.

### REVs completed
- REV-009 (`reconcile-sl-008`): done. Its one `modify POL-003` row was hand-landed: the state-root row no longer says volumes. DEC-058 has a dated amendment line (F-5). The narrative is in revision-009.md.

### Fix-now, follow-up, tolerated
- F-1, F-6, F-7, F-8, F-10, F-11: fixed during the audit (3971bc3).
- F-9 is IMP-024 and F-13 is IMP-025.
- F-12 is tolerated, with its rationale in the disposition.

Reconcile pass complete; handoff to /close.
