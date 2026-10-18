# REV REV-004 — POL-003 gains a rooms axis, and borrowed moves to fabric.nix

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

SL-005 PHASE-04 made `rooms` the ninth required `mkFleet` argument (DEC-033; restated
for DEC-025 as DEC-042) and moved the `borrowed` check from `mkfleet.nix` to
`fabric.nix`, where `liveNames` now includes each room's `room-<name>` namespace.
Design: `.doctrine/slice/005/design.md` sec-10. User assent (verbatim):
"3. a) agreed b) agreed" — b) is this revision. Left un-approved and un-applied.

### POL-003 — axis table gains a row

Add after "the confined repos" and before "a probe's fabric":

| axis | the one home | what it holds |
| --- | --- | --- |
| rooms | **the caller's `rooms` argument** to `mkFleet` (DEC-033) | per room: declared users with their ssh public keys, and declared sizes (`vcpu`, `mem`, `volume`). No kind. Required, with no implicit default: a consumer with no rooms writes `rooms = {}` |

### POL-003 — Rationale, the `borrowed` paragraph

Before: "`borrowed` (in `mkfleet.nix`), its intersection with what the caller's `fleet` declares, **throws at eval** ..."

After: "`borrowed` (in `fabric.nix`), its intersection with what the caller's `fleet` and `rooms` declare, **throws at eval** ..., and `liveNames` includes each declared room's `room-<name>` namespace, so a probe may not borrow a room's namespace either."

### RSK-005 — one line added

"One resolvable attr per declared room, each with a drop-in that supplies its namespace: `microvm -c <room>` resolves a `nixosConfigurations` attr as a slot does, so the risk widens only by declared names."
