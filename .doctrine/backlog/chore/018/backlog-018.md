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
