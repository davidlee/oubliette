# CHR-016: The probes and the justfile spell the devshell root their own way

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

SL-003 PHASE-01 (412b77f) made `perimeter/root.nix` the one spelling of
`${CAPSULE_ROOT:-${MICROVM_SPIKE_ROOT:-$PWD}}` for host/ and flake.nix. Other
places still spell it their own way, all without `MICROVM_SPIKE_ROOT`:

- `probe/netns-egress.sh`, `probe/two-capsules.sh`, `probe/freshness.sh` and
  `probe/netns-boot.sh`: `ROOT=${CAPSULE_ROOT:-$PWD}`. They could take it
  through the probe builder's `prelude`.
- `justfile:51`: the proxy log path.

Nearby, the same class: `state="${CAPSULE_STATE:-$root/.vm/host}"` is spelled
in both `perimeter/default.nix` (pathDefs) and `host/quarantine.nix`
(fragment). Separately, it is worth asking whether `MICROVM_SPIKE_ROOT` has any
caller left, or can go.
