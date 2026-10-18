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
fresh-as-of: <yyyy-mm-dd> · <PHASE-NN | stage> · <head-commit>

### Produced

### Learned

### Open
