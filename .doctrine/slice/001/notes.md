# Notes SL-001: A slot may declare which target it is for

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-09-18, design run revision 5)

Constraining governance: `POL-002` (a target's name appears only in
`target.nix` and `inputs.target.url`; `contract-target.md` moves with the
boundary), `POL-003` (one home per axis; resolution is the front end's act),
`POL-004` (a program takes its host tie as an argument), `STD-001`.
`docs/contract-assignment.md`: `profile` is unconstrained for an assigner;
**`source` is a host declaration keyed by profile, host operator only** — the
row that decides `ISS-008`.

Verified facts the design rests on:

- `host/wrap.nix` defaults `CAPSULE_REPO` from `cfg.repo`
  (`/home/${owner}/dev/${target.name}`); `host/git-channel.nix:134` and
  `host/cli.nix` `repoFor` both read `${CAPSULE_REPO:-$profile_path}`. So the
  front end's fetch is on the same defect as provision, not only provision.
- `~/flakes` does not set `repo`; the default is what runs.
- `profileCell` already renders the sole-rendered-document fallback as a bare
  name, identical to a record. Objective 4's ambiguity predates the new field.
- `profileCell` captures `profileNameFor` — a new step must return failure
  explicitly (`mem.fact.oubliette.errexit-skips-a-captured-function`).
- `slotPolicy` is rendered per slot from `capsules.instances` at build; the
  profile default can take the same shape.

Open questions: the run's inquiry map, `inq-2`…`inq-6` (`doctrine design show
SL-001`).

## Further review passes (2026-09-18, run revision 49)

Three adversarial passes have run: Codex (`fnd-1`…`fnd-12`), Opus
(`fnd-13`…`fnd-30`), and a fresh Opus pass on the integrated text
(`fnd-31`…`fnd-46`: four major, nine minor, three nit). All are disposed on the
run. The third pass still found majors, so the yield has not reached zero. But
three of its four were about the *verification* rather than the design's
mechanism: an unbuildable fixture, a check left out of `just build`, and a case
that could not reach its subject. The fourth, `fnd-33`, was a consequence of a
decision nobody had followed through.

What a fourth pass would probe, if one runs — only the text the third pass's
integrations added:

- `handoff`'s path comparison (sec-4): whether "the same name" in this host's
  directory is the right comparand when the source's record and the pin
  disagree (`name!`), and what `land` does with a moved checkout;
- the provision-failure message and rule (sec-3): whether any other caller of
  `provisionSlot` (`setup`) now reports "nothing was recorded" where it used to
  record;
- the removed-option check inside `checked` (sec-5): whether the second module
  evaluation it needs is cheap enough to live in the gate both built attributes
  pass through;
- the stub's `CASE_PROGRAM_FAIL` switch and `out.args`: whether existing
  `policyCases` rounds read `out.argv` in ways the change disturbs.

Recommendation: no full fourth pass. The human section review should read those
four places with the questions above; a narrow Opus pass on just them is the
cheaper option if the reviewer wants one.

## PHASE-06 evidence (2026-09-18, live host after the user's switch)

- **The live module path runs this build.** The inner program the wrapper
  `/run/current-system/sw/bin/capsule` execs contains PHASE-05's handoff
  message ("was pinned with its checkout at") and PHASE-04's ("nothing was
  recorded for"). Both `capsule` and `capsule-provision` wrappers export
  exactly four `CAPSULE_*` defaults, and no `CAPSULE_REPO`. This proves the
  wrapper text only; it does not prove which checkout a push uses. That is
  VH-2's job.
- **VH-1 holds.** `capsule all status`: f–j (unassigned, not created) read
  `[doctrine]`; a–e (recorded) read bare `doctrine`; every value sits under its
  header label. This does not exercise a declared profile no document backs, or
  a drifted pin (`*`/`!`), on this host; `policyCases` holds those.
- **VH-2 holds.** The user created and started `f`, which is unassigned. From
  a neutral cwd (the scratchpad) with `CAPSULE_REPO` unset,
  `capsule f provision --profile panopticon` with no ref exited 1. The usage
  names `/home/david/dev/panopticon`, which is panopticon's `path` in
  `/var/lib/capsule-profiles/panopticon.json`, and not
  `/home/david/dev/doctrine`. Next came PHASE-04's "nothing was recorded for
  'f'". `/var/lib/capsule/slot/f/` held only `allowlist` before and after (no
  `profile/`, no `assignment.json`), and `status` still read `[doctrine]` with
  no unit. This proves that the refusal on a started slot names the
  profile's document path. It does not prove that a *completed* provision
  pushes from that path: nothing was pushed, and no provision of a non-default
  profile ran to completion on this host. Side finding: the "still name the
  previous assignment" wording presumes a prior assignment, and `f` had none.
  It is cosmetic and was not filed.
- EX-2: `~/flakes/modules/nixos/capsule.nix` lines 1–3 and 59–60 describe the
  removed `repo` default; flagged to the user (outside this repo). `~/flakes`
  sets no `repo`, so the switch evaluated.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-18 · slice started · PHASE-06 completed (VH-1, VH-2 held live)

### Produced

- Design locked on the user's sign-off (`RV-007` concluded, both review lanes
  attested); `plan.toml`/`plan.md` (six phases).
- `DEC-012`…`DEC-016` (accepted; `DEC-012` wording corrected twice, `DEC-014`
  once); `design.md` sec-1…sec-5 with `fnd-1`…`fnd-46` integrated (Codex 1–12,
  Opus 13–30, fresh Opus 31–46); slice scope reconciled; runbook steps
  `review.scope`, `review.selectors` and `review.passes` discharged.
- `ISS-011` (widened by `fnd-37`); `ISS-012` (`fnd-44`, parked); `ISS-013`
  (PHASE-05: the git-channel programs' `jq` comes from the ambient `PATH`).

### Learned

- Design `inq-6`'s disposition was wrong (`fnd-1`).
- `handoff`'s `provisionSlot … || exit 1` disables errexit inside it; `work`'s
  unchecked status made a failed provision recordable (`fnd-17`), and
  `capsule-provision` exits 1 *after* the code lands in three places (`fnd-32`).
- `statusHeader` was already misaligned: `mem cur/peak` overflows `%-11s`
  (`fnd-13`).
- Source was already pinned for `brief --from-host`; the user chose to make that
  the rule (`fnd-18`, option b). `handoff` reads the pin and this host's document
  both, so it needs its own check (`fnd-33`).
- `lib/modules.nix` makes `options` throw on an unmatched definition, so a
  removed-option case must `tryEval` each check separately (`fnd-23`).
- A width case discriminates only if a fixture cell is as long as the real one
  (`[unbacked]`, ten characters).
- A `$` or backtick in single quotes is `SC2016`, fatal under
  `writeShellApplication`; `a b;touch pwned` is the hostile name shellcheck
  accepts quoted and bare (`fnd-31`, checked with shellcheck this session).
- `just build` lists every flake attribute by hand; a new check belongs inside
  an existing gate or in the justfile (`fnd-34`).
- PHASE-01: an agreement check cannot see a render-only character (both sides
  are *meant* to differ on `a$b`), so the grammar table carries each name's
  expected `profileNameOk` verdict beside the agreement; that row is what the
  `$` mutation turns red, not the agreement.
- PHASE-03: dropping the rendered `*)` branch turns nothing red — no fixture
  slot reaches it; held by its comment.
- PHASE-02: policyCases' old `unsaw "built*"` could never fail (`both` was on
  `holed` by then); status rounds now read the profile by column (`profileOf`),
  which only works because the alignment round holds.
- PHASE-04: a failed provision under `handoff` *was* recorded (generation
  moved), which is now red-then-green. Its pin round cannot discriminate
  (same bytes re-pinned); the generation round carries it. A local `given` in
  `provisionSlot` collided with `collectSlot`'s under shellcheck; `forward`.
- PHASE-05: `mkRemovedOptionModule`'s two halves are checkable at eval through
  `extendModules` plus two `tryEval`s, without a new flake attribute. A
  `grep -vq` "does not name X" round crept into the first draft, and it passed
  while the program never reached the question (item 37's shape).
- The binary refuses review policy `adversarial-then-human` (22-byte label over a
  16-byte bound) — a doctrine defect; the run uses `adversarial-only`.

### Open

- PHASE-01…PHASE-05 done (mutations watched red; REV-001 approved by the
  user and applied). `ISS-008` is fixed in code (7030e39), and its backlog
  status is for /reconcile or /close. PHASE-06 done: host switched,
  VH-1 and VH-2 held live (see "PHASE-06 evidence").
- Next: `/audit` → `/reconcile` → `/close`. Use review policy
  `adversarial-only` (see Learned).
