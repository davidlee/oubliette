# ISS-025: A slot's git and its target's tool-set git collide silently in system-path

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed

Raised in SL-006's session, after PHASE-07's live rung. `vm/capsule.nix`
(`environment.systemPackages`, ~:142) lists `pkgs.git` beside
`fragments.compose`'s floor, which is the target's `toolsPackage`. A tool set
that carries its own git (`gitFull`, for doctrine's `dev-tools`, per the seat)
puts two `bin/git` into one `system-path` buildEnv. NixOS builds that env with
`ignoreCollisions = true` (`nixos/modules/config/system-path.nix`), so the
build warns at most and one of the two wins without any check failing.

Not verified here: which git a slot's `PATH` actually resolves, and whether the
two differ in anything a slot uses (the channel's `upload-pack`/`receive-pack`,
`send-email`, credential helpers).

## Why it matters

The guest's tool set has two owners (CLAUDE.md, `compose(floor, extras)`); a
silent collision means neither owner decides which git the agent runs, and
the target's devshell and its slot can drift on the one tool the git channel
depends on — the drift the floor exists to prevent.

## Not affected

Rooms (SL-006): `vm/room.nix` keeps a repo's tool set out of
`environment.systemPackages` and reaches it only through `session`'s
`/etc/room/repo/<r>/tools` link, so only `pkgs.git` is in the room's
`system-path` (PHASE-07 A7: `session`'s git is `/run/current-system/sw/bin/git`).

## Options, not chosen

- Drop `pkgs.git` when the floor supplies a git (needs a way to ask, which
  must not name the target — POL-002).
- Give the guest's git a priority (`lib.hiPrio`/`lowPrio`) so the winner is
  declared rather than incidental.
- A `hostModuleUnits`-style eval check that the slot's `system-path` has one
  `bin/git`, naming the collision as the class.
