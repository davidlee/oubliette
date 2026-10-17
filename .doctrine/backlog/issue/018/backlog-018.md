# ISS-018: mkFleet's probe prelude requires policies named build and sealed

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`mkfleet.nix:1067-1068` (the probe prelude) reads
`policies.policies.build.allowlist` and `policies.policies.sealed.allowlist`.
Before SL-004 that was `flake.nix` binding this host's own policies; since
SL-004 it is a generic builder, so every caller — oubliette's fixture, the
template, any consumer — must declare policies named exactly `build` and
`sealed`, or eval fails. Nothing in `docs/contract-*.md` says so. A POL-003
smell (a name required implicitly); found by RV-013 F-14, first noted in SL-004
PHASE-07's sheet (R3).

Options: have `probe` name the two policies (`probe = {target; fabric;
policies = {open = "build"; sealed = "sealed";}}`), or state the requirement in
the contract and refuse with a reason at eval. The first keeps POL-003; the
second is cheaper.
