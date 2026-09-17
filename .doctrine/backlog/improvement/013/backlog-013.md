# IMP-013: Nothing reports a slot booting an older image than the flake declares

**Observed, not reasoned, and it cost a session.** `SL-245` in capsule `c` was
stopped by test failures whose cause was the guest's compiler:

| | rustc |
| --- | --- |
| capsule `c` (and `b`) | `1.98.0-beta.6 (2026-07-25)` |
| this host's `flake.lock`, re-evaluated | `1.99.0-beta.4 (2026-09-06)` |

The lock was current. `/var/lib/microvms/c/current` was a symlink written
**2026-08-15** and never rewritten, because a created VM tracks its state
directory and not the flake. `just refresh-build c` is the whole fix; finding
that it was the fix is the part that cost.

## The gap

`capsule all status` reports drift on every axis but this one:

| axis | marker |
| --- | --- |
| profile document moved on from the slot's | `*` |
| pinned bytes are not the ones the record names | `!` |
| **booted image is older than the flake declares** | **nothing** |

So the one drift that presents *only as red tests inside a guest* is the one
drift the host cannot see. Every other axis fails on the host, in a verb, with a
reason. This one fails as someone else's build.

## Why it gets worse rather than staler

`IMP-006` makes a second target a second image and `IMP-003` makes the
composition per-assignment. Both turn one drift into N independent ones, each
still presenting as red tests in a different guest. `CON-001` already records
that this host *"has run as three runner store paths at once"* — so N is not
hypothetical, it is the current state under a declaration that says one.

## Shape, and the constraint on it

The comparison is `/var/lib/microvms/<slot>/booted` (what the VMM launched)
against what the flake now declares. The second half is the expensive half: a
full `nixosConfigurations.<slot>` eval is far too slow for a status line that
runs on ten slots.

So this **needs `IMP-012`** — the record carrying the image it started under —
and the cheap comparison becomes record-versus-`booted`, plus `booted`-versus-
`current` for "updated but not restarted". Both are symlink reads. Whether a
third state — *`current` is older than the flake* — is worth an eval at all, or
belongs in a separate non-status verb, is the open question.

Note `IMP-009`: status is already too wide to read. This is a fourth marker
column, not a fifth field, and it should land with or after that item rather than
widening the table again.

## Evidence rung (`STD-001`)

The failure is **observed** (one session lost, two slots measured a month behind
the lock). The proposed signal is **unbuilt**.
