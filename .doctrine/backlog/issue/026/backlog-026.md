# ISS-026: just refresh-build and just up assume a slot: on a room, up's 'created' exits 2 after the update

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Seen 2026-10-19 at SL-007 PHASE-05. `just refresh-build assistant` (just/fleet.just)
ran `sudo microvm -u assistant` correctly, then `just up assistant`, whose
`capsule <name> created` is a slot verb: on a room the front end exits 2 and
`up` passes that through ("up failed with exit code 2"). The room was left
updated and stopped; `capsule assistant start` finished it by hand.

Also not obvious: a host switch does not move a room's (or slot's) runner —
`/var/lib/microvms/<n>/current` changes only through `microvm -u`, so a
restart after a switch alone boots the old image.

Fix shape: `up`/`refresh-build` dispatch on room vs slot (a room is always
created by the module? check), or a room-aware `created`.
