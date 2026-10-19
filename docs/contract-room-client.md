# Contract: a room's client

What a client of a room's door gets from this repo, and what it must be. A
client is anything on this host that is not one of oubliette's own doors (`ssh`,
`push`, `collect`): a human's `ssh` or `git`, or an agent's jail. Decided in
`DEC-056` (strict, read-only) and `DEC-057` (the bundle); the door itself is
`DEC-037` and the room's one trust store is `DEC-047`. Source:
[host/room-client.nix](../host/room-client.nix).

## The bundle

`packages.<system>.room-client-<r>`, one per declared room, and none when
`mkFleet`'s `rooms = {}`. The derivation is `capsule-room-client-<r>`:

| output | what it is |
| --- | --- |
| `etc/ssh_config` | the door as ssh_config lines: one `Host *` block, a socat `ProxyCommand` by store path, `StrictHostKeyChecking=yes` |
| `bin/ssh` | openssh's `ssh`, linked rather than wrapped |

It needs nothing on the client's `PATH`. Use it as
`ssh -F <bundle>/etc/ssh_config <user>@<name>`, and only so: the block is
`Host *`, so an `Include` of it from `~/.ssh/config` would send every destination
through the room's door and check every host against the room's key.

## Attributes

The bundle's `passthru`, and nothing else:

| attribute | value |
| --- | --- |
| `room` | the room's name |
| `socket` | the door, `/run/capsule-room/<r>/ssh.sock` |
| `knownHosts` | the room's trust store, `<stateDir>/room/<r>/known_hosts` |
| `hostKeyAlias` | `room-<r>` |
| `config` | the store path of the ssh_config file (also `etc/ssh_config`) |
| `binds` | the two directories a jail must mount, below |

## Precondition: the module owner

A client runs as the **module owner** (`DEC-037`). Only that uid may read the
`0700` trust store and connect to the `0600` socket, and the bundle cannot grant
either. A jail's uid must therefore be the owner's.

## Strict checking, and a client never writes

The config says `StrictHostKeyChecking=yes` over the room's one trust store, and
`GlobalKnownHostsFile none` (ssh otherwise trusts `/etc/ssh/ssh_known_hosts`; see
`mem.fact.oubliette.ssh-reads-global-known-hosts`). A client **never writes**
`known_hosts`. Learning a key is left to oubliette's own doors, which are
`accept-new` and the only writers; `forget-host-key` empties the file. So a
client refuses (ssh exit 255) a room whose key no door has learned:

- before the first `push`, `ssh` or `collect`, and
- after `forget-host-key`, until the next one.

A caller may rely on that refusal (the satan runner does, SL-006 design sec-5).

## The binds

`binds` is `[ /run/capsule-room  <stateDir>/room/<r> ]`; read-only is enough.

- **`/run/capsule-room`, the door's root and not its directory.**
  `/run/capsule-room/<r>` is the relay's `RuntimeDirectory`, which systemd
  removes on every relay stop, so a bind of it would point at a dead inode
  (`mem.fact.oubliette.runtime-directory-goes-on-every-stop`). The module makes
  the root at boot.
- **`<stateDir>/room/<r>`, the directory and not the file.** `known_hosts` does
  not exist until the first push; ssh creates it and the module makes only the
  directory.

Neither is a file or the socket itself. A bind is mounted as root and opened as
the owner, so it grants no access on its own
(`mem.fact.oubliette.a-bind-is-not-an-access`).

**The root reaches every room's door, not only `<r>`'s** (`DEC-056`): a jail
given these binds can connect to any room's socket. What it reaches past the
socket is decided by authentication, by the user key the client brings.

## What is the client's

The bundle sets no destination name, no user and no identity. `Host *` matches
whatever the client calls the room (`room-<r>`, the guest's address, the bare
name); the login and the key are the client's.

## `CAPSULE_STATE` is not honoured

The trust store is the declared `stateDir`'s (`DEC-054`). oubliette's own doors
honour `CAPSULE_STATE`; the bundle's paths are fixed at build.

## Examples

Unjailed, as the module owner:

```
ssh -F "$(nix build --print-out-paths .#room-client-<r>)/etc/ssh_config" <user>@room-<r>
```

In bwrap (a sketch; **not exercised**): bind each of `binds` read-only, the
config, and the store closure the config and `ssh` need, and run as the owner's
uid. ssh resolves its own uid to a passwd entry and exits without one, so the jail
must provide one (here, the host's, read-only):

```
b=$(nix build --print-out-paths .#room-client-<r>)
bwrap --unshare-all \
  --ro-bind /etc/passwd /etc/passwd \
  --ro-bind /run/capsule-room /run/capsule-room \
  --ro-bind <stateDir>/room/<r> <stateDir>/room/<r> \
  $(nix-store -qR "$b" | sed 's/.*/--ro-bind & &/') \
  "$b/bin/ssh" -F "$b/etc/ssh_config" <user>@room-<r>
```

## What is not proven

`roomClientCases` pins the config `ssh -G` resolves, the binds, and the refusal
and first-contact behaviour against a fixture `sshd -i`. Nothing here was run
against a live room, authentication itself is unpinned, a real jail's bind is
unpinned, and `/run/capsule-room` surviving a relay stop is `ASM-004`, the live
rung's (`STD-001`).
