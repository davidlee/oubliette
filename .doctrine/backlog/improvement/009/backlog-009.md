# IMP-009: Status is too wide to read

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised by the operator during `SL-002`'s design (2026-09-15): *"status is already
borderline illegibly wide, it likely needs splitting into a few separate
subcommands, to take --columns, or something."*

`capsule all status` prints 18 columns on one row per slot (`host/cli.nix:926`):
`created vm proxy relay door answers head dirty baseline age disk mem cur/peak
refs gen profile policy unit purpose`. `DEC-009` adds a nineteenth, a host-side
allocation column, and a free-space line under the table.

## The constraint any fix must keep

`host/cli.nix:916` says there is **one format, one header and one row, with no
column that comes and goes** (`NOTES item 51` decision 3). It is one table over N
slots and M targets, so a shape that depended on any one of them would change
between two runs on one host silently. `POL-002` says the same for printed text.
A `--columns` flag chosen by the *caller* is compatible with that. A column that
appears only when some slot has a value is not.

## Candidate shapes, not yet weighed

- **Split by the question asked.** Plan D's D5 grouped status by steering
  question, and the columns already fall into groups: lifecycle (`created vm
  proxy relay door answers`), work (`head dirty baseline age refs`), resources
  (`disk alloc mem`), assignment (`gen profile policy unit purpose`). A few
  subcommands, or a default view plus named ones.
- **`--columns`**, with a declared default set.
- **A narrower default** that drops the lifecycle detail to one derived state
  column, with the full set behind a flag.

Whatever is chosen needs a suite. Today `observeCases` pins only the guest half
(the tab-separated line), and a grep of `host/*-cases.nix` on 2026-09-15 found
nothing that pins the table's header or column order. A split view has no
suite to inherit.

## Not exercised

Nothing is designed or built. The column list was read from `host/cli.nix` on
2026-09-15.
