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
                                       vm/capsule.nix   assertion from slotRefusal flavour.extras
                                       mkfleet.nix      roomChecks: door rules (ssh, routing, sudo/doas) + persist edges
                                       fragments-cases.nix  fragmentsCases (new suite)

boot order in a room that selects postgresql-18
  home.mount ─► room-persist.service ─► var-lib-postgresql.mount ─► local-fs.target
                                                    └────────────► postgresql.service ─► postgresql-setup ─► postgresql.target
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
  carries a `guestModule` or `persist`; `vm/capsule.nix` makes it an
  `assertions` entry (sec-5), so its message is readable at eval.

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
  `unitConfig.DefaultDependencies = false`; `after` and `requires`
  `home.mount`; `before` `local-fs.target` and each bind's mount unit. Its
  script: `umask 077`, `mkdir -p /home/.fragments` and, **only when missing**,
  `mkdir -p /home/.fragments/<name><path>`. Under that umask every parent
  `mkdir -p` makes is `0700`, root's; an existing directory is never touched,
  so a service-owned tree is not reset each boot (RV-025 F-7). Absent when there
  are no entries.
- **`fileSystems.<path>`**: `device = "/home/.fragments/<name><path>"`,
  `fsType = "none"` (required, no default: RV-025 F-2),
  `options = ["bind" "x-systemd.requires=room-persist.service"
  "x-systemd.after=room-persist.service"]`. `requires` is what pulls the
  oneshot into the boot transaction; `after` alone only orders it.

So the source exists before the bind, the bind is in `local-fs.target`, and any
unit with `RequiresMountsFor = <path>` waits for it. NixOS's own state directory
handling (`StateDirectory`, its chown) then runs on the bound directory as it
would on the root fs. In the pinned microvm.nix `/home` is not `neededForBoot`,
so this is all stage 2 (RV-025 F-2, evidence: a read-only eval).

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
    # Names PostgreSQL refuses as roles, its superuser, and the databases a
    # fresh cluster already has, which ensureDBOwnership would hand over.
    reserved = n: lib.hasPrefix "pg_" n
      || builtins.elem n ["postgres" "public" "none" "current_user" "current_role" "session_user" "template0" "template1"];
  in {
    assertions = [{
      assertion = !(lib.any reserved logins);
      message = "fragments.nix postgresql-18: a login is a reserved role name: ${toString (lib.filter reserved logins)}";
    }];
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_18;
      enableTCPIP = false;
      settings.listen_addresses = lib.mkForce "";
      # Replaces NixOS's default rules, whose `local all all peer` would admit
      # any login to any database. NixOS adds those with mkAfter, so a
      # prepended rule would leave them as the fallback.
      authentication = lib.mkForce ''
        local all      postgres peer map=postgres
        local samerole all      peer
      '';
      ensureDatabases = logins;
      ensureUsers = map (name: {
        inherit name;
        ensureDBOwnership = true;
      }) logins;
    };
  };
};
```

- **A login reaches only databases named for a role it holds** (RV-025 F-1).
  Every normal user of the image gets a role and a database of its own name, no
  `CREATEDB`, no `SUPERUSER`. The access rules (`pg_hba`, first match wins)
  admit the `postgres` maintenance role to every database and any other login
  only to a database whose name is a role it is a member of (`samerole`; a role
  is a member of itself, and a superuser is not counted unless granted). So
  `eve -d agent` matches no rule and is refused. In a room the logins are its
  declared users; the module reads `config`, not the room record.
- **A shared database is the operator's act, by convention** (user, 2026-10-24).
  Root in the guest is reached only by the host's admin keys; it becomes the
  superuser by peer through the `postgres` system user:

  ```
  capsule <room> ssh            # as root, with an admin key
  runuser -u postgres -- psql
    CREATE ROLE proj NOLOGIN;
    CREATE DATABASE proj OWNER proj;
    GRANT proj TO agent, eve;   -- members may now open db proj; others may not
  ```

  No room user can become `postgres` (no sudo, no keys on it). The shared role
  and database live in the cluster on `/home`, survive like any data, and are
  not declared anywhere; a declared shared database would be a parameterised
  fragment, which `DEC-059` leaves for later.
- **Reserved names refuse at eval** (RV-025 F-6, F-9). `rooms.nix` admits
  `pg_demo` and `template1`; PostgreSQL refuses `CREATE USER pg_demo`, and
  `ensureDBOwnership` would give `template1`'s login the template every later
  database is copied from. The fragment's own assertion fails the image with
  the names, and only for a room that selects it.
- **Socket only**: `listen_addresses = ''`. `enableTCPIP = false` alone still
  listens on localhost. Peer auth: a login is its database identity and no
  password exists.
- **The major is in the name.** NixOS's `dataDir` is
  `/var/lib/postgresql/<psqlSchema>`, under the persisted path, so selecting
  `postgresql-19` later starts an empty cluster beside the old one. Upgrade
  (`pg_upgrade`, or `pg_dump`/restore) is the operator's.
- **Readiness is `postgresql.target`** (RV-025 F-5). `postgresql.service` is
  only the server; roles and databases are made by `postgresql-setup`, after
  it, and `postgresql.target` requires both. No oubliette verb waits or
  reports; `systemctl is-active postgresql.target` over the door is how to ask.
- **Host access**: `ssh -L 5432:/run/postgresql/.s.PGSQL.5432` (or a local socket
  path) through the room's door, with the room-client bundle or
  `capsule <room> ssh`. The door's sshd is NixOS-default, which permits
  stream-local forwarding; this adds nothing to the perimeter.
- **Reset and backup** are the operator's: `dropdb` and re-create as `postgres`
  (root runs `runuser -u postgres`), or, with the room stopped, root removes
  `/home/.fragments/postgresql-18`; `pg_dump` over the forward.
<!-- doctrine:section sec-5 -->
## The guard and the slot refusal (`DEC-060`, `DEC-066`)

**Door rules.** `mkfleet.nix`'s `roomChecks` already assert root's keys, DHCP
off with the static link, no console autologin, and each user's exact groups.
They gain:

- `services.openssh.settings.PasswordAuthentication == false`;
- `services.openssh.settings.PermitRootLogin == "prohibit-password"`;
- no default route: `networking.defaultGateway == null` and the door network
  `10-capsule` has no `gateway` and no `routes`;
- no elevation (RV-025 F-3): `security.sudo.enable`, `security.sudo-rs.enable`
  and `security.doas.enable` all false. `vm/room.nix` sets
  `security.sudo.enable = false`; a room never had a sudoer, and NixOS's
  enabled sudo always carries default root and wheel rules, so emptiness of
  its rule list is not a usable check. A module granting elevation must
  re-enable one of the three, which is what fails.

These hold for every room, fragment or not. **They are a regression guard over
the settings they name, not a proof over every effect a module can have**: a
root `AuthorizedKeysCommand`, an sshd `Match` block or a second network
declaration is not among them. The boundary that makes that acceptable is that
every `guestModule` is oubliette's, reviewed here (`DEC-034`); the guard
catches the likely mistakes.

**Persistence rules**, generic over fragments, for each `persists` entry:
`fileSystems.<path>` has `device` `/home/.fragments/<name><path>`, `fsType`
`none`, and options containing `bind` and
`x-systemd.requires=room-persist.service`; `room-persist` has
`DefaultDependencies = false`, `home.mount` in both `after` and `requires`, and
`local-fs.target` in `before`. `room-persist` exists iff there are entries.

**Slots refuse.** `vm/capsule.nix` adds
`{assertion = slotRefusal flavour.extras == null; message = …;}` to
`assertions`, so a capsule image naming a capability fragment fails to build
with that message, and a suite reads the failing message from
`config.assertions` rather than through `tryEval` (RV-025 F-8). A capsule's
volume is its checkout and its provision resets tracked files, so where a slot
would persist is its own design; until then a capability fragment in
`flavour.extras` is a refusal, not a silent package-only half. `NOTES item 4`
stays open, and `docs/contract-target.md` is unchanged.
<!-- doctrine:section sec-6 -->
## Verification (`DEC-064`)

Rungs per `STD-001`. Everything in the first list is in `just build`.

- **`fragmentsCases`** (new, `fragments-cases.nix`, beside its subject). Its
  subjects are the **shipped** vocabulary and **evaluated** images handed in by
  `mkfleet.nix`: the fixture rooms, and the same images extended with one
  module each (`extendModules`) for the negative cases; the header says so.
  A refusal is read as the **message of a failing entry in
  `config.assertions`** (or a `roomChecks` reason), never a bare `tryEval`
  verdict. Red first.
  1. `slotRefusal ["agents"]` is null; with `postgresql-18` it names it.
  2. A capsule image with `postgresql-18` in `flavour.extras` has a failing
     assertion carrying that message.
  3. `persists ["search" "postgresql-18"]` is exactly
     `[{name = "postgresql-18"; path = "/var/lib/postgresql";}]`; `modules
     ["search"]` is `[]`.
  4. `assistant` (selects it): postgresql enabled, major 18,
     `listen_addresses == ""`, `authentication` exactly the two rules (`samerole`),
     `ensureUsers` names exactly its declared users with no clauses,
     `ensureDatabases` the same, and no failing assertion.
  5. `assistant` extended with a user `pg_demo`, then with `template1`: each a
     failing assertion naming it.
  6. `lounge` (selects none): postgresql disabled, no `/var/lib/postgresql`
     filesystem, no `room-persist`.
  7. Positive control first: both clean fixture rooms pass every `roomChecks`
     rule. Then `assistant` extended with `security.sudo.enable = true` and a
     NOPASSWD grant: `roomChecks` fails with the elevation rule, and only it.
  8. Mutations, each required to turn a named case red, recorded in the phase
     notes: drop `x-systemd.requires` (persistence rules); flip
     `listen_addresses`; restore `local all all peer`; drop `template1` from the reserved list; replace the capsule
     assertion with an unrelated throw (case 2).
- **`roomImages`**: the door and persistence rules over both fixture rooms;
  `assistant`'s image builds with postgres in it.
- **`just check`** and lint over every touched file; wired into `just build`
  and `just cases` (check that, NOTES item 51 step 3).

**Live, by the user (VH)**, on a room selecting `postgresql-18`:

1. start the room; `systemctl is-active postgresql.target`,
   `findmnt /var/lib/postgresql` (source on `/home`), and
   `stat -c %a /home/.fragments` is `700` — confirms the ordering inference;
2. as `agent`: `psql -c 'create table t(x int); insert into t values (1)'`;
3. stop and start the room; `psql -c 'select * from t'` reads `1`, and
   `/home/.fragments/postgresql-18/var/lib/postgresql` is still postgres-owned;
4. from the host: `ssh -L` the socket over the door, `psql` through it as
   `agent` — confirms peer auth over a forward;
5. as `eve`, with her own role: `psql -U eve -d agent` is refused, and
   `psql -d eve` succeeds;
6. as root, the sec-4 shared-database recipe for `proj` granted to `agent`
   only: `agent -d proj` succeeds, `eve -d proj` is refused.

Whatever is not run is reported as not exercised. No probe is added.
<!-- doctrine:section sec-7 -->
## Contracts and records

- `docs/contract-flavour.md`: capability fragments move from *unbuilt* to
  *built, for rooms*: the `guestModule`/`persist` keys, that the guest owns
  persistence, and that slots refuse one. Its `item 4` row stays a possibility.
- **README, a "PostgreSQL in a room" section** (user, 2026-10-24: so it is not
  rediscovered): selecting `postgresql-18`; who can be the superuser (guest
  root by admin key, then `runuser -u postgres -- psql`; no room user); the
  shared-database recipe; the forward; readiness (`postgresql.target`); reset,
  backup and the major-version bump. `templates/fleet/flake.nix`'s rooms
  comment points at it.
- A doctrine memory scoped to `fragments.nix` and `vm/room.nix` with the
  superuser path, recorded when the fragment ships, not before.
- `POL-003`'s rooms row is **not** revised: no new field. `DEC-052`'s `extras`
  now selects capabilities as well as tools, which `DEC-059` records.
- Fixture: `assistant.extras = ["search" "postgresql-18"]`.
<!-- doctrine:section sec-8 -->
## Risks and what is out of scope

- **Inferred, verified live only**: that `room-persist` runs between
  `home.mount` and the bind in a firecracker guest's boot; that a forward
  reaches peer auth as the login. A build proves neither. Read-only evals in
  RV-025 show the pieces evaluate and `/home` is a stage-2 mount.
- **The guard is finite** (sec-5): it names settings, and a reviewed
  vocabulary is what bounds the rest.
- **Space**: the database shares `/home`'s size. A full `/home` stops both
  logins' writes and postgres. Accepted for now (`DEC-061`).
- **Image size**: `assistant` and any consumer room selecting it grows by
  postgres' closure.
- **`/home/.fragments` is root's**: `0700`, outside every home; a user reaches
  the cluster only through the socket, and only their own database.
- Out of scope: slots selecting capability fragments; a dedicated volume;
  backup or reset verbs; TCP or any host network path; parameterised fragments;
  extensions; schemas; shared databases declared rather than made by the operator.
<!-- doctrine:section sec-9 -->
## Code impact

| path | change |
|---|---|
| `fragments.nix` | `guestModule`/`persist` keys; `modules`, `persists`, `slotRefusal`; the `postgresql-18` entry; header's "two things absent" revised |
| `vm/room.nix` | imports `fragments.modules room.extras`; `room-persist.service` and the bind `fileSystems` from `fragments.persists room.extras`; `security.sudo.enable = false`; header |
| `vm/capsule.nix` | throws `fragments.slotRefusal flavour.extras` |
| `mkfleet.nix` | `roomChecks` door and persistence rules; `fragmentsCases` wiring |
| `fragments-cases.nix` (new) | `fragmentsCases` |
| `just/fleet.just` | `fragmentsCases` in `build` and `cases` |
| `justfile` | the new file in `nix_paths` if it lists files |
| `fixture/default.nix` | `assistant` selects `postgresql-18` |
| `templates/fleet/flake.nix`, `README.md` | the commented room example; README's "PostgreSQL in a room" section (sec-7) |
| `docs/contract-flavour.md` | capability fragments built, for rooms |
| `CLAUDE.md` | `fragmentsCases` in the suite list |
