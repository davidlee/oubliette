# Plan F — an assistant: one persistent guest, many repos

Not a plan yet: what a plan has to settle, and what the answers cost. Written
2026-10-16 from a scoping conversation, and downstream of two records in other
repos that this file does not own: satan's `IDE-007` (a persistent VM that
SATAN raises proposals from, replacing the satan-patcher bridge) and
`~/flakes`' `IDE-003` (a host LiteLLM service that holds every real model key
and hands clients revocable virtual keys).

Scope: *one long-lived microVM on this host holding checkouts of roughly seven
of the user's repos, driven by a runner that lives outside this repo, reaching
models only through LiteLLM, and returning work only as git the host fetches.*

## The one-line answer

**It is a room ([Plan E](./plan-e-room.md)), not a slot.** A capsule is one
agent, one repo, one unit of work, and its machinery — the assignment record,
the brief, the snapshot, observe, status, the volume verbs — is shaped by that.
An assistant has many repos and no unit of work, so making it a slot would
teach all of those that a slot can hold N targets, or have it skip them by
convention, which is the drift `POL-003` exists to prevent. As a room it never
meets them. What it shares with a capsule is what Plan E already argues is
separable: the namespace, the tap, the image builder, the halt semantics.

```
              host
  ┌───────────────────────────────────────────────────────────┐
  │ ~/dev/<repo> ×7 (real)        LiteLLM (~/flakes, real keys)│
  │   │ push refresh  ▲ promote          ▲ unix socket         │
  │   │               │ (human)          │                     │
  │   │        quarantine/<repo>         │                     │
  │   │               ▲ fetch            │                     │
  └───┼───────────────┼──────────────────┼─────────────────────┘
      │ ssh (host-initiated, both ways)  │
  ┌───┼───────────────┼──────────────────┼─────────────────────┐
  │   ▼               │      socat: TCP-LISTEN ─▶ UNIX-CONNECT │
  │  room netns: no uplink, no proxy, no route anywhere        │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │ guest: /home on a volume, N clones, virtual key only │  │
  │  │ session <repo> -- <cmd>  →  that repo's tools on PATH│  │
  │  └──────────────────────────────────────────────────────┘  │
  └────────────────────────────────────────────────────────────┘
        ▲ ssh in (the runner, scheduled outside oubliette)
```

## What a plan has to settle

### 0. Precondition: `IMP-015` first

Seven repos as literal inputs of oubliette's flake is `IMP-015`'s problem
times seven — anyone cloning this repo would fetch this host's projects. So the
repo list, and each repo's tool set, belongs in the operator's consumer flake,
and oubliette exports a builder that takes them as arguments. A room's repo set
is then one more declaration on that side of the line, and nothing here learns
what any repo is (`POL-002`).

### 1. The namespace is Plan E's, with no uplink

[Plan E](./plan-e-room.md) §1–2 apply unchanged: `capsule-netns` learns that a
namespace may have no uplink (an absence, not a kind), and the room's namespace
name is declared and asserted disjoint from `capsules.nix` the way
`probeFabric`/`borrowed` is. Building both rooms on one change is the point —
two callers is what shows the seam is in the right place.

**Default egress is none.** No proxy, no allowlist, no route; the model path
below is not egress, it is a door. Open: whether any repo's build fetches at
build time (a registry, say) — if so, the room takes an optional proxy on a
policy whose allowlist names no git host, declared in `policies.nix` like any
other. "No git egress" is then that policy's content, not a new mechanism.

### 2. The model door: a socket, never a route (`POL-001`)

LiteLLM listens on a unix socket on this host (`~/flakes` owns the service and
the socket's mode). A unit with `NetworkNamespacePath=` the room's runs
`socat TCP-LISTEN:<net.host>:<port>,fork UNIX-CONNECT:<socket>` — the mirror
image of the capsule's ssh relay, which crosses the same boundary the other way
for the same reason: a socket is a filesystem object and there is no mount
namespace. Nothing routes from the guest to the host, and the forward drop and
the guard stay meaningful.

What the guest holds is a LiteLLM **virtual key**: limited to named models,
with its own budget, revocable on the host without touching the guest. That
leaves two existing records live, not solved: `CON-004` (a rotated secret does
not reach a running capsule) and `QUE-003` (does an injected credential survive
use). Delivery is the existing inject path, unless that turns out to be
capsule-shaped.

Hardening of the forwarder copies Plan E's: `DynamicUser`, no capabilities. The
access control is the socket's mode, on the host, where it belongs.

### 3. Tools: per repo, baked host-side, activated by the launcher

The operator's habit is nix-direnv — one repo's devshell active at a time,
switched on `cd`. That does not transfer: evaluating a flake inside the guest
needs its inputs fetched (git egress) and a store that substitutes (more
egress), and the guest has neither by design.

So each repo's tool set is built **on the host** and carried in the image as
its own store path, never unioned onto a shared `PATH` (two repos' toolchains
would collide). Activation is a guest program, `session <repo> -- <cmd>`: set
`PATH` from that repo's set, `cd` into its clone, exec. That is the shape the
user sketched — *the agent registers intent for a session in a repo; another
process starts it there with that repo's tools active* — and it sidesteps the
direnv problem for non-interactive harness shells, because the environment is
set before the harness starts and its subprocesses inherit it. No shell hook,
so no login-shell scope question (`mem.fact.oubliette.environment-variables-is-login-shell-scope`).

Stated rather than discovered: **one session is one repo.** A harness that
`cd`s into a second clone keeps the first one's tools.

Costs to measure, not assume: the closure of seven tool sets (they share most
of nixpkgs, and `EVD-007` priced one composition at about half a gigabyte), and
that a tool change is an image rebuild plus a reboot. The volume makes the
reboot cheap; it does not make it free.

### 4. Git: one quarantine per repo

The host starts every transfer, as in the capsule: it pushes to refresh a
guest clone and fetches proposals out. **Fetches land in a per-repo quarantine
repository, not in the real repo**, for the reasons the capsule's channel does
it (NOTES item 34, `RSK-006`): guest-authored packs are attacker-shaped, and
the size bound covers one packfile, not the transfer. Promotion into the real
repo is the human's step. This differs from `IDE-007`'s "fetch straight into
`refs/remotes/satan/*`, no ref policy needed"; that record should change, not
this one.

`host/git-channel.nix` takes injected fragments (`POL-004`), so the intent is
one instance per repo rather than a second channel. To check before designing:
whether its profile-document shape takes a room's repo without learning what a
room is, or whether its programs assume a slot behind the transport.

### 5. Ingress: the runner ssh's in, and lives elsewhere

Scheduling, the queue, prompt composition and result classification are
satan's (`IDE-007`). Oubliette's part is a door: a non-root agent user whose
key is the runner's, reached through a relay like the capsule's — but not *the*
capsule relay socket, whose existence selects a transport (Plan E). Whether the
runner is on this host (a unix-socket relay) or on the tailnet (Plan E's
`.socket` forwarder) decides which; the first is the expected case.

### 6. Persistence is a volume, stated

Plan E §3 answered the other way: `/home` is on a volume and survives reboots.
"Burning it down" is a delete. The slot volume verbs (clone, reset-home) are
slot-scoped and do not apply; whether a room needs its own reset is open.

## Two operational costs, known in advance

**A room that is always up blocks every probe.** Plan E's cost, made
permanent: probes refuse on `any_vm_running`, deliberately unscoped. With an
assistant running all the time, no probe runs on this host without stopping it
first. Either that is accepted as a routine stop, or the refusal is narrowed —
and narrowing a safety refusal is its own decision, not a side effect.

**`vm-stop` reaps a non-slot VM rather than halting it.** Same as Plan E; a
persistent guest with work in flight wants the graceful path more than a chat
room does.

## Out of scope here

- The LiteLLM service, its Postgres and its master key — `~/flakes` `IDE-003`.
- The runner, its queue and its approval surface — satan `IDE-007`.
- Plan E's furniture (shared tmux, chat): an assistant has one occupant.

## Sequencing, as currently understood

```
IMP-015 ──▶ room namespace (shared with Plan E) ──▶ model door
                                                 ├─▶ per-repo tools + session
                                                 └─▶ per-repo git channel
```

The model door and the git channel are independent of each other once the
namespace exists; per-repo tools needs `IMP-015`'s consumer flake to have a
place to declare them.
