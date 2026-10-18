# Assistant room over many repos: clones, tools and a per-repo git channel

## Context

SL-005 built rooms: a guest with no uplink, its own namespace, a door
(`DEC-037`: a per-room unix-socket ssh relay, a declared user, host keys on the
volume) and front-end verbs (`DEC-041`: `capsule <room> ssh | start | stop`,
stop through the stop key). It deliberately stopped short of what makes the
assistant room (Plan F, [plan-f-assistant.md](../../../docs/plan-f-assistant.md),
`IDE-002`) hold **more than one repo**: the repos are named in its design
(`repos = [<target name>]`, reusing `targets/`) and not built, the per-repo
quarantine layout is pinned (`DEC-040`) and not built, and per-repo tools are a
non-goal.

The consumer is satan's SL-023 (the patch runner, hosted in `~/dev/malebolge`
under satan `DEC-051`). Its design names oubliette's share as *room, door,
refresh-push and quarantine-fetch verbs, graceful stop; later a land verb*, and
builds its `GitChannel` port (`refresh(repo, baseRef) → oid`,
`collect(repo, jobId) → {ref, oid}`, `reachable()`) against a capsule slot
standing in until this slice gives it a room adapter. Its door config waits on
satan `ASM-005` (door as Plan F §5 sketches it).

```
consumer: rooms.assistant.repos = [ "satan" "doctrine" … ]   (names in targets/)
   │
   ├─▶ room image: one tool set per repo, never unioned       (Plan F §3)
   │      session <repo> -- <cmd>  → that repo's PATH, cwd = its clone
   ├─▶ clones on a room volume                                (ISS-021 → amend DEC-040)
   │
host ──refresh <room> <repo> <ref>──▶ guest clone             ┐ one git channel,
host ◀─collect <room> <repo> <branch>── /var/lib/capsule/      │ room transport,
                    collect/<room>/<repo>.git (fsckObjects)    ┘ quarantine keyed by repo
   ▲
   └── satan runner (host) via GitChannel port; Emacs fetches quarantine ref to promote
```

## Scope & Objectives

1. **A room declares its repos** as target names (`repos`), resolved against
   the consumer's `targets/` with an eval-time refusal for an unknown name.
   Nothing generic learns what a repo is (`POL-002`); one declaration per axis
   (`POL-003`) — a repo's tools come from its target's `toolsPackage`, never a
   second per-repo declaration.
2. **Clones live on a volume.** Settle `ISS-021`: `DEC-040` puts a clone at the
   target's `guestPath` (under `/work`), which is off a room's only volume
   (`/home`). Choose a second volume or a room-relative clone path, and
   supersede `DEC-040`'s clone-path clause with a new record.
3. **Per-repo tools, activated by a launcher** (Plan F §3). Each repo's tool set
   is in the image as its own store path. `session <repo> -- <cmd>` sets `PATH`
   from that set, `cd`s into the clone and execs. One session is one repo.
   How pi-env (SL-023's execution environment, which ssh's in as the agent user
   with the clone as `cwd`) gets that environment is a design question.
4. **The per-repo git channel** (`DEC-040`, Plan F §4): `host/git-channel.nix`
   gains a room transport fragment over the room's socket, with the quarantine
   key separate from the transport name, so N repos in one room do not collide
   on one bare repo (NOTES item 50). Host-initiated in both directions:
   - **refresh**: push a real-repo ref into the room's clone of that repo
     (seeding the clone on first use).
   - **collect**: fetch a named branch from the room's clone into
     `/var/lib/capsule/collect/<room>/<repo>.git`, `transfer.fsckObjects` on.
   Both reachable through the front end (`capsule <room> refresh | collect
   <repo> …`, widening `DEC-041`'s verb set), with outcomes a caller can tell
   apart: room unreachable vs anything else (SL-023's `ChannelUnavailable` /
   `ChannelFailed`).
5. **Stable room uids** (`RSK-012`): a persistent `/home` must not change owner
   because a user was added and the name order shifted.
6. **No HostKeyAlias collision** (`RSK-011`): a room's alias cannot equal a
   slot's, since the runner pins room host keys strictly (`DEC-037`).
7. **Relay the pinned interface to satan**: what SL-023's room adapter and door
   config read (verb argv, exit-status contract, quarantine path and ref
   names, clone paths, the `session` shape), so `ASM-005` can be validated.

## Non-Goals

- **The model door** (Plan F §2) — split to `IDE-003`. SL-023's runner calls
  the gateway from the host; nothing in the room needs a model path yet.
- **A land verb.** Promotion into a real repo is never a program here
  (`DEC-040`); SL-023 promotes by Emacs fetching the quarantine ref.
- A room reset / delete verb (Plan F §6), an optional build-time proxy policy
  for a room (Plan F §1), a planned-stop signal to the runner.
- Narrowing `any_vm_running` (`DEC-031` stays: a probe stops the room first).
- The runner, queue, approval surface (satan SL-023); the gateway
  (`flakes:SL-011`); any `~/flakes` edit — named, and applied by the user.
- Plan E's furniture.

## Affected surface (coarse)

- `rooms.nix`, `rooms-cases.nix`: `repos`, refusals, clone and quarantine paths.
- `vm/room.nix`: per-repo tool sets, the `session` launcher, clone volume,
  fixed uids.
- `host/git-channel.nix`, `host/git-channel-cases.nix`, `host/quarantine.nix`,
  `host/profile.nix`: room transport, quarantine key split from transport.
- `host/cli.nix`, `host/room-verbs-cases.nix`: `refresh` / `collect` for rooms;
  HostKeyAlias.
- `host/services.nix`, `mkfleet.nix`: volumes, quarantine tmpfiles, suite wiring.
- `fixture/`, `templates/`: the fixture assistant declares repos.
- `docs/plan-f-assistant.md`, `docs/contract-*.md`, `CLAUDE.md` suite list.

## Risks, assumptions, open questions

- **SL-005 is not closed** (7/9 phases; PHASE-08 docs and PHASE-09 live remain).
  This slice builds on its code; design can start, execution should follow its
  close or at least PHASE-09's live proof of the door.
- **Closure size.** Seven tool sets in one image; `EVD-007` priced one
  composition at ~0.5 GB. To be measured, not assumed. A tool change is an
  image rebuild plus a reboot.
- **pi-env and `session`.** pi-env uploads and runs a daemon in the guest over
  ssh; whether it can take a per-repo environment (a wrapper command, an env
  file, a `ForceCommand`) is unknown until read.
- **Does `host/git-channel.nix`'s profile shape take a room repo** without
  learning what a room is (`POL-004`), or do its programs assume a slot behind
  the transport? Plan F §4 asked this; research X5 in SL-005 started it.
- **Seeding a clone**: refresh-from-nothing (push into an empty repo) vs a
  provision-like step. A slot's provision resets tracked files only
  (`mem.fact.oubliette.a-provision-resets-tracked-files-only`); a room clone is
  long-lived and must not inherit that surprise silently.
- **`base_ref`**: SL-023 validates a real-repo branch name (satan `DEC-059`,
  `ISS-041`); refresh takes a ref, not `HEAD`.
- **Assumption**: the runner runs on this host as the module owner (satan
  `DEC-050`; `DEC-037`'s socket is 0600).

## Verification / closure intent

- Case suites (red first) for: unknown-repo refusal at eval; clone and
  quarantine paths per repo with no collision across two repos in one room;
  refresh and collect through the shipped channel against a fixture room;
  distinct exit statuses for room-down vs failure; uid stability across a
  reordered user set; alias disjointness.
- `just build` builds the fixture assistant image with two repos' tool sets,
  and a mutated launcher goes red.
- Live (user, root): on this host, the assistant room holds two real repos;
  `session <repo> -- <check>` runs each repo's own check; a commit on
  `job/<id>` in one clone collects into that repo's quarantine and nowhere
  else; a room stop/start keeps clones, uids and host keys.
- satan SL-023 told what to build its room adapter against; `ASM-005` checkable.
- `ISS-021`, `RSK-011`, `RSK-012` closed; `IDE-002` fulfilled in full except
  `IDE-003`.

## Summary

## Follow-Ups

- `IDE-003` — the model door.
