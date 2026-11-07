# IMP-029: A slot's proxy and uplink are optional, for a slot that reaches models through a door and fetches nothing else

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

The user's direction (2026-11-08), split out of SL-010 so the door stays small.

A slot's proxy carries two kinds of traffic: model API calls and the target's
own fetches, per its policy's allowlist. SL-010's door takes the first. A slot
whose policy fetches nothing else needs no proxy, and possibly no uplink: its
namespace would be shaped like a room's.

Evidence it is cheap: the unit graph already runs guests with `uplink = null`.
Rooms do (no proxy, no aggregator; `host/services.nix`, `rooms.nix:217`).
`capsules.nix:141` always gives a slot an uplink, so the change is mostly in the
declaration.

Open:
- Does an uplink-less slot keep its declared index? Its /30 is carved from it.
- What do the `policy` verb and status do for a slot with no proxy to re-point?
- Is "no uplink" a slot field or a policy value? POL-003 allows one home only.
