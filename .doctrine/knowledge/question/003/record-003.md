# QUE-003: Does an injected credential survive use

Unknown, and measurable. The token **rotates on refresh** and the capsule holds a
**copy, not the shared file** — so host and capsule drift, and how long a
capsule's copy stays good is nobody's number.

`capsule-inject --force` is the answer until it is measured, which means the
current mitigation is *re-inject when something breaks* rather than *know when it
will*.

Distinct from `CON-004`, which says a rotation does not reach a **running**
capsule and explains why that is deliberate. This asks a narrower thing: given a
copy taken at time T, at what point does it stop working?

What would answer it: one capsule, one injected token, and a periodic use until
it fails — a duration, landed in the observation ledger. Cheap, and nobody has
paid for it because a `--force` re-inject costs seconds.


## Answered (2026-11-08)

The user's estimate: an injected copy stays good for about a year, so freshness is not
the concern. That is an account, not a measurement (STD-001): no observation
was taken. What remains is the copy's *value* if it leaks, which is RSK-013,
and its way out is IDE-004.
