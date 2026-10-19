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
  - git `safe.directory` for the readers covering `/work/*` (system gitconfig),
    since git refuses a repo owned by another user ("dubious ownership"),
    including as the source of a local clone. Verify on the room's git
    (2.55 on the host) rather than assume.
- With `readers = []`, the seed is unchanged (`0700`), so existing rooms keep
  their modes.
- `/srv/fleet/flake.nix`: `rooms.assistant.users.satan` (uid, key) and
  `repos.readers = ["satan"]`. The key is issued by `~/flakes` with the
  daemon's door file (flakes:SL-015).

## Verification

- `rooms-cases.nix`: an unknown reader, and `repos.user` listed as a reader,
  both throw.
- Rendered seed (pure check): `0750` and the readers' group when `readers` is
  set; `0700 -g users` when it is not.
- Live, in room `assistant` after a restart (the seed runs at boot):
  - as `satan`: `git clone /work/<repo> ~/x` succeeds and
    `git -C /work/<repo> log -1` works;
  - as `satan`: `touch /work/<repo>/f` and `git -C /work/<repo> commit`
    fail with permission denied;
  - as `satan`: `/home/agent` is still unreadable;
  - a patch job on the same repo still prepares, runs and collects (the
    runner's clean step and `dirty_clone` check are `agent`'s and unaffected).

## Links

satan:SL-027 design §4.8 (room user, D3 by permissions) and §7 Q2;
satan:DEC-075 (vm mode's own room user); satan:RV-035 F-2.
