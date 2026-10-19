# A room-client bundle: one export of a room's door for host clients and their jails

## Context

From `IMP-022`, raised by flakes:SL-015 inq-6 in its handback to satan:SL-027
(2026-10-20). oubliette owns the room door (`DEC-037`, `DEC-047`), but spells
it only as shell words inside its own programs. Every host client rebuilds it.

```
oubliette (owns the door)                 host clients (rebuild it)
─────────────────────────                 ─────────────────────────
rooms.nix:185  socketOf r                 ~/flakes/features/satan/runner.nix:157
  /run/capsule-room/<r>/ssh.sock            home-manager ssh_config: literal socket,
rooms.nix:187  stateDirOf state r           system socat, literal known_hosts path
  → known_hosts (room-git.nix:86)         satan:SL-027 jailed malebolge daemon
host/room-git.nix:75  door                  its own ssh_config, its closure's socat:
  -o StrictHostKeyChecking=accept-new        a jail sees only its own /nix/store
  -o HostKeyAlias=room-<r>                   closure, so the system socat is absent
  -o UserKnownHostsFile=<known_hosts>
  -o ProxyCommand=<socat> - UNIX-CONNECT:<sock>   (host/guest-ssh.nix proxyThrough)
```

Facts the design must hold (evidence, read 2026-10-20):

- The door words exist once, as shell words for an argv array
  (`host/room-git.nix` `door`), used by `capsule-room-git` and the front end's
  door (`host/cli.nix`, via `roomTrust`).
- The socket is `0600`, owned by the module owner; the room's state directory
  is `0700` (`DEC-037`, `mkfleet.nix:1211`). A client must run as the owner.
- `stateDir` is a NixOS module option (`host/services.nix:571`), not a `mkFleet`
  argument, so the known_hosts path depends on module config.
- satan's runner passes `HostKeyAlias`, `StrictHostKeyChecking` and
  `UserKnownHostsFile` on pi-env's command line and keeps only `ProxyCommand` and
  `ServerAliveCountMax` in its config (runner.nix:150-161).
- satan's `IMP-044` asks for room data (repos, user) to reach home-manager from
  one source; it is adjacent, not this slice.

## Scope & Objectives

1. **A bundle per declared room**: an ssh client, a generated client config whose
   closure carries what it names (socat), and the list of host paths a jail must
   bind (the door socket's directory, the room's known_hosts). Usable by a jail
   definition and by an unjailed unit alike.
2. **One source for the door.** The bundle's config and `door`'s shell words
   render from one description of the door; no second spelling of the socket,
   alias, trust store or ProxyCommand.
3. **Exported** where a consumer flake (e.g. `/srv/fleet`) and the home-manager
   that reads it can reach it, without an implicit default for the state root
   (`POL-003`). Settled by `DEC-054`: the state root becomes `mkFleet`'s tenth
   argument, `stateDir`. The module's `stateDir` option is removed, and the
   module, `capsule-cli` and `capsule-volume-root` read the declared value.
   This is in scope, together with the fixture and template edits, a `DEC-042`
   successor and a `POL-003` revision. The `/srv/fleet` edit stays the user's.
4. **A case suite** that reads the shipped config with `ssh -G` and pins it
   against the door the programs use, so the two cannot drift.
5. **Contract**: the bundle's fields documented as what a room client may rely on
   (`docs/`), in the same commit as the export.

## Non-Goals

- Changing any consumer: satan's runner, satan:SL-027's jailed daemon,
  `~/flakes`, `/srv/fleet`. They get a handback naming the export.
- Identity (the client's key) and the room user: the consumer's (`IMP-022`).
- Room repo data for home-manager (satan's `IMP-044`).
- Slot (capsule) doors, the tailnet ingress (Plan E), the model door (`IDE-003`).
- Changing the door itself: socket path, mode, alias, or oubliette's own
  `accept-new` doors (`DEC-056` sets strict checking for *clients* only). Two
  changes from RV-023 are in scope:
  - every door gains `GlobalKnownHostsFile none`, because `DEC-047`'s one
    store has to be the only store;
  - the module creates `/run/capsule-room` at boot.
- Moving the module's other path options (`policyDir`, `allowlistDir`,
  `profileDir`) into the fleet declaration.

## Open questions (for `/design`)

Settled in the design run: `DEC-054` (export site and state root), `DEC-055`
(one door option list), `DEC-056` (binds and client strictness), `DEC-057`
(bundle shape). The original questions follow, kept for the record.

- **Where the export lives.** A `mkFleet` output needs the state root it cannot
  see; a read-only module option sees `stateDir` but reaches home-manager only
  through `osConfig`. Or the bundle takes the state root as an argument.
- **Form of the config.** A `Host room-<r>` block (alias-addressed) or `Host *`
  (as runner.nix today), and whether the bundle's `ssh` is a wrapper passing
  `-F`, or the config alone plus `openssh` in the closure.
- **Duplicate options.** pi-env sets three of the door options itself; ssh lets
  the command line win, so carrying them in the config is harmless but is a
  second place they are stated. Decide whether the config is the whole door.
- **Read-only known_hosts.** A jail binding known_hosts read-only cannot record
  first contact under `accept-new`; first contact today is oubliette's push.
  Bind read-write, or require a prior push and say so.
- **Bind granularity.** The socket's directory versus the socket itself (a bind of
  a socket path breaks when the relay recreates it); the room state directory
  versus the one file.

## Verification intent

- A new `*Cases` suite in `just build`, red first: `ssh -G` over the bundle's
  config yields the same ProxyCommand, HostKeyAlias, UserKnownHostsFile and
  StrictHostKeyChecking as `door`; the bundle's closure holds socat; the bind list
  names exactly the socket directory and the trust store. Mutate `door` and watch
  it go red.
- `just check`, `just` green. No live room run is required; if one is taken it
  is recorded as an observation, not assumed.

## Summary

## Follow-Ups

- `satan:SL-027` and `flakes:SL-015` (handback, each in that repo's words;
  nothing is written there from here): the room's client bundle is
  `packages.<system>.room-client-<r>` (`docs/contract-room-client.md`), with its
  `binds`, strict and read-only checking, and the module owner as the only uid
  that may use it; and `/srv/fleet` must declare `stateDir`.
- The `/srv/fleet` `stateDir` edit is the user's: it already declares it
  (flake.nix:183) but needs this repo's commits pushed and its lock bumped from
  `10f05c1`.
- Pending the user's acceptance (basis: "a,b agreed"): DEC-058, the `mkFleet`
  ten-arguments successor to DEC-042, and REV-008, POL-003's host state root row.
  `IMP-022` resolves at close.
