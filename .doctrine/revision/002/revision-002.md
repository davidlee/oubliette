# REV REV-002 — reconcile SL-003

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

## Reconcile narrative

SL-003 split the guest image per target: targets live in `targets/`, each has a
tool-set flake in `flake.nix`'s `targetFlakes`, and a declared slot boots the
image its `profile` names (DEC-017, DEC-018, DEC-019). Both policies still
described one target in `target.nix`.

- [RV-011 F-9] **POL-002**: the list of where a target's name may appear is now
  `targets/`, `flake.nix`'s target inputs and `targetFlakes`, the probe subject
  (`probeTarget`), and a slot's `profile`. In limbs 1–2, `target.nix` becomes
  `targets/` / the target's file.
- [RV-011 F-9] **POL-003**: the confined-repo row moves to `targets/` and names
  `targetFlakes` and the eval check that both name the same targets. The slots
  row says a declared slot's `profile` is also the build binding. "No perimeter
  value lives in `target.nix`" becomes "in a target's file".
- Landed with the rows: POL-002's *Excluded* list and its NOTES item 31 reference,
  and POL-003's `target.guestPath` exclusion, which still named `target.nix` in
  the present tense.
