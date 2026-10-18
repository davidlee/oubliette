# IDE-002: A persistent assistant room over many repos (Plan F)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

One long-lived microVM holding checkouts of ~7 of the operator's repos, driven
by a runner outside this repo (`satan:IDE-007`), reaching models only through
the host's LLM gateway (`flakes:SL-011`, which `flakes:IDE-008` may move here),
returning work only as git the host fetches into per-repo quarantines. A room
(Plan E), not a slot.

The scoping, and what a plan has to settle: [plan-f-assistant.md](../../../../docs/plan-f-assistant.md).
`IMP-015` (resolved) was the precondition: the repo list and tool sets live in
the consumer flake rather than as oubliette inputs.
