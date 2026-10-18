# REV REV-006 — POL-003's rooms row declares each user's uid

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

SL-005 PHASE-10 fixed RSK-012: a room's root fs is tmpfs, so a user's uid must be
declared, not assigned in name order, or adding a user re-owns `/home`. The
declaration shape changed to `{ uid; keys; }`, and POL-003's rooms row must say
so. User assent, verbatim: "3. agreed".

### POL-003 — the rooms row of the axis table

Before: "per room: declared users with their ssh public keys, and declared sizes …"

After: "per room: declared users, each `{ uid; keys; }` — a declared uid in
1000–29999 and their ssh public keys — and declared sizes (`vcpu`, `mem`,
`volume`). No kind. Required, with no implicit default: a consumer with no rooms
writes `rooms = {}`"
