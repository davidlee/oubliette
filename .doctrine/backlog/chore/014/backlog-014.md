# CHR-014: Probe setup's provisionSlot push against the scrub gate

`RV-004` `F-5` asked whether the front end's own ssh traffic, opened just before
a clone's scrub, is counted as *work* by the idle rule — so that `capsule <dest>
start` or `capsule <dest> setup` refuses its own scrub as busy.

`SL-002` `VH-7` answered **half** of it. `ssh agent@guest true` — `waitAnswers`'
exact shape — leaves no session at the gap the scrub occupies, read three times,
with a `setsid sleep 60 &` control proving the read discriminates. The premise
holds: a `State=closing` `agent` session **does** refuse, seen twice
(`mem.fact.oubliette.a-closing-session-lives-as-long-as-its-work`).

**The other half is unprobed.** `setup`'s `provisionSlot` push moves a packfile
rather than exiting immediately, so its session lives longer, and it is the only
remaining path that could reproduce `F-5`. It is also the path the intended use
takes: `DEC-006` says a warm start is `volume clone-from <src>` then
`setup <ref>`.

**Shape of the probe.** Clone onto a stopped slot so a marker is pending, then
run `capsule <dest> setup <ref>` and read
`loginctl show-session -p Name -p Service -p Class -p State` for every `agent`
session at the moment the gate calls the scrub. A `closing` `agent` `sshd`
session there means the idle rule counts the front end's own traffic, which
reopens the design rather than getting patched in code.

Fail-safe either way: the gate refuses rather than injecting onto an unscrubbed
clone. The cost of `F-5` being real on this path is a warm start that cannot
complete without a stop.

Raised at `SL-002`'s closure audit as `RV-006` `F-9`, disposed follow-up.
