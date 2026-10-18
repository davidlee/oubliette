# REV REV-005 — POL-004 says what two callers proved and did not

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

SL-005 built rooms beside slots (design sec-8). POL-004's rationale still names
Plan E as "the first test" of separability; that test has now run, and the
rationale should say what it proved and what it did not. User assent, verbatim:
"4. agree".

### POL-004 — Rationale, first paragraph

Before: "… or a guest that is not a capsule at all (`docs/plan-e-room.md`, the
first test of whether the machinery underneath is separable from the product)."

After: "… or a guest that is not a capsule at all (`docs/plan-e-room.md`). SL-005
ran that test with two callers: one `capsule-netns`, one unit set and one guard
serve both slots and rooms. It did not prove the room module itself separable —
the two fixture rooms differ only in values, and the room module first meets a
second shape at Plan E's tailnet ingress or Plan F's repos."
