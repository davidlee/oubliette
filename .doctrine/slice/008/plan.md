# Plan SL-008: a room-client bundle

## Why these phases, in this order

```
PHASE-01 state root ──► PHASE-02 one door ──► PHASE-03 bundle ──► PHASE-04 contract + records
(DEC-054)               (DEC-055)              (DEC-056, DEC-057)   (design sec-6)
```

Each phase stands on the previous one. The bundle names `<stateDir>/room/<r>/known_hosts`,
so the state root has to be a declared value first. It also renders the door,
so the door has to be one option list first. Each of the first three phases
lands green and on its own: PHASE-01 changes no door, and PHASE-02 changes the
door words but adds no export. Docs and governance records come last, so they
describe what shipped rather than what was planned.

- **PHASE-01** is the widest change. It breaks every `mkFleet` caller, and it
  touches the module, two programs' build arguments and the fixture/template.
  Isolating it means a red build there is about the state root and nothing
  else.
- **PHASE-02** carries the door-level change from RV-023 F-2
  (`GlobalKnownHostsFile none`) and the channel's half of design sec-5 case 6.
  At plan time that half moved into `roomGitCases`, the suite that already
  builds the channel from its shipped text over fixture sockets. The channel's
  door is then pinned in the channel's own suite, one suite per subject.
- **PHASE-03** is the export plus `roomClientCases`, including the bundle's
  half of case 6.
- **PHASE-04** carries the two governance acts that need the user, the
  `DEC-042` successor and the `POL-003` revision, and the handback.

## Plan-time evidence

- **An unprivileged `sshd -i` works inside the nix build sandbox** (2026-10-20,
  `nix-build` of a runCommand with openssh 10.5p1 and socat). Behind
  `socat UNIX-LISTEN`, with `/build/state` as root, the three steps gave:
  - strict, before the key is learned: `Host key verification failed`;
  - `accept-new`: wrote `room-x ssh-ed25519 …`, then `Permission denied`;
  - strict, after: `Permission denied`.

  Design sec-5 case 6's fallback is not needed. `/build` is the sandbox's build
  directory on this host.
- **The state-root refusal lives in `state-dir.nix`**, not `fleet.nix`. Design
  sec-8 allowed for this ("if the refusal lives in fleet.nix"). `fleet.nix` is
  slot binding, and a suite belongs beside its subject.

## Boundaries

- No consumer is edited: `/srv/fleet`, `~/flakes`, satan.
- The module's other path options stay options.
- Nothing here runs a live room. The fixture sshd is the run rung. A jail
  reaching a real room, and `/run/capsule-room` surviving a relay stop, are the
  consumer's reach rung (`STD-001`).
