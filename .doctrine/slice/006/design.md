<!-- doctrine:section sec-1 -->
## Shape

A room that declares repos holds one clone per repo on a second volume, runs
commands with one repo's tools at a time, and exchanges git with the host only
through one generic program the front end resolves for it. Nothing in this
slice teaches a slot program that a room exists, and nothing generic learns
which repo it holds (`POL-002`).

```
consumer (mkFleet)                     oubliette
rooms.assistant = {                    rooms.nix: resolve targets, policy, user
  users.agent = { uid; keys; };   ──▶  (refusals are reasons, DEC-048)
  repos = { user = "agent";              │
            targets = [a b]; };          ├─▶ vm/room.nix: room-work.img at /work,
  policy = "build";                      │     room-seed per repo, session,
  sizes = { …; work = …; };              │     /etc/room/tools/<repo>  (DEC-043/044/049)
}                                        └─▶ host/cli.nix: capsule <room> push|collect
                                               │  resolves repo ∈ room.repos (DEC-051)
                                               ▼
                         capsule-room-git --room <r> --profile <repo> (DEC-045)
                           pre-flight: socket + SSH banner, else exit 75 (DEC-050)
                           ssh as repos.user, known_hosts per room, alias room-<r> (DEC-047)
            push ──▶ +<oid>:refs/host/<branch> in /work/<repo>   (worktree untouched)
         collect ◀── +refs/heads/<branch> → collect/<r>/<repo>.git
                       refs/capsule/<r>/heads/<branch>, fsck, ulimit (DEC-046)

satan runner: pi-env daemon started as `session <repo> -- <daemon> serve …`
```

Clone paths are each target's `guestPath`, so DEC-040's layout stands as
written and `ISS-021` closes by adding a volume.

<!-- doctrine:section sec-10 -->
## Risks and what is out of scope

- **SL-005 is open.** PHASE-10 edits `rooms.nix` and `vm/room.nix`; this slice
  starts after it lands. The live rung needs SL-005 PHASE-09's door proven.
- **`DEC-044` is provisional.** If a repo's work needs an extra in the room, the
  set's composition is revisited — a successor decision, not a flag.
- **Closure.** N tool sets in one image may be large (`EVD-007` priced one at
  about 0.5 GB); measured, not assumed. A tool change is a rebuild and a reboot.
- **Accept-new is trust on first use.** Sound only because the path is a
  host-created socket into a VM this host booted; stated in `DEC-047`.
- **`RSK-006` carries over.** The ulimit bounds one packfile, not the transfer.
- **Disk.** A sparse `/work` per room adds to `RSK-007`.
- **Clone residue.** Untracked files accumulate in a long-lived clone; job
  hygiene (`git switch`, a clean check) is the runner's.
- Out of scope: the model door (`IDE-003`), a land verb, a room reset or
  delete verb, a build-time proxy for a room, narrowing `any_vm_running`, the
  runner itself, any `~/flakes` change.

<!-- doctrine:section sec-11 -->
## Code impact

| path | change |
| --- | --- |
| `rooms.nix` | `targets`, `policies` arguments; `repos`/`policy`/`sizes.work`; reasons; record fields |
| `rooms-cases.nix` | new verdicts |
| `mkfleet.nix` | bind the new arguments; `roomVms` passes target flakes; `roomChecks` rules; wire `roomGitCases`, `sessionCases`; install `capsule-room-git` |
| `vm/room.nix` | `/work` volume, seed per repo, git, tool links, `session` |
| `vm/session.nix` (new), `vm/session-cases.nix` (new) | the launcher and its suite |
| `host/room-git.nix` (new), `host/room-git-cases.nix` (new) | the program and its suite |
| `host/quarantine.nix` | the bounded fetch fragment |
| `host/git-channel.nix` | uses the policy and fetch fragments instead of inline copies |
| `host/guest-ssh.nix` | one ProxyCommand helper |
| `host/programs.nix` | builds `capsule-room-git` beside the channel |
| `host/cli.nix` | room verbs, the room's known_hosts and alias, `forget-host-key` |
| `host/room-verbs-cases.nix` | new verb cases |
| `host/services.nix` | `room/<r>` tmpfiles; `capsule-room-git` installed |
| `fixture/default.nix`, `fixture/stub-flake.nix` | second target, its package, the assistant's repos |
| `templates/fleet/flake.nix` | the commented example |
| `just/fleet.just`, `CLAUDE.md` | the new suites |
| `docs/contract-assignment.md`, `docs/contract-target.md`, `docs/plan-f-assistant.md` | sec-9 |

<!-- doctrine:section sec-2 -->
## The declaration and `rooms.nix` (`DEC-048`, `DEC-046`)

A room may carry three more fields, **all present or all absent**:

| field | shape | meaning |
| --- | --- | --- |
| `repos` | `{ user; targets = [<target name>]; }` | the clones it holds and the declared user who owns them |
| `policy` | a name in `policies.everything` | bounds and permits room collects; its allowlist is inert (no uplink) |
| `sizes.work` | MiB | the `/work` volume |

`rooms.nix` gains the `targets` and `policies` arguments at its one binding site
(`mkfleet.nix`, where both are in scope) and new pinned `reasons`, each a
refusal at eval in the existing `"rooms.nix: <rule> (DEC-0NN); <clauses>"` form:

- a partial set (some of `repos`, `policy`, `sizes.work` without the others);
- a target not in `targets`; an empty `targets`; a target named twice;
- `repos.user` not among the room's declared users (and so without a declared
  uid — `RSK-012`'s rule carries over without a second check);
- a policy not in `policies.everything`.

The record gains `repos` (resolved: per target `{ name; guestPath; }`) and
`policy`, or `null` for both. Rooms without repos are unchanged, so Plan E's
lounge and every existing consumer keep working (`POL-002`'s absent path).

`POL-003`'s rooms row gains `repos`, `policy` and `sizes.work` by a revision
(REV), on top of the PHASE-10 wording; `DEC-033`'s shape is extended, not
replaced (`DEC-048` references it).

<!-- doctrine:section sec-3 -->
## The guest: `/work`, the seed, tools and `session` (`DEC-043`, `DEC-044`, `DEC-049`)

`vm/room.nix` takes the resolved record and the targets' flakes (`roomVms` in
`mkfleet.nix` passes `targetFlakes`, as `fleet.nix` does for slots). When the
record has repos:

- **Volume.** `room-work.img` at `/work`, sized `sizes.work`, beside
  `room-home.img`. `roomChecks` gains the rule; a room without repos is asserted
  to have no `/work` volume.
- **Seed.** `room-seed` (already ordered before sshd) per repo: `install -d -o
  <user> -g users -m 0700 <guestPath>`, then, as the user, `git init
  --initial-branch=<workBranch> <guestPath>` when `<guestPath>/.git` is absent.
  Never anything else: the clone is the agent's from then on.
- **Base tools.** `git` in `environment.systemPackages`. With NixOS's required
  packages that gives pi-env `sh`, `uname`, coreutils (`sha256sum`, `mktemp`),
  `which` and `bash` on the base `PATH`.
- **Tool sets.** For a target whose `toolsPackage` is not null, its package is
  linked at `/etc/room/tools/<repo>` and kept out of `systemPackages`, so two
  repos' toolchains never meet on one `PATH`. No fleet extras (`DEC-044`,
  provisional).
- **`session`.** A `writeShellApplication` generated from the record:

  ```
  session <repo> -- <argv…>
    unknown repo, or no "--"  → stderr, exit 2
    PATH=/etc/room/tools/<repo>/bin:$PATH   (only when the repo has a set)
    cd <guestPath>
    exec "$@"
  ```

  It prints nothing to stdout, sources no profile, and passes argv through
  untouched, so `session satan -- <daemon> serve --token X` is pi-env's daemon
  with satan's tools inherited by every command it runs. Its repo table is the
  record's values, rendered once per room image — the image is already per room
  (`DEC-032`).

<!-- doctrine:section sec-4 -->
## The channel: `capsule-room-git` (`DEC-045`, `DEC-050`, `DEC-046`)

One program, one store path, every room. It takes the room and the repo at run
time and learns nothing else:

```
capsule-room-git --room <r> --profile <repo> --policy <p> push    <branch>
capsule-room-git --room <r> --profile <repo> --policy <p> collect <branch>
```

`--profile` is the existing reader (`host/profile.nix` `select`), which yields
`profile_path` (the host checkout) and `profile_guest_path`. `--room` is
checked with `checkToken` and selects the socket
(`/run/capsule-room/<r>/ssh.sock`), the known_hosts file and the quarantine
key. No `--capsule`, no `CAPSULE_NAME`: a room is named on argv only, as
`DEC-041` already required.

**Shared, not copied.** Three fragments the slot channel already holds become
functions both programs call:

| fragment | today | becomes |
| --- | --- | --- |
| quarantine paths | `repoOf`, `codeRefsOf`, `checkToken` (`host/quarantine.nix`) | used as is: `repoOf "$room/$repo"`, `codeRefsOf "$room"` |
| policy lookup | inline `case` (`host/git-channel.nix` ~451-473) | a fragment yielding `maxBytes`/`may` |
| bounded fsck fetch | inline subshell (`host/git-channel.nix` ~603-611) | a fragment taking the URL and refspecs |

The ProxyCommand line, spelled today in `guest-ssh.nix` and in the front end's
`doorVia`, becomes one helper both use. The slot transport's
`StrictHostKeyChecking=no` stays for slots (NOTES item 18); the room's ssh argv
is strict with its own file (sec-5).

**Order of a run.**

1. Parse; refuse (exit 2) on usage, bad token, unknown policy, `may != yes`.
2. Pre-flight: the socket exists **and** an `SSH-2.0` banner arrives through
   it (`socat` with a timeout). Otherwise exit **75**.
3. **push**: `git rev-parse --verify <branch>^{commit}` in `profile_path`
   (refuse, exit 2, if absent); `git push ssh://<user>@<guest><guestPath>
   +<oid>:refs/host/<branch>`; print the oid. The worktree is never touched, so
   `updateInstead` and its residue (`ISS-009`) never arise.
4. **collect**: create `collect/<r>/<repo>.git` bare if absent; bounded fetch
   of `+refs/heads/<branch>:refs/capsule/<r>/heads/<branch>` with
   `transfer.fsckObjects`, `--no-tags`, `ulimit -f`; print the ref and its oid.
5. Any failure after the banner exits **1** — including authentication and a
   changed host key, which are trust failures, not downtime.

`repos.user` reaches the program as `--user`, filled by the front end; the
program does not read the declaration.

<!-- doctrine:section sec-5 -->
## Host keys and the front end (`DEC-047`, `DEC-051`)

**One store per room.** `$stateDir/room/<room>/known_hosts`, the directory made
by the module's tmpfiles (`0700 owner users`). Every door to a room uses it with
`StrictHostKeyChecking=accept-new` and `HostKeyAlias=room-<room>`: the front
end's `ssh`, both channel verbs, and satan's runner (its `known_hosts` setting
points here). First contact learns the key over a host-local socket into a VM
this host booted; a changed key is refused everywhere at once. `room-<room>`
cannot equal any slot's `capsule-<slot>`, which closes `RSK-011`.

**Verbs.** The room branch of `host/cli.nix` grows from three to six:

| verb | does |
| --- | --- |
| `ssh [user]`, `start`, `stop` | as `DEC-041`; `ssh` now uses the room's store and alias |
| `push <repo> <branch>` | refuse unless `repo ∈ repos.targets`; exec `capsule-room-git --room <r> --profile <repo> --user <repos.user> --policy <policy> push <branch>` |
| `collect <repo> <branch>` | the same, `collect` |
| `forget-host-key` | truncate the room's `known_hosts` |

A room without repos refuses `push` and `collect` by name ("declares no
repos"). Every other verb refuses as today. `status` is unchanged.

<!-- doctrine:section sec-6 -->
## The interface satan SL-023 builds against

Relayed to satan when the slice closes (the user's act, ADR-001 term 2); it
supersedes the slot recipe that `satan:ASM-005` stands in for.

| SL-023 piece | oubliette provides |
| --- | --- |
| door: ssh config | `ProxyCommand socat - UNIX-CONNECT:/run/capsule-room/<room>/ssh.sock`, user `repos.user` |
| door: `known_hosts` | `/var/lib/capsule/room/<room>/known_hosts`, `HostKeyAlias room-<room>` |
| per-repo `guest_path` | the target's `guestPath`, `/work/<target>` — not `/work/repos/<target>`. Checked in `preparing`, before the first command in that repo (`test -d <guest_path>/.git` through the env), where room-down is already handled — not at runner startup, when the room may be routinely stopped (`DEC-031`) |
| execution env | start pi-env's daemon as `session <repo> -- <daemon path>` through a custom `Connection` command built from pi-env's exported `detectPlatform`/`deployDaemon`/`sshArguments`; the repo comes from each job's `RepoConfig`; test a reconnect after a room stop |
| `GitChannel.refresh` | `capsule <room> push <repo> <branch>` → oid on stdout; then `git switch -c job/<id> <oid>` through the env |
| `GitChannel.collect` | `capsule <room> collect <repo> job/<id>` → `refs/capsule/<room>/heads/job/<id>` in `/var/lib/capsule/collect/<room>/<repo>.git` |
| `GitChannel.reachable` | exit 75 from either verb, or `capsule <room> ssh <user> true` |
| typed errors | 75 → `ChannelUnavailable`; 1 → `ChannelFailed`; 2 → a refusal (a bug in the caller) |
| clone state and hygiene | a fresh clone is `git init` on an unborn `workBranch`, no commits; `git switch -c job/<id> <oid>` works from there once `push` delivered the oid. `push` never touches the worktree, so residue is only what earlier jobs left: a clean-tree check before the switch is the runner's (`returnToWork` is slot-only) |
| promotion | Emacs fetches the quarantine ref; no oubliette program (`DEC-040`) |

<!-- doctrine:section sec-7 -->
## Fixture, template and the consumer

- **Fixture.** A second target whose stub flake exports a real (tiny) tool
  package, so two repos' sets are distinguishable in a built image. The fixture
  `assistant` declares `repos = { user = "agent"; targets = [fixture, <second>]; }`,
  `policy = "build"` and `sizes.work`. The lounge stays repo-less: it is the
  absent path's case.
- **Template.** `templates/fleet/flake.nix`'s commented assistant gains the
  three fields; `templateCases` still builds the uncommented template.
- **`/srv/fleet`.** No required change: rooms without repos are valid. Adding
  repos to the live assistant is the user's edit, at the live rung.

<!-- doctrine:section sec-8 -->
## Verification

Each suite is red first, in `just build`, and is mutated once to watch it fail
for the right reason.

| suite | pins | kind |
| --- | --- | --- |
| `roomsCases` (extended) | each new reason by its text; the partial set; the record's `repos`/`policy`; a repo-less room unchanged | library, `tryEval` + `deepSeq` |
| `roomGitCases` (new, `host/room-git-cases.nix`) | usage and token refusals → 2; unknown policy and `may != yes` → 2; no socket → **75**; push of a branch the host checkout lacks → 2; argv up to the door | program, shipped store path |
| `sessionCases` (new, `vm/session-cases.nix`) | unknown repo → 2; `PATH` gains the set only for a repo with one; cwd is `guestPath`; argv passes untouched; stdout empty | program, guest-shipped, fixture paths |
| `roomVerbsCases` (extended) | `push`/`collect`/`forget-host-key` resolve and refuse; a repo the room lacks → 2; a repo-less room refuses by name | front end over a fixture pool |
| `hostModuleUnits` | the room's state directory tmpfiles | evaluation |
| image gate | the fixture assistant builds with both tool sets and `/work`; `roomChecks`' new rules | build |

Not reachable by a case (ssh cannot be stubbed): the banner branch, an auth
or host-key failure → 1, an actual push and collect. Those are the **live
rung** (`STD-001`): the assistant on this host with two real repos; `push`;
a commit on `job/<id>` via `session`; `collect` lands in that repo's quarantine
and no other; a changed host key refuses everywhere; stop/start keeps clones,
uids and host keys. The image's closure size with N sets is measured and
recorded as an EVD (`ADR-003`, against `EVD-007`).

<!-- doctrine:section sec-9 -->
## Governance and docs footprint

| item | change |
| --- | --- |
| `POL-003` rooms row | REV: gains `repos`, `policy`, `sizes.work` (user's assent at that phase) |
| `DEC-041` | superseded by `DEC-051` (recorded) |
| `ISS-021`, `RSK-011` | closed by `DEC-043`, `DEC-047` |
| `IDE-002` | fulfilled except `IDE-003` (the model door) |
| `docs/contract-assignment.md` | the room row gains repos, policy, the work volume, the quarantine and the known_hosts store |
| `docs/contract-target.md` | a target may be a room's repo; its `guestPath` is that clone |
| `docs/plan-f-assistant.md` §3, §4 | from "to check" to what was built |
| SL-005 design sec-6 | its `HostKeyAlias=<room>` and "no room channel" sentences are now false; noted, not rewritten |
| `CLAUDE.md` | suite list gains `roomGitCases`, `sessionCases` |
| memory | a gotcha if one is found; none is predicted |

