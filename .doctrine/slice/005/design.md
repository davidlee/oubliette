<!-- doctrine:section sec-1 -->
## Shape

A **room** is a long-lived guest that is not a slot: no target, no assignment record, no egress. This design gives it the same *kind of record* a slot already has, minus the uplink, so everything that builds a guest's namespace, units and audit iterates one set, and a room differs from a slot by an absence rather than a kind (`DEC-036`, Plan E §1).

```
consumer: mkFleet { …eight as today…; rooms = { lounge = {…}; assistant = {…}; }; }
                                   │
   fleet.slots ─▶ capsules.nix ─▶ slot records  {name; ns="cap-<n>";  uplink={dev addr peer gw prefix}; socket="/run/capsule/<n>/ssh.sock"}
   rooms       ─▶ rooms.nix    ─▶ room records  {name; ns="room-<n>"; uplink=null;                       socket="/run/capsule-room/<n>/ssh.sock"; users; sizes}
                                   │   rooms.nix throws (reason in `reasons`) on a name ∈ slots ∪ {hello, capsule}, a bad
                                   │   name or user; mkfleet's liveNames gains room-<n>, so `borrowed` covers the probe fabric
                     guests = slot records ∪ room records
   ┌─────────────── over guests (one construction each) ───────────────┐   ┌──── over slots only (uplink ≠ null) ────┐
   capsule-netns-<n> · tap drop-in · microvm@<n> drop-in · ssh relay · guard   capsule-proxy-<n> · allowlist · sudo · slot tmpfiles
                                   │
   nixosConfigurations: hello · capsule · <slot>… · <room>…   — every image hostName capsule (DEC-032)
```

What a room has, and what it does not:

| | slot | room |
|---|---|---|
| namespace, tap, `/30` from `net` | `cap-<n>`, same tap and `/30` | `room-<n>`, same tap and `/30` (NOTES item 17) |
| uplink, proxy, allowlist | yes | **none**: no veth, no route, no resolver |
| image | its target's, hostName `capsule` | `vm/room.nix` per room, hostName `capsule` |
| ssh relay | `/run/capsule/<n>/ssh.sock` | `/run/capsule-room/<n>/ssh.sock` (`DEC-037`) |
| guard | both limbs | both limbs (`DEC-039`) |
| front end | every verb | `ssh`, `start`, `stop`, `status` (`DEC-041`) |
| devshell path | yes | **no**: rooms are module-path only |

Rooms run only on the module path. `capsule-netns` exists only there (`host/netns.nix:8-11`), and a room booted from the devshell would put its tap in the root namespace, which is the direct transport's signal (NOTES item 40). Devshell programs refuse room names: `vm` and `vm-stop` bake the declared room list and refuse a room by name before any state is made, and rooms are left out of `packages`' per-name map (`mkfleet.nix:1428`), so no devshell attribute boots one. A room's build output is `roomImages` (sec-9).

<!-- doctrine:section sec-10 -->
## Governance and docs footprint

Changed in the same commit as the code that moves each boundary (POL-002 Scope):

| record or doc | change |
|---|---|
| `DEC-025` | `mkFleet` has nine arguments. Amended through its own record (a superseding DEC restating it), not edited in place |
| `POL-003` | axis table gains `rooms`, and the `borrowed` paragraph says room namespaces are in `liveNames`. A policy change: a revision via `doctrine revision`, with the user's assent |
| `POL-004` rationale | names Plan E as "the first test of separability". Updated to say what two callers proved and what they did not (sec-8) |
| `CON-005` | unchanged in substance; its scope note gains rooms |
| `RSK-005` | gains a line: one resolvable attr per declared room, each with a drop-in that supplies its namespace |
| `docs/contract-assignment.md:62` | the noun table gains rooms as a second owner of namespace, socket and units |
| `docs/contract-target.md` | no change: a room has no target. The future `repos` field is noted in Plan F, not here |
| `docs/plan-e-room.md` | "Where this stands" and "What it touches" rewritten to point at SL-005 and this design. "No new address" confirmed |
| `docs/plan-f-assistant.md` | §1, §4, §5 point at `DEC-036`, `DEC-040`, `DEC-037` |
| `CLAUDE.md` | the case-suite list gains `netnsCases` and `roomsCases`; "Every image is hostName `capsule` (`DEC-020`)" becomes `DEC-032` |
| NOTES item 18 | its "no inbound channel" sentence is still true, since the room door is a host-local socket. Untouched |
| "no bridge, no LAN exposure" (`templates/fleet/net.nix:2`, `docs/design.md:78`, `README.md:548`) | still true: no tailnet ingress is built. Untouched |

`satan:IDE-007` and satan's SL-023 are told where the door and the quarantine layout live (`DEC-037`, `DEC-040`, sec-6). That is the user's relay, not a write into another repo.

<!-- doctrine:section sec-11 -->
## Risks and what is out of scope

| risk | consequence | handling |
|---|---|---|
| rooms and slots share the unit-name space | a later slot named like a room would collide on `capsule-netns-<n>` | `rooms.nix` throws at eval in every caller (`DEC-038`, DEC-029) |
| the door module refactor touches the live capsule guest | an unnoticed change in the slot image | build comparison of the toplevel (sec-9), recorded in the commit |
| a required ninth argument | the consumer's eval fails until it passes `rooms` | intended (POL-003). The user's one-line change at the input bump (sec-8) |
| a broken room tears down slot egress | a room fault becomes a fleet outage | intended: breakage is a breach and fleet-wide (`DEC-039`, `host/guard.nix:33-37`) |
| an always-up room blocks probes | routine stops | accepted (`DEC-031`). `capsule status` shows it, and stop is one verb |
| no NTP in a room | clock drift across suspend reaches commit timestamps | `ISS-014`, unchanged, worse for an always-up guest |
| sparse volume growth | `/home` outgrows host space | `RSK-007`, unchanged |
| every VMM runs as `microvm` | a room VMM can write slot image directories | `mem.fact.oubliette.image-directories-are-vmm-writable`, unchanged |

**Out of scope**:
- the model door (Plan F §2);
- per-repo tools and `session` (Plan F §3);
- the per-repo git channel build (`DEC-040` pins it);
- Plan E's tailnet ingress and furniture;
- a room reset verb;
- a host with rooms and no slots;
- narrowing `any_vm_running`;
- anything in `~/flakes` or satan.

<!-- doctrine:section sec-12 -->
## Code impact

The design-target selectors. Each path is one this design commits to changing or creating:

| path | change | section |
|---|---|---|
| `rooms.nix` | new: declaration to guest records, `reasons` | sec-2 |
| `rooms-cases.nix` | new: refusal verdicts and reasons, beside `rooms.nix` | sec-2, sec-9 |
| `fabric.nix` | new: `liveNames`, `borrowed`, `reason`, moved out of `mkfleet.nix` | sec-2 |
| `fabric-cases.nix` | new: the fabric's verdicts and reason, beside `fabric.nix` | sec-2, sec-9 |
| `host/netns.nix` | uplink all or nothing; `tools` argument; `capsuleEnv` over a guest record | sec-3 |
| `host/netns-cases.nix` | new | sec-3 |
| `host/services.nix` | `rooms` argument, `guests`, `perGuest`, conditional aggregator and proxy edges | sec-4 |
| `host/guard.nix` | `guests` in place of `capsules.instances` | sec-4 |
| `host/guard-cases.nix` | room cases | sec-4 |
| `host/cli.nix` | room list, resolution, four verbs, refusal, `collide` over rooms | sec-7 |
| `host/room-verbs-cases.nix` | new: the front end rendered against a fixture pool with rooms, as `host/policy-cases.nix` does | sec-7 |
| `vm/door.nix` | new: tap, sshd, root keys | sec-5 |
| `vm/room.nix` | new | sec-5 |
| `vm/capsule.nix` | imports `vm/door.nix` | sec-5 |
| `mkfleet.nix` | ninth argument, `rooms.nix` applied, room `vms`, `liveNames`, `hostModuleUnits` assertions, `roomImages`, rooms out of `packages`' per-name map, the room list baked into `vm`/`vm-stop`, suite wiring | sec-1, sec-2, sec-4, sec-9 |
| `host/vm-cases.nix` | a room name refused by `vm` and `vm-stop`, with its reason | sec-1, sec-9 |
| `fixture/default.nix` | `lounge`, `assistant` | sec-8 |
| `templates/fleet/flake.nix` | `rooms = {}` and a commented example | sec-8 |
| `just/fleet.just` | new suites and `roomImages` in `build` | sec-9 |
| `docs/plan-e-room.md`, `docs/plan-f-assistant.md`, `docs/contract-assignment.md`, `CLAUDE.md` | footprint | sec-10 |
| `docs/probes.md` | the live run's evidence and what it does not prove | sec-9 |
| `README.md` | rooms' usage, `microvm -c <room>` before the first start | sec-7, sec-10 |
| `justfile` | the new files in `nix_paths` | sec-9 |
| `host/policy-cases.nix`, `host/volume-cases.nix` | `rooms = {}` for the front end's render | sec-7 |
| `capsules.nix`, `fleet.nix`, `host/own-vms.nix` | comments only: `DEC-020` becomes `DEC-032` | sec-10 |

The front end's existing suites (`policyCases`, `volumeCases`) are per concern, so room verbs get their own suite file rather than growing one of them.

<!-- doctrine:section sec-2 -->
## The declaration and `rooms.nix`

**`rooms` is the ninth `mkFleet` argument, and it is required** (`DEC-033`, POL-003). A consumer with no rooms writes `rooms = {};`. The closed argument set (`mkfleet.nix:14-42`) stays closed. The "eight arguments" comments in `templates/fleet/flake.nix:41-42` and `fixture/default.nix:1` become nine.

```nix
rooms = {
  assistant = {
    users.agent = { uid = 1001; keys = ["ssh-ed25519 AAAA… satan-runner"]; };
    sizes = { vcpu = 4; mem = 8192; volume = "40G"; };
  };
};
```

| field | meaning | checked |
|---|---|---|
| `users.<user>` | a non-root login, `{ uid; keys; }`: these authorized keys and a declared uid; no wheel, sudo or su | `root` refused; exactly `{ uid; keys; }`; keys non-empty; uid an integer in 1000-29999 and unique within the room; name unit- and user-safe |
| `sizes` | `vcpu`, `mem`, `volume`, with the shape a target's `sizes` has | all three required: nothing defaults (POL-003) |

There is no `kind`. A people-room and an assistant differ in which users are declared, and nothing generic learns what a room is for (POL-002). The assistant's repos are **named here and not built**: a later `repos = [<target name>]` reuses `targets/`, so a repo's tools come from its target's `toolsPackage` and no second per-repo declaration appears (DEC-018).

**`rooms.nix` is pure**, the shape of `capsules.nix` and `fleet.nix`: no host values, no work. It is applied once in `mkfleet.nix` to `rooms` and the slot names, and it returns:

```nix
{ instances = { <name> = { name; ns = "room-${name}"; uplink = null;
                           socket = "/run/capsule-room/${name}/ssh.sock"; users; sizes; }; };
  reasons   = { names = null | "<message>"; users = null | "<message>"; };
}
```

Each refusal is a value in `reasons` and is exactly what `instances` throws, as `fleet.nix` does (`fleet.nix:15-17, 42-47`), so a suite asserts *why* and not only *that* (`DEC-038`):

- **names**: a room name that is a slot name, `hello` or `capsule`, or not unit-safe. Rooms and slots share one unit-name space (`capsule-netns-<n>`, `microvm@<n>`) and one `nixosConfigurations` space, which is what makes the first three collisions real.
- **users**: a user named `root`, a user that is not `{ uid; keys; }`, no uid, no keys, a uid outside 1000-29999, or a uid shared within one room. The uid is declared because a room's root is tmpfs, so NixOS would allocate undeclared uids afresh every boot in name order, while `/home` keeps the numbers its files were written under (`RSK-012`, PHASE-10). 1000-29999 is NixOS's normal-user range; `nixbld*` sit at 30001 and up.

**The probe fabric** is checked at the same moment and with the same message as before, but by a pure `fabric.nix` (`{lib}: {capsules, rooms, fabric}: {liveNames; borrowed; reason;}`), which `mkfleet.nix` applies once and whose `reason` it throws in the probe prelude. It left `mkfleet.nix`'s `let` so a suite (`fabricCases`) can read the reason as a value, the `fleet.nix`/`rooms.nix` shape (PHASE-04). The throw fires when a probe is forced, not in every eval, and the wiring line is pinned by no suite (`ISS-022`). `liveNames` gains every room's `ns`, so `borrowed` is non-empty if a probe fabric value equals one. That makes the check three declarations wide: slots, rooms and the probe fabric (NOTES item 38's "one declaration wide" gap closed for rooms). Socket paths are disjoint by prefix and need no check. A room name that is a front-end verb or `all` is refused by the front end's own `collide`, where the verbs are known (sec-7).

<!-- doctrine:section sec-3 -->
## `capsule-netns` with no uplink

One program, two callers (`DEC-035`, Plan E §1). The program learns that **a namespace may have no uplink**, keyed by its values, and never learns what a room is.

**The uplink group** is `EGRESS_NS DEV PEER ADDR GW UPLINK_PREFIX RESOLVER`. Today every one is `${VAR:?}` (`host/netns.nix:137-147`). After the change:

| group state | `up` | `undo_up` (shared with `down` and the rollback) |
|---|---|---|
| all set | unchanged: resolver file, veth, route (199-209) | unchanged: both peer deletions, then the namespace |
| all empty or unset | namespace, `lo`, forwarding off, tap guard rule; **no** resolver file, veth or route | namespace deletion and resolver cleanup only; **no** peer deletions (174-175) |
| any other mix | **refuses** with the names that are set and unset, before the trap is armed and before anything is built | n/a |

`NS`, `TAP`, `TAP_ADDR` and `PREFIX` stay required in both shapes. `addr` and the `down` refusal (a VMM still in the namespace) are unchanged. The refusal comes first, so a misconfigured unit fails as itself and leaves nothing for a teardown to guess at (NOTES item 37).

`capsuleEnv` (`host/netns.nix:368-380`) becomes a function of a guest record. For `uplink = null` it emits only `NS TAP TAP_ADDR PREFIX`. Unset rather than empty-string is the convention, so the unit's `Environment=` lines carry nothing for a room. The program accepts both, since an empty value is the same absence.

**`capsule-netns` takes `tools` and `etcNetns ? "/etc/netns"` as arguments with defaults**, as `host/guard.nix` takes `tools`, so `host/services.nix` builds it with the real `iproute2`/`nftables`/`procps` and path, and a suite builds the same text against stubs (POL-004). Both shipped copies stay one store path because the defaults are the real ones. `etcNetns` exists because a build sandbox's `/etc` is read-only and stubbing the tools cannot reach the resolver file's shell redirect, so `netnsCases` is handed a scratch `/etc/netns` and says so; cases 1 and 2 then assert the resolver file's content and absence positively (PHASE-02).

**`netnsCases`** (`host/netns-cases.nix`) runs the shipped `capsule-netns` with a stub `ip`, `nft` and `sysctl` that log their argv and can be told to fail:

1. Uplink `up`: the logged call sequence equals today's. This pins the slot path unchanged.
2. No-uplink `up`: no `veth`, no `link set … netns $EGRESS_NS`, no `route`, no resolver file, and the guard rule is installed.
3. Partial group: exit status *and* the reason naming the mixed variables, with nothing logged.
4. No-uplink `up` with the stub `nft` failing: the rollback runs `undo_up` with no peer deletion and the namespace is deleted.
5. No-uplink `down`: namespace deleted, no peer deletion.

Each assertion carries its reason, and the suite is mutated once (restore an unconditional peer deletion) to watch case 4 go red.

<!-- doctrine:section sec-4 -->
## Host units over guests, and the guard

**`host/services.nix` takes `rooms` beside `capsules`** and binds `guests = attrValues capsules.instances ++ attrValues rooms.instances` next to today's `instances` (`host/services.nix:59`). A second helper `perGuest` sits beside `perInstance` (203). Each unit is built once, by whichever set it belongs to (`DEC-036`):

| unit | over | what differs for a room |
|---|---|---|
| `capsule-netns-<n>` | guests | `requires`/`after` the aggregator only when `uplink != null` (366-367); env from `capsuleEnv` (sec-3) |
| `microvm-tap-interfaces@<n>` drop-in | guests | nothing |
| `microvm@<n>` drop-in | guests | `wants` the relay, and the proxy only when `uplink != null` (417). Stop-key check and stop unchanged (sec-5, sec-7) |
| `capsule-ssh-relay-<n>` | guests | `c.socket` and `RuntimeDirectory` are the record's (`capsule-room/<n>` for a room). Same `socat`, mode `0600`, owner, `BindsTo` the tap (302-360) |
| `capsule-proxy-<n>`, allowlist link, sudo rules, `slot/<n>` tmpfiles | slots | not built |
| `capsule-perimeter-guard` | guests | sec-4 below |

**Unit names do not change**, so `hostModuleUnits`' filter (`mkfleet.nix:680-682`) already covers every room unit: the newline check, the bind-versus-user pairing and the programs' shellcheck reach rooms with no edit to the check. That is the main reason rooms reuse the slot unit names rather than taking `room-*` ones (research X4). The cost is the shared name space, and sec-2's throw is what makes that safe.

The `instances != []` assertion (570-573) stays about slots. A host with rooms and no slots is out of scope.

`microvm.vms` stays undeclared (597-602, NOTES item 49). A room is created as a slot is, by `microvm -c <room>` against its `nixosConfigurations` attr, and its drop-in supplies the namespace, so `RSK-005` widens only by declared names.

### The guard

**Rooms join the guard's `declared` list** (`DEC-039`, `host/guard.nix:67`). The guard takes `guests` rather than `capsules.instances` and asks each one the same questions:

- limb two: a running `microvm@<n>` is inside its own namespace (`vm_in_ns`);
- when the namespace exists: forwarding off (`ns_not_forwarding`) and the `capsule-guard` tap rule.

The aggregator checks are unchanged and remain unconditional. A room failing a check is the whole host's problem, exactly as a slot's is, and the guard's response (tear down egress) is the same. `CON-005` stays true, only wider: the guard is still the one reader of every guest namespace. The report line counts guests. `guardCases` gains a room in its fixture and a case where a running room VMM is outside its namespace.

<!-- doctrine:section sec-5 -->
## The guest: a shared door, and `vm/room.nix`

**Every image is hostName `capsule`** (`DEC-032`, superseding `DEC-020`). `nixosConfigurations` gains one attr per declared room beside `hello`, `capsule` and the slots, so `any_vm_running`'s `microvm@capsule` (`probe/harness.sh:294`) sees a running room and every probe refuses, which is what `DEC-031` asks. Rooms are built by `mkVm "capsule" ./vm/room.nix { room = rooms.instances.<n>; }` in `mkfleet.nix`'s `vms`, beside `fleet.nix`'s slot images.

**The door module** (`vm/door.nix`, new) holds what every confined guest needs and today lives only in `vm/capsule.nix` (`DEC-034`):

- the tap interface, from `net` (`vm/capsule.nix:125-131`), **and the guest's side of the link**: the static `net.guest/net.prefix` address on the tap's MAC, no DHCP, no gateway, `services.resolved` off (`vm/capsule.nix:150-163`). Without this a room never answers at `net.guest`, since `vm/common.nix:34` turns DHCP off (RV-014 F-1);
- sshd with no passwords, root by key only, host keys at a path the importer names on its volume (265-279);
- `users.users.root.openssh.authorizedKeys.keys = access.adminKeys ++ [access.stopKey]` (296), so root is reachable only by the host's keys (POL-001 limb 3) and the stop key works.

`vm/capsule.nix` imports it and passes its host-key path (`${work}/ssh`). Its behaviour does not change, and sec-9's build comparison checks that the capsule image's toplevel is unchanged or differs only by option-definition order.

**`vm/room.nix`** imports `vm/door.nix` and adds only:

- `microvm.{vcpu, mem}` and one volume, `room-home.img` mounted at `/home` with `size = sizes.volume`. Exec is permitted, since a client may upload a tool daemon (`DEC-037`);
- one `users.users.<user>` per declared user: `isNormalUser`, home `/home/<user>`, the declared keys and the declared uid (sec-2), no extra groups;
- `security.lockKernelModules` and `security.protectKernelImage`, as the capsule sets them and for `vm/capsule.nix`'s reasons. They are in `vm/room.nix`, not `vm/door.nix`, so the slot images do not move (user-directed, PHASE-05);
- host keys under `/home/.ssh-host-keys/`, so they live on the volume and survive reboots;
- `services.getty.autologinUser = lib.mkForce null`: `vm/common.nix:13` autologs root on the console, the capsule overrides it to `agent` (`vm/capsule.nix:280`), and a room overrides it to nobody, so root stays key-only (POL-001 limb 3; RV-014 F-2);
- a first-boot seed that makes each home and the host-key directory with the right owners, the shape of `capsule-seed` (`vm/capsule.nix:302-340`) without the repository.

No egress, proxy, target tools, `reset-home` or kernel-command-line target marker (`DEC-021` is a slot's). The profile verbs never see a room (`DEC-023`), because the front end refuses them (sec-7).

**Size**: one image per room, because the keys are in the closure. Rooms are few, and the closure is a minimal NixOS with sshd.

<!-- doctrine:section sec-6 -->
## The door, and the quarantine layout

> **Superseded in part by SL-006** (`DEC-045`, `DEC-047`, `DEC-051`): every door to a room checks `/var/lib/capsule/room/<room>/known_hosts` with `HostKeyAlias=room-<room>` and accept-new, not `<room>` (which could equal a slot's alias, `RSK-011`); the room channel is built, as `capsule-room-git` and the front end's `push` and `collect`. The sentences below are kept as SL-005 decided them.

This section is **the interface `satan:IDE-007` designs against**. It restates `DEC-037` and `DEC-040` as a client sees them.

### Reaching a room (`DEC-037`)

```
runner (as the module owner)                       room-<n> namespace
  ssh -F <app config>                                ┌──────────────────────────────┐
    ProxyCommand=socat - UNIX-CONNECT:  ──▶ /run/capsule-room/<n>/ssh.sock ──socat──▶ <net.guest>:22
    <user>@<net.guest>                    (mode 0600, module owner,       │  sshd: declared users only │
    HostKeyAlias=<room>, strict           BindsTo the tap)                │  /home on the room volume   │
                                                                          └──────────────────────────────┘
```

| property | value |
|---|---|
| socket | `/run/capsule-room/<room>/ssh.sock`, mode `0600`, owned by the module's owner; exists only while the room's tap does |
| login | `<declared user>@<net.guest>` with that user's declared key; no other login but root |
| root | only the host's `access.adminKeys` and `access.stopKey`; never a client's key |
| host keys | on the room volume, stable until the volume is deleted. A client may pin them (`HostKeyAlias`, strict checking), and pi-env's strict mode works |
| home | `/home/<user>` on the volume, persistent, exec permitted |
| egress | none: no route, no resolver, and no link but `lo` and the tap. The guest can address only `net.host`, which is the room namespace's own end of the tap and not this host's root namespace. Its kernel answers ICMP there and **no service listens** (the relay connects outward to `net.guest:22`). The tap guard rule keeps it to that one address (`host/netns.nix:217-224`). The model door (Plan F §2), a future listener at `net.host`, is not part of this slice, and satan's option D does not need it (research X6; RV-014 F-3) |
| lifecycle | `capsule <room> start | stop` (sec-7). A stop is a reboot through the stop key, so an in-flight command is cut, and any probe run stops the room first (`DEC-031`) |

pi-env reaches this door unchanged: it passes `-F <configFile>` and disables only `RemoteCommand` and `PermitLocalCommand` (pi-env `src/ssh.ts:90, 100-101`), so a `ProxyCommand` in its config file works. The client must run as the module owner to open the socket. The tailnet ingress (Plan E's `.socket` forwarder) is a different door and is not built here.

### Where proposals will land (`DEC-040`, pinned, not built)

| thing | value |
|---|---|
| guest clone | the target's `guestPath` inside the room |
| quarantine | one bare repo per room and repo: `/var/lib/capsule/collect/<room>/<target>.git`, `transfer.fsckObjects` as today |
| transport | `host/git-channel.nix` given a room transport fragment over the room socket, with the quarantine key (`<room>/<target>`) separate from the transport name (POL-004) |
| promotion | a human's act outside oubliette (satan's Emacs surface). There is no room `fetch` into a real repo |

The build-out is a follow-on slice. Until then a client can read and write the room only over the door.

<!-- doctrine:section sec-7 -->
## The front end and stopping a room

**`capsule` learns rooms for four verbs** (`DEC-041`). `host/cli.nix` gains a baked `rooms=(…)` list beside `declared` (329). Name resolution tries slots, then rooms. A room is only ever named on argv, never resolved implicitly or read from `CAPSULE_NAME`, which stays slot-only.

> **Superseded in part by SL-006** (`DEC-051`, which supersedes `DEC-041`): a room takes six verbs (`push`, `collect` and `forget-host-key` added), `ssh` checks the room's own `known_hosts` with `HostKeyAlias=room-<room>` (`DEC-047`), and the refusal text names all six. The table below is kept as SL-005 decided it.

| verb | for a room |
|---|---|
| `capsule <room> ssh [user] [-- cmd]` | `door`'s `human` mode (`host/cli.nix:728-740`) with the room's socket and `HostKeyAlias=<room>`, as `<user>@<net.guest>`. `user` defaults to the room's only user if it has exactly one, and is required otherwise: the declaration is the default, not a guess |
| `capsule <room> start` | its own branch, not the slot path: `systemctl start microvm@<room>`, then the readiness check asks **`root@<net.guest>`**, since the host's admin key is root's in every guest (`vm/door.nix`). No profile resolution, record or injection. The slot path's readiness is hardcoded to `agent` (`host/cli.nix:748`) and then injects (1858+), so a room with users `ada` and `bob` would read as failed (RV-014 F-4) |
| `capsule <room> stop` | `systemctl stop microvm@<room>`: the drop-in's `ExecStop` reboots the guest through the stop key, then `microvm-shutdown` (`host/services.nix:434-438`) |
| `capsule status` | a rooms block after the slot table: name, running or not, and socket present. That is what a refused probe needs to see. It is a separate block so `IMP-009`'s width problem does not grow. With no slot up and a room up, an unnamed `capsule status` answers as `capsule all status`, so that block is reachable without naming `all`; any other unnamed verb with no slot up refuses as before (PHASE-10) |
| any other verb | refuses: `capsule: '<room>' is a room; rooms take ssh, start, stop (status lists them)`, exit 2 |

**A room name may not be a verb or `all`.** The front end already throws at eval when a slot name is one (`host/cli.nix:296-302`, `collide`). `collide` widens to slot and room names, because verbs are known only there, and its message names which kind collided: `'<n>' is both a room and a verb (or all)` (RV-014 F-5, F-9).

`sockOf` returns the record's socket, so `doorsOpen`'s glob over `/run/capsule/*/ssh.sock` (698-705) never counts a room, and transport selection for slot programs is untouched (NOTES items 20, 40).

**Stopping** is the slot path exactly: the `microvm@` drop-in's stop-key check before start, and the reboot-then-shutdown stop (C22, NOTES item 11). A room's root trusts `access.stopKey` through `vm/door.nix`, so the check passes. The devshell `vm-stop` never meets a room, because devshell programs refuse room names, so its non-slot branch does not change.

`roomVerbsCases` (`host/room-verbs-cases.nix`, the front end rendered against a fixture pool with rooms, as `policyCases` does) pins only what it can observe. `pkgs.systemd` and `pkgs.openssh` are in the front end's `runtimeInputs` (`host/cli.nix:326`), so no case can stub `systemctl` or `ssh` (`host/policy-cases.nix:104`; RV-014 F-6). It pins: a room name consumed as a name rather than a verb, a slot verb on a room refusing with its reason, a two-user room's `ssh` with no user refusing before any `ssh` runs, and, as an eval verdict, a fixture room named `ssh` throwing from `collide` with its reason. What `ssh`, `start` and `stop` actually invoke is proven by the live run (sec-9).

<!-- doctrine:section sec-8 -->
## Fixture, template and the consumer

**The fixture** (`fixture/default.nix`) declares two rooms, nobody's, through the one module:

- `lounge`: users `ada` (uid 1001) and `bob` (uid 1002), each with a fixture key. This is Plan E's shape.
- `assistant`: user `agent` (uid 1001) with a fixture key. This is Plan F's door.

Both use the fixture's `net` and sizes off the live fabric. Its probe fabric stays disjoint from `room-lounge` and `room-assistant`. The two rooms differ only in values, and that is stated rather than oversold: the seam proved here is slot versus room through one `capsule-netns`, one unit set and one guard. Plan E's tailnet ingress and Plan F's repos are where the room module itself meets a second shape (inq-11).

**The template** (`templates/fleet/`) passes `rooms = {};` plus a commented example. `templateCases` evaluates the template's wiring of the ninth argument and no room. Room evaluation and builds are the fixture's (sec-9; RV-014 F-8).

**The consumer** at `/srv/fleet` must pass `rooms` the moment this lands, because the argument is required. That is the user's change, made in the same sitting as bumping the oubliette input: `rooms = {};` to change nothing, or `rooms.assistant = …` to bring the assistant up. Nothing on the host changes until then: a room's units are not `wantedBy` anything, as a slot's are not.

**`ISS-020`**: oubliette's flake exports the fixture fleet's host module, so the fixture's rooms ride along as its slots already do. Noted, not fixed here.

<!-- doctrine:section sec-9 -->
## Verification

Every check here is in `just build` (`just/fleet.just:64-76` lists them by hand, so each new suite gets a line and an `inherit`), and each new case is mutated once to watch it fail (POL-004 Verification).

| claim | kind of check | how |
|---|---|---|
| no-uplink `capsule-netns`, the partial-group refusal, rollback with no peer, slot path unchanged | program cases | `netnsCases` (sec-3) over the shipped store path |
| `rooms.nix` refusals and their reasons | eval verdicts | `roomsCases` (`rooms-cases.nix`, beside `rooms.nix` as `fleet-cases.nix` is beside `fleet.nix`): `tryEval (deepSeq …)` per refusal, reason asserted in the shell, as `fleet-cases.nix` does |
| the probe fabric meets a room namespace | library values | `fabricCases` (`fabric-cases.nix`, beside `fabric.nix`): `borrowed` and `reason` read as values for a fabric naming a room's and a slot's namespace. That `mkFleet` throws on `reason` is pinned by no suite (`ISS-022`) |
| room units evaluate, carry no newline, pair binds with users, programs shellcheck | module evaluation | `hostModuleUnits`/`hostModulePrograms` over the fixture with rooms, no check edited (sec-4) |
| a room's netns unit does not require the aggregator, and its `microvm@` does not want a proxy | module evaluation | new assertions in `hostModuleUnits` over the room units' fields |
| the guard audits rooms | program cases | `guardCases` gains a room, and a room VMM outside its namespace failing limb two |
| front-end room resolution and refusals, and the verb collision | program cases, eval verdict | `roomVerbsCases` (sec-7); argv of `ssh`/`start`/`stop` is live-only |
| the devshell refuses rooms | program cases | `vmCases` gains a fixture room: `vm <room>` and `vm-stop <room>` exit 2 with the reason and create no `.vm/<room>/` (sec-1) |
| room images build, and say what a room must | build | a `roomImages` output linking the fixture rooms' declared runners, each forced through `roomChecks` first, so a broken rule throws with its reason: hostName `capsule`; the console autologs nobody; DHCP off with the door's static link; `room-home.img` at `/home`; root's keys exactly the admin keys and the stop key; kernel modules and image locked; and per declared user: present, a normal user, exactly its keys, its record's uid, no extra groups. Added to `just build`'s list. That recipe lists no VM images today (`just/fleet.just:64-76`), so this is a new gate, not an existing one (RV-014 F-7) |
| the template's wiring of the ninth argument | eval | `templateCases` with `rooms = {}`. It exercises the argument, not a room. Room evaluation and builds are the fixture's (RV-014 F-8) |
| the capsule guest is unchanged by the door module | build comparison | `nix-store --query` the fixture slot image's toplevel before and after: equal, or a diff confined to option order, recorded in the commit |

**Live** (root, the user's to run; evidence per `STD-001`, recorded in `docs/probes.md` with what it does not prove):

1. With `rooms.assistant` declared in the consumer: `capsule assistant start`. `ip netns exec room-assistant ip route` shows no default route and `ip link` shows only `lo` and the tap. The guard reports N+1 namespaces verified.
2. `capsule assistant ssh` reaches `agent`, `ssh -F` with the `ProxyCommand` line reaches it as a client would, and the serial console asks for a login rather than handing over root.
3. From inside: `ip route` is empty past the `/30`, `getent hosts example.com` fails, and a TCP connect to `net.host` on any port is refused. A TCP connect to an address outside the `/30` gets *no route*. Assert both directions: the door works and nothing else does. ICMP to `net.host` is answered by the room namespace's own kernel and is not a breach (sec-6).
4. Any probe refuses while the room runs. `capsule assistant stop` exits cleanly through the stop key, and the probe then runs.

**Not proven by any of this**: anything about pi-env or satan's runner beyond reaching the door; the unit-level teardown after a failed `ExecStart` (`RSK-003`, unchanged for rooms); a room's behaviour across a host suspend (`ISS-014`).

