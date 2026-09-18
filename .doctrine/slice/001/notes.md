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
fresh-as-of: 2026-09-18 · design reviewing (run revision 33) · findings integrated

### Produced

- `DEC-012`…`DEC-016` (accepted; `DEC-012` wording corrected per `fnd-6`);
  `design.md` sec-1…sec-5 revised with `fnd-1`…`fnd-12` integrated; slice scope
  reconciled (objectives 3, 4, 4a, 4b, 5a, 6, 7; risks).

### Learned

- Design `inq-6`'s disposition ("a provision resolves its profile once") is
  **wrong** — superseded by `fnd-1`: `provisionSlot` resolves, then `work`'s
  dispatch re-resolves from the original argv.
- `recordProvisioned` can leave a pin with no record (`fnd-2`); `profileDirFor`
  serves it.
- `fnd-1`'s race has no seam a fixture can reach: removing the forwarded
  `--profile` turns no case red (sec-5 says so). The finding's suggested
  "stub rewrites the record mid-run" case was not adopted for that reason.
- A column overflow in `statusFmt` leaves fields space-separated, so only an
  offset check sees it (sec-5).
- `mkRemovedOptionModule` reports through `config.assertions`, so the removal
  message is readable at eval (`fnd-7`'s case).
- The binary refuses review policy `adversarial-then-human` (22-byte label over
  a 16-byte admission bound) — a doctrine defect; the run uses
  `adversarial-only`.

### Open

- User confirmation of the scope growth: objective 4a (provision behaviour on
  `CHR-011` bug 3's branch) and the `POL-003` revision.
- Human review of the revised sections (the user's; the run's policy is
  adversarial-only), then the `review.scope` runbook step and the lock.
