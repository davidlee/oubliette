# REV REV-009 — reconcile SL-008

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

## Reconcile narrative

- [RV-024 F-5]: POL-003's host-state-root row (landed by REV-008) said
  `stateDir` holds "slot records, volumes and quarantines". Volumes live under
  `microvms` (default `/var/lib/microvms`, host/cli.nix:107; host/volume-root.nix).
  What `stateDir` holds is slot records (host/services.nix `slotRoot`), the
  scrub marker, quarantines and each room's known_hosts (`rooms.stateDirOf`).

### POL-003: the host state root row, "what it holds"

Before: "the directory under which slot records, volumes and quarantines live."

After: "the directory under which slot records, the scrub marker, quarantines
and each room's known_hosts live; volumes are not under it."

The same correction goes into DEC-058's record body as a dated amendment line;
the decision itself is unchanged. User agreement: "agreed" (2026-10-20), given to
the reconcile proposal for RV-024's brief.
