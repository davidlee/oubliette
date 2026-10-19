# REV REV-008 — POL-003 gains a host state root axis

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

SL-008 made the host state root a fleet declaration: `stateDir`, the tenth
required `mkFleet` argument (`DEC-054`; restated for DEC-042 as the proposed
successor DEC-058). POL-003 says one declaration per axis and no implicit
default; the state root is an axis, and it has no row. User assent (verbatim):
"a,b agreed" — b) is this revision. Left un-approved and un-applied.

### POL-003 — axis table gains a row

Add after "rooms" and before "a probe's fabric":

| axis | the one home | what it holds |
| --- | --- | --- |
| host state root | **the caller's `stateDir` argument** to `mkFleet` (`DEC-054`) | the directory under which slot records, volumes and quarantines live. Required, with no implicit default: a canonical absolute path, refused at eval otherwise |
