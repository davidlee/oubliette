<!-- doctrine:section sec-1 -->
## Shape

```
consumer flake (/srv/fleet)                oubliette
───────────────────────────                ─────────
mkFleet { …; rooms; stateDir; }  ───────►  rooms.nix        socketOf, stateDirOf
                                           host/room-door.nix   optionsOf {checking room socket knownHosts}
                                             ├─ words  → capsule-room-git, front end   (checking = accept-new)
                                             └─ config → room-client-<r>               (checking = yes)
                                           host/room-client.nix  per room → packages.room-client-<r>
                                             etc/ssh_config   Host * + the door, socat by store path
                                             bin/ssh          openssh's ssh
                                             passthru         room socket knownHosts hostKeyAlias config binds
                                           host/services.nix   module reads declared stateDir (option removed)

host clients (out of scope here)           read packages.<sys>.room-client-<r>
  satan runner (home-manager, standalone)    ssh -F ${b.config} …; door file takes b.knownHosts, b.hostKeyAlias
  jailed daemon (bwrap)                      packages += b; --ro-bind each of b.binds
```

Three changes, in dependency order: the state root becomes a declaration
(`DEC-054`, sec-2); the door becomes one option list with two renders
(`DEC-055`, sec-3); the bundle is built from both (`DEC-056`, `DEC-057`, sec-4).

<!-- doctrine:section sec-2 -->
## The state root is a declaration (`DEC-054`)

`mkFleet` takes a tenth argument, `stateDir`: a string, required, with no
default (`POL-003`). It is refused at eval unless it is an absolute path over
`[A-Za-z0-9._+/-]` with no `..` component (RV-023 F-4). That one check covers
two hazards:
- ssh reads `UserKnownHostsFile` as a list and expands `%` tokens, which is
  `refuseOddState`'s reason (host/room-git.nix:89-100);
- the value is spliced unquoted into generated shell (host/cli.nix:937,
  host/volume-root.nix:76) and into whatever reads it later.

A narrow character set beats escaping at each insertion: one check, and no
insertion added later can miss it. It runs in `mkFleet` and is exposed for
`fleetCases` to pin, following the `reasons` pattern in `fleet.nix`.

Readers, all from the one argument:

| reader | today | after |
|---|---|---|
| the module (tmpfiles, slot root, wrapper `CAPSULE_STATE` default, perimeter checks) | `cfg.stateDir`, option default `/var/lib/capsule` (host/services.nix:571-578) | `stateDir`, closed over by the module `mkFleet` builds |
| `capsule-cli` `moduleState` | default `/var/lib/capsule` (host/cli.nix:94), never passed | passed the declared value at both call sites (mkfleet.nix:624, host/services.nix:160); both copies stay one store path (RSK-004) |
| `capsule-volume-root` `moduleState` | default `/var/lib/capsule` (host/volume-root.nix:46), never passed, so a module override already disagreed with it | passed the declared value (host/programs.nix:264) |
| room-client bundles | — | `rooms.stateDirOf stateDir r` |

The argument defaults stay in `cli.nix` and `volume-root.nix` as POL-004 seams
(suites pass a sandbox path). They are no longer reached by any shipped caller.

The module option is removed with
`lib.mkRemovedOptionModule ["services" "capsule-perimeter" "stateDir"] "<message naming mkFleet's stateDir>"`,
so a host config that still sets it fails at eval and says where the value moved.
The perimeter check keeps its own spelling of `"${stateDir}/room/${n}"`
(mkfleet.nix:1156-1167), now over the declared value, so it still cannot agree
with itself.

The fixture (`fixture/default.nix`) and the template (`templates/fleet/flake.nix`)
declare `stateDir = "/var/lib/capsule"`. `/srv/fleet` must add the same at its
next input bump; that edit is the user's, as `rooms` was (`DEC-042`).
`CAPSULE_STATE` keeps working as a per-invocation override for the programs
that honour it. The bundle does not honour it: a bundle is a build product,
and the declaration is its only source.

<!-- doctrine:section sec-3 -->
## One door, two renders (`DEC-055`)

New `host/room-door.nix`, a function of `{lib, guestSsh, socat, stateDirOf}` (`stateDirOf` is `rooms.stateDirOf`, passed as room-git.nix takes it today, host/programs.nix:223):

```nix
aliasOf = room: "room-${room}";
optionsOf = {checking, room, socket, knownHosts}: [
  {name = "StrictHostKeyChecking"; value = checking;}
  {name = "HostKeyAlias";          value = aliasOf room;}
  {name = "UserKnownHostsFile";    value = knownHosts;}
  {name = "GlobalKnownHostsFile";  value = "none";}
  {name = "ProxyCommand";          value = guestSsh.proxyCommand {inherit socat socket;};}
];
words  = args: concatMapStringsSep " " (o: ''-o "${o.name}=${o.value}"'') (optionsOf args);
config = args: "Host *\n" + concatMapStrings (o: "  ${o.name} ${o.value}\n") (optionsOf args);
knownHostsIn = roomDir: "${roomDir}/known_hosts";
knownHostsOf = state: room: knownHostsIn (stateDirOf state room);
```

- `words` takes shell expressions (`$room`, `$sock`), as `door` does now. Every
  value is double-quoted; today `StrictHostKeyChecking=accept-new` is the one
  unquoted value, and quoting it changes no argv.
- `config` takes nix strings. ssh_config's `ProxyCommand` takes the rest of the
  line; `UserKnownHostsFile` is safe because of sec-2's eval refusal.
- `host/guest-ssh.nix` gains `proxyCommand {socat, socket}` =
  `"${socat} - UNIX-CONNECT:${socket}"`, and `proxyThrough` becomes
  `-o "ProxyCommand=${proxyCommand …}"`. That is the same text, so slot callers
  (`viaSocket`, `doorVia`, services.nix:142-147, mkfleet.nix:550-553,
  1549-1558) are unchanged.
- `host/room-git.nix` takes `roomDoor` instead of defining `door` and
  `knownHosts*`. It calls `roomDoor.words {checking = "accept-new"; …}`. It
  re-exports nothing it no longer owns: `roomTrust` (host/programs.nix:289)
  becomes `{door = roomDoor.words; inherit (roomDoor) knownHostsOf; inherit
  (roomGitShipped) refuseOddState;}`, and the front end (host/cli.nix:856-868,
  1988-1998) supplies `checking = "accept-new"` in the human door.
- `socat` is `lib.getExe pkgs.socat`, built once in `room-door.nix`
  (`DEC-053`'s precedent, moved from room-git.nix:72).

- `GlobalKnownHostsFile none` is new for **every** door, oubliette's included
  (RV-023 F-2). ssh consults `/etc/ssh/ssh_known_hosts*` by default
  (`ssh -G -F /dev/null` here), so today's door words check a second store
  beside the room's. That contradicts `DEC-047`'s one store, and a client
  promised refusal before first contact would not refuse a key the host's
  global file holds.

Neither render is a spelling of the other. The alias, the trust store and the
ProxyCommand each have one home.

<!-- doctrine:section sec-4 -->
## The bundle (`DEC-056`, `DEC-057`)

New `host/room-client.nix`, `{pkgs, lib, roomDoor, rooms, stateDir}: record ->
derivation`. For each room record `r`:

```nix
let
  knownHosts = roomDoor.knownHostsOf stateDir r.name;
  config = pkgs.writeText "capsule-room-client-${r.name}-ssh_config"
    (roomDoor.config {checking = "yes"; room = r.name; socket = r.socket; inherit knownHosts;});
in pkgs.runCommand "capsule-room-client-${r.name}" {
  passthru = {
    room = r.name; socket = r.socket; inherit knownHosts;
    hostKeyAlias = roomDoor.aliasOf r.name;
    inherit config;                          # the store path of the file
    binds = [(dirOf (dirOf r.socket)) (rooms.stateDirOf stateDir r.name)];
  };
} ''
  mkdir -p $out/etc $out/bin
  ln -s ${config} $out/etc/ssh_config
  ln -s ${pkgs.openssh}/bin/ssh $out/bin/ssh
''
```

(Sketch, not final text.)

- **Binds** (`DEC-056`): `/run/capsule-room`, the parent of every room's
  RuntimeDirectory, which systemd removes on each relay stop
  (host/services.nix:348); and `$stateDir/room/<r>`, which exists from boot
  (tmpfiles, host/services.nix:797) while `known_hosts` exists only after the
  first push. Both are derived from the record and the declaration; neither is
  respelled. Read-only binds are enough: `connect()` needs no write, and a client
  never writes `known_hosts`.
- **The parent exists from boot** (RV-023 F-3). Only a relay's start creates
  `/run/capsule-room`, as the parent of its RuntimeDirectory
  (host/services.nix:348). The module therefore adds one tmpfiles rule when
  rooms exist: `d <dirOf (dirOf (socketOf <any room>))> 0755 root root -`. It
  is derived from `socketOf`, so the path is not spelled out again. A jail
  started before any relay binds an empty directory, and each room's door
  appears under it when that room starts.
- **Strictness**: `checking = "yes"`. A client refuses before the first push
  and after `forget-host-key` until the next push. That is ssh exit 255, the
  behaviour satan's runner already relies on (SL-006 design sec-5).
- **Precondition**: the client runs as the module owner (`DEC-037`). The bundle
  cannot grant that, and its contract says so.
- **Export**: `mkFleet` adds `packages.${system}."room-client-${r}"` for each
  room in `roomRecords`, beside `roomImages`. With `rooms = {}` there are none.
- No user and no identity, so the destination name is the caller's. `Host *`
  matches `room-<r>`, `net.guest` and the bare name alike.

<!-- doctrine:section sec-5 -->
## Verification

The suites below are at the build and run rungs (`STD-001`). Nothing here
reaches a live room; that is the consumer's reach rung.

- **`roomClientCases`**, in `host/room-client-cases.nix`. It is a function of
  `pkgs`, `lib`, the **shipped** bundle for the fixture's room, and the
  **shipped** `roomDoor` (the `words` render). Red first. It is wired into
  `packages` and `just build` (just/fleet.just:77-80); check this explicitly
  (NOTES item 51 step 3).
  1. `ssh -G -F ${bundle}/etc/ssh_config anyhost` yields
     `stricthostkeychecking true`, `hostkeyalias room-<r>`,
     `userknownhostsfile <declared>/room/<r>/known_hosts`,
     `globalknownhostsfile none`, and a `proxycommand`
     whose first word is an executable socat store path and whose socket is the
     record's.
  2. The same `ssh -G` with `-l x` and the destinations `room-<r>`, `10.99.0.2`
     and `<r>`: each yields the same proxycommand. This pins `Host *` against
     the three names clients use.
  3. `ssh -G $(words {checking = "accept-new"; …}) anyhost` with no `-F`
     (`-F /dev/null`) yields the same alias, trust store and proxycommand as
     (1), and `stricthostkeychecking accept-new`. This proves the renders agree
     and differ only by `checking`.
  4. `binds` is exactly the socket's grandparent and the room state directory;
     the known_hosts path lies under the second; the socket lies under the first.
  5. `bin/ssh` resolves to an executable openssh `ssh`.
  6. **Both doors against a fixture sshd** (RV-023 F-5). An unprivileged
     `sshd -i` behind `socat UNIX-LISTEN:<fixture socket>` serves as the room.
     The 2026-10-20 spike showed `accept-new` writes the key and auth then fails
     with `Permission denied`. The fixture builds the bundle and the channel
     over the fixture socket through the same seam `roomGitCases` uses
     (`roomGitOf`, mkfleet.nix:715-722), with the state root from the fixture's
     declaration. Three steps:
     - (a) The bundle's `ssh` before any push: `Host key verification failed`,
       and `known_hosts` absent or empty.
     - (b) The **shipped** `capsule-room-git push` (or the fixture-socket
       build of it): an entry `room-<r> ssh-ed25519 …` lands in
       `$state/room/<r>/known_hosts`, and nothing lands elsewhere.
     - (c) The bundle's `ssh` again: `Permission denied`. The key was accepted
       and auth was refused, which is as far as a client with no identity gets.

     This pins the channel's call site, not just the render. If an unprivileged
     sshd cannot run inside the nix build sandbox, case 6 drops to a stated
     residual (the live rung), and the user is told before the plan is
     approved.

  Each case asserts its reason, not only its exit status. **Mutations** (each
  must go red, and for the right reason, never at shellcheck): set the bundle's
  `checking` to `accept-new` (fails 1); drop `Host *` for `Host room-<r>` (fails
  2); bind `dirOf r.socket` instead of its parent (fails 4); drop
  `GlobalKnownHostsFile` from `optionsOf` (fails 1 and 3); pass the channel a
  wrong `knownHosts` at its call site (fails 6b).
- **`fleetCases`**: a `stateDir` that is relative, contains a `..` component,
  or contains a space, `%` or `$(…)` is refused with its reason. An absent
  `stateDir` fails eval naming the argument.
- **`roomVerbsCases`** and **`roomGitCases`** stay green unchanged. They already
  pin the front end's door with `ssh -G` (host/room-verbs-cases.nix:350-361),
  so the quoting change in sec-3 is covered.
- **`hostModuleUnits`**: setting `services.capsule-perimeter.stateDir` fails
  eval with the removal message, the tmpfiles rules carry the declared root, and
  `/run/capsule-room` has its `0755 root` rule when rooms exist and none when
  they don't.
- **`templateCases`** forces the template with `stateDir` declared.
- `just check` and `just` stay green.

<!-- doctrine:section sec-6 -->
## Contracts and records

- **New `docs/contract-room-client.md`**, indexed in `docs/index.md`. It covers
  what a room client may rely on:
  - the attributes (`room`, `socket`, `knownHosts`, `hostKeyAlias`, `config`,
    `binds`);
  - the precondition (run as the module owner);
  - strict checking, and refusal before the first push;
  - that the destination name, the user and the identity are the client's.

  `docs/contract-assignment.md:63`'s room row points to it. Its definition of
  `<state>` changes from the module's `/var/lib/capsule` to `mkFleet`'s
  `stateDir`, and it keeps the `CAPSULE_STATE` override (RV-023 F-7).
- **CLAUDE.md**: the claim that accept-new writing a room's `known_hosts` is
  "not reachable by any case" (room-git-cases.nix:18-21) becomes false if case
  6 lands. Update that header.
- **README**: the module setup block (README.md:153ff) loses `stateDir`, and the
  `mkFleet` description gains it. "Rooms" (README.md:489ff) names the bundle.
- **`DEC-042` successor**: "mkFleet has ten arguments", restating it with
  `stateDir`, then `doctrine supersede`. Needs the user's assent at reconcile or
  earlier.
- **`POL-003` revision**: add the state root to the axis table, through
  `doctrine revision`, with the user's assent.
- **`DEC-037` and `DEC-047`**: their consequences name satan's hand-rendered
  config. At reconcile, `DEC-057` and `DEC-056` are linked as the successors of
  those lines. The records are not edited.
- **Handback** to satan:SL-027 and flakes:SL-015: name `packages.<sys>.room-client-<r>`,
  its `binds`, and that `/srv/fleet` must declare `stateDir`. This goes in the
  slice's Follow-Ups, in each repo's own words. Nothing is written into those
  repos from here.
- `IMP-022` resolves at close.

<!-- doctrine:section sec-7 -->
## Risks and what is out of scope

- **Every `mkFleet` caller breaks** until it declares `stateDir`, `/srv/fleet`
  included. This is accepted in `DEC-054`, and the failure names the argument.
  Per the forward-design memory, running capsules are not designed around.
- **`/run/capsule-room` surviving a room stop** is documented systemd behaviour
  (only the configured RuntimeDirectory is removed) and has not been observed
  here. The live check belongs to the consumer: stop a room under a running jail
  and restart it, and the door answers without restarting the jail. Recorded as
  an assumption, not load-bearing for the build.
- **The bundle ignores `CAPSULE_STATE`.** A host that moves its state at run
  time has bundles naming the declared root. That is intended: a consumer's jail
  is built, not invoked.
- **`GlobalKnownHostsFile none` changes oubliette's own doors.** A host that
  relied on a global known_hosts entry for a room stops trusting it. No such
  entry is declared anywhere, and `DEC-047` already forbids that second store.
- **The fixture sshd may not run in the build sandbox** (sec-5 case 6). If it
  can't, the fallback is a stated residual.
- **The quoting change in `words`** is covered by the existing `ssh -G` pins in
  `roomVerbsCases`.
- **Out of scope**: consumer edits; the module's other path options; the door's
  socket, mode, alias and oubliette's `accept-new`; slot doors; Plan E's
  ingress; `IDE-003`.

<!-- doctrine:section sec-8 -->
## Code impact

| path | change |
|---|---|
| `mkfleet.nix` | `stateDir` argument and its eval refusal; passes it to the module, `capsule-cli`, host programs, bundles; `packages."room-client-<r>"`; `roomClientCases` wiring; perimeter check over the declared root |
| `host/room-door.nix` (new) | `aliasOf`, `optionsOf`, `words`, `config`, `knownHostsIn`, `knownHostsOf` |
| `host/room-client.nix` (new) | the per-room bundle |
| `host/room-client-cases.nix` (new) | `roomClientCases` |
| `host/guest-ssh.nix` | `proxyCommand`; `proxyThrough` uses it |
| `host/room-git.nix` | takes `roomDoor`; `door`, `knownHosts*` and its own socat removed |
| `host/programs.nix` | builds `roomDoor` once; `roomTrust` from it; `moduleState` to `volume-root.nix` |
| `host/cli.nix` | human room door passes `checking`; `moduleState` passed from mkFleet |
| `host/services.nix` | `stateDir` option removed (`mkRemovedOptionModule`); reads the declared value; passes `moduleState`; tmpfiles `d /run/capsule-room` (derived) when rooms exist |
| `host/volume-root.nix` | unchanged text; now passed `moduleState` |
| `fleet.nix` and `host/fleet-cases.nix` | `stateDir` reasons and their cases (if the refusal lives in `fleet.nix`) |
| `host/room-verbs-cases.nix`, `host/room-git-cases.nix`, `host/wrap-cases.nix` | follow the moved `door`/`roomTrust` arguments; room-git-cases' header (accept-new unreachable) revised if sec-5 case 6 lands |
| `CLAUDE.md` | the same claim, where it summarises the room channel's suite |
| `fixture/default.nix`, `templates/fleet/flake.nix` | `stateDir = "/var/lib/capsule"` |
| `just/fleet.just` | `roomClientCases` in `just build` and `just cases` |
| `docs/contract-room-client.md` (new), `docs/index.md`, `docs/contract-assignment.md`, `README.md` | sec-6 |

