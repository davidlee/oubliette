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

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-18 · design reviewing (run revision 44) · Opus review integrated

### Produced

- `DEC-012`…`DEC-016` (accepted; `DEC-012` and `DEC-014` wording corrected);
  `design.md` sec-1…sec-5 with `fnd-1`…`fnd-30` integrated (Codex 1–12, Opus
  13–30); slice scope reconciled; `review.scope` discharged (revision 40).
- `ISS-011` — cross-target re-provision reads HEAD under the old document.

### Learned

- Design `inq-6`'s disposition was wrong (`fnd-1`).
- `handoff`'s `provisionSlot … || exit 1` disables errexit inside it; `work`'s
  unchecked status made a failed push recordable (`fnd-17`).
- `statusHeader` was already misaligned: `mem cur/peak` overflows `%-11s`
  (`fnd-13`).
- Source was already pinned for `brief --from-host`; the user chose to make that
  the rule (`fnd-18`, option b).
- `lib/modules.nix` makes `options` throw on an unmatched definition, so a
  removed-option case must `tryEval` each check separately (`fnd-23`).
- A width case discriminates only if a fixture cell is as long as the real one
  (`[unbacked]`, ten characters).
- The binary refuses review policy `adversarial-then-human` (22-byte label over a
  16-byte bound) — a doctrine defect; the run uses `adversarial-only`.

### Open

- Human review of the revised sections; section attestations; the lock.
- Whether a second adversarial pass runs on the revised text (Codex quota, or
  Opus again).
