In a room selecting `postgresql-18` (SL-009, `fragments.nix`, `vm/room.nix`):

**Superuser path.** Only guest root is the superuser, by peer auth through the
`postgres` system user. Root is reached by the host's admin keys
(`access.adminKeys`) and by the host's stop key (the `microvm@` units' reboot
credential, `vm/door.nix`; no `command=` restriction, so a full root login):

    capsule <room> ssh root        # a host admin key or the stop key
    runuser -u postgres -- psql

pg_hba is exactly `local all postgres peer map=postgres` then
`local samerole all peer` (mkForce'd, replacing NixOS's default fallback).

**No room user can be superuser.** A room has no sudo (`security.sudo` off,
DEC-060); roomChecks' elevation rule refuses sudo-rs/doas; `postgres` has no
keys. A room with `adminKeys = []` still has the stop key as its only root credential. Do not "fix"
a missing superuser by granting a login sudo: that breaks the door rule.

**`shared_` rule.** A shared database is the operator's act: `CREATE ROLE
shared_<x> NOLOGIN; CREATE DATABASE shared_<x> OWNER shared_<x>; GRANT
shared_<x> TO <logins>`. `samerole` admits members. No login may be named
`pg_*`, `shared_*`, `postgres`, `template0/1`, etc. (fragments.nix assertion),
so a later-declared user never meets an existing NOLOGIN role of its own name
(which NixOS ensureUsers would skip, leaving it unable to log in).

**Forward.** `capsule <room> ssh` takes no ssh options (args after the user are
the remote command); forward the socket with the room-client bundle:
`"$b/bin/ssh" -F "$b/etc/ssh_config" -L 5432:/run/postgresql/.s.PGSQL.5432 <user>@room-<room>`.

Readiness is `postgresql.target`, not `postgresql.service`. User-facing
detail: README.md "PostgreSQL in a room". Not live-verified until SL-009
PHASE-05 (ASM-005/006).

