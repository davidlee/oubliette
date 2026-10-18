# Rooms: a namespace with no uplink, and the door a room is reached by

## Context

A *room* is a long-lived guest that is not a capsule slot. Two are scoped:
Plan E's room ([plan-e-room.md](../../../docs/plan-e-room.md)), where several
people ssh into one shared box, and Plan F's assistant
([plan-f-assistant.md](../../../docs/plan-f-assistant.md), `IDE-002`): one
persistent guest holding many repos, driven by `satan:IDE-007`'s runner.
Neither is built. Both need the same namespace machinery underneath, and
Plan F §1 says to build them on one change: two callers are what show the
seam sits in the right place, and that is Plan E's stated purpose ("is the
machinery separable from the product?").

`IMP-015` (SL-004) was the precondition and is met. Declarations live in the
consumer flake and reach oubliette as `lib.mkFleet` arguments.

`satan:IDE-007` is waiting on this slice's design. Its door-facing half
designs against Plan F §4 (one quarantine repo per repo) and §5 (a non-root
agent user reached by ssh). Both are scoping notes today, and this design
must pin them as an interface.

```
mkFleet { rooms = …; fleet = …; }        (consumer)
   │  eval: room namespace names ∩ slot namespace names = ∅, else throw
   ▼
capsule-netns up  (uplink env empty ⇒ no veth, no route, no resolver hop)
   │
   ├── people-room guest  (Plan E: users, sshd, tailnet drop)
   └── assistant guest    (Plan F: agent user, N clones, door below)
          ▲ ssh as agent (runner, satan:IDE-007)
          ▼ host fetch → per-repo quarantine repo → human promotes
```

## Scope & Objectives

1. **`capsule-netns` gains an absence, not a kind** (Plan E §1). The uplink
   block is conditional on its own values being empty. The program learns that
   *a namespace may have no uplink* and never learns what a room is. It is one
   program with two callers, so the room inherits NOTES item 37's teardown
   lessons rather than a second copy that never learned them.
2. **Room namespace names are declared and asserted disjoint** (Plan E §2).
   An eval-time intersection with the slot namespace set throws, reusing the
   `probe.fabric`/`borrowed` shape in `mkfleet.nix` rather than inventing a
   second answer (NOTES item 38).
3. **Two callers on that machinery**: a minimal Plan E room guest and a minimal
   Plan F assistant guest, each with host units in the existing NixOS module.
   Minimal means just enough guest for the seam to be tested by two shapes,
   not either room's full furniture.
4. **Pin the door interface `satan:IDE-007` designs against**, as design
   decisions:
   - Plan F §5: the agent user, the runner's key, and the relay (a unix-socket
     relay on this host, distinct from the capsule relay socket, whose existence
     selects a transport).
   - Plan F §4: the per-repo quarantine layout, and whether
     `host/git-channel.nix`'s profile shape takes a room's repo without
     learning what a room is.
5. **Record the probe-refusal answer** as a knowledge decision. Probes refuse
   on `any_vm_running` (deliberately unscoped), so a room that is always up
   means a routine stop before any probe. Plan E's answer is to accept that
   rather than soften a safety refusal. It is prose today and should be a
   decision record.

## Non-Goals

- **Model door** (Plan F §2, the socat forwarder to the `flakes:SL-011`
  gateway socket). It is a follow-on slice, independent of the git channel once
  the namespace exists.
- **Per-repo tools and the `session` launcher** (Plan F §3). Follow-on.
- **Building the per-repo git channel.** This slice pins its interface (item
  4) and builds it only if the design finds it is one instance of
  `host/git-channel.nix` per repo with no new code.
- Plan E's furniture: shared tmux, chat, identity beyond the door, fork-bomb
  limits (Plan E §5–6).
- Narrowing `any_vm_running`. That is a separate safety decision.
- The runner, queue and approval surface (`satan:IDE-007`). The gateway
  service and its keys (`flakes:SL-011`, unless `flakes:IDE-008` moves it).
- Any `~/flakes` change (for example, the tailnet port). Where the perimeter
  half lives there, the design names it and the user applies it.

## Affected surface

- `host/netns.nix`: the conditional uplink block.
- `mkfleet.nix`: a `rooms` argument, the disjointness throw, and room outputs.
- `host/services.nix` (or a new `host/room.nix` imported by it): the room's
  netns, tap, and relay units, inside the existing module.
- `vm/`: new room guest modules.
- `templates/` and `fixture/`: the example consumer and fixture gain a room
  declaration (DEC-030 eval-checks the template).
- `host/*-cases.nix`: a case suite for the no-uplink path of `capsule-netns`
  and for the throw.
- `docs/plan-e-room.md`, `docs/plan-f-assistant.md`, `docs/contract-*.md`:
  annotated in the same commit as anything that moves the boundary.

## Risks, assumptions, open questions

- **Stale table in Plan E.** Plan E's "What it touches" predates `IMP-015`: it
  puts `rooms.nix` in this repo. Under POL-003 and DEC-025/026, the
  declaration is a consumer `mkFleet` argument and oubliette holds only the
  function. To be settled in design.
- **The front end and `vm-stop`.** Both assume slots: `vm-stop` reaps a
  non-slot VM rather than halting it. Whether a room gets the graceful path
  (the stop key, reboot rather than poweroff) is a design choice. Plan F wants
  it more than Plan E does.
- **Is a room an image per room, or a target-like declaration?** DEC-020 says
  only slots are instantiable and every image is hostName `capsule`. A room
  breaks that by construction. The design must say what it is named and how
  the "VMM identified by namespace" rule still holds.
- **Addressing.** A room needs a `/30` and a tap that are not a slot's. Does
  that come from the `net` declaration (one home per axis), and is it covered
  by the same disjointness throw?
- **Persistence.** Plan F §6 puts `/home` on a volume. The slot volume verbs
  are slot-scoped. Whether a room needs its own reset stays open, and is
  probably out of scope.
- **Assumption:** the runner runs on this host (Plan F §5's expected case,
  `satan:IDE-007` open item 2). If it turns out to be on the tailnet, the relay
  choice changes to Plan E's `.socket` forwarder.

## Verification / closure intent

- A case suite runs `capsule-netns` with empty uplink values and asserts the
  no-uplink shape *and* that a normal slot `up` is unchanged. It is mutated
  once to watch it go red.
- `hostModuleUnits` evaluates the room units. A `tryEval` case pins the
  disjointness throw *and its reason*, forced with `deepSeq`.
- Both room guests build, and the template eval-check passes with a room
  declared. Everything is in `just build`.
- A live run (the user's, needs root): a room boots in its namespace with no
  route out, and the agent user is reachable through the relay. Its evidence is
  recorded per STD-001, with what it does not prove.
- Design decisions recorded for the §4/§5 interface, and `satan:IDE-007`
  told where to read them.

## Summary

The shared namespace machinery for non-slot guests, proven by two callers, plus
the door interface `satan:IDE-007` needs pinned. The model door, tools and git
channel build-out follow.

## Follow-Ups

- Model door slice (Plan F §2).
- Per-repo tools and `session` (Plan F §3).
- Per-repo git channel build-out (Plan F §4), if it is not one instance per
  repo.
- `satan:IDE-007`: correct "LiteLLM virtual key" to "gateway key" (fixed on
  this side in 67807e5).
