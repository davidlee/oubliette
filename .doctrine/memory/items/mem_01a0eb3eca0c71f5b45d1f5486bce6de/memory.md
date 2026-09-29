`inputs.target.url` is `github:davidlee/doctrine/edge` (ISS-015), not a
`git+file:` checkout, because the lock is committed and a stranger's clone has
to be able to fetch what it pins.

- A doctrine change needs a commit **and a push** before
  `nix flake update target` sees it. Uncommitted *or unpushed* work there is
  invisible to the capsule.
- To try unpushed doctrine work, override one build:
  `nix build .#capsule --override-input target git+file:///home/david/dev/doctrine`.
- **Never** `nix flake lock --override-input target git+file:…` — that writes the
  local path back into the lock and the flake is unfetchable elsewhere again.
- `microvm -c` takes no override flags, so a created slot always gets the
  **locked** rev: push, update the lock, then `just refresh-build <slot>`.

Supersedes [[mem.fact.oubliette.git-file-inputs-read-committed-head]].
