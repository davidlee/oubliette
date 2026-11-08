# ISS-030: No verb clears a model-door override, so a slot cannot return to as-declared

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found live in SL-010 PHASE-08, leg 9 (docs/probes.md, "A model door on one
slot, live"). `capsule <n> model on|off` writes `/var/lib/capsule-model-door/<n>`
and the record's `model_door` together; nothing removes the file or sets the
record back to `null` ("as declared", docs/contract-assignment.md). Once a slot
has been toggled, a later change to its `modelDoor` declaration has no effect
on the door. Leg 9 reached "no override" only by deleting the file by hand, and
the record then still said `"on"`, so status and the relay's condition
disagreed. Candidate: `capsule <n> model declared` (or `reset`), removing the
file and nulling the record under the same lock and hook as on/off, with its
undo rows in `policyCases`.
