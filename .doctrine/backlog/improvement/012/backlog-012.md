# IMP-012: A slot says which image it is, and the record's image field stops being inert

**The insurance `plan-c` recommended and `Plan D` L1 records as not taken.** The
field is already in the record — `image`, and it is `null` on every live slot.
Nothing writes it and nothing reads it.

> Cheap insurance, taken now: the instance record carries its own `target`,
> defaulting to the single global one. Mixed-target then becomes a relaxation
> rather than a rewrite, and costs nothing today.
> — [plan-c](../../../docs/plan-c-multi-capsule.md#mixed-targets-defer-but-keep-it-possible)

`Plan D` L1: *"the cheap insurance it recommended — a `target` field on the
instance record — **was not taken**: `declared` carries `index` and nothing
else."* `CON-001` is the same absence read from the composition end.

## What is actually missing, in today's vocabulary

plan-c's one `target` field is two fields here, and only one of them exists:

| half | field | state |
| --- | --- | --- |
| run-time (the target's values) | `profile` + `profile_snapshot` | **taken** — named per slot, pinned at provision, and status marks `*`/`!` when it drifts |
| build-time (the guest image) | `image` | **inert** — `null`, written by nobody |

So a slot names the project it was *assigned* and cannot name the project it is
*running*. Today those cannot disagree, because there is one `capsuleVm` and
every declared capsule is bound to it. The moment they can, the front end is
resolving a profile for a guest that is a different project — and there is no
diff to notice, because the profile half will look perfectly correct.

## Why it is its own item, ahead of IMP-003 and IMP-006

Both of those need it and neither is it. `IMP-006` names it outright — *"a slot
has to say which image it is, or the front end is resolving a target for a guest
that is a different project"* — and calls it a prerequisite. `IMP-003` describes
the same field arriving as a consequence of per-assignment flavour selection.
Waiting for either means the binding lands in the same change that first makes it
load-bearing, which is the opposite of insurance.

It is also cheap in a way neither of them is: one field written at start, one
comparison, no second image, no `microvm -u` per slot, no 3.0 GiB of erofs.

## Shape

The runner store path is already on disk and already per-slot —
`/var/lib/microvms/<slot>/booted`, which is what the VMM actually launched, and
`current`, which is what `microvm -u` last wrote. Record the former at `start`
the way `profile_snapshot` is pinned at provision, and the record answers "which
image is this" without an eval.

Two consumers follow, and the second is why the shape matters:

- a refusal when a slot's record names an image the slot is not running;
- **staleness** — `IMP-013`, which needs a cheap answer to "what image is this
  slot" and cannot afford a flake eval in `status`.

Note `CON-001`'s observation, which is this host and not a hypothetical: *"the
fleet has run as three runner store paths at once."* The one-image lever is an
argument about the declaration, so a field that records the truth is not
redundant with it — it is the only thing that would have shown the divergence.

## The constraint this must not break

A VMM is identified by its namespace, never by its name, precisely because the
one-image lever makes every capsule `microvm@capsule` in the process table. A
per-slot image identity must not read as a per-slot process identity —
`IMP-003` carries the same warning and for the same reason.

## Evidence rung (`STD-001`)

Unbuilt. The divergence above is *observed* (three runner store paths, one of
them a month old); the harm it insures against is *reasoned*, and stays reasoned
until a second image exists.
