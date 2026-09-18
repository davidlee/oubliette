# ISS-013: The git-channel programs read their profile with the jq on PATH, not their own

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found in SL-001 PHASE-05, writing `wrapCases`' composition case.

`host/profile.nix`'s reader calls `jq`, and it exports `inputs = [pkgs.jq
pkgs.coreutils]` for its callers' `runtimeInputs`. `capsule-provision`
(`host/git-channel.nix`, `runtimeInputs = [pkgs.git pkgs.openssh]`) does not
take them. So the program finds `jq` only when the caller's `PATH` has one. With
none, every document reads as "is not a readable JSON object", which names the
document rather than the missing tool.

Why nothing saw it:
- `gitChannelCases`' `runCommand` has `jq` in `nativeBuildInputs`.
- The live host has `jq` on the system `PATH`.
- `wrapCases` failed on it under `env -i` and was given the same
  `nativeBuildInputs` so it could test what it is for. The comment there names
  this item.

To check: which other programs splice `profileSelect` or the reader without
`profile.inputs` (`collect` at `host/git-channel.nix:371`, and
`host/programs.nix`). The fix is probably `++ profile.inputs` at each one, and
then removing `jq` from both suites' `nativeBuildInputs`, so that removing it
from the program turns them red.
