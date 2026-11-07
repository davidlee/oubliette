# A model door for a capsule: a slot reaches the host LLM gateway through its namespace, first for pi

## Context

Grows out of IDE-003 (originally written for a room, Plan F §2). The first
consumer is a **slot**: quotient's pi agent running inside a capsule, making
its model calls through the host's `llm-gateway` instead of the egress proxy
with a provider key in the guest.

The gateway (`flakes:SL-011`) listens on `/run/llm-gateway/api.sock`. Its
directory is mode 0750, group `llm-gateway`, and that directory is the gate
(uvicorn makes the socket itself 0666). It serves only chat completions and the
model list. It authenticates with its own keys, issued on the host by
`llm-gateway issue <alias> --models … --budget …` and revocable there.

The shape is the mirror image of the slot's ssh relay (`host/services.nix`,
`relayUnit`). The relay is socat in the slot's namespace from a host unix
socket to the guest's TCP port 22. The door is socat in the slot's namespace
from a TCP listener on `net.host` to the host gateway's unix socket. A socket is
a filesystem object and the guest has no mount namespace, so nothing routes
from the guest to the host. The forward drop and the guard keep their meaning
(POL-001).

```
host root ns                          slot ns cap-<name>
/run/llm-gateway/api.sock  ◀─UNIX─  socat TCP-LISTEN:<net.host>:<port>,fork
   (group llm-gateway)                 DynamicUser, SupplementaryGroups=llm-gateway
                                            ▲ TCP
                                       guest pi ── base URL http://<net.host>:<port>
                                                   gateway key (injected)
```

## Scope & Objectives

1. **The door unit.** A per-slot systemd unit joined to the slot's namespace
   (`NetworkNamespacePath=`), hardened like the relay and the proxy:
   `DynamicUser`, no capabilities, `SupplementaryGroups=llm-gateway`, address
   families AF_INET and AF_UNIX only. A `microvm@` drop-in `wants` it, as it
   already does the proxy and the relay.
2. **Declared, not implied (POL-003).** Whether a slot has a door is a
   declaration (per slot or per policy; design picks). It has a working absent
   path: no declaration means no unit and no listener. The socket path and
   port are values from the caller, not constants a generic file spells
   (POL-002: no gateway name in generic code beyond what the caller supplies).
3. **The guest side.** pi in the guest is pointed at
   `http://<net.host>:<port>`. That config is declared (a fragment's
   `guestModule` or the caller's), never copied from `$HOME`. pi is already in
   the `agents` fragment (`fragments.nix`), so this is configuration rather
   than a new package.
4. **The key.** A gateway key from `llm-gateway issue` is delivered by the
   existing inject path (`host/inject.nix`) as a declared payload. The
   `produce` fragment and the issuing are the consumer's; oubliette learns no
   key format.
5. **Tests.** A `*Cases` suite or `hostModuleUnits` coverage for the unit's
   presence and absence and its hardening. Whether a fixture can carry the
   forwarder end to end (socat to a fixture unix listener) is a design
   question.

## Non-Goals

- **IDE-004** (the gateway holds the claude/codex OAuth credentials).
  Later, and mostly `~/flakes` work. RSK-013 stays open.
- **Rooms.** The same unit should serve a room unchanged, because one
  `capsule-netns` serves both (SL-005). But wiring a room, and POL-005's
  reading ("a room never fetches"), is a follow-up.
- **The devshell path** (`capsule-host`). The host gateway is a module-path
  service; whether the devshell path gets a door is a design question, and the
  default is no.
- **Owning the gateway module.** That is `flakes:IDE-008`. This slice
  consumes the socket and its group as given.
- Changes to the gateway itself.

## Affected surface

- `host/services.nix`: the door unit and the `microvm@` drop-in's `wants`.
- `capsules.nix` / `fleet.nix` (or `policies`): the declaration.
- `templates/fleet/`: the consumer template's declaration and its inject
  entry.
- `fragments.nix` / `vm/capsule.nix`: pi's base URL in the guest.
- `mkfleet.nix`: wiring and the suites in `just build`.
- `docs/contract-target.md` or a new contract section, if the boundary moves.
- `docs/plan-f-assistant.md` §2 points at this slice.

## Risks, assumptions, open questions

- **Assumption:** pi can be pointed at an OpenAI-compatible base URL with a
  bearer key through declared config. Unverified; the research round checks
  it.
- **Assumption:** the host user that runs `llm-gateway` already creates the
  `llm-gateway` group in `~/flakes`, and the module path can name it. If the
  group is absent, the unit must refuse clearly, not fail opaquely.
- **Open:** what decides whether a slot has a door: slot, policy or target.
  Policy is the perimeter's axis, which argues for policy.
- **Open:** the port. One constant across slots (the address already is), from
  the caller's `net`.
- **Risk:** a second way out beside the proxy. The gateway limits models and
  budget per key, but a guest with a door can spend that budget. The key's
  limits are the control, and they are host-side.
- **Risk:** the module path cannot be exercised live without the user's
  rebuild of `~/flakes` (they run system builds).

## Verification / closure intent

- Suites green in `just build`; each fails when its subject is mutated.
- `just check` clean.
- Live, the user's step: a slot whose declaration has a door boots, pi in it
  completes one request through the gateway, and a slot without a door has
  no listener on the port. The verdict lands in `docs/probes.md` / the
  observation ledger (STD-001: say which verb the evidence covers).

## Summary

One declared, hardened socat unit per slot, from the slot's namespace to the
host gateway socket, plus pi's declared base URL and an injected gateway key.

## Follow-Ups

- A room's door (the IDE-003 remainder), with POL-005's reading.
- IDE-004 / RSK-013: route claude and codex through the gateway too.
