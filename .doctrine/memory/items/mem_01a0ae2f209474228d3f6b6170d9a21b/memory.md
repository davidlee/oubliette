`doctrine slice conformance` reads `.doctrine/state/slice/NNN/boundaries.toml`
and reports three cells — undeclared, undelivered, conformant — by comparing the
paths those recorded ranges touched against the slice's `design-target`
selectors. **Every one of those cells assumes the ranges are right.** A row whose
`code_start_oid`/`code_end_oid` name the wrong commits produces a perfectly
clean-looking report.

Two shapes, both found in one slice at `SL-002`'s closure audit (`RV-006` `F-3`,
`F-4`):

- **A gap between rows.** Work that lands without flipping a phase status —
  a review's remediation commits, typically — is covered by no row. Only a path
  that is *new* in that gap shows up, as `undelivered`; every path an earlier
  phase already delivered stays `conformant` and hides the rest.
- **A row over the wrong commits.** PHASE-06's row covered an unrelated
  `chore:` commit and excluded the phase's own. Nothing in the report moved,
  because the file that chore touched was already delivered elsewhere.

**The read that finds both**, and it is cheap:

```sh
cat .doctrine/state/slice/NNN/boundaries.toml
git log --oneline --reverse <first-start>^..HEAD
```

Walk the rows against the log. Every commit should fall inside exactly one row,
and every row should contain the commits its phase's notes claim. Then size any
repair before proposing it — `git diff --name-only <a> <b> | grep -v '^\.doctrine/'`
says what a widened range would actually attribute.

**Repairing is `doctrine slice record-delta <id> PHASE-NN --start <a> --end <b>`,
and it UPSERTs by phase** — one contiguous range per phase, no second row. So
work that amends two phases can only be attributed to one of them, and the
over-attribution belongs in `notes.md` beside the range rather than left for the
next reader of `boundaries.toml` to discover.

Neighbour: [[mem.pattern.oubliette.a-mutation-must-reach-the-case]] — same
family, a check that agrees with itself.
