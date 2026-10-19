# IMP-023: A room's repos can be read, not written, by its other users

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

satan:SL-027 (malebolge daemon vm mode) runs the interactive daemon's coding
tools in room `assistant` as a second room user (`satan`), so that its work
reaches the host only as a patch job: it may read the `/work` clones the
patch runner's user (`agent`) owns, never write them. Raised as finding F-2 on
satan:RV-035 (the SL-027 design review); the user chose this repair over
dropping `/work` access.

Today no other user can read a clone. `room-seed` creates each one on every
boot with `install -d -m 0700 -o <repos.user> -g users <guestPath>`
(`vm/room.nix:164-172`), and declared users get no groups (`vm/room.nix:95-108`).
As `satan`, `git clone /work/<repo>` fails with EACCES.

## Shape

- `rooms.nix`: `repos` gains `readers = [<user>]` (default `[]`). Each reader
  must be a declared user other than `repos.user`; it throws otherwise, with
  cases in `rooms-cases.nix` beside the bad-`repos.user` case.
- `vm/room.nix`, when `readers` is non-empty:
  - a group for repo readers (e.g. `repos-read`) with a **declared gid**: the
    root fs is tmpfs, so an undeclared gid is reallocated each boot, as uids
    are (RSK-012);
  - `repos.user` and each reader in that group;
  - `room-seed` makes each clone directory `0750`, group `repos-read`, not
    `0700` / `users`. Inside it, git writes under `agent`'s umask (022), so
    files are readable and not writable by the group; the directory mode is
    the only gate needed;
  - **no** git `safe.directory` from the room (decided 2026-10-20, see
    *Git trust* below).
- With `readers = []`, the seed is unchanged (`0700`), so existing rooms keep
  their modes.
- `/srv/fleet/flake.nix`: `rooms.assistant.users.satan` (uid, key) and
  `repos.readers = ["satan"]`. The key is issued by `~/flakes` with the
  daemon's door file (flakes:SL-015).

## Git trust (decided 2026-10-20)

The first shape had the room set `safe.directory = /work/*` system-wide. It
does not: that setting is git's opt-out from refusing repos another user owns,
and with it off, git run by a reader in `/work` runs the **owner's** repo
config as the reader. Evidence, host git 2.55.0 with the owner faked by
`GIT_TEST_ASSUME_DIFFERENT_OWNER=1`:

- no `safe.directory`: `git -C <repo> log` and a plain local `git clone` are
  refused ("dubious ownership"); `git clone --no-local <repo>` succeeds and
  runs none of the repo's config;
- with it: `git status` ran the repo's `core.fsmonitor`, and a filter driver
  declared in the repo's config and `.gitattributes`, as the reader;
- a global `core.hooksPath` does not close it: repo config outranks global,
  so the repo's own `core.hooksPath` wins, and hooks are the minor vector.

So the repos' user (the patch runner) could act as every reader. The room
ships permissions only; a reader either clones with `--no-local` (or
`file://`) or opts in itself (its own `~/.gitconfig`, or `-c
safe.directory=…` per command), taking that risk in its own repo. A reader
can opt in whatever the room does, so a room-wide exception would only move
the choice away from the party that bears it. satan:SL-027 decides for
`satan`.

## Verification

- `rooms-cases.nix`: an unknown reader, `repos.user` listed as a reader, and
  a non-list `readers` throw; readers are carried in order. **Done.**
- `roomImages`: the repos' user and each reader carry exactly the readers'
  group, everyone else none, and the group's gid is declared; the fixture's
  `assistant` has reader `eve`. **Done.**
- Rendered seed (read by eval, not asserted): `0750 -g repos-read` for the
  fixture's `assistant`; `lounge` unchanged. No room in the fixture has repos
  without readers, so that branch's `0700 -g users` is not rendered.
- Live, in room `assistant` after a restart (the seed runs at boot):
  - as `satan`: `git clone --no-local /work/<repo> ~/x` succeeds;
    `git -C /work/<repo> log -1` is refused ("dubious ownership") and
    succeeds with `-c safe.directory=/work/<repo>`;
  - as `satan`: `touch /work/<repo>/f` and `git -C /work/<repo> commit`
    fail with permission denied;
  - as `satan`: `/home/agent` is still unreadable;
  - a patch job on the same repo still prepares, runs and collects (the
    runner's clean step and `dirty_clone` check are `agent`'s and unaffected).

## Live results (2026-10-20, room `assistant`, after `microvm -u` and a restart)

- `satan` is uid 1002 in groups `users` and `repos-read` (2000); every clone
  is `drwxr-x--- agent repos-read`, `/work` itself `0755 root`.
- As `satan`: `git clone --no-local /work/doctrine` succeeded; `git -C
  /work/doctrine log` was refused ("dubious ownership") and succeeded with
  `-c safe.directory=/work/doctrine`; `touch` in the clone and in its `.git`
  and `git commit` (`index.lock`) were denied; `ls /home/agent` was denied.
- **Not yet exercised:** a patch job on a repo beside a reader (prepare, run,
  collect as `agent`). That is the last check before this resolves.

## Links

satan:SL-027 design §4.8 (room user, D3 by permissions) and §7 Q2;
satan:DEC-075 (vm mode's own room user); satan:RV-035 F-2.
