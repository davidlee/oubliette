# ISS-031: The model relay is triggered twice at one VM start, second source unknown

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Observed live in SL-010 PHASE-08, leg 6: with the door `off`, one stop/start of
`microvm@a` (active 22:52:21) triggered `capsule-model-relay-a` twice, at
22:52:21 and 22:52:35, each skipped by `exec-condition`. Harmless while the
condition holds, but the second trigger's source is not established: the
`microvm@` drop-in's `wants`, the `bindsTo` netns/tap units re-activating, or
something else. Establish it from the journal (`systemctl list-dependencies
--reverse`, `journalctl -o verbose` for the job's cause) before anything relies
on one start per VM start.
