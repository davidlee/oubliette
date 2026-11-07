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

Settled in design (DEC-069 to DEC-073):

1. **The relay unit** (DEC-070, DEC-072). `capsule-model-relay-<n>` runs
   `socat TCP-LISTEN` on `net.host:<port>` to `UNIX-CONNECT:<socket>`, as the
   owner, in the slot's namespace. It is bound to the namespace and the tap,
   allows only the guest's address, and copies the ssh relay's hardening. The
   `microvm@` drop-in `wants` it when the slot's door is on.
2. **The declaration** (DEC-069, DEC-071). A slot declares
   `modelDoor = "on" | "off"`, its state at start. An absent field means no
   unit. The host side is an optional `net.modelDoor = {port; socket;}`.
   Evaluation refuses:
   - `modelDoor` on a slot when `net.modelDoor` is absent;
   - a port equal to `proxyPort` or 22;
   - a socket path failing `state-dir.nix`'s path refusal.
3. **The verb** (DEC-072). `capsule <n> model on|off` is owner-only, like
   `policy`. It records the override in the live record (`-` means "as
   declared") and starts or stops the unit. The status table gains a `model`
   column.
4. **The guest side is the consumer's** (DEC-073). Inject entries carry the
   gateway key (per `$capsule`, opaque), pi's `models.json`
   (`apiKey: "!cat …"`) and `PI_OFFLINE=1`. The template and the fixture carry
   examples. Oubliette ships no guest code for it.
5. **Text that moves.** `docs/contract-target.md:324` and `:336` are restated,
   and Plan F §2 is annotated.
6. **Tests.**
   - `hostModuleUnits`: the unit exists only for declaring slots, with its
     hardening, tap binding and one-line `ExecStart` pinned.
   - Negative cases for each refusal, with the reason asserted.
   - A cases suite for the verb.
   - The user's live run, recorded in `docs/probes.md`.

## Non-Goals

- **IDE-004** (the gateway holds the claude/codex OAuth credentials).
  Later, and mostly `~/flakes` work. RSK-013 stays open.
- **Rooms.** The same unit should serve a room unchanged, because one
  `capsule-netns` serves both (SL-005). But wiring a room, and POL-005's
  reading ("a room never fetches"), is a follow-up.
- **An optional proxy / uplink for a slot.** IMP-029 (user's call,
  2026-11-08). The door must work without depending on the uplink.
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
- `host/cli.nix`: the `model` verb and the status column.
- `state-dir.nix`: the reused path refusal (read, not changed, if it fits).
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
- **Open: does a slot with a door still need a proxy?** (user, 2026-11-08)
  The proxy carries two kinds of traffic: model API calls and the target's
  own fetches (registries, git remotes, per its policy's allowlist). The door
  replaces only the first. So a slot whose policy fetches nothing beyond the
  model needs no proxy, and possibly no uplink at all: its namespace would be
  shaped like a room's, which `capsule-netns` already builds (SL-005). The door
  is what makes a sealed slot usable for agent work. **Direction (user): the
  proxy becomes optional for a slot. Out of this slice, tracked as IMP-029.** Evidence it is cheap: the unit graph
  already has a working `uplink = null` path, which rooms use (no proxy, no
  aggregator; `host/services.nix`, `rooms.nix:217`). A slot always gets one
  today (`capsules.nix:141`), so the change is mostly in the declaration.
  Design questions: does an uplink-less slot keep its declared index (the /30
  is carved from it); what the `policy` verb and status do for a slot that has
  no proxy to re-point; and whether "no uplink" is a slot field or a policy
  value (POL-003: one home). The door must not depend on the uplink: it
  reaches the host through a socket, not a route.
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

- IMP-029: a slot with a door and nothing else to fetch drops its proxy.
- A room's door (the IDE-003 remainder), with POL-005's reading.
- IDE-004 / RSK-013: route claude and codex through the gateway too.
