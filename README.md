# Oubliette: Inhuman Confinement
 
> An oubliette is a deep, medieval dungeon chamber, shaped like a bottle to make 
> climbing out impossible. A solitary trapdoor in the ceiling is the only 
> entry. There is no exit.

![oubliette](./oubliette.png)

## What for?

A **capsule**: a [firecracker](https://github.com/firecracker-microvm/firecracker) [microVM](https://github.com/microvm-nix/microvm.nix) used to securely confine a coding agent. 

It holds a real git clone of one **target** repo, carries that project's 
tool set, and has exactly enough network to work, and no more. 

Oubliette manages a fleet of capsules on a NixOS host, for safe, unattended 
execution of untrusted code.

It is [doctrine](https://github.com/davidlee/doctrine)'s reference capsule host implementation, 
but will work with any project which satisfies its 
[contract](/docs/contract-target.md). It is intentionally unaware of 
project and framework semantics.

Design rationale and known gaps live in [docs/](./docs/index.md). Here's 
a [walkthrough with diagrams](./docs/architecture-walkthrough.md).

This file describes how to use it.

## Prerequisites

- KVM (`/dev/kvm` is `crw-rw-rw-` here, so no group membership needed).
- nix-direnv — `direnv allow` gets you the devshell and its commands.
- The host config below. Without it the capsule still runs; it just isn't
  confined.

## Host requirements

Part of the perimeter lives in the host's NixOS config rather than in this
flake, because it has to hold across a reboot and be unreachable from anything
this repo runs. Nothing here is optional.

```nix
# The only port the guest may reach: the proxy. It was two until the git
# channel inverted (NOTES item 18) — the host initiates git now, so there is
# no service on 9418 and nothing to allow.
networking.nftables.enable = true;
networking.firewall.interfaces."vm-capsule".allowedTCPPorts = [3128];

# The tap is an endpoint, never a transit path.
networking.nftables.tables.capsule-forward = {
  family = "inet";
  content = ''
    chain forward {
      type filter hook forward priority filter - 10; policy accept;
      iifname "vm-capsule" drop
      oifname "vm-capsule" drop
    }
  '';
};

# So the host side can prove the drop above is loaded, rather than trusting
# that this file still says so. Read-only, exact arguments, one command.
# Sudoers is last-match-wins: this must come after any broad wheel/ALL rule
# or it does nothing.
security.sudo.extraRules = lib.mkAfter [{
  users = ["david"];
  commands = [{
    command = "/run/current-system/sw/bin/nft list table inet capsule-forward";
    options = ["NOPASSWD"];
  }];
}];
```

The **module path** needs one thing of its own, out-of-band because it is a
secret and this host's alone — the key a `microvm@<name>` unit presents to ask
its guest to shut down. Generated once:

```sh
sudo install -d -m 0755 /var/lib/capsule-stop
sudo ssh-keygen -t ed25519 -N "" -C "capsule stop key" -f /var/lib/capsule-stop/key
sudo chown microvm:kvm /var/lib/capsule-stop/key && sudo chmod 0400 /var/lib/capsule-stop/key
cp /var/lib/capsule-stop/key.pub keys/stop-key.pub    # in the consumer flake: it is in the guest's closure
```

Not the human's key: an `ExecStop` has no ssh agent and no way into her home,
and a unit should not hold a credential whose passphrase is a person's business.
Replacing it is a guest rebuild, since the public half rides in the closure. A
capsule whose stop key is missing or unreadable by the `microvm` uid refuses to
start — see "Stopping" below for why that is the right end of the failure.

All of that first block belongs to the **devshell shape**, whose tap is in the
host's own namespace. The module path does not use it: its taps are inside per-capsule
namespaces, where a forward drop written here would never see a packet, and its
control is that namespace's own `ip_forward` instead. Leave this config in
place — it is what keeps the devshell path honest — and note that the module
turns *global* forwarding on for the proxies' egress, so the check below reports
`dropped` rather than `latent` and would report `open` if you ever removed the
table.

**These are verified, not assumed.** `capsule-net up` and `capsule-host` both
call the same check and report one of three states:

| state     | means                                                              |
| --------- | ------------------------------------------------------------------ |
| `dropped` | the table is loaded and both rules are present. Verified.           |
| `latent`  | the drop can't be read, but `net.ipv4.ip_forward` is 0, so nothing forwards yet. Warns. |
| `open`    | forwarding is live and the drop can't be read. **Refuses to start.** |

`capsule-host` keeps checking for the life of the session, because forwarding is
global state it doesn't own — start docker or tailscale mid-session and the
watch tears the proxy down with it. Same if the tap's address disappears. The guest loses egress rather than keeping it past a control that
has gone.

`latent` is the honest verdict for a host with no sudo rule: unverifiable is
not the same as absent, and it is only safe while nothing forwards.
`/run/current-system/sw/bin/nft` rather than a store path because this flake and
the host config have separate nixpkgs pins and sudo matches the command string
literally.

**Interface-scoped ports, not `trustedInterfaces`.** That option accepts
*everything* arriving on the tap, which puts every `0.0.0.0`-bound host service
inside the jail's reach — sshd, whatever's on 8080, the lot. Plain
`allowedTCPPorts` is the opposite mistake: it opens the proxy and the git
daemon on the LAN and the tailnet.

**The forward drop is what makes "no default route" true rather than merely
configured.** The guest has no gateway, but a guest that gets root can add one,
and then the only thing between it and your LAN is whether the host forwards.
`net.ipv4.ip_forward` is global and both docker and tailscale turn it on for
their own reasons, so this cannot be left to inspection — hence the check
above, which refuses to bring the link or the services up in that state. Its own
table rather than `networking.firewall.filterForward`, which switches the
*whole host's* forward policy to drop and would take those same daemons out;
`drop` is terminal in any chain, so a separate table needs no cooperation from
the firewall's.

IPv6 on the tap is handled by `capsule-net` itself (disabled before the link
comes up) — a boot-time sysctl would fire before the interface exists.

The *allow* half of the firewall config is not verified, and doesn't need to be:
omit it and the guest reaches nothing, loudly. Only the silent-failure half
(the forward drop) is checked.

### The module path: a dedicated uid, and a namespace per capsule

`capsule-host` runs tinyproxy as **you** — a bug in its HTTP parser lands on an
account holding `~/.ssh`, `~/.claude` and every repo on the machine. The flake
exports a NixOS module that gives it its own system uid, namespace and cgroup
ceiling instead — and, since the same rebuild is what can create namespaces,
puts **each capsule in a network namespace of its own**:

```nix
imports = [inputs.microvm-spike.nixosModules.capsule-perimeter];
services.capsule-perimeter = {
  enable = true;
  owner = "david"; # runs the git channel; reads the egress log by group
};
microvm.host.enable = true; # the microvm@ template these units hang drop-ins on
```

The state root is not an option here: it is `mkFleet`'s `stateDir`, declared
beside `fleetPath`, so the front end, the programs and this module read one
root (`DEC-054`). A host that still sets `services.capsule-perimeter.stateDir`
fails eval with a message saying so.

The namespace is what makes more than one capsule possible, and it moves the
control this whole thing rests on *into this repo*: `net.ipv4.ip_forward` is
per-namespace, so the guest's confinement is a sysctl these units own rather
than a global one docker and tailscale also write. The host is now *required* to
forward and NAT — for the proxies' egress, with nothing about a guest resting on
it. The module sets that up itself, along with the resolver stub a namespaced
capsule needs (`DNSStubListenerExtra` on `10.101.0.1`, plus the firewall allow
for it); `services.resolved` must be on or it refuses to evaluate.

**The VM stays imperative.** Nothing here declares `microvm.vms.<name>`,
deliberately: that makes the host config evaluate the guest closure, and this
host's config is fetchable from darwin only because it does not. (That was
first a fetchability argument — the target input was a `git+file:` path on one
machine — and ISS-015 made the input a GitHub url, so what remains is that the
host config need not learn what a capsule contains.) So:

```
# the flake ref carries no fragment: `microvm` appends
# #nixosConfigurations.<name>.config.microvm.declaredRunner itself, and needs
# root for /var/lib/microvms and the gcroots.
sudo microvm -c capsule -f /home/david/dev/microvm-spike   # once
sudo systemctl start microvm@capsule                       # every time
sudo microvm -u capsule                                    # after a guest change
```

Those three, with their traps, are `just up <name>` / `just down <name>` /
`just refresh <name>` — `up` creates only if this host has never seen the
capsule and refuses while the devshell shape holds the tap, `down` shows what
the stop actually did, and `refresh` takes it cleanly down before rebuilding the
state directory. The commands above are what they run.

**Only the create needs this checkout.** `microvm -c <name>` resolves the
instance's name as a flake attribute, so it is the one part of a capsule's life
that cannot happen without the flake — which is why `just up` still exists.
Everything after it is `capsule <name> start | stop | ssh | admin |
forget-host-key | provision | inject | baseline | collect | refresh | adopt |
brief | setup`, installed on the
host by the module, so a
human logged in with no repo has the whole lifecycle. The recipes delegate to it
rather than keeping a second copy.

**`start` waits for the guest and injects.** A running VMM is not a capsule you
can work in: `$HOME` is on the volume, so credentials and secrets have to be
pushed in (the consumer's `setup.nix`, below). Every payload is write-if-absent, so a restart
keeps what the capsule has, and a payload with no source on this host is named
and skipped. If the guest does not answer ssh within a minute, `start` says so
and fails rather than reporting a start it did not finish.

**A second capsule is a name and a create, not a second image.** Declare it in
the consumer's `capsules.nix` (its own index; at most 11 characters), rebuild the host so its
namespace, proxy and relay units exist, then create and start it exactly as
above under its own name. The declared names are **slots** — `a` and `b` today
— and a slot's name carries no meaning on purpose: what a capsule is working on
is a record this repo does not keep yet (docs/contract-assignment.md). Its
declared `profile` must name a target in the consumer's `targets/`, since that is the image it
boots (`fleet.nix`). Every slot bound to one target is the *same*
`nixosConfigurations` value, so they share one runner store path and one image —
what differs is the namespace, the volume and the state directory. Every image's
hostname is `capsule`, so the shell prompt inside one does not say which slot you
are in.

```
sudo microvm -c b -f /home/david/dev/microvm-spike
capsule b start
capsule b setup main            # provision, inject, baseline
```

The cost of imperative is that the state directory is not derived from anything:
a guest closure edit reaches the VM when `microvm -u` rebuilds
`/var/lib/microvms/<name>/current`, and not before. A rebuild of the *host* moves
the units, not the guest.

**A missing or stale create fails as a dependency, not as itself.** Both
`microvm@<name>` and its tap unit carry microvm.nix's
`ConditionPathExists=/var/lib/microvms/%i/current/bin/tap-up`. With no create the
condition is unmet, so the tap unit is **skipped** — which systemd logs as
`finished successfully` — and the proxy's `BindsTo` on a unit that never became
active fails. All you are told is `A dependency job for microvm@capsule.service
failed`, naming neither the tap unit nor the absent directory. So read
`ls /var/lib/microvms/<name>/current/bin` first; `tap-up`, `tap-down`,
`microvm-run` and `microvm-shutdown` are the whole of what should be there.

Wired in on Sleipnir: `~/flakes/modules/nixos/capsule.nix`, imported from
`hosts/Sleipnir/config.nix`, with the input taking `inputs.target.follows =
"nixpkgs"` (that follows moves at the cutover to the consumer flake; it is
still there until then). Nothing in the host config evaluates the guest, so that shim spares
it a fetch; it was a fetchability requirement only while the target input was a
`git+file:` path on one machine (ISS-015).
That shim is exactly why the VM is created imperatively above: the VMM moves
under systemd without the host config ever learning what a capsule contains.

Starting the VM is all of it: the drop-ins pull the namespace in first, and the
VM wants its proxy and its ssh relay, so `just ssh` works as soon as the guest
is up. Opt-in, and `capsule-host` stays exactly as it was — it needs no root and
no rebuild, which is what makes it the development path. **Run one or the other,
never both:** they no longer fight over a port (the unit's is inside a
namespace), which is worse rather than better — two perimeters, two logs, and no
way to tell which one served a request. `capsule-host` refuses if a
`capsule-proxy-*` unit is active.

| | `capsule-host` | the units |
| --- | --- | --- |
| runs as | you | `capsule-proxy` |
| where the tap is | root namespace | `cap-<name>`, with the guest |
| the forward control | the host's global sysctl, read back through sudo | `ip_forward=0` inside each capsule's namespace |
| way in | `ssh 10.99.0.2` | `/run/capsule/<name>/ssh.sock` (`just ssh <name>`) |
| proxy log | `.vm/host/tinyproxy.log` | `/var/lib/capsule-proxy/<name>/tinyproxy.log`, rotated weekly |
| quarantine | `.vm/host/collect/` | `<stateDir>/collect/` |
| perimeter check | sudo read + supervised watch | `capsule-perimeter-guard.service`, root, no sudo rule needed |
| ceilings | none | `MemoryMax`, `CPUQuota`, `TasksMax`, `IOWeight` |

The units, per capsule and per host:

| unit | what |
| --- | --- |
| `capsule-egress-ns` | one per host: the aggregating namespace every capsule's proxy leaves through, and where the drops between them live |
| `capsule-netns-<name>` | the capsule's namespace, its `ip_forward=0`, its resolver, its uplink and its input drop |
| `capsule-proxy-<name>` | tinyproxy, joined to that namespace |
| `capsule-ssh-relay-<name>` | the unix socket that is the way in, owned by `owner` |
| `capsule-perimeter-guard` | one per host: verifies every namespace, every 10s, `BindsTo` from every proxy |

- The module installs `capsule-provision` and `capsule-collect` **wrapped** with
  the units' `CAPSULE_STATE` (and its profile, policy and allowlist
  directories) as defaults, because unwrapped they default to `$PWD/.vm/host` — the foreground path's — and would quarantine wherever you
  happened to be standing. The devshell's copies still shadow them inside this
  repo, so each path keeps its own state; both print the path they used, so read
  that line rather than assuming.
- **Which capsule** is an argument, not a build: `--capsule <name>` on any of the
  four, else `CAPSULE_NAME`, else a refusal. One store path serves every capsule,
  because the only thing that differs between two of them is a relay socket and
  that path is derived from the name. `export CAPSULE_NAME=a` for a session's
  worth of it. There is no default slot: the name says nothing about what is in
  the capsule, so a program acting on one nobody chose would have nothing to
  give the mistake away (NOTES item 28).
- **Which *target* is an argument too, and the same deal**: `--profile <name>`,
  else `CAPSULE_PROFILE`, else a refusal (NOTES item 51). The target's run-time
  values — where the checkout is, what the baseline and refresh commands are,
  which paths are its out-of-band state — are a rendered document
  (`nix build .#capsule-profiles` to read this host's), and a program loads one
  rather than carrying them. No default here either, and for a sharper reason: on
  a host confining two projects a fallback would run a verb against the wrong
  one's paths and report success having taken nothing. **`capsule <slot> <verb>`
  fills it in for you** from the slot's assignment record, so in practice you
  type it only when driving a program directly.
- **The guard is a start dependency (`BindsTo`)**, so no proxy can come up while
  a namespace is missing, forwarding, or missing a drop — and all of them stop
  when one does. It does not restart itself: a refusal stays a refusal until you
  fix the cause and start it again.
- **Stopping** is `systemctl stop microvm@<slot>`, and it is clean because the
  unit's `ExecStop` asks the guest to *reboot* over ssh first, with the host's
  stop key (above). The guest unmounts and resets; `reboot=k` turns that reset
  into a VMM exit, which is the one thing firecracker's i8042 stub does
  implement — `SendCtrlAltDel`, the only signal microvm.nix has on its own, is
  inert here because the guest's i8042 never attaches (NOTES item 11). Without a
  readable stop key a capsule **refuses to start**, since the only stop left
  would be a power cut. `Restart=no` is set so microvm.nix's default does not
  bring a deliberately stopped capsule straight back.
- `capsule-netns-<name>` **refuses to stop while a VMM is in its namespace**,
  because deleting the namespace takes the tap and a tap cannot be swapped under
  a running VM. Stop the VM first; that is also the ordering systemd uses.
- Adding this repo as an input to the host config means host rebuilds read its
  committed HEAD, same as the `git+file:` gotcha for doctrine.

`just units` prints the units the module would generate, without rebuilding a
host — the only mechanical check this half has.

## Quickstart

Three terminals, or three tmux windows:

```
capsule-net up            # once per boot; sudo. creates the tap, owned by you
capsule-host --policy build  # foreground: the egress proxy, under a named policy
vm capsule                # foreground: the VM, with its serial console on your tty
```

The guest boots with an **empty** `/work/doctrine`. Give it history from the
host, naming the base commit — any branch, tag or sha in the target repo:

```
capsule-provision --profile doctrine main
```

History is not everything a capsule needs. `$HOME` is on the volume, and
freshness deletes volumes, so a fresh capsule has no agent credentials either.
Push the declared payloads — the consumer's `setup.nix` says what they are, and nothing not
named there leaves this host:

```
capsule-inject             # all of them; add a payload name to pick one
```

It refuses to replace anything already there: a capsule's copy of a credential
drifts from this host's once the agent uses it. `capsule-inject PAYLOAD --force`
when you mean it — including after you change a secret on this host, which
otherwise does not reach a capsule that already has one.

**Secrets are a payload too.** `$HOME/.config/capsule/<name>.env`, or
`$HOME/.config/capsule/env` for every capsule, lands at `/work/.env` — which the
guest's login shell already sources. Neither file is a requirement: that payload
is declared `optional`, so a host with no source for it says which payload it
skipped and carries on. For 1Password, swap the entry's `produce` for `op inject`
(the line is written out in the consumer's `setup.nix`): `op` reaches a *host* socket, and
firecracker has no shares, so the environment is rendered here and pushed — it is
never fetched from inside.

A provisioned capsule still has empty caches, so the first build in it is the
slow one. Take it deliberately, and keep the number:

```
capsule-baseline --profile doctrine   # runs the profile's `baseline` to green, and records it
```

The run detaches in the guest and writes its log and one line of
`/work/baseline/history.tsv` **on the volume as it goes** — so Ctrl-C, a closed
terminal or a dropped link costs you the output, never the result. Run it again
while one is in flight and you re-attach to it. `--detach` to start one and
leave.

Then from a fourth terminal: `ssh agent@10.99.0.2`. Inside the guest you are
`agent`, in `/work/<target>`:

```
just test
just web-build
git commit -am 'work'      # locally; there is nothing to push to
```

Back on the host, collect it. That fetches the guest's branches into a
quarantine repo — `--no-tags`, fsck'd, under a packfile ceiling — and prints what
landed with its sha:

```
capsule-collect --profile doctrine --policy build   # -> .vm/host/collect/<name>.git
just branches              # what is in there
just fetch                 # second step: quarantine -> the repo you work in
```

A result has a second half, and it is not a commit: the target's gitignored
runtime state plus whatever the agent never committed. When the target declares
`statePaths`, the same collect brings that back too — one atomic fetch, so nobody
sees a result commit without the state that goes with it — and there are two ways
out of quarantine for it:

```
just adopt a /tmp/exhibit --list   # validate and report, writing nothing
just adopt a /tmp/exhibit          # lay it out here, for a human to read
just brief b a                     # or into capsule b, for a second agent
```

`adopt` and `brief` both refuse a tree that would not stay inside where it is
going, and `brief` additionally refuses unless both capsules are at the commit
that state was the state of
([items 32](docs/ledger/032-the-sideband-channel.md),
[34](docs/ledger/034-adopting-a-guest-authored-tree.md),
[35](docs/ledger/035-briefing-a-capsule-with-state.md)).

## Commands

| command             | what                                                       |
| ------------------- | ---------------------------------------------------------- |
| `capsule-net up`    | create the tap + assign `10.99.0.1/30`. Needs sudo.         |
| `capsule-net down`  | remove it. Refuses while a VM runs; `--force` overrides.    |
| `capsule-net verify`| report the perimeter's state without touching the link.      |
| `capsule-host --policy NAME` | tinyproxy + the perimeter watch, serving that policy's allowlist. Foreground, unprivileged. Refuses without a policy. |
| `capsule-provision REF` | push `REF` from the profile's repo onto the guest's branch. |
| `capsule-collect`   | fetch the guest's refs into a quarantine repo named for it.  |
| `capsule-inject [PAYLOAD...] [--force]` | push the payloads declared in the consumer's `setup.nix` (its `access.injections`) — credentials into `/work/home`, secrets to `/work/.env`. `capsule <name> start` runs it. |
| `capsule-baseline [--detach]` | run the profile's `baseline` in the guest to green; record it on the volume. |
| `capsule-refresh`   | run the profile's `refresh` in the guest's checkout — the step a provision takes itself, on its own. |
| `capsule-adopt DIR` \| `--list` | validate the collected state half and lay it out in `DIR`, which must be empty or absent. |
| `capsule-brief SRC[:STAGE]` | put capsule `SRC`'s collected state into this capsule's checkout. Both must be at the same commit. |

Every row above except `capsule-net`, `capsule-host`, `capsule-inject` and
`capsule-adopt` also takes `--capsule NAME` and `--profile NAME`, and refuses
without either; `capsule <slot> <verb>` supplies both.

Every host builds the last three. A target that declares no `refresh` or no
`statePaths` gets a refusal naming what is missing, not a program that half-works.

Each of them takes `--capsule <name>`, or `CAPSULE_NAME`, to say which capsule it
means — and refuse without one, since a slot's name gives nothing away. On the
devshell path there is only one guest, and an undeclared name is refused rather
than quietly served. `capsule <name> <verb>` is the
front end that supplies the flag and picks the copy of each that can reach the
capsule named — the programs refuse rather than guess, so choosing is a front
end's job.

| command             | what                                                       |
| ------------------- | ---------------------------------------------------------- |
| `capsule [name] <verb>` | resolve a capsule — named, or `CAPSULE_NAME`, or whichever one is up — and run a verb at it: `start`, `stop`, `created`, `status`, `branches`, `fetch`, `ssh`, `admin`, `forget-host-key`, `setup`, or any of the four above. It exits 2 when it cannot tell what was asked, so `created` answers only 0 or 1. |
| `capsule all <verb>`| the same, over every declared capsule. Questions only — `status`, `branches`, `fetch`. |
| `vm <name>`         | run a VM: `capsule` is the guest image, `hello` the smoke test, and a slot name is the same image under that slot's state directory. Devshell shape. |
| `vm-stop <name>`    | ask that guest to reboot, then account for the VMM. Devshell shape. |
| `just ssh [name]`   | `capsule <name> ssh`, from the checkout — over the relay socket if the capsule has one. |
| `just units`        | the units the host module generates, without rebuilding a host. |
| `sudo probe-netns`  | evidence: is a netns per capsule sound? No VM, seconds.      |
| `sudo probe-netns-boot` | evidence: does the capsule boot with its tap in one?     |
| `sudo probe-netns-egress` | evidence: does the perimeter survive the move into one? |
| `sudo probe-freshness [REF]` | evidence: what a fresh capsule costs, and which axes hold. |
| `sudo probe-two-capsules [REF_A] [REF_B]` | evidence: two at once — independent, and at what price. |

Nothing in the guest: it initiates neither direction, and has no remote.

The probes are answers kept runnable, not tools — see [docs/probes.md](./docs/probes.md).
`probe-netns-boot` boots the real capsule inside a namespace and shuts it down
again, so it refuses to start beside `capsule-net up` or a running VM; run it
from the repo, since `$PWD/.vm` is where the VM's state lives.

Those are the lifecycle; `just` has the gate, the create, and everything that
needs more than one command to answer — the run-time verbs are `capsule`'s and the
recipes delegate. `just check` is the gate (every nix file
parses and is alejandra-clean — no eval, so it can't trigger a VM build).
`just status` is `capsule all status` — a row per capsule (created, VM / proxy /
relay unit state, door, whether the guest answers, refs collected) — plus the
devshell shape's own tap and listener, which are the only parts of a perimeter
this namespace can read directly. What is inside a capsule's namespace is
`capsule-perimeter-guard`'s to verify, and the table names it rather than
guessing: `ip netns exec` needs root, and a status that needs root is a status
nobody runs. Then `just verify`, `just fetch`, `just branches`,
`just proxy-log [name]`, `just allowed`, `just ssh`, `just admin`.
`just --list` for the rest. Addresses come from the consumer's `net` and target paths from
the target's file in its `targets/`, never a literal.

## Rooms

A room is a shared guest that is not a capsule: no assignment, and no uplink,
proxy or route out (`DEC-036`; [Plan E](docs/plan-e-room.md),
[Plan F](docs/plan-f-assistant.md)). It is declared in `mkFleet`'s `rooms`
argument (`rooms = {}` for none) with its sizes and its users, each user
`{ uid; keys; }`. The uid is declared, in 1000-29999, so adding an earlier name
never re-owns `/home` (`RSK-012`). The module owns no toolchain or agent names
(`POL-002`); a room's contents are the caller's values.

A room may also hold targets as repos: `repos = { user; targets = [...]; }`,
a `policy` and `sizes.work`, all three or none (`DEC-048`). Each repo is a
clone at its target's `guestPath` on a `/work` volume, owned by `repos.user`;
in the room, `session <repo> -- <cmd>` runs a command there with that target's
tool set (the template's `flake.nix` comments the fields).

Every room has a base, `git bash coreutils-full which` plus the `extras` it
declares (names from `fragments.nix`'s vocabulary, `extras = [...]`, optional on
any room). It is on a login's `PATH`, and `session` puts it behind a repo's tool
set and ahead of the caller's `PATH` (`DEC-052`).

`extras` may also select a capability fragment, `postgresql-18` today; see
[PostgreSQL in a room](#postgresql-in-a-room).

```
capsule <room> ssh [user] [-- cmd]
capsule <room> start
capsule <room> stop
capsule <room> push <repo> <branch>      # the target's checkout -> refs/host/<branch>; prints the oid
capsule <room> collect <repo> <branch>   # -> <state>/collect/<room>/<repo>.git; prints <oid>\t<ref>
capsule <room> forget-host-key
```

A room is created once, as a slot is, before anything can start it:
`sudo microvm -c <room> -f git+file:///srv/fleet` (the consumer's path). Until
then its units fail as a *dependency*, naming neither the room nor the create.

A room is named on argv and never resolved implicitly. Every other verb
refuses it: `capsule: '<room>' is a room; rooms take ssh, start, stop, push,
collect, forget-host-key (status lists them)`. A room with no repos refuses
`push` and `collect`: `room '<room>' declares no repos, so it has nothing to
push or collect.` `ssh` with no user named on a room that declares several refuses
and asks for one; on a room that is not up it says
`capsule: no socket at <path>, so room '<room>' is not up.`. A stop is a
reboot through the stop key, so it cuts in-flight work.

`capsule status` ends with a `rooms:` block (`room`, `vm`, `socket` columns)
whenever the host declares any. A running room makes a probe refuse (`DEC-031`).

The door is a per-room unix socket, `/run/capsule-room/<room>/ssh.sock`, mode
`0600`, owned by the module's owner and present only while the room's tap is.
A client runs as that owner and reaches the guest by `ProxyCommand` as a
declared user (`DEC-037`).

Every door to a room — `ssh`, `push`, `collect` — checks one `known_hosts` of
the room's own, `<state>/room/<room>/known_hosts` (`<state>` is `CAPSULE_STATE`,
else `mkFleet`'s `stateDir`), as `HostKeyAlias=room-<room>` with accept-new: the
first contact learns the key, a changed one is refused (`DEC-047`). After the room's volume
is deleted, `capsule <room> forget-host-key` empties that file
(`capsule <room>: forgot the room's host key (<file>).`).

`push` and `collect` exit 2 for a caller error, decided before the room is
asked anything; **75 when the room is not answering** (no socket, or no ssh
banner through it), which a script can treat as "start it"; and 1 for anything
after the banner, a host-key or authentication failure included (`DEC-050`).

A client that is not oubliette's own door gets the same door as a bundle,
`packages.<system>.room-client-<r>` (one per declared room): `etc/ssh_config`
(`Host *`, strict checking, no user, no identity) and `bin/ssh`, with the
mounts a jail needs as the `binds` attribute. It checks the room's key and never
writes it, so it refuses until a `push`, `ssh` or `collect` has learned it, and
it runs as the module's owner. [docs/contract-room-client.md](docs/contract-room-client.md)
is the contract (`DEC-056`, `DEC-057`).

## PostgreSQL in a room

`extras = ["postgresql-18"]` on a room (optionally beside `search`) runs
PostgreSQL 18 in that room (`SL-009`; `DEC-059`, `DEC-060`, `DEC-062`). It is
the one capability fragment: a guest module plus a path that must survive,
which a room persists on its `/home` and a slot refuses
([contract-flavour.md](docs/contract-flavour.md)). A room that selects nothing
is unchanged, as `lounge`; a slot whose `flavour.extras` names it fails to
build (`slotRefusal`). The server listens on its unix socket only
(`listen_addresses = ""`, no TCP) and no password exists.

**Each login's own database.** Every normal user the room declares gets a role
and a database of its own name, owns that database, and has neither `CREATEDB`
nor `SUPERUSER`. `psql` with no arguments, as that login, connects over the
socket by peer authentication. The access rules are exactly two, first match
wins, and they replace NixOS's default `local all all peer`, which would
otherwise remain as the fallback:

```
local all      postgres peer map=postgres
local samerole all      peer
```

`samerole` admits a login only to a database named for a role it is a member of
(every role is a member of itself), so `psql -U eve -d agent` is refused.

**Reserved names.** A login named `pg_*`, `shared_*`, `postgres`, `public`,
`none`, `current_user`, `current_role`, `session_user`, `template0` or
`template1` fails the room's image at eval, naming them (`fragments.nix
postgresql-18: a login is a reserved role name: …`), and only for a room that
selects the fragment.

**Who can be the superuser.** Guest root, reached by the host's admin keys
(`access.adminKeys`) and by the host's stop key (the root credential the
`microvm@` units use to ask the guest to reboot, `vm/door.nix`; unrestricted,
so a full root login), with `prohibit-password` and no password login, is the
superuser by peer through the `postgres` system user:

```
capsule <room> ssh root          # a host admin key (access.adminKeys) or the stop key
runuser -u postgres -- psql
```

No room user can become `postgres`: a room has no sudo (`security.sudo` is off,
`DEC-060`), the door's elevation rules refuse sudo-rs and doas (`roomChecks`),
and `postgres` has no keys. A room whose `adminKeys` is empty has the host's stop
key as its only root credential.

**A shared database** is the operator's act, by convention, run inside that
`psql`:

```
CREATE ROLE shared_proj NOLOGIN;
CREATE DATABASE shared_proj OWNER shared_proj;
GRANT shared_proj TO agent, eve;   -- members may open it; others may not
```

A shared role is named `shared_<x>`, and no login may be: a user declared later
then never meets an existing `NOLOGIN` role of its own name, which NixOS would
skip creating and leave unable to log in. A shared role named outside the
convention is the operator's to rename before a colliding user is declared.
Nothing declares it; it lives in the cluster, on `/home`.

**From the host.** Forward the socket with an `ssh -L` over the room's door, using
the room-client bundle's `ssh` ([contract-room-client.md](docs/contract-room-client.md), which
refuses until a `push`, `ssh` or `collect` has learned the room's key):

```
b=$(nix build --print-out-paths .#room-client-<room>)
"$b/bin/ssh" -F "$b/etc/ssh_config" -N \
  -L 5432:/run/postgresql/.s.PGSQL.5432 <user>@room-<room>
```

(or a local socket path in place of `5432`). `capsule <room> ssh` takes no ssh
options: its first argument is the user and everything after is the remote
command, so there is no `-L` through it. Peer authentication makes a forwarded
connection the logged-in ssh user, which is how it is meant to work; the live
check is `ASM-006`'s, not yet made. The door's sshd is NixOS-default and
permits stream-local forwarding, and the forward adds nothing to the perimeter.

**Readiness is `postgresql.target`.** `postgresql.service` is only the server;
roles and databases are made by `postgresql-setup` after it, and
`postgresql.target` requires both. As root over the door,
`systemctl is-active postgresql.target` asks. No `capsule` verb waits or
reports.

**Reset, backup and the major version** are the operator's; there is no verb.
Reset is `dropdb` and re-create as `postgres` (`runuser -u postgres`), or, with
the room stopped, on the host, deleting `.fragments/postgresql-18` from the
room's `room-home.img`. Backup is
`pg_dump`, over the forward or as `postgres` in the guest. The major is in the
fragment's name and NixOS's data directory is
`/var/lib/postgresql/<psqlSchema>` under the persisted path, so a future
`postgresql-19` fragment (none exists; `fragments.nix` refuses unknown names)
would start an empty cluster beside the old one; carry the data with
`pg_upgrade`, or `pg_dump` and restore. A new image reaches a room only once
its runner is moved: after a switch `current` still names the old one, and
`microvm -u <room>` (what `just refresh-build <room>` runs) moves it, then
`capsule <room> start`.

**The data shares `/home`.** The cluster is a bind onto `/var/lib/postgresql`
from `/home/.fragments/postgresql-18/var/lib/postgresql` on the room's `/home`
volume, made first by `room-persist` (`DEC-061`). `/home/.fragments` is root's
`0700`, outside every home, so a login reaches the cluster only through the
socket and only its own database. Stop and start, an image rebuild and a host
switch keep it; deleting `room-home.img` loses it with the homes. The database
shares `/home`'s size (`sizes.volume`), so a full `/home` stops both a login's
writes and postgres, and the image grows by postgres' closure. A dedicated
volume per fragment is `DEC-068`, not built.

**Not proven.** `fragmentsCases` pins the rules, the image and the module's
settings. No room has been booted with it: that the bind is ordered after
`/home` at boot (`ASM-005`) and that a forward reaches peer auth as the login
(`ASM-006`) are the live rung's (`STD-001`).

## Moving one capsule's work to another slot

Run once, c→d, 2026-08-16 — every step is a built verb, none of it is
hand-rolled. Source slot `S`, destination `D`, unit `U`:

1. **Read `git status` in `S`.** Anything uncommitted **under `statePaths`**
   travels (`git add -f` stages worktree content into the state half); anything
   uncommitted **outside** them does not, and untracked-and-not-ignored is the
   case that bites. Commit those in `S` first so they ride the code half.
2. `capsule S collect` — both halves, one atomic fetch, scoped to `S`'s recorded
   unit. **Needs `S` up.** Nothing committed after this point travels.
3. `capsule S fetch` — quarantine → `~/dev/<target>`, landing
   `refs/capsule/S/heads/work` and `refs/capsule/S/state/<stage>`. Namespaced, so
   no branch of yours moves. Works whether `S` is up or stopped.
4. `capsule D provision refs/capsule/S/heads/work --state S` — **one command, and
   the `--state` is the whole point.** Not `setup` then `brief`: a brief taken
   after a provision refuses on any target whose refresh writes tracked files
   (NOTES item 47), and there is no way to sequence around it.
   `capsule-provision` resolves the ref with `rev-parse --verify "$ref^{commit}"`,
   so a full refname is fine.
5. `capsule D unit U`, `capsule D purpose …`, `capsule D inject`,
   `capsule D baseline`. The record is front-end written, so the unit has to be
   set for `D`'s own future collect; `--state S` is scoped by `S`'s exhibit and
   does not read it.
6. `capsule S stop` when you are ready, **and not before you have taken anything
   you want out of its `$HOME`**.

**`$HOME` does not travel.** `/work/home` is on each slot's own volume and
firecracker cannot share a filesystem, so `~/.claude` (session history),
`.claude.json`, `.pi` and any hand-done setup are `S`'s alone. Whatever
the consumer's `setup.nix` declares comes back via `capsule D inject`; anything typed by hand is
retyped. That is what decides when the cut is cheap, and nothing else.

**A provision does not have to go through `~/dev/<target>`** — `src` is
`"${CAPSULE_REPO:-$profile_path}"` (`host/git-channel.nix`) and a quarantine is a
real bare repo. This section used to call the module wrapper's unconditional
`CAPSULE_REPO` export a control. It stopped being one at `ISS-004`, which made
every export a default a caller could override, and SL-001 removed it
(`ISS-008`). Source is chosen by whoever writes the profile document's `path`,
or by a caller who sets `CAPSULE_REPO`, and that caller is the human the program
already runs as. Step 3 is one cheap command, not a requirement.

## Process lifecycle

`vm` is **not** a daemon: it's firecracker in the foreground with the guest's
serial console on your terminal. Closing the terminal SIGHUPs it, which works
but is a power-cut — the guest gets no shutdown and the volume replays its ext4
journal next boot. Prefer `poweroff` at the console, or `vm-stop` from
elsewhere. `pgrep -af 'microvm@'` is the entire inventory; nothing is
registered anywhere.

**A guest that has shut down may leave the VM running.** Firecracker doesn't
exit on guest poweroff — it halts the vCPU and keeps holding the tap, so the
next `vm capsule` fails with `Device or resource busy`. `vm-stop` handles this
(poweroff, wait, then terminate the VMM); `pgrep -af 'microvm@'` is the check.

**A tap cannot be swapped under a running VM.** `capsule-net down` while the VM
runs destroys the netdev while firecracker keeps the fd; recreating the tap
attaches to nothing and the guest goes silent (`No route to host`). Only a VM
restart recovers it, which is why `down` refuses by default.

## Network

Point-to-point tap, host `10.99.0.1/30` ↔ guest `10.99.0.2/30`. No bridge, no
NAT, **no default route in the guest**, no resolver in the guest. Everything
outbound goes through the host's proxy, which resolves names itself — so an
unlisted host cannot be reached or even resolved.

To let something new out, edit the file the policy names — for `build` that is
the consumer's allowlist in its `policies.dir` (`perimeter/egress-allow.txt` in the
template; extended regex, one hostname per line) — and
restart the proxy. No rebuild: an allowlist is deliberately a plain file, and
what a policy declares is *which* file.

To move a slot to a different policy, `capsule <name> policy <name>` on the
module path. It selects from the set that slot declares in the consumer's `capsules.nix`,
writes the record, re-points that slot's allowlist link and restarts its proxy —
so egress drops for the length of a restart, which is what a tightening costs.
The vocabulary is the consumer's `policies.nix`; a project never names its own perimeter
([NOTES item 36](./docs/ledger/036-a-policy-is-selected-not-named.md)).

`ssh` runs the other way — host to guest — and widens nothing.

## Changing the guest's tools

The tool set comes from the target's own flake — its `toolsPackage` in
the target's file in the consumer's `targets/` (for doctrine, `packages.dev-tools`) — so both this VM and that devshell take from
one list. To change it:

```
cd ~/dev/doctrine          # edit devToolPkgs in flake.nix
git commit && git push     # the input is github:…/edge, so it reads what is pushed
cd ~/dev/oubliette && nix flake update target && git commit flake.lock
just refresh-build <slot>  # per slot; module path
```

**The last line is the one that is easy to skip, and skipping it is silent.**
`nix flake update target` moves the lock; a created VM tracks its state
directory and not the flake, so until `microvm -u` has run for a slot that slot
keeps the tool set it was built with, and the pin reads perfectly current while
it does. `just refresh-build <slot>` is the stop, `microvm -u` and restart in
one. On the devshell path it is `vm-stop <name> && vm <name>` instead, which
rebuilds the image as part of starting it.

Tools the target's list omits because it assumes a host that has them go in
that target's `extraTools`, not here.

## Pointing it at a different repo

A target is a file in a consumer flake's `targets/`, paired with its tool-set
flake in the `targets` argument to `lib.mkFleet` (`<name> = {decl; flake;}`);
its key there is its name. Oubliette itself declares only `fixture/`, which is
nobody's. The file holds everything target-shaped: path, tools
package, cache directories, the out-of-band state paths, the guest's sizes and
the build config rendered from them. `targets/default.nix` derives the rest from
the name — the guest's checkout path and the absolute cache paths — so the motd
and the host side follow. Only the consumer's `flake.nix` imports `targets/`; everything else is
handed the set or one named member of it.

What is *not* in there is the perimeter. The egress allowlist and the collect
ceiling are host **policy**, declared in the consumer's `policies.nix` and selected per slot,
because a control chosen by whoever names the project is a control the naming
authority holds ([NOTES item 36](./docs/ledger/036-a-policy-is-selected-not-named.md),
[item 25](./docs/ledger/025-assignment-is-a-perimeter-verb.md)).

What does *not* move with the target is the consumer's `setup.nix` — which agent you sign in
as is a property of you, not of the repo under confinement, so a second target
takes that list unchanged.

One duplication is unavoidable: an input's url must be a literal, so the
target's input in the consumer's `flake.nix` (for doctrine, its `doctrine`
input, paired in `targets.<name>.flake`) has to name the same repo as `path`
in the target's file, and nix will not check that for you. For a one-off, override it
instead: `--override-input doctrine path:/home/you/dev/other`, in the consumer. Keep the url one
that anybody can fetch — the lock is committed, so a local path there makes the
flake unbuildable on every other machine (ISS-015) — and keep overrides on
builds: `nix flake lock --override-input` writes the override into the lock.

A second target usually wants a policy of its own — half of any allowlist is
that project's dependency hosts — so add one to the consumer's `policies.nix` and put its name
in the declared set of the slots that may take it. It is still host-side: an
allowlist read out of the repo being worked on is an allowlist the agent can
widen. NOTES item 16 has the reasoning, and why *concurrent* capsules is a much
bigger job than a different one.

The field-by-field contract — what is required, what has a working absent path,
what the capsule supplies back, and the porting order — is
[docs/contract-target.md](./docs/contract-target.md).

## Troubleshooting

| symptom                                        | cause                                                     |
| ---------------------------------------------- | --------------------------------------------------------- |
| `Cannot assign requested address` on start     | tap missing — `capsule-net up`                             |
| firecracker `TapOpen … Operation not permitted` | also tap missing: an absent name makes `TUNSETIFF` *create* one, which the unprivileged VMM may not do. Tap present and still EPERM ⇒ wrong owner (`cat /sys/class/net/vm-capsule/owner` should be your uid) |
| firecracker `Device or resource busy`          | tap exists and is already attached — a VMM outlived its guest; `pgrep -af 'microvm@'`, then `vm-stop` |
| `Address already in use` on start              | orphaned daemon from an earlier run; `capsule-host` names the pid |
| `No route to host` to `10.99.0.2`              | tap was recreated under a running VM, or the VM is down    |
| `refusing — net.ipv4.ip_forward is on`         | the `capsule-forward` table isn't loaded (or isn't readable) while something forwards — see "Host requirements" |
| egress dies mid-session, `Tearing down egress` | same, but it happened after start: docker/tailscale flipped forwarding |
| `FORWARD drop ... cannot be verified`          | the sudo read rule is missing; safe only while `ip_forward` is 0 |
| guest reaches nothing, host is up              | host firewall dropping the tap — see "Host requirements"    |
| a hostname 403s through the proxy              | not in the file the running policy names (`capsule <name> policy` says which); `.vm/host/tinyproxy.log` names the host |
| a download hangs mid-way, no error, no log line | proxy at `MaxClients` — `ss -lnt 'sport = :3128'` shows a non-zero `Recv-Q` (connections queued, never accepted). Cap the client (`bun install --network-concurrency 8`) or raise `MaxClients` in `perimeter/default.nix` |
| the proxy log looks stale while egress works   | the unit path is serving, not `capsule-host` — its log is `/var/lib/capsule-proxy/tinyproxy.log`. `just proxy-log` picks the right one |
| a TUI (claude, etc.) renders but ignores Enter | was the serial console's own quirk; loading `i8042`/`atkbd` in the guest fixed it (NOTES item 11) — if it returns, run TUIs over ssh |
| `modprobe` fails in the guest                  | `security.lockKernelModules` — deliberate; NOTES has the trade |

State lives in `.vm/` (volume images, sockets, proxy logs, quarantine repos) and
is gitignored. Deleting `.vm/capsule/capsule-work.img` resets the guest's
workspace — **including any commits not yet collected**. Deleting
`.vm/host/collect/` discards the collected exhibits, so fetch anything worth
keeping into the real repo first.

**Never loop-mount `capsule-work.img`.** It is guest-written ext4, and `mount`
feeds its metadata to the host kernel. Read it with `fuse2fs`/`debugfs`, or
just ask the guest over ssh. (docs/design.md has the reasoning.)
