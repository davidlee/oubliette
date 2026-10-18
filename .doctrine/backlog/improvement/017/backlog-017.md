# IMP-017: A room's session runs git from the room image's system PATH, which nothing promises

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## What was observed

SL-006 PHASE-07 (2026-10-19), answering phase OQ-1: inside `session <repo> --`,
`git` resolves to `/run/current-system/sw/bin/git` (git 2.55.0). That is the
room image's own `git`, from `vm/room.nix:96`, not anything in a repo's tool set.
A push, a `git switch` and a commit through `session` all worked from a
non-login `capsule assistant ssh agent -- …` command.

## The gap

Two binding sources promise different things:

- `docs/contract-target.md` (room tools row) and `DEC-043` promise `git` **on
  the base `PATH`**.
- SL-006 design sec-6 tells satan's runner to call `session` by absolute path,
  *because a non-login ssh command's `PATH` is not promised*.

`session` prepends `tools/bin` to whatever `PATH` it inherits and runs the argv
by name. So `git` (and `bash`/`which`, design :128) is reached through exactly
the `PATH` design sec-6 says nobody promises. It held on this host because
NixOS's sshd gives a non-login command `/run/current-system/sw/bin`. Nothing in
oubliette pins it, and satan's interface relies on it.

## Options

- Promise it: state in the contract that a room's non-login command `PATH`
  holds the base tools, and pin it in a case suite or a live check.
- Or make `session` independent of it: give `session` the base tools' directory
  explicitly (behind `tools/bin`), so the caller's `PATH` stops mattering.

Either way, design sec-6's "not promised" and the contract's "on the base
`PATH`" should end up saying the same thing.
