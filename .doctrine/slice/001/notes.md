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
fresh-as-of: 2026-09-18 · design reviewing (run revision 29) · 4879de8+

### Produced

- `DEC-012`…`DEC-016` (accepted); `design.md` sec-1…sec-5; 13 design-target
  selectors; run findings `fnd-1`…`fnd-12` (Codex, all accepted, repairs in
  each finding's `resolution`).

### Learned

- Design `inq-6`'s disposition ("a provision resolves its profile once") is
  **wrong** — superseded by `fnd-1`: `provisionSlot` resolves, then `work`'s
  dispatch re-resolves from the original argv.
- `recordProvisioned` can leave a pin with no record (`fnd-2`); `profileDirFor`
  serves it.
- The binary refuses review policy `adversarial-then-human` (22-byte label over
  a 16-byte admission bound) — a doctrine defect; the run uses
  `adversarial-only`.

### Open

- Integrate `fnd-1`…`fnd-12` into sec-1…sec-5 and the slice scope; `POL-003`
  now also needs a revision (`fnd-3`); `DEC-012`'s "key" wording → "value"
  (`fnd-6`).
- Human review of the revised sections (the user's; the run's policy is
  adversarial-only).
