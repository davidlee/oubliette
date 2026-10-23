<!-- doctrine:section sec-1 -->
## Shape

```
consumer flake                         oubliette
──────────────                         ─────────
rooms.assistant.extras =  ──────────►  rooms.nix        unchanged: a name is checked against
  ["search" "postgresql-18"]                            fragmentNames and carried through
                                       fragments.nix    vocabulary.<n> = { packages;
                                                                           guestModule ? ;   plain NixOS config
                                                                           persist ? [ ]; }  paths that must survive
                                                        compose  → packages (as today)
                                                        modules  → the selected guestModules
                                                        persists → [ {name; path;} ] of the selected
                                                        slotRefusal → null | why a slot may not select one
                                       vm/room.nix      imports modules; for each persist entry:
                                                          room-persist.service  mkdir /home/.fragments/<n><p>
                                                          fileSystems.<p>       bind, requires room-persist
                                       vm/capsule.nix   throws slotRefusal flavour.extras
                                       mkfleet.nix      roomChecks: three door rules + each persist bind
                                       fragments-cases.nix  fragmentsCases (new suite)

boot order in a room that selects postgresql-18
  home.mount ─► room-persist.service ─► var-lib-postgresql.mount ─► local-fs.target
                                                    └────────────► postgresql.service (RequiresMountsFor)
host client:  ssh -L 5432:/run/postgresql/.s.PGSQL.5432  over the room's door  ─► peer auth as the login
```

Four pieces, in dependency order: the capability fragment in the vocabulary
(sec-2); the room's persistence of what a fragment declares (sec-3); the
`postgresql-18` fragment itself (sec-4); the guard and the slot refusal (sec-5).
No `rooms.nix` field, no host-side unit, no new volume.
<!-- doctrine:section sec-2 -->
## The capability fragment (`DEC-059`, `DEC-060`)

`docs/contract-flavour.md` has always said a flavour is packages *and* guest
capability fragments, and `fragments.nix` kept each entry an attrset so a
`guestModule` could arrive. This builds that half, and nothing else of the
contract's unbuilt list (per-assignment extras, the image identity) moves.

An entry may carry, beside `packages`:

| key | type | meaning |
|---|---|---|
| `guestModule` | a NixOS module | plain guest config, imported unparameterised. It reads what it needs from the guest's own `config` and is never told room, slot, or where persistence lives |
| `persist` | list of absolute paths, default `[]` | what must survive the guest's lifecycle. The guest decides how (sec-3) |

`fragments.nix` gains three functions of a selection, beside `compose`, each
reading only key names until a selected entry is used, so an unselected
fragment's module is never evaluated:

- `modules extras` — the selected entries' `guestModule`s.
- `persists extras` — `[{name; path;}]`, one per selected entry's `persist` path.
- `slotRefusal extras` — `null`, or the message naming each selected entry that
  carries a `guestModule` or `persist` (sec-5).

An entry with `persist` but no `guestModule` is legal and pointless; nothing
refuses it. An unknown name stays `compose`'s refusal, and `rooms.nix` still
checks names against `fragmentNames` first.

**The vocabulary is oubliette's.** That is why this does not reopen `DEC-034`:
a consumer still supplies no module, and every `guestModule` is reviewable in
this repo. The guard in sec-5 is for the mistake a reviewer misses.
<!-- doctrine:section sec-3 -->
## A fragment's persistence is the room's (`DEC-061`, `DEC-068`)

A room's root fs is tmpfs; `/home` is its one volume that every room has. For
each entry of `fragments.persists room.extras`, `vm/room.nix` renders:

- **`room-persist.service`**, one oneshot for all entries:
  `DefaultDependencies = false`, `After`/`Requires` `home.mount`, `Before`
  `local-fs.target`; its script `install -d -m 0700` each
  `/home/.fragments/<name><path>` (parents root-owned `0700`). Absent when there
  are no entries.
- **`fileSystems.<path>`**: `device = "/home/.fragments/<name><path>"`,
  `options = ["bind" "x-systemd.requires=room-persist.service"
  "x-systemd.after=room-persist.service"]`.

So the source exists before the bind, the bind is in `local-fs.target`, and any
unit with `RequiresMountsFor = <path>` waits for it. NixOS's own state
directory handling (`StateDirectory`, its chown) then runs on the bound
directory as it would on the root fs.

**Why not a directory handed to the fragment.** The source must be made after
`/home` mounts and before the bind, which is before `room-seed` (it runs
`After = local-fs.target`). Handing a fragment a directory would make each
fragment order that itself against a room unit it should not know.

**What survives.** Stop/start, image rebuild and host switch keep `/home`, so
they keep the data. Deleting `room-home.img` loses it, with the homes.

**A dedicated volume later** (`DEC-068`, not built): the room would satisfy a
`persist` path with a `microvm.volumes` entry mounted at that path instead of a
bind. No fragment changes. `POL-003` forbids a default size, so the room
declaration would carry one per fragment (e.g. `sizes.fragments.<name>`), and
moving existing data is a one-off copy by the operator.
<!-- doctrine:section sec-4 -->
## The `postgresql-18` fragment (`DEC-062`, `DEC-063`, `DEC-065`, `DEC-067`)

```nix
postgresql-18 = {
  packages = [];
  persist = ["/var/lib/postgresql"];
  guestModule = {config, lib, pkgs, ...}: let
    logins = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  in {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_18;
      enableTCPIP = false;
      settings.listen_addresses = lib.mkForce "";
      ensureDatabases = logins;
      ensureUsers = map (name: {
        inherit name;
        ensureDBOwnership = true;
        ensureClauses.createdb = true;
      }) logins;
    };
  };
};
```

- **Roles by convention**: every normal user of the image gets a role and a
  database of its own name, with `CREATEDB`, never `SUPERUSER`. In a room those
  are its declared users; the module reads `config`, not the room record.
- **Socket only**: `listen_addresses = ''`. `enableTCPIP = false` alone still
  listens on localhost. Authentication stays NixOS's default,
  `local all all peer`, so a login is its database identity and no password
  exists.
- **The major is in the name.** NixOS's `dataDir` is
  `/var/lib/postgresql/<psqlSchema>`, under the persisted path, so selecting
  `postgresql-19` later starts an empty cluster beside the old one. Upgrade
  (`pg_upgrade`, or `pg_dump`/restore) is the operator's.
- **Readiness**: `postgresql.service` has `RequiresMountsFor` its `dataDir`
  and NixOS's own `postgresql-setup` creates roles and databases after start.
  No oubliette verb waits for it or reports it; `systemctl is-active postgresql`
  over the door is how to ask.
- **Host access**: `ssh -L 5432:/run/postgresql/.s.PGSQL.5432` (or a local socket
  path) through the room's door, with the room-client bundle or
  `capsule <room> ssh`. The door's sshd is NixOS-default, which permits
  stream-local forwarding; this adds nothing to the perimeter.
- **Reset and backup** are the operator's: `dropdb` as the owner; or, with the
  room stopped, root removes `/home/.fragments/postgresql-18`; `pg_dump` over the
  forward.
<!-- doctrine:section sec-5 -->
## The guard and the slot refusal (`DEC-060`, `DEC-066`)

**Door rules.** `mkfleet.nix`'s `roomChecks` already assert root's keys, DHCP
off with the static link, and no console autologin. They gain:

- `services.openssh.settings.PasswordAuthentication == false`;
- `services.openssh.settings.PermitRootLogin == "prohibit-password"`;
- no default route: `networking.defaultGateway == null` and the door network
  `10-capsule` has no `gateway` and no `routes`.

These hold for every room, fragment or not, so a `guestModule` that weakens
the door fails `roomImages` with the rule.

**Persistence rules**, generic over fragments: for each `persists` entry, a
`fileSystems.<path>` whose `device` is `/home/.fragments/<name><path>` with
`bind`, and `room-persist.service` present iff there are entries.

**Slots refuse.** `vm/capsule.nix` throws `fragments.slotRefusal
flavour.extras` when it is not null. A capsule's volume is its checkout and its
provision resets tracked files, so where a slot would persist is its own
design; until then a capability fragment in `flavour.extras` is a refusal, not
a silent package-only half. `NOTES item 4` (a target's tests wanting a
database) stays open, and `docs/contract-target.md` is unchanged.
<!-- doctrine:section sec-6 -->
## Verification (`DEC-064`)

Rungs per `STD-001`. Everything in the first list is in `just build`.

- **`fragmentsCases`** (new, `fragments-cases.nix`, beside its subject). Its
  subjects are the **shipped** vocabulary and the **evaluated** fixture room
  images, handed in by `mkfleet.nix`; the header says the rooms are the
  fixture's. Verdicts
  read at eval with `builtins.tryEval` over `deepSeq`, asserted in shell, each
  with its reason. Red first.
  1. `slotRefusal ["agents"]` is null; `slotRefusal ["agents" "postgresql-18"]`
     carries a message naming `postgresql-18`.
  2. A capsule image evaluated with `postgresql-18` in `flavour.extras` throws
     that message (proves the call site, not just the function).
  3. `persists ["search" "postgresql-18"]` is exactly
     `[{name = "postgresql-18"; path = "/var/lib/postgresql";}]`; `modules
     ["search"]` is `[]`.
  4. Fixture `assistant` (selects `postgresql-18`): postgresql enabled,
     package major 18, `listen_addresses == ""`, `ensureUsers` names are
     exactly its declared users, none with `superuser`, `ensureDatabases` the same.
  5. Fixture `lounge` (selects none): postgresql disabled, no
     `/var/lib/postgresql` filesystem, no `room-persist`.
  6. Mutation: drop `x-systemd.requires` or flip `listen_addresses`, watch the
     case go red; recorded in the phase notes.
- **`roomImages`**: the new door and persistence rules over both fixture
  rooms; `assistant`'s image builds with postgres in it.
- **`just check`** and lint over every touched file; wired into `just build`
  and `just cases` (check that, NOTES item 51 step 3).

**Live, by the user (VH)**, on a room selecting `postgresql-18`:

1. start the room; `systemctl is-active postgresql` and
   `findmnt /var/lib/postgresql` (source on `/home`) — confirms the ordering
   inference;
2. as a declared user: `psql -c 'create table t(x int); insert into t values (1)'`;
3. stop and start the room; `psql -c 'select * from t'` reads `1`;
4. from the host: `ssh -L` the socket over the door, `psql -h <local socket dir>`
   as that user — confirms peer auth over a forward;
5. as a second user, connecting to the first's database is refused.

Whatever is not run is reported as not exercised. No probe is added.
<!-- doctrine:section sec-7 -->
## Contracts and records

- `docs/contract-flavour.md`: capability fragments move from *unbuilt* to
  *built, for rooms*: the `guestModule`/`persist` keys, that the guest owns
  persistence, and that slots refuse one. Its `item 4` row stays a possibility.
- Room usage docs (where `extras` is documented — README and
  `templates/fleet/flake.nix`'s rooms comment): selecting `postgresql-18`, the
  forward, reset, backup and the upgrade path.
- `POL-003`'s rooms row is **not** revised: no new field. `DEC-052`'s `extras`
  now selects capabilities as well as tools, which `DEC-059` records.
- Fixture: `assistant.extras = ["search" "postgresql-18"]`.
<!-- doctrine:section sec-8 -->
## Risks and what is out of scope

- **Inferred, verified live only**: that `room-persist` runs between
  `home.mount` and the bind in a firecracker guest's early boot; that a forward
  reaches peer auth as the login. A build proves neither.
- **Recursion**: the module reads `config.users.users` while NixOS's postgres
  module defines a user in it; case 4 is what shows it evaluates.
- **Space**: the database shares `/home`'s size. A full `/home` stops both
  logins' writes and postgres. Accepted for now (`DEC-061`).
- **Image size**: `assistant` and any consumer room selecting it grows by
  postgres' closure.
- **`/home/.fragments` is root's**: `0700`, outside every home; a user cannot
  reach the cluster files, only the socket.
- Out of scope: slots selecting capability fragments; a dedicated volume;
  backup or reset verbs; TCP or any host network path; parameterised fragments;
  extensions; schemas.
<!-- doctrine:section sec-9 -->
## Code impact

| path | change |
|---|---|
| `fragments.nix` | `guestModule`/`persist` keys; `modules`, `persists`, `slotRefusal`; the `postgresql-18` entry; header's "two things absent" revised |
| `vm/room.nix` | imports `fragments.modules room.extras`; `room-persist.service` and the bind `fileSystems` from `fragments.persists room.extras`; header |
| `vm/capsule.nix` | throws `fragments.slotRefusal flavour.extras` |
| `mkfleet.nix` | `roomChecks` door and persistence rules; `fragmentsCases` wiring |
| `fragments-cases.nix` (new) | `fragmentsCases` |
| `just/fleet.just` | `fragmentsCases` in `build` and `cases` |
| `justfile` | the new file in `nix_paths` if it lists files |
| `fixture/default.nix` | `assistant` selects `postgresql-18` |
| `templates/fleet/flake.nix`, `README.md` | the commented room example and usage |
| `docs/contract-flavour.md` | capability fragments built, for rooms |
| `CLAUDE.md` | `fragmentsCases` in the suite list |
