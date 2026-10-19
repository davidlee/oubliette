Sealing a guest means it has no egress. It does **not** stay sealed if anything it
writes can later be read by a guest that *does* have egress. A disk is the easy
way to build that by accident: attach the same block device to a sealed boot and,
later, to a networked one, and whatever the sealed side staged there leaves with
the networked side. **Removing the sealed guest's own volumes from the networked
boot doesn't help if one volume is shared.**

It is easy to miss because each boot looks safe on its own: the networked boot
"attaches only a scratch volume", the sealed boot "has no uplink". The leak is in
the *sequence*, not in either boot. `RFC-001`'s option E, a setup boot for a room,
did exactly this in its first draft, and claimed a fetcher exploit "finds nothing
to take". `RV-021` F-1 caught it.

**The rule:** data crosses from a networked boot into a sealed one, one way, on a
volume the host creates **fresh** for that networked boot from host-chosen inputs
only. The host **discards** it before the next networked boot. Attaching it
read-only on the sealed side is defence in depth, not the control.

Any cache kept across networked boots needs its own argument that no block the
sealed guest wrote can enter a networked guest, **including retry and failure
paths**. The default answer is: don't keep one.

Check any design that toggles a guest between "sealed" and "networked", or hands
a disk between two guests with different egress: trace every volume across the
whole sequence, not boot by boot.
