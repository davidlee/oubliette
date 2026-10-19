After a NixOS switch that changes a room's image, `/var/lib/microvms/<room>/current`
still points at the old runner: the switch does not update a microvm's declared
runner. Only `microvm -u <room>` moves it — `just refresh-build <room>` does that,
then fails at its slot-only `up` step (exit 2, `ISS-026`); finish with
`capsule <room> start`. Check: the runner's closure holds the new store path
(SL-007 PHASE-05 checked for `room-base`).

Symptom when forgotten: a live check reads the *old* behaviour and looks like the
change did not work (SL-007: `session` still had no `git` until `microvm -u`).
