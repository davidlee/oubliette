# CHR-018: The assistant room holds the rest of the user's repos

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

After SL-006's live rung (doctrine + goad-walk), the user wants the live
`assistant` room in `/srv/fleet` to hold these repos too:

- `~/dev/{www,retrograde,panopticon,satan-attrd,goad,malebolge,oubliette,resume}`
- `~/.config/emacs`
- `~/flakes` (nix-config)
- `~/notes`

Each needs a target in the consumer: `targets/<name>.nix` (`path`,
`toolsPackage` — `null` where the repo has no flake or tool set yet —
`extraTools`, `caches`, state paths), a row in `targets/default.nix`, and, where
the contract needs one, a literal flake input. It is values only, with no new code
(POL-002). Most repos have no nix tool set yet, so they go in as
`toolsPackage = null` targets and get a flake later.

Open before doing it:
- whether a target with no flake still needs a `targetFlakes` input;
- whether declaring a target builds its own image even when no slot binds it,
  which would matter for rebuild cost with ~13 targets.

`~/flakes` and `~/notes` going into an agent room was the user's explicit
choice, made knowing that POL-001's host-side perimeter (egress filtering)
is all that contains them.

## Progress, 2026-10-19

Declared and built, **not deployed**: consumer `/srv/fleet` `1899eb3`,
`b3011a7` (pushed). All thirteen targets are in `rooms.assistant.repos`. The
runner builds; it has not been booted, so no clone of the eleven new repos
exists yet.

- Every repo now exports `packages.dev-tools` (no agents in any: the room's
  agent is satan's runner, pi-durable). New this session: www (closes its
  IMP-005), goad, resume, notes, emacs-config (closes its IMP-025), malebolge
  (a new flake), oubliette (`flake.nix`, not mkFleet), and nix-config as the
  subflake `flakes/dev-tools`, because its root flake takes the fleet as an
  input, so the reverse input would be a cycle. nix-config's repo root is
  `$HOME`, so the target's `path` is `/home/david`.
- The two open questions: (1) moot, since every target has a flake now; (2) no.
  `image-<name>` is a lazy attribute, and the room build built none of them.
- Each new input follows the consumer's nixpkgs (the user's call, after
  measuring both). Size: `docs/probes.md` Figures, the *thirteen tool sets*
  row.
- The target files' `sizes` are placeholders the profile render requires; no
  slot binds these targets.

Left open: deploying the room (it is satan's runner's live room, so a restart
is the user's to schedule), and checking that `room.sizes` (mem 4096, work
32768 MiB) holds eleven more clones. Possible trims, owned by the repos: rust
toolchains without `rust-docs`, and one shared rust channel.
