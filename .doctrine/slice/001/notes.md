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

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-18 · slice ready · design locked (run revision 55) · plan committed (7d434af), six phase sheets materialised

### Produced

- Design locked on the user's sign-off (`RV-007` concluded, both review lanes
  attested); `plan.toml`/`plan.md` (six phases).
- `DEC-012`…`DEC-016` (accepted; `DEC-012` wording corrected twice, `DEC-014`
  once); `design.md` sec-1…sec-5 with `fnd-1`…`fnd-46` integrated (Codex 1–12,
  Opus 13–30, fresh Opus 31–46); slice scope reconciled; runbook steps
  `review.scope`, `review.selectors` and `review.passes` discharged.
- `ISS-011` (widened by `fnd-37`); `ISS-012` (`fnd-44`, parked).

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
- The binary refuses review policy `adversarial-then-human` (22-byte label over a
  16-byte bound) — a doctrine defect; the run uses `adversarial-only`.

### Open

- PHASE-01…PHASE-06 unstarted; next is `/phase-plan PHASE-01` then `/execute`.
- PHASE-03 `VH-1`: the user approves the POL-002/POL-003 revisions before apply.
- PHASE-06 needs the user's host switch (`~/flakes`).
