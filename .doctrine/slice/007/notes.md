# Notes SL-007: Programs bring their own tools: session's base tools and the profile reader's jq

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-19 · plan authored (5 phases), slice ready · PHASE-01 next

### Produced
- DEC-052 (room base = floor + declared extras; supersedes DEC-044)
- DEC-053 (profile reader carries its jq)
- design.md sec-1..sec-7; research/research.md (gitignored)
- ISS-023 resolved · duplicate of ISS-013

### Learned
- No suite runs capsule-refresh/brief/baseline host programs (research.md Thread 2).
- NixOS bash defaults an unset PATH to /no-such-path (GPT, review/019/gpt-second-opinion.md).
- buildEnv checks collisions inside itself only; system-path ignores them (ISS-025).

### Open
- IMP-017, ISS-013 (resolve at close)
- Follow-up: a room user's login shell (slice-007.md § Follow-Ups)
- satan relay line at close (design sec-6)

## Design review passes

- 2026-10-19: one informal GPT pass (gpt-6-sol, read-only) over sec-2/sec-3,
  kept as `review/019/gpt-second-opinion.md`; three corrections taken into
  sec-2/sec-4 (`dd9252d`). Then the user's section review ("agreed").
- **No further pass needed** before plan. What one would probe, if wanted:
  the `rooms.nix` → `vm/room.nix` threading of `extras` (whether a refusal
  reaches every caller's eval, as `reasons.policy` does), and whether
  `/etc/room/base` in a repo-less room changes SL-005's fixture rooms in any
  way a suite pins.
