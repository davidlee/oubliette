# REV REV-001 — A slot's declared profile is a named exception to POL-002 and a step in POL-003's order

Revision (ADR-013) — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

SL-001 lets a slot declare which target it is for (`profile` in
`capsules.nix`), and the front end resolves that declaration between the record
and the sole document. Both policies state rules the field changes, so they
move in the same commit as the code and `docs/contract-target.md` (SL-001
`DEC-012`; design sec-2, "Governance").

The warrant is convenience, not necessity: an unassigned slot with no target is
a fine state, and there is no `profiles` set because an assigner is
unconstrained in `profile` (`docs/contract-assignment.md`, *Who may assign*).

### POL-002 — Statement, "exactly two places"

Before:

> **`doctrine` may appear in exactly two places**: `target.nix`, and
> `inputs.target.url`, which cannot be computed.

After:

> A target's name may appear in code (`*.nix`, `*.sh` and the justfile,
> outside comments, `.doctrine/` and the tool configuration — `.mcp.json`,
> `.claude/`, `.codex/`) only in `target.nix`, `inputs.target.url`, and as a
> slot's `profile` value in `capsules.nix`. Generic source never hardcodes a
> target's identity or branches on it; a host-declared value may be threaded
> into a generated front end. A case suite's fixture may reproduce a target's
> layout as data, since a fixture is what a program is run against, not what it
> is.

The list keeps the rule checkable by search: in those files and outside
comments, a hit anywhere else is a violation. The following sentence (nothing
target-shaped in `perimeter/`, `vm/capsule.nix` or the justfile) is unchanged.

### POL-002 — Statement, "No program carries"

Before:

> **No program carries a target's values or its name — nor its own existence.**

After:

> **No program carries a target's values or its name — except a host-declared
> value threaded into the generated front end — nor its own existence.**

Without this, the first change contradicts it: `slotDeclaredProfile` is exactly
such a value in exactly such a program. It is built into the store, not written
in the repo, so the search above still holds.

### POL-002 — Scope, Excluded

Adds: a slot's `profile` value in `capsules.nix`, alongside `target.nix` and
`inputs.target.url`.

### POL-003 — Statement, the slots row

Before: `which slots exist (a…j) and the policy set an assigner may select within`

After: `which slots exist (a…j), the policy set an assigner may select within,
and the profile each slot declares — a convenience, with no set beside it`

### POL-003 — Statement, resolution order

Before:

> resolves which target a verb means by explicit flag, then the slot's record,
> then the one profile this host declares, refusing when several.

After:

> resolves which target a verb means by explicit flag, then the slot's record,
> then the slot's declared profile, then the only document in the profile
> directory, refusing when there are none or several. **A slot's declared
> profile is not the implicit default this policy forbids**: it is declared,
> per slot, in the axis's one home, and a name no document backs refuses at use
> rather than resolving to something else.

The last step is renamed because "declares" now names the new step.
