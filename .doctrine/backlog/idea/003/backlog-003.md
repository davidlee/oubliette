# IDE-003: A model door for a room: socat in the room namespace to the host LLM gateway socket (Plan F section 2)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Plan F §2: a unit with `NetworkNamespacePath=` the room's runs
`socat TCP-LISTEN:<net.host>:<port>,fork UNIX-CONNECT:/run/llm-gateway/api.sock`,
`DynamicUser`, `SupplementaryGroups=llm-gateway`; the guest holds a gateway key
issued by `llm-gateway issue`, delivered by the inject path.

Split out of SL-006 (2026-10-18, user's call): satan SL-023's runner calls the
gateway from the host, so no current consumer needs a model path inside the
room. Becomes live when an in-room harness does. Ownership of the gateway
module is still `flakes:IDE-008`'s question.

## First consumer: pi in a capsule (2026-11-08, user's call)

The first use case is a **slot**, not a room: quotient's pi agent running
inside a capsule, so its model calls go through the gateway rather than
through the egress proxy to a provider with a real key. That widens this
item from "a room" to "a namespace", which costs nothing structurally: one
`capsule-netns` serves slots and rooms (SL-005), so the forwarder unit is the
same with the slot's namespace in `NetworkNamespacePath=`.

What differs for a slot, to settle at design:
- **Policy.** A slot has an uplink and a proxy; the door is a second way out
  beside it. POL-001 still holds (a socket, never a route), but the door
  should be declared per slot or per policy (POL-003), not implied by the
  fleet. For a room, POL-005 ("a room never fetches") needs a reading that a
  host socket is not a fetch.
- **Key delivery.** The slot's inject path already exists; the gateway key
  (`llm-gateway issue`) rides it. CON-004 and QUE-003 still apply.
- **pi itself.** pi is an operator convenience, so it is a `fragments.nix`
  extra, not a target's floor (NOTES item 31). Its provider config needs the
  door's `<net.host>:<port>` as base URL, declared, never scraped from `$HOME`.
- **Ownership** of the gateway module is still `flakes:IDE-008`'s question.
