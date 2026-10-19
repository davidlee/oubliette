# Notes SL-007: Programs bring their own tools: session's base tools and the profile reader's jq

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-19 · PHASE-01..05 completed, live pass · audit next · head 71f141b+

### Produced
- DEC-052 (room base = floor + declared extras; supersedes DEC-044); amended: floor coreutils-full (bb52b4a)
- DEC-053 (profile reader carries its jq)
- DEC-043 choice re-pointed to DEC-052 (PHASE-04)
- design.md sec-1..sec-7 (sec-2/sec-3 amended 54b9838); plan.toml/plan.md
- commits 7ce98a2 (P01) · 8672b2d (P02) · 3728bf1 (P03) · a4a7808 (P04) · 71f141b (P05)
- ISS-023 resolved · duplicate of ISS-013
- ISS-026 (refresh-build/up assume a slot; switch does not move a room runner)

### Learned
- No suite runs capsule-refresh/brief/baseline host programs (research.md Thread 2).
- NixOS bash defaults an unset PATH to /no-such-path (GPT, review/019/gpt-second-opinion.md).
- buildEnv checks collisions inside itself only; system-path ignores them (ISS-025).
- NixOS required packages use coreutils-full, not coreutils (notes § PHASE-03 premise).
- A host switch does not move /var/lib/microvms/<n>/current; only microvm -u (ISS-026).
- `capsule <room> ssh -- a; b` runs b in the remote login shell: quote the payload (notes § PHASE-05).

### Open
- IMP-017, ISS-013 (resolve at close)
- DEC-044 still `accepted` though DEC-052 supersedes it (reconcile)
- CON-001 "extras are fleet-wide" now holds for slots only (reconcile)
- Memory candidates for /close harvest: switch-vs-microvm -u for rooms; ssh payload quoting
- Follow-up: a room user's login shell (slice-007.md § Follow-Ups)
- satan relay line drafted (notes § PHASE-05 EX-3); the user delivers

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

## PHASE-02

### What landed
- `rooms.nix`: `fragmentNames` in the second argument set (no default, POL-003);
  `extrasShaped`/`extraPairs` beside `reposShaped` (shape before content, so a
  non-list or `[1]` is its one reason, never a type-error abort);
  `reasons.extras` (DEC-052: "extras not a list of fragment names", "not in the
  vocabulary (<names>)"; the vocabulary sits only inside the clause's `what`, so
  it stays lazy); record `extras = decl.extras or []`; `instances` throws
  `reasons.extras` after `policy`; header updated.
- `mkfleet.nix` `roomDecision`: `fragmentNames = attrNames (import ./fragments.nix
  {inherit pkgs; inherit (flavour) sources;}).vocabulary` (names only).
- Five fixture appliers: `rooms-cases.nix` (invented `["search" "editor"]`, via a
  `withVocabulary` applier that `with'` is a partial application of), and
  `fabric-cases.nix`, `host/guard-cases.nix`, `host/netns-cases.nix`,
  `host/room-verbs-cases.nix` pass `fragmentNames = [];`.
- `roomsCases` cases 18-23: not-a-list and `[1]`; unknown name (offender,
  vocabulary, and `assistant ("search")` absent); absent -> `[]` on both kinds of
  room, exact-record literal gained only `extras = [];`; declared -> carried in
  order; `fragmentNames = throw` never forced (Q1 ruling, both kinds of room);
  independence from policy.

### T1 red
With `fragmentNames` accepted but `reasons.extras = null` and the record field
present, 15 FAIL lines: both not-a-list cases, the unknown-name case, each with
its needles, and case 23's extra. (Before the record field existed the suite
aborted at eval: `attribute 'extras' missing`, no FAIL lines.)

### EX-3 mutation
Mutant: deleted the `else if !(isNull reasons.extras) then throw reasons.extras`
branch from `instances`. `nix build '.#roomsCases'`:
```
FAIL extras as a bare string throws: got 'false', wanted 'true'
FAIL an extra that is not a string is a reason, not an abort: got 'false', wanted 'true'
FAIL a name outside the vocabulary throws: got 'false', wanted 'true'
```
No eval error. The reason-needle checks stayed green (they read `reasons`, not
`instances`), and case 23's verdict stays true because the policy throws first.
Restored from scratchpad copy, `cmp` identical; `just` green.

### Choices
A1-A5 as the sheet. Q1: case 22 included. Q2: single-suite build used to read
FAIL lines. Q3: no extra `nix eval`; the exact-record literal differing only by
`extras = []`, and unchanged verdicts elsewhere, is the EX-4 evidence.

### Verify
`just check` rc 0; `just` rc 0, zero FAIL lines.

### Not exercised
- Nothing renders `extras` (PHASE-03); no image changed.
- `/srv/fleet` declares no extras, so the binding's laziness against the
  consumer is pinned by case 22 only, not observed.

## PHASE-03

### What landed
- `fragments.nix`: `search` (`ripgrep`, `fd`) and `emacs` (`[pkgs.emacs]`,
  ruling 4) in the vocabulary, one comment over both (room-grain, DEC-052).
  Header: per-slot selection bullet gains that a room selects its own
  (`rooms.<r>.extras`); "broad-and-few" gains that the arithmetic is slot-grain.
- `vm/session.nix`: `base ? "/etc/room/base"` beside `root`; refuses `no base
  at <base>` (exit 2) after the name and repo checks; one assignment
  `PATH="$tools$base/bin''${PATH:+:$PATH}"` (A4). Header rewritten for DEC-052;
  `runtimeInputs = []` with its comment updated.
- `vm/room.nix`: names `flavour`; imports `fragments.nix` as `vm/capsule.nix`
  does; `base = buildEnv {name = "room-base"; paths = compose {floor = [git
  bash coreutils-full which]; inherit (room) extras;};}`, no `ignoreCollisions`.
  `systemPackages = [base] ++ optional repos session` (`pkgs.git` gone);
  `etc."room/base".source = base` for every room. `room-seed`'s own `pkgs.git`
  untouched. Header rewritten: a repo-less room now gains the floor.
- `mkfleet.nix`: `roomChecks` rule over every room, `etc ? "room/base"` and
  its source in `systemPackages`; the `:224-225` comment no longer says a
  repo-less image "stays what it was". `sessionCases` call unchanged (A5).
- `vm/session-cases.nix`: tree gains `base` (a `git` marker printing
  `base-git`) and `nobase/`; `kit`'s set is a `symlinkJoin` of `kit-marker` and
  a `git` marker (`kit-git`); `render base` builds `fixture` and `noBase`.
  Two cases rewritten (order with a set; order without), new: base `git`
  found, repo shadows base, no-bin refusal + repo-check-first, empty `PATH`
  (both repos), `env -u PATH`. Image block: `etc."room/base"` found or throw;
  `bin/{git,bash,sh,which,ls}` executable; base in `systemPackages`. Floor
  only (ruling 3).
- `fixture/default.nix`: `assistant` declares `extras = ["search"]`; comment
  says `lounge` is extras' absent path.

### Red
1. Suite written first: eval error `function 'anonymous lambda' called with
   unexpected argument 'base'` (expected first red).
2. `session` accepting `base` with no behaviour: the image block's throw
   `sessionCases: the evaluated room has no environment.etc."room/base"` fires
   at eval and hides the run cases. **Deviation:** to see FAIL lines, the throw
   was temporarily replaced by `{source = "/nonexistent";}` (restored from a
   scratchpad copy, `cmp` identical). Red then: no-bin refusal (exit 0, reason),
   both order cases, base `git`, both empty-`PATH` cases, unset prefix, all
   five image binaries, base-in-`systemPackages`. Green already: repo shadows
   base, repo-check-first, every usage/grammar/shipped refusal.
3. After T3 the run cases went green; the image block stayed red (eval throw)
   until T4.

### EX-4 mutation (VA-1)
Mutant: `PATH="$tools''${PATH:+:$PATH}"` (refusal kept, so `$base` is still
read). No eval or shellcheck error; the suite ran:
```
FAIL   with tools/bin, then the base, then the caller's PATH: got '<tree>/kit/tools/bin:<caller>' …
FAIL   with the base ahead of the caller's PATH: got ':<caller>' …
FAIL the base's git is found when the caller has none: got '', wanted 'base-git'
FAIL an empty caller PATH ends at the base, with no trailing :: got '<tree>/kit/tools/bin:' …
FAIL   and without a set is the base alone: got '', wanted '<tree>/base/bin'
FAIL   and the child's PATH starts at the base
```
Green under the mutant: shadow, refusals, image block. Restored from copy,
`cmp` identical, suite green.

### T6 roomChecks mutation
- Mutant A: `etc = {} // …` (no `room/base` for any room). `nix build
  '.#roomImages'`: `roomImages: room 'assistant': /etc/room/base is absent or
  its base is not in environment.systemPackages (DEC-052)` — `assistant` is
  hit first (name order) and aborts.
- Mutant B: `lib.optionalAttrs (room.repos != null) {"room/base".source =
  base;}`, to reach the repo-less room: `roomImages: room 'lounge': /etc/room/base
  is absent or …` (same reason).
Both restored from copy, `cmp` identical.

### EX-5 collision (VA-1)
Temporary `collide = {packages = [pkgs.gitMinimal];};` in the vocabulary and
`assistant.extras = ["search" "collide"]`; `nix build '.#sessionCases'` failed
building `room-base` (rc 1, builder exit 25):
```
pkgs.buildEnv error: two given paths contain a conflicting subpath:
  `/nix/store/3ba67bl…-git-minimal-2.55.0/libexec/git-core/git-bugreport' and
  `/nix/store/msr1v91…-git-2.55.0/libexec/git-core/git-bugreport'
hint: this may be caused by two different versions of the same package in buildEnv's `paths` parameter
```
The first conflict reported is under `libexec/`, not `bin/git` as the sheet
guessed; the claim (a colliding extra fails the build) holds. Both files
restored from copies, `cmp` identical. Collisions between the base and the rest
of `system-path` stay unchecked (design sec-2).

### EX-6 / verify
`just check` rc 0; `just` rc 0, zero FAIL lines. Out paths of `roomsCases`,
`fabricCases`, `roomGitCases`, `roomVerbsCases`, `vmCases`, `hostModuleUnits`
identical before (T0) and after (T9): verdicts trivially unchanged. Rendered
bases: `assistant` `bin/` has `bash fd git ls rg sh which`; `lounge` has `bash
git ls sh which`. VT-1..VT-5 greps all hit.

### Not exercised
- No room booted: a login `PATH` and `session` inside a live guest are not
  observed; the image case asserts the render, not the boot.
- `emacs` is in the vocabulary but no fixture room selects it, so it is never
  built here.
- `unset PATH`: the child received `<tree>/base/bin:/no-such-path` (bash's build
  default exported by `writeShellApplication`'s preamble); only the prefix is
  asserted.

## PHASE-04

Docs, comments and decision records only; no behaviour change. Worker model
sonnet; rulings OQ-1 yes, OQ-2 yes, OQ-3 no, plan-f one sentence yes.

### VA-1 grep (widened; ledger excluded), before / after
Before: 10 hits (probes.md:1580; contract-target.md:95, :359;
contract-assignment.md:80; plan-f-assistant.md:134; vm/room.nix:23, :119;
vm/session.nix:2; mkfleet.nix:250, :254). After: 2 hits.
- `docs/probes.md:1580`: kept, historical measurement from SL-006's live rung
  citing `IMP-017` as the then-open gap (ADR-003, STD-001).
- `docs/plan-f-assistant.md:134`: "superseding `DEC-044`", intended.
The secondary grep (`PATH it inherits`, `fleet extras`) returns nothing outside
the ledger.

### Changed
- `docs/contract-target.md` :95, :359; `docs/contract-flavour.md` header;
  `docs/contract-assignment.md` room row and paragraph; `CLAUDE.md` two-owners
  paragraph; `docs/plan-f-assistant.md`; `templates/fleet/flake.nix` (comment
  plus `extras = ["search"];` in the commented example only).
- `vm/session.nix:2` and `vm/room.nix:23,119` re-pointed (DEC-049/DEC-052);
  `mkfleet.nix:250` -> DEC-049, `:254` -> DEC-052 (refusal strings; no suite
  pins their text).
- `DEC-043` choice: only the last sentence changed, now "git joins the room's
  base tools: it is in the floor of the room's base (DEC-052)."; other fields
  unchanged (verified with `doctrine show`).
- `doctrine supersede DEC-052 DEC-044` (OQ-2): rc 0. `inspect` shows no edge on
  either; only DEC-044's `updated` date changed on disk. DEC-044 status is still
  `accepted` per `show`. Worth checking at /reconcile.
- CON-001 ("Extras are fleet-wide") now holds for slots only; untouched, deferred
  to /reconcile (OQ-3).
- README.md:495-499 not touched (optional, not taken).

### Verify
`just check` rc 0 (alejandra clean); `just` rc 0, zero FAIL lines.
Not exercised: nothing evaluates the template's commented `extras`; PHASE-03's
rendered fixture room proves the field. IMP-017/ISS-013/ISS-023 left for /close.

## PHASE-05 — live (2026-10-19)

Consumer `/srv/fleet` `f5fcecc` (oubliette `34160e8`, assistant
`extras = ["search" "dev-facilities" "emacs"]`); host switched by the user.
The switch alone did **not** move the room: `/var/lib/microvms/assistant/current`
changes only through `microvm -u` (ISS-026). `just refresh-build assistant`
updated it (runner `2viwd…`, holds `room-base` `asicd5i…`) then failed at
`up`'s slot-only `created` (exit 2, ISS-026); `capsule assistant start` by
the user finished it.

EX-1, from this host (payload quoted as one string: unquoted, ssh joins the
argv and everything after the first `;` runs in the remote login shell, which
reads as a false pass — it did, once):

    capsule assistant ssh agent -- "env -i /run/current-system/sw/bin/session doctrine -- sh -c 'echo PATH=\$PATH; command -v git; command -v rg; readlink -f \$(command -v git)'"
    PATH=/etc/room/repo/doctrine/tools/bin:/etc/room/base/bin:/no-such-path
    /etc/room/base/bin/git
    /etc/room/base/bin/rg
    /nix/store/lg46w7hrjx7kylsh6645c9l975i8h43b-git-2.55.0/bin/git

Before the refresh the same command gave `PATH=…/tools/bin:/no-such-path` and
no `git` at all: the defect IMP-017 names, live. `git` resolves to the same
store path the system's was (design sec-6: no behaviour change expected).

EX-2, an interactive login (`bash -lc`): `rg`, `fd`, `emacs`, `git` on `PATH`
from `/run/current-system/sw/bin`, and `ls` is `coreutils-full-9.11` (the
amended floor; nothing shadows the system's).

Observed: the base's `bin` also carries mailutils' programs (`mail`,
`movemail`, `pop3d`, …) and `ebrowse`/`etags`, from the `emacs` fragment.
Harmless; noted for whoever weighs image size.

Not exercised: two extras colliding; `capsule-refresh`/`brief`/`baseline`
live with no system `jq` (profileCases runs the reader's text).

EX-3, the satan relay (for the user to deliver):

> `session` now supplies the room's base tools itself (`git bash coreutils
> which` plus the room's declared extras, at `/etc/room/base/bin`), behind the
> repo's `tools/bin` and ahead of the caller's `PATH` — so your runner's `PATH`
> no longer matters inside `session`. Keep calling it by absolute path.
