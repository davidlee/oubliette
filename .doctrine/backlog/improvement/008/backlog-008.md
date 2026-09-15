# IMP-008: Status shows whether a slot is a clean clone source

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised during `SL-002`'s design (2026-09-15). The question was: *"if I'm
considering a clone and want to know whether a slot is clean or dirty, how do I
find out?"*

`DEC-007` lets `capsule <slot> volume clone-from <m>` take any stopped declared
slot as its source. It says outright that the clean-source rule in
`docs/contract-assignment.md` (a source should be `baselined` and not `dirty`)
is **not enforced**, because every signal behind that rule is read through the
guest and the source has to be stopped. So the operator judges it, and today
nothing adds the judgement up for them.

## What the operator can see today

This is only available while the slot is running. A stopped slot shows `-` in
every observed column.

| signal (`contract-assignment.md`, *States*) | today |
| --- | --- |
| worktree dirty | the `dirty` column in `capsule all status` |
| `head_oid != base.oid` | by eye only: the `head` column against `capsule <slot> record`'s `base.oid` |
| baseline ok **at the current head** | half: `baseline` and `age` show the last verdict, and the commit it ran on is in `history.tsv` but `host/observe.nix` discards it |
| `$HOME` touched since the baseline | nothing |
| an interactive session opened | nothing (Plan D `D6`, `IMP-002`) |

The manual recipe, which `clone-from`'s output should name until this lands:
`capsule <m> start`, then `capsule <m> status` and `capsule <m> record`, compare
`head` with `base.oid`, then `capsule <m> stop`.

## The improvement

Show what the host can read, without any new guest mechanism:

1. **`ahead` / at-base.** Compare the observed `head` with the record's
   `base.oid`, host-side. This costs no extra round trip, and the contract
   already lists `ahead` as an observed field.
2. **Baseline at head.** `observe` also returns the baseline record's commit.
   That is one more field in its fixed tab-separated line, and the order is
   pinned by `observeCases`, which builds the command from the shipped fragment.
3. **A `clean` column**: at base, not dirty, and baseline ok at head.

**Out of scope:** the two guest-only signals (`$HOME` touched, session opened).
They stay with `IMP-001`'s remainder of `D4`'s clean/dirty model, and `D6`
respectively. Name the column so it does not claim more than these three
signals.

## Not exercised

Nothing here has been built or run. The table above was read from
`host/observe.nix` and `host/cli.nix`'s status row on 2026-09-15.
