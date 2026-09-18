# Review RV-008 — reconciliation of SL-001

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

The closure audit of `SL-001` (*a slot may declare which target it is for*).
Six phases `completed`, lifecycle moved `started → audit`, head `b243d8d`, tree
clean apart from the user's `flake.lock`.

**Surface reviewed.** The main worktree at `b243d8d`. This slice was driven
solo, not by `/dispatch`, so there is no candidate branch. The subject is
`git diff 648f98f..b243d8d` outside `.doctrine/`: 17 files. PHASE-01…05 built
it, and PHASE-06 produced live evidence only.

**Gate, run before raising.** `just` exited 0: check, build, `hostModuleUnits`,
every `*Cases` suite and fmt. `doctrine slice verify-vt SL-001` passes every
`VT` except PHASE-05 `VT-4`, which is unattributable by construction (see
`F-5`). `doctrine check gate` still resolves to a `just gate` recipe that does
not exist; that is `CHR-015`, filed from `RV-006`, so it is not raised again.

### Lines of attack

1. **Does the registry tell the truth?** `slice conformance`'s undeclared and
   undelivered cells, and whether each recorded phase range is the range that
   phase actually landed.
2. **Does the code do what design sec-2…sec-4 say?** Every row of sec-5's code
   impact table and sec-4's prose table; every row of sec-3's caller table;
   `provisionSlot` and `recordProvisioned` under errexit; `handoff`'s path
   comparison and its ordering against anything destructive. This lane ran as
   an independent read-only pass over the diff.
3. **Can each case fail?** The design names a case for most mutations; the
   phase sheets' VA logs are the evidence, and they are disposable
   (gitignored).
4. **Is each claim's evidence its own?** `STD-001`: VH-2 is a refusal, not a
   push, and must not be read as a completed provision from panopticon's path.
5. **What was found and never filed?** The phase sheets' Findings sections and
   the notes' "fourth pass" questions.

### Invariants the slice is held to

- `POL-002` as revised by `REV-001`: the target's name appears in code only in
  `target.nix`, `inputs.target.url` and `capsules.nix`'s `profile` values, plus
  the declared `.doctrine/` layout fixtures.
- `POL-003` as revised: resolution is the front end's act, in the order flag,
  record, declaration, sole document.
- `POL-004`: every new behaviour is reachable by a case suite through an
  argument, not a host path.
- `DEC-012`…`DEC-016`.
- A provision that exited non-zero is never recorded, and a pin is never left
  without a record except when that one write fails.

## Synthesis

**Verdict: closeable.** There are ten findings and no blocker. Seven were
fixed in the audit, one goes to the reconciliation brief, one is tolerated and
one is aligned. The fixes are committed at `35fa6de`, and `just` exited 0
after them.

**The finding that mattered is `F-6`, and the slice created it.** PHASE-04
made the record write "checked" by putting it behind `|| return 1`. That check
switched errexit off inside `recordWrite`. A failed jq then emptied the record,
and the provision reported success. On the plain verb this was a regression:
before the check, errexit killed the run with the record intact. The design had
also written the case off: "a stub cannot make `recordWrite` fail without a
seam". But a corrupt `assignment.json` makes it fail, and the new round uses
exactly that. The mechanism is now `mem.fact.oubliette.checked-call-disables-errexit-inside-it`.
The same class reached the unit, purpose and policy writes, and the one fix in
`recordWrite` covers all of them. Only the independent read-only pass saw this.
None of the three design passes did, and neither did the phase's own mutation
table, because the mutation it named ("drop the `|| return 1`") could only ever
stay green.

**Everything else held when re-read against the code.** Every row of sec-5's
code-impact table and sec-4's prose table was delivered, apart from the
ownership row that `F-9` fixed. The resolution order, the escaping, answer 3,
"declares", the brackets, the column widths, the forwarding and `handoff`'s
ordering all match the design. The `POL-002` search is clean. Every VT
verifies (`F-5` explains the one it cannot attribute). Every VA mutation went
red, and notes.md now keeps the record (`F-3`).

**The notes' four open "fourth pass" questions are answered.**

- `setup` did report "nothing was recorded" wrongly (`F-7`, fixed).
- When the source's record and pin disagree (`name!`), `profileDirFor` falls
  back to this host's document, as `fetch` does, so `handoff` compares like
  with like.
- `land` reads only the pin (`fetchSlot`, `repoFor`), so a moved checkout lands
  in the old path, consistent with the pinned-source rule.
- The second module evaluation in `checked` costs nothing visible: `just` is
  green.

**Standing risks, and what the evidence does not prove.**

- **VH-2 is a refusal, not a push.** It shows the module path names
  panopticon's `path` before any push. It does not show a completed provision
  of a second target, which is `IMP-006`/`CHR-011`'s.
- **Held by text alone:** the rendered `*)` branch, the race that the forwarded
  `--profile` closes, the `misprofiled` assertion, and a failed `mv` in
  `recordWrite` (only the jq failure is driven).
- **Tolerated (`F-8`):** `handoff` refuses a moved checkout even under
  `CAPSULE_REPO`. It is safe, but a false refusal.
- **Pre-existing and parked:** `ISS-011` (the guest readers take the slot, not
  the resolved profile), `ISS-012` (`--force` recorded as the ref), and
  `ISS-013` (the git-channel programs' ambient `jq`).
- `doctrine check gate` still resolves to a recipe this repo does not have
  (`CHR-015`).

## Reconciliation Brief

### Per-slice (direct edit)

- **`F-2`: docs/status.md.** The load-bearing change is
  `doctrine slice selector add` with `docs/status.md` as a `design-target`
  (intent: status's Now row names the brackets, `DEC-014`). Mirror it with a
  row in design sec-5's code impact table.
- **`F-6`: host/record.nix.** The load-bearing change is
  `doctrine slice selector add` with `host/record.nix` as a `design-target`
  (intent: `recordWrite` exits on its own failed jq or mv, because a checked
  caller switches errexit off). Design edits:
  - sec-5 code impact gains the row.
  - sec-3 "With the pin": the write's failure is stopped inside `recordWrite`,
    not only at the call. The `|| return 1` alone was the defect. The
    provision prints "provisioned, but could not record it".
  - sec-5's "Not exercised" paragraph loses its claim that a stub cannot make
    `recordWrite` fail. A corrupt record does, and the case
    *a record the write cannot rewrite fails the provision* drives it.
  - The mutation table row "drop the `|| return 1` on the record write → none"
    becomes "drop `recordWrite`'s own exit on jq → that case".
- **`F-4`, `F-7`: design sec-3's quoted failure message.** It becomes the
  shipped text: "nothing was recorded for '$n' by this provision, which did not
  complete — the slot's profile, pin and base are as they were. A provision
  that completes records them."

### Governance/spec (REV)

- None. `POL-002` and `POL-003` were revised inside the slice (`REV-001`,
  applied), and the audit found them consistent with the code.

### Backlog

- `ISS-008` is fixed in code (`7030e39`) and closed live on the module path by
  PHASE-06 VH-2. Move it to resolved at `/reconcile` or `/close`.

## Reconciliation Outcome

### Direct edits applied (with the user's agreement)

- **Selector registry:** `docs/status.md` and `host/record.nix` added as
  `design-target` (`F-2`, `F-6`).
- **Registry range:** PHASE-06 widened to end at the reconcile commit, so the
  audit fix `35fa6de` is inside a recorded range. This is the only shape
  `record-delta` accepts (one contiguous range), and it attributes the audit and
  reconcile commits to PHASE-06. That over-attributes, deliberately.
- **design.md sec-3:**
  - the quoted failure message is the shipped one (`F-4`, `F-7`);
  - "With the pin" says the check alone was the defect, and that
    `recordWrite` exits on its own (`F-6`).
- **design.md sec-5:**
  - the code impact table gains `host/record.nix` and `docs/status.md`
    (`F-2`, `F-6`);
  - the Provision bullets gain the corrupt-record case;
  - the mutation table's record-write row names that case;
  - "Not exercised" drops the record-write claim and says a failed `mv` is not
    driven (`F-6`).
- **Backlog:** `ISS-008` resolved (fixed).

### REVs completed

- None needed. `REV-001` (`POL-002`, `POL-003`) was applied inside the slice.

### Withdrawn / tolerated

- `F-8` tolerated: `handoff` refuses a moved checkout even under
  `CAPSULE_REPO`. The rationale is in the disposition.
- `F-5` aligned.

Reconcile pass complete. Handoff to `/close`.
