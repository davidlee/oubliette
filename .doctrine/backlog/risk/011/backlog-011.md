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

**Fixed (2026-10-19, SL-006 PHASE-07), by `DEC-047`.** A room's doors file its
key under `HostKeyAlias room-<room>`, in the room's own
`$stateDir/room/<room>/known_hosts`. Nothing about a slot uses either that
alias or that file. Resolution `fixed` rather than `mitigated`: the collision
the risk names cannot happen at all, because `room-<n>` cannot equal
`capsule-<n>` and the stores are separate files. Nothing residual is left to
make it less likely.

Live, A11 (runsheet bundle `~/sl006-live/bundle.txt`):

- The stored key was swapped host-side for a throwaway. `capsule assistant ssh`
  then failed with 255 (`REMOTE HOST IDENTIFICATION HAS CHANGED`), and `push`
  and `collect` each failed with 1, stdout empty.
- `forget-host-key` (0) emptied that file and no other. The next `ssh` (0)
  re-learned `room-assistant` with the identical fingerprint, and a re-push (0)
  printed the same oid.
- The file was then byte-identical to the original.

Not exercised: a room actually named `capsule-<slot>`, and a slot reprovision's
`ssh-keygen -R` running alongside a room. Both are covered by construction,
not by a run.
