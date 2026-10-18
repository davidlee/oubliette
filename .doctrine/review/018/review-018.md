# Review RV-018 — reconciliation of SL-006

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Mode: **conformance**, self-audit. Surface: the primary checkout at `e16fe32`
(`main`), range `3a52d2e..e16fe32` — not a dispatched slice, so no candidate
branch.

Lines of attack:

1. **Path conformance** — `doctrine slice conformance 6` (PHASE-07's row
   bootstrapped by `record-delta --start cc72b97 --end 4c1d210`, since PHASE-07
   never went `in_progress`). Undeclared and undelivered cells read as leads.
2. **Design vs code** — `host/room-git.nix`, `vm/session.nix`,
   `host/quarantine.nix`, `rooms.nix`, `vm/room.nix`, `host/cli.nix`,
   `host/services.nix`, `host/programs.nix` read against design sec-2..sec-5:
   the order of a run (every caller error 2 before the pre-flight), the 75/2/1
   contract (`DEC-050`), argv-only naming (`DEC-041`), one trust store per room
   (`DEC-047`), no repo table in `session` (`POL-002`), the fragments shared not
   copied (`DEC-045`).
3. **Verification** — `just` (build, units, every `*Cases`) and `doctrine check
   gate` at HEAD; each plan EX/VT/VA against the phase sheets' Findings, and
   PHASE-07's live record against design sec-8's live rung (`STD-001`: which
   verb each piece of evidence covers).
4. **Governance** — `POL-001`..`POL-004` held; `REV-007` applied to `POL-003`;
   the departures the harvest lists, and whether design, decisions
   (`DEC-040`, `DEC-043`, `DEC-045`, `DEC-050`) and contracts say what shipped;
   the binding-source contradiction `IMP-017` names.
5. **The satan-facing interface** (design sec-6) — it is outward-facing, so a
   divergence there is costlier than one in prose read only here.

## Synthesis

**Closure story.** SL-006 does what its design set out to do, and the code is
right where it departs from the text. A room that declares repos gets `/work`,
one seeded clone per repo, and `session`, which reads a tree rendered in `/etc`
and holds no repo table (`POL-002`). One generic program, `capsule-room-git`,
pushes a host branch to `refs/host/<branch>` and collects one branch into
`collect/<room>/<repo>.git`, on fragments shared with `capsule-collect`
(`refuseToken`, `policyLimits`, `boundedFetch`, `proxyThrough`), not copied
(`DEC-045`). The run order holds the design's main rule: every caller error is
decided on this host and exits 2 before the room is asked anything, so none can
read as 75 (`DEC-050`). The front end resolves the repo, user and policy off the
record (`DEC-051`), and every door to a room checks one `known_hosts` under
`room-<room>` (`DEC-047`, `RSK-011` closed).

Evidence, by verb (`STD-001`): `just` green at `e16fe32` (build, units, every
`*Cases`, including the new `quarantineCases`, `sessionCases`, `roomGitCases`);
`doctrine check gate` rc 0; path conformance 27 conformant, 0 undelivered,
undeclared only mechanical paths and governance records (F-5). Each phase's
mutation was observed red and reverted (phase sheets 01–05). The live rung
(phase-07 A4–A16) observed every plan VA-1 item on this host: push prints the
oid and leaves the worktree alone, a commit through `session`, collect into
that repo's quarantine and no other, 75 with the room stopped, a changed key
refused by the door and both verbs until `forget-host-key`, stop/start keeping
clones, uids and host key, and a slot collect on the shared fetch. EVD-010
records the closure cost against the repo-less room, with the nixpkgs-bump
confound stated.

**Standing risks.**
- `IMP-017` / F-1: `session`'s base tools ride a `PATH` that two binding sources
  describe differently. It works on NixOS today; nothing pins it. The user picks
  the direction at reconcile.
- F-4: design sec-6 offers satan a reachability probe that conflates trust
  failure with downtime. The relay has gone; its correction is the user's act.
- `ISS-024`'s fix is pinned at eval only until the user's next rebuild (F-8).
- `ISS-025` (slot git collision), `ISS-023`, `IMP-018`, `CHR-018`: open, outside
  this slice. `DEC-044` stays provisional by the user's word.
- Not exercised anywhere with a real sshd: an authentication failure (F-9).
  Not exercised live but cased: no banner (roomGitCases), an oversize pack and
  a malformed object (quarantineCases). Not exercised at all: a wrong-repo
  collect live, a build through `session`.

**Tradeoffs accepted.**
- `boundedFetch` adds `|| exit 1` after `ulimit`, a change to slot behaviour
  only where `ulimit` itself fails — the safe direction, explained at the
  fragment.
- `push`'s collision with a room name is not thrown at eval (`roomVerbs` is
  separate from the slot verb list); `push` and `forget-host-key` are no slot's
  verbs, so the name stays unambiguous.
- A collect of a branch the room lacks is 1, not 2: the room is the only one
  that knows, and DEC-050 puts everything after the banner at 1.

## Reconciliation Brief

### Per-slice (direct edit)

- **design.md sec-3 and sec-6 (F-1)** — make the base-tools promise one thing
  with `DEC-043` and `docs/contract-target.md`'s room tools row. **Ask the user
  which direction first**: (a) promise a room's non-login `PATH` carries the
  base tools and say how it is pinned, or (b) `session` supplies them itself
  (code: `IMP-017`). Edit to match the answer; if (b), say in sec-3 that the
  code is IMP-017's and not yet built.
- **design.md sec-8 (F-2)** — the "Not reachable by a case" paragraph and the
  `roomGitCases` row: a fixture door reaches no-banner → 75 and post-banner
  failure → 1; only authentication and host-key refusal through a real sshd are
  live-only.
- **design.md sec-4 (F-3)** — `--profile` is `profileLoad` behind
  `refuseToken 2`, with why (`select` exits 1 and falls back to
  `CAPSULE_PROFILE`); step 1's full refusal list (`--user` login name, a state
  root with whitespace or `%`, both ref-format checks, `refs/heads/<branch>`
  exactly, `--` ends options); stdout lines: push `<oid>`, collect
  `<oid>\t<ref>`.
- **design.md sec-6 (F-3, F-4)** — the `GitChannel.refresh`/`collect` rows state
  those stdout shapes; the `GitChannel.reachable` row keeps 75 and drops or
  qualifies `ssh <user> true` (1 for down, 255 for a changed key, may prompt).
  Note for the user: the satan SL-023 relay needs the same correction.
- **design.md sec-5 and sec-11 (F-8)** — sec-5 names the `0750` parent
  (`stateRootOf`) beside the room's `0700` directory, citing `ISS-024`; sec-11's
  `host/services.nix` and `mkfleet.nix` rows gain the parent rule and the
  `unparented` check.
- **selector registry, then sec-11 (F-5)** — load-bearing:
  `doctrine slice selector add` (design-target) for `flake.nix`,
  `host/policy-cases.nix`, `host/volume-cases.nix`, `README.md`,
  `.doctrine/slice/005/design.md`; mirror rows in sec-11. Re-run
  `doctrine slice conformance 6`.

### Governance/spec (REV or record edit)

- **DEC-050 consequences (F-2)** — "cases pin no socket, no banner and a
  post-banner failure with a fixture door; authentication and host-key refusal
  through a real sshd are proven live".
- **DEC-043 (F-1)** — only if the user's answer to F-1 changes what "git joins
  the room's base tools" promises.
- **DEC-040 title and consequences (F-6)** — retitle to the layout it decides;
  record that SL-006 built it as a separate program (`DEC-045`), not a room
  transport fragment in `host/git-channel.nix`.
- **ISS-024 (F-8)** — append that tmpfiles' acceptance on this host is
  unobserved until the user's next rebuild.

### Already done in the audit

- **docs/contract-target.md:19-26 (F-7)** — fix-now, in the audit commit.

## Reconciliation Outcome

The user chose F-1 option (b), `session` supplies the base tools, and placed
the code in `IMP-017` as its own slice, not this one. All proposed edits were
agreed in session ("agreed").

### Direct edits applied
- design.md sec-3 Base tools: they ride the inherited `PATH` until `IMP-017`
  makes `session` supply them (F-1).
- design.md sec-4: `profileLoad`, not `select`; step 1's full refusal list;
  stdout `<oid>` / `<oid>\t<ref>` (F-3).
- design.md sec-5: the declared `0750` parent (`stateRootOf`, `ISS-024`) (F-8).
- design.md sec-6: refresh/collect stdout shapes; `reachable` is 75 only, with
  why `ssh <user> true` is not equivalent; execution env names `IMP-017` (F-1,
  F-3, F-4).
- design.md sec-8: the fixture door reaches 75 (no banner) and 1 (after a
  banner); only a real sshd's auth/host-key refusal is live-only (F-2).
- design.md sec-11: rows for `flake.nix`, the two cli-building suites,
  `README.md`, SL-005's design; the parent rule and `unparented` check (F-5, F-8).
- Selector registry: design-target `flake.nix`, `host/policy-cases.nix`,
  `host/volume-cases.nix`, `README.md`, `.doctrine/slice/005/design.md`,
  `.doctrine/slice/005/notes.md`, `docs/probes.md`. `slice conformance 6` now
  shows only governance records undeclared (F-5).
- docs/contract-target.md: intro (F-7, audit commit); `toolsPackage` absent
  path and the room tools row say the inherited `PATH`, until `IMP-017` (F-1).

### Records edited (no REV: none is an ADR, policy, standard or spec)
- DEC-040: retitled "A room's quarantine is one bare repo per room and repo";
  consequences say SL-006 built it as `capsule-room-git` (`DEC-045`) (F-6).
- DEC-050: consequences say what a fixture door cases and what is live (F-2).
- ISS-024: live acceptance pending the user's next rebuild, and what to observe (F-8).
- IMP-017: the user's direction, and what it will change.
- DEC-043: unchanged; "git joins the room's base tools" holds under (b).

### Withdrawn / tolerated
- F-9: tolerated — an sshd authentication failure is exercised nowhere;
  rationale in the disposition.

### Outside this repo
- The F-4 correction (and F-3's stdout shapes) for satan SL-023: relay text
  given to the user in session; delivering it is the user's act.
- satan's answer (relayed by the user after close): its runner's own ssh
  checks the room's store with `StrictHostKeyChecking=yes`, sound because a push
  always runs first and learns the key; it pins collect's `<oid>\t<ref>`.
  design.md sec-5 updated to say so.

### Hazard
- `doctrine design show 6` reports design.md "behind its run (revision 38)".
  The run cannot see reconcile edits; **do not `design materialise SL-006`**,
  which would render the pre-reconcile prose over them
  (`mem.fact.oubliette.reconcile-edits-are-invisible-to-the-design-run`).

Reconcile pass complete — handoff to /close.
