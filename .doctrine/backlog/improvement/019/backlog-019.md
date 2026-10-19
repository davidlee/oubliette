# IMP-019: A room repo whose tools are npm packages cannot install them

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised 2026-10-19 from `CHR-018`. malebolge's `just check` runs biome, eslint,
tsc and vitest through `npx`, from `node_modules`, which `npm ci` fills. A slot
could do that, since the policy allowlist admits `registry.npmjs.org` through the
proxy. A room cannot: it has no uplink and so no proxy (`vm/room.nix`,
`rooms.nix` `uplink = null`). Its `dev-tools` holds only node and just.

Two shapes, neither chosen:
- **The repo's flake builds `node_modules`** (e.g. `importNpmLock` or
  `buildNpmPackage` over `package-lock.json`) and exports it, or exports the four
  tools. No perimeter change, and nothing generic learns what npm is (POL-002).
  It is malebolge's work, not this repo's.
- **A room gets an uplink** to the proxy under its policy, whose allowlist is
  inert today. That is a perimeter change (POL-001) and takes back the room's
  defining property, no way out (`vm/room.nix`), so it needs a decision record,
  not a value.

The first is cheaper and keeps the room sealed. The same gap applies to any
room repo whose tools come from a language package manager rather than nix.

**Settled 2026-10-19 by `RFC-001` → `POL-005` ("A room never fetches"):** the
first shape, the repo's flake builds the tree. The room stays sealed and
`DEC-036` stands. The work moved to the repos: doctrine `IMP-519` (export
`webModules`) and malebolge `IMP-001` (a dev `node_modules`). Separate id
spaces, so those ids are theirs, not this corpus's. The room's missing loader,
which both may hit, is `IMP-021` here.
