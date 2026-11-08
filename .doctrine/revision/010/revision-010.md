# REV REV-010 — reconcile SL-010

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

## Reconcile narrative

- [RV-028 F-4]: SL-010 added two declarations that POL-003's axis table did not name, and design sec-7 deferred the table edit to reconcile. The addressing row's list gains **the model door** (`net.modelDoor`: port, socket). The slots row gains **each slot's `modelDoor`** (`"on"` / `"off"` / absent), where absent means the slot has no door. The policy's statement and its no-default rule are unchanged: the slot's value is declared per slot and has no default, and the verb's override is front-end state in the record, as `policy` is.
