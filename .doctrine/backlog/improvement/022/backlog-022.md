# IMP-022: Export a room-client bundle: ssh client, door config and jail binds for host clients of a room

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

oubliette owns the door (`host/guest-ssh.nix:184`: `ProxyCommand=<socat store
path> - UNIX-CONNECT:<door socket>`), but each host client rebuilds the
knowledge to reach it. satan's patch runner has a home-manager-rendered
`ssh_config` (`~/flakes/features/satan/runner.nix`), and satan:SL-027's jailed
malebolge daemon renders its own inside its jail definition, because a jail sees
only its own `/nix/store` closure and the system's socat store path is not in it.

Raised by flakes:SL-015 inq-6 (handback to satan:SL-027, 2026-10-20). Interim
in satan:SL-027: the jail renders its own `ssh_config` with its closure's socat
and the per-room socket path `/run/capsule-room/<room>/ssh.sock`.

## Shape

Per room: an ssh client, a generated client config with its closure, and the
list of host paths a jail must bind (door socket directory, known_hosts),
consumable by a jail definition and by an unjailed unit alike. Identity and
room user remain the consumer's.

## Then

satan's runner and jailed daemon consume it; their hand-rendered configs go.
