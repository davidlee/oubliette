The guest's idle rule counts an `agent` session as work unless `Service=login`
or `Class` is `manager`/`manager-early`. A session in **`State=closing`** is
therefore work — confirmed live twice, and `capsule <slot> volume reset-home`
refuses with status 3 listing it.

**But a closing session is reaped the moment its last task exits.** `loginctl`
keeps the scope `active (abandoned)` with `TasksCurrent=N` only while something
is still in the cgroup; when that goes, so does the session.

So `ssh agent@guest true` — which is what the front end's `waitAnswers` runs
immediately before a clone's scrub — **leaves nothing behind**. Read three times
at the gap the scrub occupies: no session survives. The control that makes this
a real negative rather than a fast look: `setsid sleep 60 &` from an agent ssh
login *is* visible at the same gap, in `closing` with `TasksCurrent=1`.

**Why it matters:** `RV-004` `F-5` predicted the front end's own probe would
make a post-clone `start` refuse as busy. It does not, because `true` leaves no
work. The worry is sound in shape — a closing session really does refuse — and
wrong about this probe. A *heavier* probe would reproduce it, so
`setup`'s `provisionSlot` push remains untested this way.

Related: [[mem.fact.oubliette.a-detached-baseline-leaves-two-agent-sessions]],
[[mem.fact.oubliette.guest-autologins-agent-on-every-getty]].
