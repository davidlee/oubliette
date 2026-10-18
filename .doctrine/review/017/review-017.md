# Review RV-017 — reconciliation of SL-005

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Mode: **conformance**, self-audit. Surface: the primary tree at `6a91942`
(SL-005 fully committed; SL-006 is being implemented concurrently in the same
tree, so this audit makes no code edits).

Evidence run this pass: `just` rc 0 (check, build with every suite incl.
`netnsCases roomsCases fabricCases roomVerbsCases roomImages`, template-cases,
units); `doctrine check gate` rc 0; `doctrine slice verify-vt 5` 25/25 PASS;
`doctrine slice conformance 5`; the module front end `capsule status` live.

Lines of attack:
1. **Design vs code** — every locked section (sec-1..12) against what landed;
   the gitignored phase sheets 02/04/05/07/10 are the only record of the
   deviations, so each is carried here as a finding.
2. **Conformance algebra** — undeclared paths are either scope creep or a
   registry gap.
3. **Pins** — every sec-9 claim has the check sec-9 names, or the gap is stated.
   CLAUDE.md's rules: pin the reason, force what you pin, a wrapper/wiring line
   falls between suites.
4. **Live evidence** (STD-001) — what `docs/probes.md` "A room with no way out"
   proves and does not.
5. **Policies** POL-001..004 held: perimeter host-side (no uplink, root by key),
   nothing generic learns a room's purpose, one declaration per axis, reusable
   code takes injected seams.

## Synthesis

**Verdict: SL-005 delivered what its locked design asked for.** It has one
code gap, deferred (F-1 → ISS-022). The rest is design text that fell behind
direction the user gave during the slice (F-3..F-7) and a selector registry
that never learned the paths the phases touched (F-8). Nothing blocks.

Surface: the primary tree at `6a91942`, the last SL-005 commit. SL-006 has
since landed `6f103c7` and `e626f69` on top. The second of those changes
`rooms.nix` again (repos, a policy, a work volume), so the prime cache reads
stale for reasons that are SL-006's, not this audit's.

How the parts fit, briefly:

```
mkFleet { rooms } ─▶ rooms.nix (records + reasons) ─▶ fabric.nix (borrowed, reason)
                          │                                   └─ thrown in the probe prelude (F-1)
                          ├─▶ host/services.nix: units over guests ─▶ capsule-netns (no uplink)
                          ├─▶ host/guard.nix: audits every guest namespace
                          ├─▶ host/cli.nix: ssh | start | stop, status block, collide
                          └─▶ vm/room.nix + vm/door.nix ─▶ roomImages (+ predicates, F-6)
```

One behaviour, end to end. A room has **no way out** because its
`capsule-netns` unit gets no uplink environment (`capsuleEnv` over a record
with `uplink = null`). The program then builds no veth, route or resolver, and
refuses a half-set group before arming its trap. `netnsCases` pins the slot
sequence unchanged, the no-uplink sequence, the partial refusal and its reason,
and a rollback with no peer deletion (the mutation of case 4 went red). Live:
`ip route` inside showed only the `/30`, `1.1.1.1:443` was unreachable, and
`net.host:22` was refused, while the door reached `uid=1001(agent)` and the
same key was refused as root.

What holds the policies: POL-001 holds host-side (no route, a guard over every
guest namespace, root by host keys only, and the console autologin pinned off
at build). POL-002 holds: no `kind`, and a room differs from a slot by an
absent uplink. POL-003 holds: `rooms` is a required ninth argument, uids are
declared (F-3), and the name spaces are disjoint at eval, except the
known_hosts alias (F-10, RSK-011). POL-004 holds through the `tools`/`etcNetns`
seams (F-5).

**Standing risks**
- ISS-022 (F-1): a probe fabric that borrows a live name throws only in a build
  that includes probes, and the wiring line is pinned by nothing.
- Slot start readiness after the PHASE-07 refactor (F-2) is equivalent by
  reading only. The first `capsule <slot> start` on this host is its evidence.
- RSK-011 (F-10): a room named `capsule-<slot>` collides with that slot's
  host-key alias.
- The serial console's login prompt is unobserved (F-9). Its configuration is
  pinned at build.
- Ids DEC-042 and REV-004..006 were allocated locally while the reservation
  remote refused the key. RV-017 and ISS-022 were allocated normally this
  session, so the remote is back, but nobody has checked whether those earlier
  four collide with anything.
- Unchanged and named by the design: RSK-003, ISS-014, RSK-007, VMM-writable
  image directories.

**Tradeoffs consciously accepted**: F-2 and F-9 are tolerated with rationale.
F-1 is deferred by the user's choice, because SL-006 shares the tree.

**Optional checks for the user** (root, cheap): watch the serial console the
next time the room starts (F-9), and start one slot once to exercise the
refactored readiness (F-2).

Read further: `doctrine show RV-017`, `doctrine show ISS-022`,
`doctrine show RSK-011`, `doctrine show DEC-042` (the nine arguments).

## Reconciliation Brief

All entries are per-slice. Every governance or spec change this slice needed
already landed during it (REV-004, REV-005, REV-006, DEC-042), and F-1's fix
brings the code to POL-003's wording, so **no REV is needed**. Describe
SL-005's state, as of `6a91942`. SL-006's later changes to `rooms.nix` are
SL-006's to reconcile.

### Per-slice (direct edit)
- **F-3** design.md sec-2: users table row and example become
  `users.<u> = { uid; keys; }`, with the uid declared in 1000-29999. The
  `reasons.users` bullet lists the clauses (shape, no uid, no keys, uid range,
  uid shared within a room). sec-5: the user bullet carries the declared uid,
  and roomImages checks the image's uid against the record's. sec-8: the
  fixture users carry uids. Basis: RSK-012, the user's "fix it in this slice".
- **F-4** design.md sec-2's probe-fabric paragraph: `liveNames`/`borrowed`/
  `reason` live in pure `fabric.nix`, applied once in mkfleet.nix and thrown
  in the probe prelude. sec-9 gains a `fabricCases` row. sec-12 gains
  `fabric.nix` and `fabric-cases.nix`.
- **F-5** design.md sec-3: `capsule-netns` takes `tools` **and**
  `etcNetns ? "/etc/netns"`, and netnsCases is handed a scratch `/etc/netns`
  (a build sandbox's `/etc` is read-only).
- **F-6** design.md sec-5: `vm/room.nix` also sets `security.lockKernelModules`
  and `security.protectKernelImage` (user-directed, kept out of the door so slot
  images don't move). sec-9's roomImages row adds the three predicates:
  console autologs nobody, no extra groups, uid equals the record's.
- **F-7** design.md sec-7's `capsule status` row: an unnamed `status` with no
  slot up and a room up answers as `all status`. Otherwise the unnamed refusal
  stands.
- **F-8** selector registry (load-bearing): `doctrine slice selector add 5`
  (design-target) for `fabric.nix`, `fabric-cases.nix`, `host/vm-cases.nix`,
  `docs/probes.md`, `README.md`, `justfile`, `host/policy-cases.nix`,
  `host/volume-cases.nix`, `capsules.nix`, `fleet.nix`, `host/own-vms.nix`,
  then re-run `doctrine slice conformance 5`. Mirror in design.md sec-12: rows
  for the substantive paths and one line for the comment-only DEC-032
  citations.

### Governance/spec (REV)
- none (see above).

### Not reconcile's
- F-1 → ISS-022, F-10 → RSK-011 (backlog, code). F-2 and F-9 are tolerated.

## Reconciliation Outcome

User's assent to the whole brief: "agreed". Written against SL-005's state at
`6a91942`; SL-006's later `rooms.nix` changes are SL-006's to reconcile.

### Direct edits applied (design.md)
- sec-2: the example, the `users.<user>` row and the `users` refusal bullet become
  `{ uid; keys; }` with a declared uid in 1000-29999, with the reason (F-3).
- sec-2: the probe fabric is checked by pure `fabric.nix`, thrown in the probe
  prelude. The probe-only firing and the unpinned wiring cite ISS-022 (F-4).
- sec-3: `capsule-netns` takes `tools` and `etcNetns`, and netnsCases is handed a
  scratch `/etc/netns` (F-5).
- sec-5: the user bullet carries the declared uid (F-3). New bullet: the kernel locks
  are in `vm/room.nix`, not the door (F-6).
- sec-7: an unnamed `status` with only a room up answers as `all status` (F-7).
- sec-8: the fixture users' uids (F-3).
- sec-9: the probe-fabric row is now `fabricCases` with ISS-022 named (F-4). The
  roomImages row lists every `roomChecks` rule (F-6).
- sec-12: rows for fabric.nix, fabric-cases.nix, docs/probes.md, README.md,
  justfile, the two cases files' `rooms = {}`, and the comment-only DEC-032 files
  (F-8 mirror).

`doctrine design adopt` was refused by design ("at reconcile, edit design.md
directly and do not adopt"), so the run stays locked over the edited text.

### Selector registry
- `doctrine slice selector add 5 --intent design-target` for 11 paths (F-8).
  Conformance: 0 undelivered, 31 conformant. The only undeclared paths are
  `.doctrine/` records (governance, memory, observations, notes).

### REVs completed
- none needed: REV-004, REV-005, REV-006 and DEC-042 landed during the slice.

### Not reconcile's
- F-1 → ISS-022 and F-10 → RSK-011 (backlog). F-2 and F-9 are tolerated, with
  rationale in their dispositions.

Reconcile pass complete — handoff to /close.
