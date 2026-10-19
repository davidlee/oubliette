# IMP-021: A room has no loader for prebuilt binaries, so npm's native tools cannot run there

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised 2026-10-19 by `RFC-001`. `vm/capsule.nix` enables `programs.nix-ld`
and sets `LD_LIBRARY_PATH` over `runtimeLibs`, because "a guest that cannot run
a binary it downloaded cannot run most toolchains". `vm/room.nix` has neither.

Under `POL-005` a room repo's `node_modules` is a flake output. doctrine's
`webModules` sets `dontFixup`, so its prebuilt binaries are not patched for
NixOS. Some still work: esbuild is a static Go binary, and `.node` addons load
through nix's node. A dynamically linked standalone binary such as biome's
linux-gnu build does not. Two fixes, which do not exclude each other:

- **The repo's side:** `autoPatchelfHook` in the derivation, so the tree
  runs anywhere. This is the more `POL-005`-shaped fix, since the tree then
  carries its own answer.
- **The room's side:** the room takes `vm/capsule.nix`'s loader as one shared
  fragment, not a second copy. That is generic, so it is not a `POL-002`
  smell.

Unverified: which of the room repos' tools actually need either.
