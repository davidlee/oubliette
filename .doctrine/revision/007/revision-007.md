# REV REV-007 — POL-003's rooms row gains repos, policy and a work volume

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

SL-006 (assistant room over many repos) lets a room hold clones. DEC-048 chose to
declare them as target names on the room, resolved against `targets` at eval.
DEC-046 chose to bound a room's collects by a named policy. Both put a new field
on the rooms axis, so the row that names that axis's one home must say what it
holds. The fields come from existing axes (`targets`, `policies`) and are not new
homes; that is what POL-003 requires. This extends DEC-033's shape and does not
replace it. Assent: the user replied "agreed" in session (2026-10-18), after the seat laid out this row change.

### POL-003 — the rooms row of the axis table (`.doctrine/policy/003/policy-003.md:14`)

Home, before: "**the caller's `rooms` argument** to `mkFleet` (`DEC-033`)"

Home, after: "**the caller's `rooms` argument** to `mkFleet` (`DEC-033`, `DEC-048`)"

Holds, before: "per room: declared users, each `{ uid; keys; }` — a declared uid in
1000–29999 and their ssh public keys — and declared sizes (`vcpu`, `mem`,
`volume`). No kind. Required, with no implicit default: a consumer with no rooms
writes `rooms = {}`"

Holds, after: "per room: declared users, each `{ uid; keys; }` — a declared uid in
1000–29999 and their ssh public keys — and declared sizes (`vcpu`, `mem`,
`volume`). No kind. **Optionally, and only all together**: `repos = { user;
targets; }` — names from the `targets` axis, owned by one of the room's declared
users, a repo's tools coming from its target and never from a second declaration
— `policy`, a name from the `policies` axis that bounds and permits the room's
collects (`DEC-046`), and `sizes.work`, the `/work` volume. A room without them
is unchanged. Required, with no implicit default: a consumer with no rooms writes
`rooms = {}`"
