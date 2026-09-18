# A slot may declare which target it is for

## Context

This host declares two targets as of 2026-08-17 (`IMP-004`): `doctrine.json` is
the module's own render and `panopticon.json` is hand-written host state with no
copy in this repo. `profileNameFor` (`host/cli.nix`) resolves a slot's target in
three steps — an explicit `--profile`, the slot's assignment record, then the one
document this host has rendered — so the five unassigned slots now refuse every
`profileVerb`, naming both targets. The refusal is correct and was designed for
(`NOTES item 51` decision 3). What is missing is the operator's ability to say
which target an unassigned slot is *for*, the way they already say which policy
it runs.

Two things settled before this slice was cut, both from `IMP-007`'s own framing:

**The `Plan D` §0 tension resolves as declaring, not inferring.** §0's claim is
about a slot's *name*: nothing may read meaning out of the letter `f`. A declared
field is the opposite mechanism — the meaning is written where it can be read,
changed and refused. `capsules.nix` already makes this argument verbatim for
`policy`. What does **not** transfer is the warrant. Policy's is necessity —
*absence is not a state a perimeter may be in* — and a target's absence is a
perfectly fine state for an unassigned slot. So this is a convenience, and the
field says so rather than borrowing the perimeter's sentence.

**The policy axis is the precedent for one field, not two.** `policy` +
`policies` are two statements because a policy is a *control*, and a set is what
makes `capsule <slot> policy <name>` safe to delegate.
`docs/contract-assignment.md` § *Who may assign* already commits the other way
for this axis: *"an assigner is unconstrained in `profile`, `base` and `purpose`,
and constrained to a declared set in `policy`, `class` and `extras`."* Profile is
semantics, and semantics is what delegation is for. A `profiles` set would
reverse that on the one axis that document names as unconstrained by design.

**And the field is worth little while `ISS-008` stands.** `host/wrap.nix` exports
`CAPSULE_REPO` as a default from `cfg.repo` — one target's checkout — and
`host/git-channel.nix:134` is `src="${CAPSULE_REPO:-$profile_path}"`. The wrapper
always sets it, so the document's `path` is unreachable on the module path.
Declaring that slot `f` defaults to panopticon and then having
`capsule f provision` push doctrine's checkout, exit 0, is a worse failure than
today's honest refusal. The two land together or the first one lies.

## Scope & Objectives

1. **A `profile` field per slot in `capsules.nix`** — the host operator's
   declared choice of target for a slot nobody has assigned. Optional in
   `recordOf` for the same reason `policy` is (`guardCases`' fixture constructs
   instances that are not slots).

2. **A fourth step in `profileNameFor`**, between the assignment record and the
   refusal: an explicit `--profile`, then the record, then the slot's declared
   default, then the one rendered document, then refuse. Resolution stays the
   front end's act and never a program's (`item 20`).

3. **The declared default is validated at run time and cannot be validated at
   eval, and the field says so.** `policy` is checked by `capsules.nix`'s
   `undeclared` assertion against `policies.nix`; no equivalent exists here,
   because `profileDir` is run-time state outside the store (`item 52`) and the
   second document has no copy in this repo. A slot naming a profile no document
   backs must refuse when the slot is used, naming the directory it looked in.
   **`DEC-015`: no new check** — `profileLoad`'s existing refusal does this, and
   the status cell's `[name]` attributes the name to a non-record source. In
   passing, `profileLoad`'s hint that a document is *"rendered from target.nix"*
   is corrected: a document may be hand-written.

4. **`capsule all status` distinguishes an assignment from everything else.**
   **`DEC-014`**: `[doctrine]` for *any* resolution without a record — the
   declared default and the pre-existing sole-rendered-document fallback alike —
   bare `doctrine` (with its `*`/`!` markers) for a record, `-` for neither.
   Brackets never carry `*` or `!`, since only a provision writes a pin. A
   default that renders identically to a record is a default that will be read
   as one, and the sole-render fallback already did.

5. **`ISS-008`** — the module path reaches the profile document's `path` when
   nothing in the environment names a repo, and `CAPSULE_REPO` still beats the
   document when something does (`host/git-channel-cases.nix:150` stays green).
   **`DEC-013`**: `host/wrap.nix` stops supplying `CAPSULE_REPO` (four defaults,
   with the reason stated), and `services.capsule-perimeter.repo` is removed via
   `lib.mkRemovedOptionModule`. Both readers are fixed by that one change —
   `capsule-provision`'s `src` and the front end's `repoFor`, which is where
   `fetch` writes.

5a. **`DEC-012`: a `POL-002` revision.** Its *"exactly two places"* sentence
   narrows to code, programs and printed text; a profile name as a key in a host
   declaration is a value, not a learned target. Via `doctrine revision`, in this
   slice, with `docs/contract-target.md` in the same commit as the boundary move.

5b. **`DEC-016`: the values.** All ten slots declare `profile = "doctrine"` —
   the only image this host builds. A split with a second target waits on
   `IMP-006`.

6. **Cases**, and the kinds are not interchangeable (`CLAUDE.md`). Objectives 1-4
   are the third kind — a program's own text against a fixture, in
   `host/policy-cases.nix` (which already owns the front end's resolution
   fixtures) and `host/profile-cases.nix`. Objective 5 is the **fourth** kind:
   the defect lives in the composition of wrapper and program, which is exactly
   what `wrapCases` exists for and exactly the gap `ISS-004` shipped through —
   `wrapCases` asks whether a caller's value survives, and nobody asks whether the
   program's own fallback is still reachable when no caller sets one.

7. **Documentation the change moves**: `docs/contract-assignment.md`'s ownership
   table (the `profile` noun gains a host-declared default without gaining a
   host-declared *set*), `docs/plan-d-fleet.md` L1's "the cheap insurance was not
   taken" sentence, and `capsules.nix`'s own comment carrying the warrant.

### Affected surface

`capsules.nix`, `host/cli.nix` (`profileNameFor`, the status table's profile
cell), `host/wrap.nix`, `host/services.nix` (`repo` option removed),
`host/profile.nix` (`profileLoad`'s hint), `host/policy-cases.nix`,
`host/profile-cases.nix`, `host/wrap-cases.nix`, `docs/contract-assignment.md`,
`docs/contract-target.md`, `docs/plan-d-fleet.md`, `POL-002` (revision).
Outside this repo: `~/flakes/modules/nixos/capsule.nix`'s comment names
`repo` — the user's to edit.

## Non-Goals

- **`profiles`, the selectable set.** Out, and on the contract's authority rather
  than on cost — see Context. If it is ever wanted it is a delegation boundary
  and its own slice, and it would need `contract-assignment.md` changed first.
- **The image tier.** `IMP-006` — a second target *running* is a second guest
  image and a per-slot `capsuleVm`, which is `Plan D` D7 / `IMP-003`. This slice
  gives that work the field it needs and nothing else; a slot declaring a profile
  today still boots the one image this host builds.
- **`RSK-002`'s two build-time absent paths** (`caches = {}`,
  `guestConfig = {}`). Unreachable from a document or a fixture by construction;
  they are `IMP-006`'s.
- **A `defaultProfile` host-level option** (`IMP-007` shape 2). Rejected:
  `POL-003` — an implicit default in a declaration's clothes — and it cannot
  answer `IMP-006`'s question of which image a given slot is, so it would be
  replaced on contact with the tier above.
- **Driving a live provision on a second target.** `CHR-011` and `IMP-004`'s
  step 3 own the arrangement half; nothing here goes near the slot driving
  doctrine's `SL-251`.

## Summary

The operator gains one field per slot saying which target that slot is for when
nobody has assigned it, and the module path stops answering the source question
on the document's behalf. Together they make a declared default mean what it
says: a verb on an unassigned slot resolves to a target *and* to that target's
repo.

### Risks and assumptions

- **Decided** (`DEC-013`): the wrapper stops supplying `CAPSULE_REPO` and
  `cfg.repo` is removed. The cost is the owner-relative default: a host whose
  human differs corrects `target.nix`'s `path` or its document.
- **Assumed**: `docs/contract-assignment.md`'s ownership table can gain a
  host-declared default under `profile` without disturbing *"an assigner is
  unconstrained in `profile`"* — a default is what applies when no assigner has
  spoken, not a constraint on one who has. If design finds that reading strained,
  the contract change is the deliverable and the field waits on it.
- **Risk**: objective 4's `[name]` signifier is a table-shape change, and the
  status table is the one surface `IMP-004` observed working unmodified across
  two targets. A cell that changes rendering is a cell whose absent path (`-`)
  and whose record path must both stay pinned.
- **Settled** (design `inq-6`): a declared default and `pinProfile` do not
  conflict. `host/cli.nix:535` resolves a provision's profile once and forwards
  it as an explicit `--profile`, so `provisionSlot`'s second resolution takes the
  flag step; after the record is written the record step precedes the default.

### Verification and closure intent

Green `just build`, which is where all four kinds of check live — **including any
new suite**, since `observeCases` and `baselineCases` were once wired into
`just cases` and left out of `just build` for a session (`NOTES item 51` step 3).
Each new case asserts the *reason* and not only the exit status, and each is
checked to fail by mutating the behaviour it claims to pin.

Closure needs one thing a suite cannot give: the module path driven on this host
with both documents present and one slot declaring a default — read-only verbs,
plus whatever `ISS-008` needs to show the document's `path` is reached. That is
the same arrangement gap `IMP-004` closed for the refusal and `CHR-011` still
holds for provision, and this slice does not close `CHR-011`.

## Follow-Ups

- `IMP-006` gains its precondition and stays open.
- `IMP-007` closes with this slice; `ISS-008` closes with it.
- If `/design` finds the contract's ownership table needs changing rather than
  extending, that is a `REV` against a governing artifact and not a slice edit.
