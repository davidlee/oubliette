# RSK-011: A room named capsule-<slot> shares that slot's HostKeyAlias

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## The risk

The human's door files a guest's ssh host key under a `HostKeyAlias`, since
every guest sits at the same address. A slot's alias is `capsule-<slot>`
(`hostKeyAliasOf` in `host/cli.nix`); a room's is its bare name (`roomDoor` →
`doorVia "$2" "$1"`). `rooms.nix`'s name grammar (`[a-z0-9][a-z0-9_-]*`)
admits `capsule-one`, so a room so named shares slot `one`'s known_hosts entry:

- at best, a host-key mismatch warning whenever the human goes from one to the
  other;
- and a reprovision of slot `one` runs `ssh-keygen -R capsule-one`, dropping
  the room's key with the slot's.

`rooms.nix` does not forbid it today (SL-005 shipped without the clause).

## Candidate fixes

- refuse a `capsule-*` room name in `reasons.names`, beside the slot-name and
  reserved-name clauses; or
- give a room an alias of its own namespace, e.g. `room-<name>`, matching its
  network namespace's prefix.

Open: out of scope for SL-005 PHASE-10.
