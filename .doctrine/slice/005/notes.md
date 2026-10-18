# Notes SL-005: Rooms: a namespace with no uplink, and the door a room is reached by

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-10-18, design run revision 5)

Evidence: `research/research.md` (gitignored; X-numbers below are its
cross-thread findings, C-numbers its binding constraints).

### Shaping decisions already taken
- **Image identity (X1 option a, user, 2026-10-18).** A room image keeps
  hostName `capsule`, so `any_vm_running`'s `microvm@capsule` covers it and
  DEC-031 holds with no probe change. DEC-020's "only slots are
  instantiable" is amended to "slots and declared rooms". The amendment is a
  new DEC superseding DEC-020's clause.
- **Probe refusal (DEC-031, accepted).** Stop the room before a probe.
- **Addressing (X2).** A room reuses `net` in its own namespace. No index,
  no new /30.

### Open questions (each becomes a design inquiry)
1. Shape of the `rooms` declaration: fields, required ninth `mkFleet`
   argument, where the runner key and repo list live (C9–C11, X7).
2. What builds a room image: oubliette guest modules per room kind, or a
   module the consumer supplies (POL-002).
3. `capsule-netns` with no uplink: how the absence is keyed, all or nothing
   for the uplink variables, `undo_up` with no peer (C4, NOTES item 37).
4. Disjointness: the names covered, three ways, `reasons` and a case (X2,
   C6/C7, NOTES item 38).
5. Host units: naming under `capsule-` (X4), and whether the module
   generalises `instances` or holds a separate room set.
6. Guard: a room limb, or amend CON-005 (X3, POL-001).
7. The door: relay path and owner, agent keys, host-key policy, exec home,
   pi-env reach (X6, C14, C16, C17).
8. The per-repo quarantine layout, pinned but not built (X5, C25).
9. Stop and lifecycle: ExecStop with the stop key, `vmmOf` mapping rooms
   to `capsule`, and whether the front end learns rooms for a cheap stop
   (C22, DEC-031 consequences).
10. Plan E's minimal caller: what "minimal" means once the tailnet drop and
    the furniture are out of scope.

### Risks
- RSK-005 widens with each room `nixosConfigurations` attr.
- RSK-003: the room's netns unit inherits the unproven unit-level teardown.
- ISS-014: an always-up room with no NTP drifts across suspend (X8).
- ISS-020: fixture rooms leak through oubliette's exported host module.
- `rooms` as a required argument breaks every consumer until it passes
  `rooms = {}`. `/srv/fleet` is the user's change to make.

### Assumptions
- The runner runs on this host, so the relay is a unix socket
  (`satan:IDE-007` item 2).
- Satan's option D is the leading consumer of the door: harness on the
  host, tools via pi-env (X6). Nothing here may depend on it.

### Constraining governance
POL-001..004, STD-001, ADR-002 (the ledger stays closed), DEC-020 (being
amended), DEC-025/026 (consumer arguments), DEC-029 (the throw runs in
every caller), DEC-030 (template eval-check), DEC-031, CON-005.

## Review passes (design run, reviewing stage)

- **RV-014**, adversarial, gpt-6-sol, 2026-10-18. Two rounds: 8 findings
  (1 blocker), fixed in design rev 24. A verification round verified 5,
  contested 3 (F-3, F-4, F-6) and raised F-9, a minor. F-9 fixed (rev 30).
  F-3/F-4/F-6 answered `tolerated` with reasons, so they await the user's
  disposition.
- **A further pass would probe**: the door module's refactor of
  `vm/capsule.nix` (does anything else read the moved options?), and
  `host/services.nix`'s per-guest split against the live unit graph. Both
  are cheaper to check at build time (sec-9's toplevel comparison and
  `hostModuleUnits`) than by another design read, so **no further design
  pass is proposed**.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-18 · /audit done (RV-017 concluded), before /reconcile · audited surface 6a91942

### Produced
- DEC-031..DEC-041 (design); DEC-042 supersedes DEC-025 (nine arguments; user assent quoted)
- REV-004 (POL-003 rooms axis + borrowed), REV-005 (POL-004 two callers), REV-006 (POL-003 room uid) — approved, hand-applied, done
- RV-014 (design review); F-6 settled by behaviour at PHASE-09 (docs/probes.md "A room with no way out")
- PHASE-01..10 code: 233a0e3 2b7709f 0723d6c 9d6f69b daffe6c 9a76496 8838a61 ed1a4e3 57e28ad 93a672f c24ebad a22f882 8ebf3e6; evidence a07094d (PHASE-09 probes.md); governance 33dafaf 6f7b754
- PHASE-10 appended by hand (no verb appends a phase; user accepted): RSK-012 fix + sec-7 status fall-through
- RSK-011 (open), RSK-012 (resolved, fixed)
- new files: rooms.nix, fabric.nix, vm/door.nix, vm/room.nix, + cases (rooms, fabric, netns, room-verbs); roomImages in just build
- consumer /srv/fleet d3bf0a0: rooms.assistant (agent uid 1001), oubliette f2ce48c — live on this host
- memories: mem_01a00ad6…ea57 corrected (5b42e1b: ~/flakes' override keeps its own lock for fleet inputs); mem.fact.oubliette.probe-built-from-consumer-needs-host-nixpkgs (cd78f4c)
- RV-017 (audit, reconciliation facet): F-1..F-10, all verified; brief in review-017.md
- ISS-022 (F-1, deferred by the user: the fabric throw's wiring and placement)
- memories: mem.fact.oubliette.tmpfs-root-guest-uids-move-with-name-order, mem.fact.oubliette.tryeval-does-not-catch-type-errors
- observations: committed per charter (35f686e, daffe6c, e3a1c51, c5f8495, d0364fc, 09c6975, 8591ebd)

### Learned
- tryEval catches throw/assert only → recorded (mem.fact.oubliette.tryeval-does-not-catch-type-errors)
- tmpfs-root uid allocation by name order; /home mounts after activation → recorded (mem.fact.oubliette.tmpfs-root-guest-uids-move-with-name-order)
- a build sandbox's /etc is read-only, so a program writing /etc/netns needs a path seam (etcNetns) — in CLAUDE.md and RV-017 F-5

### Open (for /reconcile and after)
- /reconcile: RV-017 `## Reconciliation Brief` — design.md sec-2/3/5/7/8/9/12 (F-3..F-7) and `slice selector add` for 11 paths (F-8); no REV
- ISS-022 (F-1): move the fabric assert onto mkFleet's result and pin the wiring — after SL-006 leaves mkfleet.nix/flake.nix
- RSK-011 (F-10): room named capsule-<slot> shares a HostKeyAlias
- tolerated: F-2 slot start readiness unpinned (first live slot start is the evidence); F-9 serial console login prompt unobserved
- locally allocated ids DEC-042, REV-004..006 — collision unchecked now that the reservation remote answers
- PHASE-09 not proven: satan's runner beyond the door; uid survival over existing files; suspend (ISS-014)
- /srv/fleet flake.lock nixpkgs bump is uncommitted (the user's)
- RV-014 F-6 follow-up candidate: an ssh/systemctl seam for host/cli.nix

## PHASE-08: docs footprint

### Blame-ignore (T10)
No `.git-blame-ignore-revs` entry for 57e28ad. `git show --stat` is 2686+/2357-
(host/cli.nix reindent), but `git show -w --stat` is 368+/39-: the reindent and the
room-verb logic share one commit, so ignoring it would attribute the room verbs to
the previous author. A future reindent-only commit is the thing to ignore.

### Drift: REV-A and REV-B not drafted
`doctrine revision new` failed twice (both titles) with:
`Error: reach=auto: reservation remote origin unreachable and local fallback declined. Set [reservation] allow-local-fallback=true or DOCTRINE_RESERVATION_FALLBACK=1 to allocate locally.`
caused by `git fetch origin +refs/doctrine/reservation/*: git@github.com: Permission denied (publickey)`.
No revision was created. EX-2 stays open until the orchestrator re-runs T1/T2
(POL-004 has assent "4. agree"; POL-003's `{ uid; keys; }` row has none yet, so
POL-003 stays stale on room users until the user agrees).

### Other notes
- `docs/probes.md`: only a guard line is :1080 ("2 of 10 declared"), already the
  new form and measured evidence; no change.
- `doctrine revision list` returns no rows although REV-004 exists (friction).
- `CLAUDE.md` "one list for the fleet today" (extras) left alone: `vm/room.nix` takes no extras.

## Relay to satan (for the user to send)

To `satan:IDE-007` / satan SL-023, from oubliette SL-005 (design sec-6):
1. ASM-005 can settle: the door is a unix socket (`/run/capsule-room/<room>/ssh.sock`),
   login `agent@<net.guest>` through `ProxyCommand`, with `HostKeyAlias` and strict
   host-key checking (host keys are stable for the volume's life). DEC-037.
2. `guest_path` is the target's `guestPath`, not runner config. The room's git
   channel is a follow-on slice (ISS-021).
3. Promotion is a plain `git fetch` from `/var/lib/capsule/collect/<room>/<target>.git`,
   with no land verb (DEC-040, satan DEC-061). IDE-007's "fetch straight into
   `refs/remotes/satan/*`" should change (oubliette plan-f §4 already says so).
4. The runner must run as the module owner: the socket is mode 0600.
5. A stop is a reboot through the stop key that cuts in-flight work, not a graceful stop.
6. A room user is `{ uid; keys; }` with a declared uid in 1000-29999 (RSK-012, a22f882),
   so a satan room declaration must carry a uid per user.

## EX-1 checklist (sec-10)

| sec-10 row | landed |
|---|---|
| DEC-025 -> nine arguments (DEC-042) | 33dafaf |
| POL-003 rooms axis + `borrowed` | 33dafaf (REV-004). REV-B (`{ uid; keys; }`, a22f882 drift): NOT drafted, see drift above |
| POL-004 rationale | REV-A: NOT drafted (reservation error); CLAUDE.md:28-31 aligned in the PHASE-08 commit |
| CON-005 scope note | ed1a4e3 |
| RSK-005 | 33dafaf |
| docs/contract-assignment.md noun table | ed1a4e3, a22f882 |
| docs/contract-target.md | untouched by design |
| docs/plan-e-room.md | PHASE-08 commit |
| docs/plan-f-assistant.md | PHASE-08 commit |
| CLAUDE.md case list `netnsCases` | 2b7709f |
| CLAUDE.md case list `roomsCases` | 9d6f69b |
| CLAUDE.md `DEC-032` | 9a76496 |
| NOTES item 18 | untouched by design |
| "no bridge, no LAN exposure" | untouched by design |
| satan relay | PHASE-08 commit (above) |
