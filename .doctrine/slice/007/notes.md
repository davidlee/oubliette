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

## PHASE-01 — the profile reader names its own jq (worker, 2026-10-19)

Ran as opus. Orchestrator's argument: the edits are mechanical, but the
phase closes a defect a test masked, and its traps are passes that prove
nothing (splicer check by store path alone, a valid-document-only reader case
while errexit is off inside `profileRead`, a mutation red that is really a
shellcheck/eval failure, Nix `''${` escaping).

**Premise (DEC-053) re-checked and holds**: 7 `jq` calls, all in `profileRead`;
everything else in `validator`/`locator`/`select` is a builtin. Seven splicers
confirmed in source (provision, collect via `profileSelect` in git-channel.nix;
baseline, refresh, brief via `profileSelect`; `capsule` via `observeFragment`;
`capsule-room-git` via `profile.fragment`). `observeFragment`/`snapshotArgs`
add only builtins.

### What landed, per file
- `host/profile.nix`: `jq = lib.getExe pkgs.jq` in the `let` (comment cites
  DEC-053/ISS-013), exported; all 7 reader calls are `${jq}`; `inputs` and its
  comment deleted; `check` has no `runtimeInputs` at all (A2). `renderDocs`'
  `jq -S .` and `dir`'s `nativeBuildInputs` untouched (design sec-3).
- `host/room-git.nix`: `++ profile.inputs` dropped.
- `mkfleet.nix`: `inherit (hostProfile) inputs` gone from snapshot/observe
  cases; `profileCases` gets `jq` and `splicers` (seven, keyed by program name).
- `host/profile-cases.nix`: args `jq`, `splicers` (no `inputs`); `probe`/
  `selector` lose `runtimeInputs`; `runCommand … {}`; fixture writes use
  `${jq}`; the renderDocs subshell alone gets `PATH="${lib.getBin pkgs.jq}/bin:$PATH"`
  with a comment that it is the render (a build step), not a reader case (A3
  ruling). New section "the reader brings its own jq", first in the suite:
  - (1) premise `command -v jq` empty; load `jsonOf base` via `probe`, assert
    rc 0 + name (calls :130/:135/:144/:203), a cachePath (:223) and statePath
    count (:224); a drifted-guestPath document refused *with its reason*
    (:157, the call errexit would hide).
  - (2) the handed names equal the seven spelled in the file; each splicer's
    `$out/bin/<name>` holds `<reader's jq> -e` (grep -F). Comment states it
    proves the splice carries the text, not that the program runs (STD-001).
- `host/state-snapshot-cases.nix`, `host/observe-cases.nix`: `inputs` arg and
  `runtimeInputs` gone; `nativeBuildInputs = [pkgs.git]`; fixture `jq -n` by
  store path, with a "writes the fixture only" comment.
- `host/git-channel-cases.nix`: `nativeBuildInputs = [pkgs.git]`; `write()`
  by store path, commented.
- `host/wrap-cases.nix`: `runCommand … {}`; comment now says the provision
  case's program carries its reader's own `jq`.
- `host/room-git-cases.nix`: header no longer cites `profile.inputs` or the
  `gitChannelCases` masking.

### Choices
- **A1**: `profile.nix` exports `jq`; `profileCases` takes it and uses it both
  for case (2)'s pattern and for writing fixtures. One source for "the reader's
  jq", and less code than a second `lib.getExe pkgs.jq` in that suite. The three
  other suites, which are not handed the profile and only write fixtures,
  compute `lib.getExe pkgs.jq` themselves.
- **A2**: `check`'s `runtimeInputs` removed entirely (coreutils unused by the
  validator). The grammar mutation below confirms `check` sees no ambient jq.
- **A3**: per ruling — scoped PATH on the renderDocs subshell only.

### Red (T1, before the reader changed)
`nix build .#profileCases`: case (1) — `FAIL with no jq on PATH, the reader
still loads a document: got '1', wanted '0'`, `FAIL missing reason 'must stay
derived from' in: … drifted.json is not a readable JSON object`; case (2) —
`FAIL <each of the seven> splices the reader's own jq: got 'no', wanted 'yes'`;
plus every pre-existing probe/selector round. Premise case passed.

### Mutation (EX-4 / VA-1)
- `host/profile.nix:130` `${jq} -e` → bare `jq -e`: red, suite FAIL lines,
  the only `error:` the profile-cases builder itself (no shellcheck/eval error;
  `capsule-profiles` built). Case (1): `FAIL with no jq on PATH, the reader still
  loads a document: got '1', wanted '0'`, `FAIL   and reads its scalars: got '',
  wanted 'fixture'`, `FAIL missing reason 'must stay derived from' in:
  capsule-profile: /build/nojq/drifted.json is not a readable JSON object`.
  Case (2): all seven `splices the reader's own jq: got 'no'`. Reverted from a
  scratch copy (cmp-checked), `just` green.
- `:157` (grammar) `${jq} -r` → bare `jq -r`: `FAIL   and its grammar still
  refuses: got '0', wanted '1'` — the errexit-hidden path, exactly as
  predicted: the probe *loaded* the drifted document. `check` (not under `||`)
  failed 127 on all eleven grammar rounds. Case (2) stays green for this one —
  it pins the `-e` call as a marker of the splice, not every call; case (1)
  covers the rest. Reverted, green.

### VA-2 sweep
`grep -rn 'inputs' host/ mkfleet.nix` survivors, each judged:
- `host/profile-cases.nix:317` — the new case (2) comment naming `record.inputs`.
- `host/record.nix:22` — `record.inputs`, untouched (design sec-3).
- `host/cli.nix:370` — `++ record.inputs`, untouched (design sec-3).
- `host/profile.nix:45` — prose, "inputs to the guest image".
- `mkfleet.nix:1`, `:29` — flake-inputs prose.
`grep -rn 'profile\.inputs\|hostProfile.*inputs'` outside `.doctrine/`: empty (EX-1).

### Verify
`just check` rc 0; `just` rc 0 (check, build — every suite — template-cases,
units); zero FAIL lines.

### Not exercised
- Any splicer **run** live with no system `jq` on a host `PATH` — PHASE-05,
  the user's. Case (2) proves the text, case (1) runs the shared text in a probe.
- No suite runs the shipped `capsule-refresh`/`-brief`/`-baseline` programs
  (research Thread 2, unchanged).
