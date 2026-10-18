# IMP-020: A room repo gets its target's caches and guestConfig, as a slot does

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised 2026-10-19 from `CHR-018`. A slot reads its target's `caches` and
`guestConfig` (`vm/capsule.nix:89`, `:180`). For doctrine that means
`CARGO_HOME=/work/.cargo`, and a rendered `config.toml` there with `jobs` set
from `sizes.vcpu`, `debug = 0` and `incremental = false`. Those two settings
remove the two largest terms in `target/` (`targets/doctrine.nix`'s own comment;
the user's host checkout carries ~100 GiB of incremental cache). `vm/room.nix`
reads only `toolsPackage`, so cargo in a room runs on its defaults, with
`CARGO_HOME` under the home.

The `assistant` room now holds four cargo repos (doctrine, goad, satan-attrd,
panopticon). The user's stance is that the agent manages its own free space, so
this is a default, not a fix.

What a room has to settle that a slot does not:
- **One room, many targets.** A slot's env vars and config paths belong to its
  one target. In a room two targets can name the same variable or path:
  `CARGO_HOME`, `.cargo/config.toml`, relative to `/work`. Per-repo env would
  belong in `session`, which already sets `PATH` per repo (DEC-049, DEC-052).
  The path collision needs a per-repo root, or a refusal at eval.
- **`jobs` derives from the target's `sizes`.** Those are placeholders for room
  repos (see the target files' comment), so a room would want its own `vcpu`.
- **A login that bypasses `session`** gets none of it, the same gap the room's
  base `PATH` has.

Not a perimeter question, and POL-002 holds: the room copies values a target
already declares, and nothing generic learns what cargo is.
